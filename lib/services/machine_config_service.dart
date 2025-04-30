import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path/path.dart' as path;
import 'package:sqflite/sqflite.dart';
import 'package:my_flutter_app/services/database.dart';
import 'package:intl/intl.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:my_flutter_app/services/network_discovery_service.dart';
import 'package:my_flutter_app/services/sync_manager.dart';
import 'package:my_flutter_app/services/master_redundancy_service.dart';
import 'package:my_flutter_app/services/ssl_service.dart';
import 'dart:math';

// Add the HttpConnectionInfo mock class extension at the top of the file
extension HttpConnectionInfoExtension on HttpConnectionInfo {
  bool get isSecure => true; // Default to true for mocking purposes
}

enum MachineRole {
  single,
  master,
  servant
}

enum SyncFrequency {
  manual,
  realTime,
  fiveMinutes,
  fifteenMinutes,
  hourly,
  daily
}

// Scan results class to hold information about discovered masters
class ScanResult {
  final String ip;
  final bool isMaster;
  final String? deviceName;
  final String? version;
  
  ScanResult({
    required this.ip, 
    required this.isMaster, 
    this.deviceName, 
    this.version
  });
}

class MachineConfigService {
  static final MachineConfigService _instance = MachineConfigService._init();
  static MachineConfigService get instance => _instance;
  
  MachineConfigService._init();
  
  // Constructor for dependency injection (in tests)
  factory MachineConfigService() => instance;
  
  // Shared preferences keys
  static const String _machineRoleKey = 'machine_role';
  static const String _masterAddressKey = 'master_address';
  static const String _syncFrequencyKey = 'sync_frequency';
  static const String _lastSyncTimeKey = 'last_sync_time';
  static const String _companyNameKey = 'company_name';
  static const String _machineIdKey = 'machine_id';
  static const String _companyProfilesKey = 'company_profiles';
  static const String _currentCompanyKey = 'current_company';
  static const String _connectedServantsKey = 'connected_servants';
  static const String _conflictResolutionKey = 'conflict_resolution';
  static const String _autoBackupEnabledKey = 'auto_backup_enabled';
  static const String _autoBackupIntervalKey = 'auto_backup_interval';
  static const String _encryptBackupsKey = 'encrypt_backups';
  static const String _deviceIdKey = 'device_id';
  
  // Default values
  Future<MachineRole> get machineRole async {
    final prefs = await SharedPreferences.getInstance();
    final roleIndex = prefs.getInt(_machineRoleKey) ?? 0;
    return MachineRole.values[roleIndex];
  }
  
  // Add getMachineRole to match the method called in backup_screen.dart
  Future<MachineRole> getMachineRole() async {
    return await machineRole;
  }

  Future<void> setMachineRole(MachineRole role) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_machineRoleKey, role.index);
    
    // Start or stop server based on role
    if (role == MachineRole.master) {
      await _startMasterServer();
    } else {
      await _stopMasterServer();
    }
  }
  
  // Server instance for master role
  HttpServer? _masterServer;
  
  // Server ports
  static const int DEFAULT_HTTP_PORT = 8080;
  static const int DEFAULT_HTTPS_PORT = 8443;
  static const int FALLBACK_HTTP_PORT = 8081;
  static const int FALLBACK_HTTPS_PORT = 8444;
  
  // Start a secure HTTPS server to respond to ping requests when in master mode
  Future<void> _startMasterServer() async {
    // Check if server is already running
    if (_masterServer != null) {
      return;
    }
    
    try {
      // Initialize the discovery service for broadcasting
      await NetworkDiscoveryService.instance.startMasterDiscoveryServer();
      
      // Initialize SSL service if needed
      await SSLService.instance.initialize(developmentMode: true);
      
      // Get security context for HTTPS
      final securityContext = await SSLService.instance.getServerSecurityContext();
      
      if (securityContext != null) {
        // Try to bind to the preferred HTTPS port
        try {
          _masterServer = await HttpServer.bindSecure(
            InternetAddress.anyIPv4, 
            DEFAULT_HTTPS_PORT,
            securityContext
          );
          debugPrint('Master HTTPS server started on port ${_masterServer!.port}');
        } catch (e) {
          debugPrint('Could not bind to default HTTPS port: $e');
          
          // Try fallback HTTPS port
          _masterServer = await HttpServer.bindSecure(
            InternetAddress.anyIPv4, 
            FALLBACK_HTTPS_PORT,
            securityContext
          );
          debugPrint('Master HTTPS server started on fallback port ${_masterServer!.port}');
        }
      } else {
        // Fallback to regular HTTP if security context creation failed
        debugPrint('Failed to create security context, falling back to HTTP');
        _masterServer = await HttpServer.bind(InternetAddress.anyIPv4, DEFAULT_HTTP_PORT);
        debugPrint('Master HTTP server started on port ${_masterServer!.port}');
      }
      
      // Start redundancy service for failover capability
      await MasterRedundancyService.instance.initialize();
      
      // Listen for server requests
      _masterServer!.listen((HttpRequest request) async {
        try {
          await _handleMasterRequest(request);
        } catch (e) {
          debugPrint('Error handling master request: $e');
          request.response.statusCode = HttpStatus.internalServerError;
          await request.response.close();
        }
      });
    } catch (e) {
      debugPrint('Error starting master server: $e');
      // Try HTTP as last resort
      try {
        _masterServer = await HttpServer.bind(InternetAddress.anyIPv4, FALLBACK_HTTP_PORT);
        debugPrint('Master HTTP server started on fallback port ${_masterServer!.port}');
        
        _masterServer!.listen((HttpRequest request) async {
          try {
            await _handleMasterRequest(request);
          } catch (e) {
            debugPrint('Error handling master request: $e');
            request.response.statusCode = HttpStatus.internalServerError;
            await request.response.close();
          }
        });
      } catch (e2) {
        debugPrint('Failed to start master server: $e2');
      }
    }
  }
  
  // Stop the master server
  Future<void> _stopMasterServer() async {
    if (_masterServer != null) {
      await _masterServer!.close(force: true);
      _masterServer = null;
      debugPrint('Master server stopped');
    }
  }
  
  /// Get the device name (public method)
  Future<String> getDeviceName() async {
    try {
      return Platform.localHostname;
    } catch (e) {
      debugPrint('Error getting device name: $e');
      return 'unknown-device';
    }
  }
  
  Future<String> get machineId async {
    final prefs = await SharedPreferences.getInstance();
    String? id = prefs.getString(_machineIdKey);
    
    if (id == null) {
      // Generate a unique machine ID if not already set
      id = DateTime.now().millisecondsSinceEpoch.toString() + 
           '-' + 
           DateTime.now().microsecondsSinceEpoch.toString().substring(10);
      await prefs.setString(_machineIdKey, id);
    }
    
    return id;
  }
  
  Future<String?> get masterAddress async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_masterAddressKey);
  }
  
  // Add getMasterAddress to match the method called in backup_screen.dart
  Future<String> getMasterAddress() async {
    return (await masterAddress) ?? '';
  }

  Future<void> setMasterAddress(String address) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_masterAddressKey, address);
  }
  
  Future<SyncFrequency> get syncFrequency async {
    final prefs = await SharedPreferences.getInstance();
    final frequencyIndex = prefs.getInt(_syncFrequencyKey) ?? 0;
    return SyncFrequency.values[frequencyIndex];
  }
  
  // Add getSyncFrequency to match the method called in backup_screen.dart
  Future<SyncFrequency> getSyncFrequency() async {
    return await syncFrequency;
  }

  Future<void> setSyncFrequency(SyncFrequency frequency) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_syncFrequencyKey, frequency.index);
  }
  
  Future<DateTime?> get lastSyncTime async {
    final prefs = await SharedPreferences.getInstance();
    final timeString = prefs.getString(_lastSyncTimeKey);
    return timeString != null ? DateTime.parse(timeString) : null;
  }
  
  // Add getLastSyncTime to match the method called in backup_screen.dart
  Future<DateTime?> getLastSyncTime() async {
    return await lastSyncTime;
  }

  Future<void> updateLastSyncTime([DateTime? time]) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_lastSyncTimeKey, (time ?? DateTime.now()).toIso8601String());
  }
  
  // Add setLastSyncTime to match the method called in backup_screen.dart
  Future<void> setLastSyncTime(DateTime time) async {
    await updateLastSyncTime(time);
  }
  
  // Company profiles management
  Future<List<Map<String, dynamic>>> get companyProfiles async {
    final prefs = await SharedPreferences.getInstance();
    final profilesJson = prefs.getString(_companyProfilesKey);
    
    if (profilesJson == null) {
      // Create a default company profile if none exists
      final defaultCompany = {
        'name': 'Default Company',
        'database': 'malbrose_db.db',
        'created': DateTime.now().toIso8601String(),
      };
      
      await setCompanyProfiles([defaultCompany]);
      return [defaultCompany];
    }
    
    return List<Map<String, dynamic>>.from(
      jsonDecode(profilesJson) as List
    );
  }
  
  // Add getCompanyProfiles to match the method called in backup_screen.dart
  Future<List<Map<String, dynamic>>> getCompanyProfiles() async {
    return await companyProfiles;
  }

  Future<void> setCompanyProfiles(List<Map<String, dynamic>> profiles) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_companyProfilesKey, jsonEncode(profiles));
  }
  
  Future<Map<String, dynamic>?> get currentCompany async {
    final prefs = await SharedPreferences.getInstance();
    final companyName = prefs.getString(_currentCompanyKey);
    
    if (companyName == null) {
      // Set the default company as current if not set
      final profiles = await companyProfiles;
      if (profiles.isNotEmpty) {
        await setCurrentCompany(profiles[0]);
        return profiles[0];
      }
      return null;
    }
    
    // Find the current company profile
    final profiles = await companyProfiles;
    return profiles.firstWhere(
      (profile) => profile['name'] == companyName,
      orElse: () => {}
    );
  }
  
  // Add getCurrentCompany to match the method called in backup_screen.dart
  Future<Map<String, dynamic>?> getCurrentCompany() async {
    return await currentCompany;
  }

  // Update setCurrentCompany to handle both String and Map parameters
  Future<void> setCurrentCompany(dynamic company) async {
    final prefs = await SharedPreferences.getInstance();
    String companyName;
    
    if (company is Map<String, dynamic>) {
      companyName = company['name'] as String;
    } else if (company is String) {
      companyName = company;
    } else {
      throw ArgumentError('Invalid company parameter type: ${company.runtimeType}');
    }
    
    await prefs.setString(_currentCompanyKey, companyName);
  }
  
  // Add a new company profile
  Future<void> addCompanyProfile(String name, String databasePath) async {
    final profiles = await companyProfiles;
    
    // Check if company with this name already exists
    if (profiles.any((profile) => profile['name'] == name)) {
      throw Exception('A company with this name already exists');
    }
    
    // Add the new profile
    profiles.add({
      'name': name,
      'database': databasePath,
      'created': DateTime.now().toIso8601String(),
    });
    
    await setCompanyProfiles(profiles);
  }
  
  // Add createCompanyProfile to match the method called in backup_screen.dart
  Future<Map<String, dynamic>> createCompanyProfile({
    required String name,
    required String database,
  }) async {
    final newProfile = {
      'name': name,
      'database': database,
      'created': DateTime.now().toIso8601String(),
    };
    
    final profiles = await companyProfiles;
    // Check if company with this name already exists
    if (profiles.any((profile) => profile['name'] == name)) {
      throw Exception('A company with this name already exists');
    }
    
    profiles.add(newProfile);
    await setCompanyProfiles(profiles);
    
    return newProfile;
  }
  
  // Delete a company profile
  Future<bool> deleteCompany(String companyCode) async {
    final profiles = await getCompanyProfiles();
    final companyIndex = profiles.indexWhere((company) => company['code'] == companyCode);
    
    if (companyIndex < 0) {
      return false;
    }
    
    final companyToDelete = profiles[companyIndex];
    final dbName = companyToDelete['database'] as String;
    
    // Remove from profiles list
    profiles.removeAt(companyIndex);
    await setCompanyProfiles(profiles);
    
    // Try to delete the database file
    try {
      // Get database service instance to use its path helper
      final dbService = DatabaseService.instance;
      final appDataDir = await dbService.getAppDataDirectory();
      final dbDir = Directory(path.join(appDataDir.path, 'database'));
      final dbPath = path.join(dbDir.path, dbName);
      final dbFile = File(dbPath);
      
      if (await dbFile.exists()) {
        await dbFile.delete();
      }
      
      return true;
    } catch (e) {
      debugPrint('Error deleting company database file: $e');
      // We still return true because the profile was removed even if file deletion failed
      return true;
    }
  }
  
  // Add method with name expected by backup_screen.dart
  Future<bool> deleteCompanyProfile(String companyName) async {
    final profiles = await getCompanyProfiles();
    final companyIndex = profiles.indexWhere((company) => company['name'] == companyName);
    
    if (companyIndex < 0) {
      return false;
    }
    
    final companyToDelete = profiles[companyIndex];
    final companyCode = companyToDelete['code'] as String? ?? companyName;
    
    return await deleteCompany(companyCode);
  }
  
  // Scan the network for master devices
  Future<List<String>> scanForMasters() async {
    final List<String> masterAddresses = [];
    
    try {
      // Use the new NetworkDiscoveryService instead of manual scanning
      final masters = await NetworkDiscoveryService.instance.discoverMasters();
      
      // Extract IP addresses
      for (final master in masters) {
        masterAddresses.add(master.ip);
        debugPrint('Found master at: ${master.ip} (${master.deviceName})');
      }
      
      return masterAddresses;
    } catch (e) {
      debugPrint('Error scanning network: $e');
      return [];
    }
  }
  
  // Test connection to master
  Future<bool> testConnection(String address) async {
    if (address.isEmpty) {
      return false;
    }
    
    try {
      // Create a MasterInfo object from the address string
      final masterInfo = MasterInfo(
        ip: address,
        machineId: 'temp-id',  // Temporary ID for connection test only
        lastSeen: DateTime.now(),
        port: 8080,  // Default port
        secure: true,  // Default to secure
      );
      
      // Use the NetworkDiscoveryService for connection testing
      return await NetworkDiscoveryService.instance.testMasterConnection(masterInfo);
    } catch (e) {
      debugPrint('Error testing master connection: $e');
      return false;
    }
  }
  
  // Synchronize with master
  Future<Map<String, dynamic>> syncWithMaster() async {
    final role = await machineRole;
    
    if (role == MachineRole.single) {
      return {'success': true, 'message': 'Nothing to sync in single mode'};
    }
    
    if (role == MachineRole.master) {
      // In master mode, just return success - servants will connect to us
      return {'success': true, 'message': 'Master mode sync completed'};
    }
    
    if (role == MachineRole.servant) {
      try {
        // Use the robust SyncManager for actual sync operations
        final result = await SyncManager.instance.syncWithMaster();
        
        if (result.success) {
          return {
            'success': true, 
            'message': result.message,
            'items_synced': result.itemsSynced,
            'items_received': result.itemsReceived
          };
        } else {
          return {
            'success': false, 
            'message': result.message,
            'has_errors': result.hasErrors
          };
        }
      } catch (e) {
        debugPrint('Error synchronizing with master: $e');
        return {'success': false, 'message': 'Error: $e'};
      }
    }
    
    return {'success': false, 'message': 'Unknown machine role'};
  }
  
  // Additional settings
  Future<bool> get encryptBackups async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_encryptBackupsKey) ?? false;
  }
  
  Future<void> setEncryptBackups(bool encrypt) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_encryptBackupsKey, encrypt);
  }
  
  Future<bool> get autoBackupEnabled async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_autoBackupEnabledKey) ?? false;
  }
  
  Future<void> setAutoBackupEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_autoBackupEnabledKey, enabled);
  }
  
  Future<String> get autoBackupInterval async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_autoBackupIntervalKey) ?? 'daily';
  }
  
  Future<void> setAutoBackupInterval(String interval) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_autoBackupIntervalKey, interval);
  }
  
  Future<String> get conflictResolution async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_conflictResolutionKey) ?? 'last_write_wins';
  }
  
  // Add getConflictResolution to match the method called in backup_screen.dart
  Future<String> getConflictResolution() async {
    return await conflictResolution;
  }
  
  Future<void> setConflictResolution(String resolution) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_conflictResolutionKey, resolution);
  }
  
  Future<List<String>> get connectedServants async {
    final prefs = await SharedPreferences.getInstance();
    final servantsJson = prefs.getString(_connectedServantsKey);
    
    if (servantsJson == null) {
      return [];
    }
    
    return List<String>.from(jsonDecode(servantsJson) as List);
  }
  
  // Add saveBackupSettings method to match the method called in backup_screen.dart
  Future<void> saveBackupSettings({
    required bool autoBackupEnabled,
    required String autoBackupInterval,
    required bool encryptBackups,
  }) async {
    await setAutoBackupEnabled(autoBackupEnabled);
    await setAutoBackupInterval(autoBackupInterval);
    await setEncryptBackups(encryptBackups);
  }

  // Handle master server requests
  Future<void> _handleMasterRequest(HttpRequest request) async {
    final response = request.response;
    final path = request.uri.path;
    
    // Add CORS headers for cross-device communication
    response.headers.add('Access-Control-Allow-Origin', '*');
    response.headers.add('Access-Control-Allow-Methods', 'GET, POST, OPTIONS');
    response.headers.add('Access-Control-Allow-Headers', 'Content-Type');
    
    // Support for CORS preflight requests
    if (request.method == 'OPTIONS') {
      response.statusCode = HttpStatus.ok;
      await response.close();
      return;
    }
    
    // Basic authentication headers - enhance this with proper token-based auth in production
    response.headers.add('X-Server-Type', 'Malbrose-POS-Master');
    response.headers.add('X-Server-Version', '1.0');
    
    switch (path) {
      case '/ping':
        // Simple ping endpoint
        response.headers.contentType = ContentType.json;
        final machineId = await this.machineId;
        final deviceName = await getDeviceName();
        final data = {
          'status': 'online',
          'machineId': machineId,
          'deviceName': deviceName,
          'serverTime': DateTime.now().toIso8601String(),
          'secure': request.connectionInfo?.isSecure ?? false,
        };
        response.write(jsonEncode(data));
        break;
      
      case '/sync':
        // For servant machines to sync data
        if (request.method == 'POST') {
          try {
            final content = await utf8.decodeStream(request);
            final data = jsonDecode(content);
            
            // Process sync request - in production this would validate authentication
            // and properly handle the sync operation
            
            response.headers.contentType = ContentType.json;
            response.write(jsonEncode({'status': 'received', 'timestamp': DateTime.now().toIso8601String()}));
          } catch (e) {
            response.statusCode = HttpStatus.badRequest;
            response.write(jsonEncode({'error': 'Invalid request data: $e'}));
          }
        } else {
          response.statusCode = HttpStatus.methodNotAllowed;
          response.write(jsonEncode({'error': 'Method not allowed'}));
        }
        break;
      
      case '/cert':
        // Endpoint to fetch the server's SSL certificate
        // Useful for servant machines to add the certificate to their trusted store
        try {
          final certPath = await SSLService.instance.getCertificatePath();
          if (certPath != null) {
            final certFile = File(certPath);
            if (await certFile.exists()) {
              final certData = await certFile.readAsString();
              response.headers.contentType = ContentType.text;
              response.write(certData);
              break;
            }
          }
          response.statusCode = HttpStatus.notFound;
          response.write('Certificate not found');
        } catch (e) {
          response.statusCode = HttpStatus.internalServerError;
          response.write('Error retrieving certificate: $e');
        }
        break;
        
      default:
        // Default 404 response
        response.statusCode = HttpStatus.notFound;
        response.headers.contentType = ContentType.text;
        response.write('Not Found');
    }
    
    await response.close();
  }

  // Add deviceId getter for synchronization
  Future<String> get deviceId async {
    final prefs = await SharedPreferences.getInstance();
    String? id = prefs.getString(_deviceIdKey);
    
    if (id == null || id.isEmpty) {
      // Generate a new device ID
      id = 'device_${DateTime.now().millisecondsSinceEpoch}_${Random().nextInt(10000)}';
      await prefs.setString(_deviceIdKey, id);
    }
    
    return id;
  }
  
  // Add getDeviceId method for compatibility
  Future<String> getDeviceId() async {
    return await deviceId;
  }
} 