import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:my_flutter_app/services/database.dart';
import 'package:my_flutter_app/services/encryption_service.dart';

/// Service for managing secure audit logs for PCI DSS compliance
class AuditService {
  static final AuditService instance = AuditService._internal();
  AuditService._internal();
  
  // Initialize flag
  bool _initialized = false;
  
  // Platform channel for credential manager
  static const _platform = MethodChannel('com.malbrose.pos/secure_storage');
  
  // Initialize the audit service
  Future<void> initialize() async {
    if (_initialized) return;
    
    try {
      final db = await DatabaseService.instance.database;
      
      // Create audit log table if it doesn't exist
      await db.execute('''
        CREATE TABLE IF NOT EXISTS audit_logs (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          event_type TEXT NOT NULL,
          encrypted_details TEXT NOT NULL,
          user_id INTEGER,
          timestamp TEXT NOT NULL
        )
      ''');
      
      _initialized = true;
      
      // Log initialization
      await logEvent(
        eventType: 'system',
        action: 'audit_init',
        message: 'Audit service initialized',
        userId: 0
      );
    } catch (e) {
      debugPrint('Error initializing audit service: $e');
    }
  }
  
  /// Log a security or audit event with encryption
  Future<void> logEvent({
    required String eventType,
    required String action,
    required String message,
    Map<String, dynamic>? details,
    int? userId,
    bool writeToFile = true
  }) async {
    try {
      // Ensure service is initialized
      if (!_initialized) {
        await initialize();
      }
      
      // Build the log data
      final timestamp = DateTime.now().toIso8601String();
      final logData = {
        'action': action,
        'message': message,
        'details': details,
        'timestamp': timestamp,
        'user_id': userId,
      };
      
      // Encrypt the log data
      final encryptedDetails = await EncryptionService.instance.encryptString(
        json.encode(logData)
      );
      
      // Save to database
      final db = await DatabaseService.instance.database;
      await db.insert('audit_logs', {
        'event_type': eventType,
        'encrypted_details': encryptedDetails,
        'user_id': userId,
        'timestamp': timestamp,
      });
      
      // Optionally write to secure log file
      if (writeToFile) {
        await _writeToSecureLogFile(eventType, action, message, details, userId);
      }
    } catch (e) {
      // Last resort logging to debug console only
      debugPrint('CRITICAL: Failed to log audit event: $e');
      debugPrint('Event: $eventType, Action: $action, Message: $message');
    }
  }
  
  /// Write log to secure file for PCI DSS compliance
  Future<void> _writeToSecureLogFile(
    String eventType,
    String action,
    String message,
    Map<String, dynamic>? details,
    int? userId
  ) async {
    try {
      // Get the logs directory
      final appDocDir = await getApplicationDocumentsDirectory();
      final logDir = Directory('${appDocDir.path}/secure_logs');
      
      // Create directory if it doesn't exist
      if (!await logDir.exists()) {
        await logDir.create(recursive: true);
      }
      
      // Format date for filename
      final dateFormat = DateFormat('yyyy-MM-dd');
      final today = DateTime.now();
      final formattedDate = dateFormat.format(today);
      
      // Create log file path
      final logFile = File('${logDir.path}/audit_log_$formattedDate.log');
      
      // Format log entry
      final timestamp = DateFormat('yyyy-MM-dd HH:mm:ss.SSS').format(today);
      String detailsStr = '';
      if (details != null) {
        // Redact sensitive information in file logs
        final redactedDetails = Map<String, dynamic>.from(details);
        _redactSensitiveData(redactedDetails);
        detailsStr = json.encode(redactedDetails);
      }
      
      final logEntry = '[$timestamp] [$eventType] [User: ${userId ?? 'System'}] $action - $message - $detailsStr\n';
      
      // Append to log file
      await logFile.writeAsString(logEntry, mode: FileMode.append);
      
      // Rotate logs if needed
      await _rotateLogsIfNeeded(logDir);
    } catch (e) {
      debugPrint('Error writing to secure log file: $e');
    }
  }
  
  /// Redact sensitive data for file logs
  void _redactSensitiveData(Map<String, dynamic> data) {
    const sensitiveFields = [
      'password', 'card', 'cvv', 'ssn', 'credit', 'secret', 'token',
      'cardNumber', 'securityCode', 'pin', 'credential'
    ];
    
    data.forEach((key, value) {
      // Check if key contains sensitive information
      bool isSensitive = sensitiveFields.any((field) => 
        key.toLowerCase().contains(field.toLowerCase()));
      
      if (isSensitive) {
        // Redact value
        if (value is String) {
          data[key] = '********';
        } else if (value is int || value is double) {
          data[key] = 0;
        }
      } else if (value is Map) {
        // Recursively redact nested maps
        _redactSensitiveData(value as Map<String, dynamic>);
      } else if (value is List) {
        // Redact lists of maps
        for (var i = 0; i < value.length; i++) {
          if (value[i] is Map) {
            _redactSensitiveData(value[i] as Map<String, dynamic>);
          }
        }
      }
    });
  }
  
  /// Rotate logs to keep storage manageable
  Future<void> _rotateLogsIfNeeded(Directory logDir) async {
    try {
      // Get all log files
      final files = await logDir.list().where((entity) => 
        entity is File && entity.path.endsWith('.log')).toList();
      
      // Sort by modification time (oldest first)
      files.sort((a, b) {
        return a.statSync().modified.compareTo(b.statSync().modified);
      });
      
      // Keep only last 30 days of logs (PCI DSS requires at least 90 days)
      const maxLogFiles = 90;
      if (files.length > maxLogFiles) {
        // Delete oldest files
        for (var i = 0; i < files.length - maxLogFiles; i++) {
          await (files[i] as File).delete();
        }
      }
    } catch (e) {
      debugPrint('Error rotating log files: $e');
    }
  }
  
  /// Retrieve audit logs with decryption (for authorized viewing)
  Future<List<Map<String, dynamic>>> getAuditLogs({
    String? eventType,
    int? userId,
    DateTime? startDate,
    DateTime? endDate,
    int limit = 100,
    int offset = 0,
  }) async {
    try {
      // Build query conditions
      String whereClause = '1=1';
      List<dynamic> whereArgs = [];
      
      if (eventType != null) {
        whereClause += ' AND event_type = ?';
        whereArgs.add(eventType);
      }
      
      if (userId != null) {
        whereClause += ' AND user_id = ?';
        whereArgs.add(userId);
      }
      
      if (startDate != null) {
        whereClause += ' AND timestamp >= ?';
        whereArgs.add(startDate.toIso8601String());
      }
      
      if (endDate != null) {
        whereClause += ' AND timestamp <= ?';
        whereArgs.add(endDate.toIso8601String());
      }
      
      // Query database
      final db = await DatabaseService.instance.database;
      final results = await db.query(
        'audit_logs',
        where: whereClause,
        whereArgs: whereArgs,
        orderBy: 'timestamp DESC',
        limit: limit,
        offset: offset,
      );
      
      // Decrypt log details
      final decryptedLogs = <Map<String, dynamic>>[];
      
      for (final log in results) {
        try {
          // Decrypt the encrypted details
          final encryptedDetails = log['encrypted_details'] as String;
          final decryptedJson = await EncryptionService.instance.decryptString(encryptedDetails);
          final details = json.decode(decryptedJson) as Map<String, dynamic>;
          
          // Merge the decrypted details with log metadata
          final decryptedLog = {
            'id': log['id'],
            'event_type': log['event_type'],
            'timestamp': log['timestamp'],
            'user_id': log['user_id'],
            ...details,
          };
          
          decryptedLogs.add(decryptedLog);
        } catch (e) {
          debugPrint('Error decrypting log ${log['id']}: $e');
          
          // Add log with error message instead of details
          final errorLog = Map<String, dynamic>.from(log as Map);
          errorLog['error'] = 'Failed to decrypt log details';
          errorLog.remove('encrypted_details');
          
          decryptedLogs.add(errorLog);
        }
      }
      
      return decryptedLogs;
    } catch (e) {
      debugPrint('Error retrieving audit logs: $e');
      return [];
    }
  }
  
  /// Log a security event specific to PCI DSS requirements
  Future<void> logSecurityEvent({
    required String action,
    required String message,
    Map<String, dynamic>? details,
    int? userId,
  }) async {
    await logEvent(
      eventType: 'security',
      action: action,
      message: message,
      details: details,
      userId: userId,
      writeToFile: true
    );
  }
  
  /// Log a transaction event (useful for auditing financial operations)
  Future<void> logTransactionEvent({
    required String action,
    required String message,
    required String transactionId,
    num? amount,
    Map<String, dynamic>? details,
    int? userId,
  }) async {
    final transactionDetails = details ?? {};
    transactionDetails['transaction_id'] = transactionId;
    if (amount != null) {
      transactionDetails['amount'] = amount;
    }
    
    await logEvent(
      eventType: 'transaction',
      action: action,
      message: message,
      details: transactionDetails,
      userId: userId,
      writeToFile: true
    );
  }
  
  /// Export logs for PCI DSS audit (authorized personnel only)
  Future<String> exportAuditLogs({
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    try {
      // Default to last 90 days if no dates specified
      startDate ??= DateTime.now().subtract(const Duration(days: 90));
      endDate ??= DateTime.now();
      
      // Get logs from database
      final logs = await getAuditLogs(
        startDate: startDate,
        endDate: endDate,
        limit: 10000, // Increased limit for export
      );
      
      // Create export directory
      final appDocDir = await getApplicationDocumentsDirectory();
      final exportDir = Directory('${appDocDir.path}/exports');
      
      if (!await exportDir.exists()) {
        await exportDir.create(recursive: true);
      }
      
      // Create export file
      final dateFormat = DateFormat('yyyyMMdd_HHmmss');
      final fileName = 'audit_export_${dateFormat.format(DateTime.now())}.json';
      final exportFile = File('${exportDir.path}/$fileName');
      
      // Write logs to file with formatting
      await exportFile.writeAsString(json.encode({
        'export_date': DateTime.now().toIso8601String(),
        'start_date': startDate.toIso8601String(),
        'end_date': endDate.toIso8601String(),
        'total_logs': logs.length,
        'logs': logs,
      }, toEncodable: _jsonEncodable));
      
      // Return the export file path
      return exportFile.path;
    } catch (e) {
      debugPrint('Error exporting audit logs: $e');
      throw Exception('Failed to export audit logs: $e');
    }
  }
  
  // Helper for JSON encoding DateTime objects
  dynamic _jsonEncodable(dynamic item) {
    if (item is DateTime) {
      return item.toIso8601String();
    }
    return item;
  }
} 