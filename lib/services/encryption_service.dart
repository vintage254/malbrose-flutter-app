import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:encrypt/encrypt.dart' as encrypt;
import 'package:path_provider/path_provider.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:path/path.dart' as p;

/// Service for encrypting and decrypting sensitive data
class EncryptionService {
  static final EncryptionService _instance = EncryptionService._internal();
  static EncryptionService get instance => _instance;
  
  EncryptionService._internal();
  
  // Platform channel for native code integration (Windows DPAPI)
  static const _platform = MethodChannel('com.malbrose.pos/secure_storage');
  
  // Fallback secure storage for non-Windows platforms
  final _secureStorage = FlutterSecureStorage();
  
  // Cache the encryption key to avoid frequent platform channel calls
  encrypt.Key? _encryptionKey;
  final encrypt.IV _iv = encrypt.IV.fromLength(16); // Fixed IV for simplicity
  
  // Initialize the encryption service
  Future<void> initialize() async {
    // Ensure we have a valid encryption key
    await _getOrCreateEncryptionKey();
  }
  
  // Get or create an encryption key, securely stored
  Future<encrypt.Key> _getOrCreateEncryptionKey() async {
    if (_encryptionKey != null) {
      return _encryptionKey!;
    }
    
    try {
      String? keyString;
      
      // Try to get existing key
      if (Platform.isWindows) {
        // Use Windows DPAPI via platform channel
        try {
          keyString = await _platform.invokeMethod<String>('getEncryptionKey');
        } on PlatformException catch (e) {
          debugPrint('Error getting key from Windows DPAPI: $e');
          // Fall back to secure storage
          keyString = await _secureStorage.read(key: 'encryption_key');
        }
      } else {
        // Use secure storage for other platforms
        keyString = await _secureStorage.read(key: 'encryption_key');
      }
      
      // If no key exists, create a new one
      if (keyString == null) {
        // Generate a new random key
        final newKey = encrypt.Key.fromSecureRandom(32);
        keyString = base64.encode(newKey.bytes);
        
        // Store the new key
        if (Platform.isWindows) {
          try {
            await _platform.invokeMethod<void>(
              'setEncryptionKey',
              {'key': keyString}
            );
          } on PlatformException catch (e) {
            debugPrint('Error storing key to Windows DPAPI: $e');
            // Fall back to secure storage
            await _secureStorage.write(key: 'encryption_key', value: keyString);
          }
        } else {
          await _secureStorage.write(key: 'encryption_key', value: keyString);
        }
        
        _encryptionKey = newKey;
        return newKey;
      }
      
      // Convert existing key string to Key object
      final keyBytes = base64.decode(keyString);
      _encryptionKey = encrypt.Key(Uint8List.fromList(keyBytes));
      return _encryptionKey!;
    } catch (e) {
      // If all else fails, use a fallback key (not secure, but better than crashing)
      debugPrint('Error getting or creating encryption key: $e');
      _encryptionKey = encrypt.Key.fromUtf8('fallback_key_please_replace_me_asap_now');
      return _encryptionKey!;
    }
  }
  
  // Encrypt sensitive string data with optional key parameter
  Future<String> encryptString(String data, {String? key}) async {
    try {
      encrypt.Key encryptionKey;
      
      if (key != null) {
        // Use the provided key
        final keyBytes = base64.decode(key);
        encryptionKey = encrypt.Key(Uint8List.fromList(keyBytes));
      } else {
        // Use the stored key
        encryptionKey = await _getOrCreateEncryptionKey();
      }
      
      final encrypter = encrypt.Encrypter(encrypt.AES(encryptionKey));
      final encrypted = encrypter.encrypt(data, iv: _iv);
      return encrypted.base64;
    } catch (e) {
      debugPrint('Error encrypting data: $e');
      // For PCI DSS compliance, we should not return unencrypted data
      // Instead, throw an exception to be handled by the caller
      throw Exception('Encryption failed: $e');
    }
  }
  
  // Decrypt sensitive string data with optional key parameter
  Future<String> decryptString(String encryptedData, {String? key}) async {
    try {
      // Handle data that couldn't be encrypted
      if (encryptedData.startsWith('UNENCRYPTED:')) {
        debugPrint('WARNING: Attempting to decrypt unencrypted data');
        return encryptedData.substring(12);
      }
      
      // Check if the data appears to be encrypted
      if (!_isLikelyEncrypted(encryptedData)) {
        debugPrint('WARNING: Data does not appear to be encrypted, returning as is: ${encryptedData.substring(0, min(10, encryptedData.length))}...');
        return encryptedData;
      }
      
      encrypt.Key encryptionKey;
      
      if (key != null) {
        // Use the provided key
        final keyBytes = base64.decode(key);
        encryptionKey = encrypt.Key(Uint8List.fromList(keyBytes));
      } else {
        // Use the stored key
        encryptionKey = await _getOrCreateEncryptionKey();
      }
      
      final encrypter = encrypt.Encrypter(encrypt.AES(encryptionKey));
      final decrypted = encrypter.decrypt64(encryptedData, iv: _iv);
      return decrypted;
    } catch (e) {
      debugPrint('Error decrypting data: $e');
      // For PCI DSS compliance, we should log this error
      await _logDecryptionError(e.toString(), encryptedData.substring(0, min(10, encryptedData.length)) + '...');
      // Return the original data instead of throwing an exception
      return encryptedData;
    }
  }
  
  // Check if a string is likely to be encrypted (base64-encoded AES output)
  bool _isLikelyEncrypted(String data) {
    // Base64 regex pattern
    final base64Pattern = RegExp(r'^[A-Za-z0-9+/]*={0,2}$');
    
    // Check if the string matches base64 pattern and has reasonable length for encrypted data
    return base64Pattern.hasMatch(data) && 
           data.length > 16 && // Minimum reasonable length for encrypted content
           !data.contains('@') && // Simple heuristic: emails have @ 
           !data.contains(' '); // Encrypted data shouldn't have spaces
  }
  
  // Log decryption errors securely
  Future<void> _logDecryptionError(String errorMessage, String dataPreview) async {
    try {
      // Get application documents directory
      final appDocDir = await getApplicationDocumentsDirectory();
      final logDir = Directory('${appDocDir.path}/logs');
      
      // Create logs directory if it doesn't exist
      if (!await logDir.exists()) {
        await logDir.create(recursive: true);
      }
      
      // Create log file with timestamp
      final now = DateTime.now();
      final logFile = File('${logDir.path}/encryption_errors_${now.year}${now.month}${now.day}.log');
      
      // Append to log file
      final timestamp = now.toIso8601String();
      final logEntry = '$timestamp - ERROR - $errorMessage - Data preview: $dataPreview\n';
      
      await logFile.writeAsString(logEntry, mode: FileMode.append);
    } catch (e) {
      debugPrint('Error logging decryption error: $e');
    }
  }
  
  // Encrypt a map (for storing in JSON)
  Future<Map<String, dynamic>> encryptMap(
    Map<String, dynamic> data, 
    {List<String>? sensitiveKeys, String? key}
  ) async {
    final result = Map<String, dynamic>.from(data);
    final keysToEncrypt = sensitiveKeys ?? _getDefaultSensitiveKeys();
    
    for (final keyName in keysToEncrypt) {
      if (result.containsKey(keyName) && result[keyName] != null) {
        if (result[keyName] is String) {
          result[keyName] = await encryptString(result[keyName] as String, key: key);
        } else if (result[keyName] is num || result[keyName] is bool) {
          result[keyName] = await encryptString(result[keyName].toString(), key: key);
        } else if (result[keyName] is Map) {
          // Recursively encrypt maps
          result[keyName] = await encryptMap(
            Map<String, dynamic>.from(result[keyName] as Map),
            sensitiveKeys: sensitiveKeys,
            key: key
          );
        }
      }
    }
    
    return result;
  }
  
  // Decrypt a map
  Future<Map<String, dynamic>> decryptMap(
    Map<String, dynamic> data, 
    {List<String>? sensitiveKeys, String? key}
  ) async {
    final result = Map<String, dynamic>.from(data);
    final keysToDecrypt = sensitiveKeys ?? _getDefaultSensitiveKeys();
    
    for (final keyName in keysToDecrypt) {
      if (result.containsKey(keyName) && result[keyName] != null) {
        if (result[keyName] is String) {
          try {
            result[keyName] = await decryptString(result[keyName] as String, key: key);
          } catch (e) {
            // Log but continue with other fields
            debugPrint('Error decrypting field $keyName: $e');
          }
        } else if (result[keyName] is Map) {
          // Recursively decrypt maps
          result[keyName] = await decryptMap(
            Map<String, dynamic>.from(result[keyName] as Map),
            sensitiveKeys: sensitiveKeys,
            key: key
          );
        }
      }
    }
    
    return result;
  }
  
  // Get the default list of sensitive keys to encrypt in maps
  List<String> _getDefaultSensitiveKeys() {
    return [
      'password', 'password_hash', 'credit_card', 'card_number', 'cvv', 
      'ssn', 'address', 'phone', 'email', 'tax_id', 'notes', 'pin',
      'bank_account', 'routing_number', 'security_question', 'security_answer',
      'cardDetails', 'customerInfo', 'paymentInfo', 'order_details',
      'receipt', 'payment_token', 'authorization_code'
    ];
  }

  // Generate a secure random encryption key
  Future<String> generateSecureKey() async {
    final newKey = encrypt.Key.fromSecureRandom(32);
    return base64.encode(newKey.bytes);
  }

  // Decrypt a field in a map if it's in the sensitive fields list
  Future<dynamic> decryptMapField(String field, dynamic value) async {
    // No decryption needed for null or non-string values
    if (value == null || value is! String) {
      return value;
    }

    // Check if this field should be decrypted
    if (_getDefaultSensitiveKeys().contains(field)) {
      try {
        // Only attempt decryption if it looks like encrypted data
        if (_isLikelyEncrypted(value)) {
          return await decryptString(value);
        } else {
          debugPrint('WARNING: Field $field has unencrypted value, returning as is.');
          return value;
        }
      } catch (e) {
        debugPrint('Error decrypting field $field: $e');
        // For PCI DSS compliance, log the error
        await _logDecryptionError(e.toString(), 'Field: $field');
        // Return the original value
        return value;
      }
    }
    
    return value;
  }
}

/// Extension method for easy encryption/decryption of maps
extension EncryptableMap on Map<String, dynamic> {
  Future<Map<String, dynamic>> encrypt({List<String>? sensitiveKeys}) async {
    return await EncryptionService.instance.encryptMap(this, sensitiveKeys: sensitiveKeys);
  }
  
  Future<Map<String, dynamic>> decrypt({List<String>? sensitiveKeys}) async {
    return await EncryptionService.instance.decryptMap(this, sensitiveKeys: sensitiveKeys);
  }
} 