import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LicenseService {
  static final LicenseService instance = LicenseService._init();
  
  // Private constructor
  LicenseService._init();
  
  // Constants
  static const String _firstLaunchKey = 'first_launch_date';
  static const String _licenseKey = 'license_key';
  static const int _trialPeriodDays = 14;
  
  // Secret salt for SHA-256 (don't change this or existing keys will be invalid)
  static const String _salt = "MalbroseSecuritySalt2024";
  
  // Get license status
  Future<Map<String, dynamic>> getLicenseStatus() async {
    final prefs = await SharedPreferences.getInstance();
    final licenseKey = prefs.getString(_licenseKey);
    
    // If a license key is stored and valid, app is licensed
    if (licenseKey != null && await _verifyLicenseKey(licenseKey)) {
      return {
        'isLicensed': true,
        'licenseKey': licenseKey,
        'daysRemaining': -1, // -1 means unlimited (licensed)
        'message': 'Licensed version',
      };
    }
    
    // Otherwise check trial period
    final firstLaunchDate = prefs.getString(_firstLaunchKey);
    
    // If this is the first launch, set the date
    if (firstLaunchDate == null) {
      final now = DateTime.now().toIso8601String();
      await prefs.setString(_firstLaunchKey, now);
      return {
        'isLicensed': false,
        'licenseKey': null,
        'daysRemaining': _trialPeriodDays,
        'message': 'Trial period: $_trialPeriodDays days remaining',
      };
    }
    
    // Calculate days remaining in trial
    final startDate = DateTime.parse(firstLaunchDate);
    final currentDate = DateTime.now();
    final difference = currentDate.difference(startDate);
    final daysRemaining = _trialPeriodDays - difference.inDays;
    
    // If trial period has expired
    if (daysRemaining <= 0) {
      return {
        'isLicensed': false,
        'licenseKey': null,
        'daysRemaining': 0,
        'message': 'Trial period has expired. Please enter a license key.',
      };
    }
    
    // Still in trial period
    return {
      'isLicensed': false,
      'licenseKey': null,
      'daysRemaining': daysRemaining,
      'message': 'Trial period: $daysRemaining days remaining',
    };
  }
  
  // Apply a license key
  Future<Map<String, dynamic>> applyLicenseKey(String key) async {
    // Normalize the license key (remove spaces, make uppercase)
    final normalizedKey = key.replaceAll(' ', '').toUpperCase();
    
    // Verify the license key
    final isValid = await _verifyLicenseKey(normalizedKey);
    
    if (isValid) {
      // Save the license key
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_licenseKey, normalizedKey);
      
      return {
        'success': true,
        'message': 'License key applied successfully.',
      };
    }
    
    return {
      'success': false,
      'message': 'Invalid license key. Please try again.',
    };
  }
  
  // Reset the license (for testing purposes)
  Future<void> resetLicense() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_licenseKey);
    await prefs.remove(_firstLaunchKey);
  }
  
  // Verify a license key
  Future<bool> _verifyLicenseKey(String key) async {
    try {
      // All these keys are valid (pre-hashed with SHA-256 for security)
      final validLicenseHashes = [
        // Hash of "MALBROSE-2024-OFFICIAL-LICENSE" + salt
        "0fa8935c9b3c71b1f3b90cbfc76ac79ae1a3aad9cc66e256d19a3b8f5f71dea7",
        
        // Hash of "MALBROSE-1234-5678-9012-3456" + salt (legacy key)
        "de2f71c1312f49b9d7a3e4b51b6e10bd40c598fa46c51e6da9bd3d45ed38057d",
        
        // Hash of "MALBROSE-DEMO-2023-1234-5678" + salt (legacy key)
        "f78e4a8b01cf30f1cc1423b3a51dec3c7fdb0ca6bbfa9c3c40839d2affd1698a"
      ];
      
      // Calculate SHA-256 hash of the entered key with salt
      final hash = sha256.convert(utf8.encode(key + _salt)).toString();
      
      // Check if the hash matches any of our valid hashes
      return validLicenseHashes.contains(hash);
    } catch (e) {
      debugPrint('Error during license verification: $e');
      return false;
    }
  }
  
  // Get the universal license key to share with all customers
  String getUniversalLicenseKey() {
    return 'MALBROSE-2024-OFFICIAL-LICENSE';
  }
} 