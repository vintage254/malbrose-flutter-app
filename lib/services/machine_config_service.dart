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
  
  // Start a simple HTTP server to respond to ping requests when in master mode
  Future<void> _startMasterServer() async {
    // Check if server is already running
    if (_masterServer != null) {
      return;
    }
    
    try {
      // Initialize the discovery service for broadcasting
      await NetworkDiscoveryService.instance.startMasterDiscoveryServer();
      
      // Start the HTTP server on port 8080
      _masterServer = await HttpServer.bind(InternetAddress.anyIPv4, 8080);
      debugPrint('Master server started on port 8080');
      
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
      // Try a different port if 8080 is in use
      try {
        _masterServer = await HttpServer.bind(InternetAddress.anyIPv4, 8081);
        debugPrint('Master server started on port 8081');
        
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
  
  // Delete a company profile by name
  Future<bool> deleteCompanyProfile(String companyName) async {
    final profiles = await companyProfiles;
    
    // Check if company exists
    final companyIndex = profiles.indexWhere((profile) => profile['name'] == companyName);
    if (companyIndex == -1) {
      throw Exception('Company profile not found');
    }
    
    // Check if this is the current company
    final current = await currentCompany;
    if (current != null && current['name'] == companyName) {
      throw Exception('Cannot delete the currently active company');
    }
    
    // Get the database path
    final companyToDelete = profiles[companyIndex];
    final dbName = companyToDelete['database'] as String;
    
    // Remove from profiles list
    profiles.removeAt(companyIndex);
    await setCompanyProfiles(profiles);
    
    // Try to delete the database file
    try {
      final dbDir = await getDatabasesPath();
      final dbPath = path.join(dbDir, dbName);
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
      // Use the NetworkDiscoveryService for connection testing
      return await NetworkDiscoveryService.instance.testMasterConnection(address);
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

  // Handle HTTP requests to the master server
  Future<void> _handleMasterRequest(HttpRequest request) async {
    // Set CORS headers for all responses
    request.response.headers.add('Access-Control-Allow-Origin', '*');
    request.response.headers.add('Access-Control-Allow-Methods', 'GET, POST, OPTIONS');
    request.response.headers.add('Access-Control-Allow-Headers', '*');
    
    // Handle preflight OPTIONS requests
    if (request.method == 'OPTIONS') {
      request.response.statusCode = HttpStatus.ok;
      await request.response.close();
      return;
    }
    
    // Check if this machine is the active leader
    final leaderInfo = await MasterRedundancyService.instance.getCurrentLeader();
    final myMachineId = await machineId;
    
    if (leaderInfo != null && leaderInfo.machineId != myMachineId && leaderInfo.isActive) {
      // Not the active leader, redirect if we can
      if (request.uri.path != '/api/ping') {
        // For ping requests, still respond to help with discovery
        final masters = await NetworkDiscoveryService.instance.discoverMasters();
        final activeMaster = masters.where((m) => m.machineId == leaderInfo.machineId).toList();
        
        if (activeMaster.isNotEmpty) {
          // Redirect to the active leader
          request.response.statusCode = HttpStatus.temporaryRedirect;
          request.response.headers.set('Location', 
              '${activeMaster.first.connectionUrl}${request.uri.path}');
          await request.response.close();
          return;
        }
      }
    }
    
    // Process the request based on path
    switch (request.uri.path) {
      case '/api/ping':
        await _handlePingRequest(request);
        break;
      case '/api/sync':
        await _handleSyncRequest(request);
        break;
      default:
        request.response.statusCode = HttpStatus.notFound;
        await request.response.close();
    }
  }

  // Handle ping requests
  Future<void> _handlePingRequest(HttpRequest request) async {
    // Get leader info for response
    final leaderInfo = await MasterRedundancyService.instance.getCurrentLeader();
    final myMachineId = await machineId;
    final isLeader = leaderInfo == null || leaderInfo.machineId == myMachineId;
    
    // Respond with JSON
    request.response.headers.contentType = ContentType.json;
    final responseData = {
      'status': 'ok',
      'role': 'master',
      'machine_id': myMachineId,
      'device_name': await getDeviceName(),
      'version': '1.0.0', // App version
      'timestamp': DateTime.now().toIso8601String(),
      'is_leader': isLeader,
      'leader_id': leaderInfo?.machineId
    };
    
    request.response.write(jsonEncode(responseData));
    await request.response.close();
  }

  // Handle sync requests
  Future<void> _handleSyncRequest(HttpRequest request) async {
    // Validate request method
    if (request.method != 'POST') {
      request.response.statusCode = HttpStatus.methodNotAllowed;
      await request.response.close();
      return;
    }
    
    // Authenticate the request
    final authHeader = request.headers.value('X-Auth-Token');
    final machineIdHeader = request.headers.value('X-Machine-ID');
    
    if (machineIdHeader == null) {
      request.response.statusCode = HttpStatus.unauthorized;
      request.response.write(jsonEncode({
        'error': 'Missing machine ID header'
      }));
      await request.response.close();
      return;
    }
    
    // In a production app, we would validate the auth token
    // For now, just log the connection
    debugPrint('Sync request from machine: $machineIdHeader');
    
    try {
      // Read request body
      final requestBody = await utf8.decoder.bind(request).join();
      final requestData = jsonDecode(requestBody) as Map<String, dynamic>;
      
      // Process the sync request using the sync manager
      // This would typically:
      // 1. Extract changes from the request
      // 2. Apply them to our database
      // 3. Get changes to send back
      // 4. Respond with those changes
      
      // For now, we'll just echo back an empty successful response
      final responseData = {
        'success': true,
        'message': 'Sync request processed',
        'changes': {}, // In a real implementation, this would contain changes for the client
        'timestamp': DateTime.now().toIso8601String()
      };
      
      request.response.headers.contentType = ContentType.json;
      request.response.write(jsonEncode(responseData));
      await request.response.close();
      
      // Track the sync in activity logs
      final db = await DatabaseService.instance.database;
      await db.insert('activity_logs', {
        'event_type': 'sync_request',
        'message': 'Sync request from $machineIdHeader',
        'timestamp': DateTime.now().toIso8601String(),
        'details': requestBody
      });
      
    } catch (e) {
      debugPrint('Error processing sync request: $e');
      request.response.statusCode = HttpStatus.internalServerError;
      request.response.write(jsonEncode({
        'error': 'Internal server error: $e'
      }));
      await request.response.close();
    }
  }
} 