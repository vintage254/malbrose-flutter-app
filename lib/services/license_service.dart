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
  
  // Demo license keys for testing
  static const List<String> _validLicenseKeys = [
    'MALBROSE-1234-5678-9012-3456',
    'MALBROSE-DEMO-2023-1234-5678',
  ];
  
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
    // For demonstration purposes, we're using a simple validation
    // In production, you would want to verify against a server or use more robust validation
    
    // Simple check against valid keys list
    if (_validLicenseKeys.contains(key)) {
      return true;
    }
    
    // For more complex validation, you could implement a checksum algorithm
    // This is just a simple example - replace with your actual validation logic
    if (key.startsWith('MALBROSE-') && 
        key.length == 24 && 
        key.split('-').length == 5) {
      
      // Additional validation could be performed here
      // For example, checking if the key contains a valid checksum
      
      // Mock validation for demonstration
      final baseKey = key.substring(0, 20);
      final checksum = key.substring(20);
      
      // Using a simple hash for validation (not secure, just for demo)
      final hash = md5.convert(utf8.encode(baseKey)).toString().substring(0, 4);
      
      return hash.toUpperCase() == checksum;
    }
    
    return false;
  }
} 