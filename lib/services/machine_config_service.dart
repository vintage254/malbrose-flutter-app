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
  
  // Switch to a different company
  Future<void> switchCompany(String companyName) async {
    final profiles = await companyProfiles;
    
    // Check if company exists
    final targetCompany = profiles.firstWhere(
      (profile) => profile['name'] == companyName,
      orElse: () => throw Exception('Company profile not found')
    );
    
    // Check if the database file exists
    final dbDir = await getDatabasesPath();
    final dbPath = path.join(dbDir, targetCompany['database']);
    final dbFile = File(dbPath);
    
    if (!await dbFile.exists()) {
      throw Exception('Database file not found: ${targetCompany['database']}');
    }
    
    // Close current database connection
    final db = await DatabaseService.instance.database;
    await db.close();
    
    // Set current company
    await setCurrentCompany(targetCompany);
    
    // Tell database service to reinitialize with the new database
    await DatabaseService.instance.switchDatabase(targetCompany['database']);
  }
  
  // Create a new company with empty database
  Future<void> createNewCompany(String name) async {
    final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
    final dbName = 'malbrose_${name.replaceAll(RegExp(r'[^\w]'), '_').toLowerCase()}_$timestamp.db';
    
    // Create empty database with schema
    final dbDir = await getDatabasesPath();
    final dbPath = path.join(dbDir, dbName);
    
    // Get schema from current database
    final currentDb = await DatabaseService.instance.database;
    final tables = await currentDb.rawQuery(
      "SELECT name, sql FROM sqlite_master WHERE type='table' AND name NOT LIKE 'sqlite_%'"
    );
    
    // Create new database with schema only
    final newDb = await openDatabase(
      dbPath,
      version: 1,
      onCreate: (db, version) async {
        for (final table in tables) {
          final sql = table['sql'] as String?;
          if (sql != null && sql.isNotEmpty) {
            await db.execute(sql);
          }
        }
      }
    );
    
    await newDb.close();
    
    // Add to company profiles
    await addCompanyProfile(name, dbName);
    
    // Switch to the new company
    await switchCompany(name);
  }
  
  // Test connection to master
  Future<bool> testConnection(String address) async {
    if (address.isEmpty) {
      return false;
    }
    
    try {
      // Test connection by sending a ping to the master
      final response = await http.get(
        Uri.parse('http://$address/api/ping'),
        headers: {'X-Machine-ID': await machineId}
      ).timeout(const Duration(seconds: 5));
      
      return response.statusCode == 200;
    } catch (e) {
      debugPrint('Error testing master connection: $e');
      return false;
    }
  }
  
  // Synchronize with master (basic implementation)
  Future<Map<String, dynamic>> syncWithMaster() async {
    final role = await machineRole;
    
    if (role == MachineRole.single) {
      return {'success': true, 'message': 'Nothing to sync in single mode'};
    }
    
    if (role == MachineRole.master) {
      // In master mode, we would handle incoming sync requests
      // This would typically involve a server implementation
      // For now, just log the call
      debugPrint('Master mode sync: Would handle incoming sync requests');
      return {'success': true, 'message': 'Master mode sync completed'};
    }
    
    if (role == MachineRole.servant) {
      final address = await masterAddress;
      if (address == null || address.isEmpty) {
        return {'success': false, 'message': 'Master address not set'};
      }
      
      try {
        // Get changes since last sync
        final db = await DatabaseService.instance.database;
        final lastSync = await lastSyncTime;
        final lastSyncFormatted = lastSync?.toIso8601String() ?? '2000-01-01T00:00:00.000Z';
        
        // Get all tables
        final tables = await db.rawQuery(
          "SELECT name FROM sqlite_master WHERE type='table' AND name NOT LIKE 'sqlite_%'"
        );
        
        // For each table, get changes since last sync
        Map<String, List<Map<String, dynamic>>> changes = {};
        
        for (final table in tables) {
          final tableName = table['name'] as String?;
          if (tableName == null) continue;
          
          // Only sync tables that have updated_at column
          try {
            final tableInfo = await db.rawQuery('PRAGMA table_info($tableName)');
            final hasUpdatedAt = tableInfo.any((col) => col['name'] == 'updated_at');
            
            if (hasUpdatedAt) {
              final rows = await db.query(
                tableName,
                where: 'updated_at > ?',
                whereArgs: [lastSyncFormatted],
              );
              
              if (rows.isNotEmpty) {
                changes[tableName] = rows;
              }
            }
          } catch (e) {
            debugPrint('Error getting changes for table $tableName: $e');
          }
        }
        
        // Send changes to master
        if (changes.isNotEmpty) {
          final response = await http.post(
            Uri.parse('http://$address/api/sync'),
            headers: {
              'Content-Type': 'application/json',
              'X-Machine-ID': await machineId,
            },
            body: jsonEncode({
              'changes': changes,
              'last_sync': lastSyncFormatted,
            }),
          ).timeout(const Duration(seconds: 30));
          
          if (response.statusCode == 200) {
            // Apply changes from master
            final masterChanges = jsonDecode(response.body) as Map<String, dynamic>?;
            
            if (masterChanges != null && masterChanges.containsKey('changes')) {
              final changesFromMaster = masterChanges['changes'] as Map<String, dynamic>;
              
              await db.transaction((txn) async {
                for (final tableName in changesFromMaster.keys) {
                  final rows = changesFromMaster[tableName] as List<dynamic>;
                  
                  for (final row in rows) {
                    final rowData = Map<String, dynamic>.from(row as Map);
                    
                    // Check if the row exists
                    final id = rowData['id'];
                    if (id != null) {
                      final existingRow = await txn.query(
                        tableName,
                        where: 'id = ?',
                        whereArgs: [id],
                        limit: 1,
                      );
                      
                      if (existingRow.isNotEmpty) {
                        // Update existing row
                        await txn.update(
                          tableName,
                          rowData,
                          where: 'id = ?',
                          whereArgs: [id],
                        );
                      } else {
                        // Insert new row
                        await txn.insert(tableName, rowData);
                      }
                    }
                  }
                }
              });
            }
            
            return {'success': true, 'message': 'Sync completed successfully'};
          }
          return {'success': false, 'message': 'Sync failed: Server error'};
        } else {
          // No changes to send
          return {'success': true, 'message': 'No changes to sync'};
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
} 