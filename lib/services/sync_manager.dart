import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import 'package:synchronized/synchronized.dart';

import 'package:my_flutter_app/services/database.dart';
import 'package:my_flutter_app/services/machine_config_service.dart';
import 'package:my_flutter_app/services/network_discovery_service.dart';

/// Manages data synchronization between master and servant devices
class SyncManager {
  static final SyncManager _instance = SyncManager._internal();
  static SyncManager get instance => _instance;
  
  SyncManager._internal();
  
  // For testing purposes
  factory SyncManager() => _instance;
  
  // Queue for pending sync operations
  final Queue<SyncItem> _syncQueue = Queue<SyncItem>();
  
  // Lock for queue operations
  final Lock _queueLock = Lock();
  
  // Lock for sync operations
  final Lock _syncLock = Lock();
  
  // Status tracking
  bool _isSyncing = false;
  DateTime? _lastSyncAttempt;
  DateTime? _lastSuccessfulSync;
  String? _lastSyncError;
  
  // Sync events
  final StreamController<SyncEvent> _syncEvents = StreamController<SyncEvent>.broadcast();
  Stream<SyncEvent> get onSyncEvent => _syncEvents.stream;
  
  // Timer for periodic sync
  Timer? _syncTimer;
  
  // Initialize the sync manager
  Future<void> initialize() async {
    // Set up the sync database table if it doesn't exist
    final db = await DatabaseService.instance.database;
    
    await db.execute('''
      CREATE TABLE IF NOT EXISTS sync_queue (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        table_name TEXT NOT NULL,
        record_id TEXT NOT NULL,
        data TEXT NOT NULL,
        operation TEXT NOT NULL,
        priority INTEGER NOT NULL DEFAULT 5,
        created_at TEXT NOT NULL,
        attempts INTEGER NOT NULL DEFAULT 0,
        last_attempt TEXT,
        error TEXT,
        UNIQUE(table_name, record_id, operation)
      )
    ''');
    
    await db.execute('''
      CREATE TABLE IF NOT EXISTS sync_log (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        event_type TEXT NOT NULL,
        message TEXT NOT NULL,
        timestamp TEXT NOT NULL,
        details TEXT
      )
    ''');
    
    // Load any pending sync items from database
    await _loadPendingSyncItems();
    
    // Start periodic sync if in servant mode
    await _configureSyncTimer();
    
    _logSyncEvent('Sync manager initialized', 'init');
  }
  
  // Load pending sync items from database
  Future<void> _loadPendingSyncItems() async {
    await _queueLock.synchronized(() async {
      final db = await DatabaseService.instance.database;
      
      // Get all pending sync items, ordered by priority (highest first)
      final items = await db.query(
        'sync_queue',
        orderBy: 'priority DESC, created_at ASC'
      );
      
      _syncQueue.clear();
      
      for (final item in items) {
        _syncQueue.add(SyncItem.fromMap(item));
      }
      
      if (_syncQueue.isNotEmpty) {
        debugPrint('Loaded ${_syncQueue.length} pending sync items from database');
      }
    });
  }
  
  // Configure the sync timer based on settings
  Future<void> _configureSyncTimer() async {
    _syncTimer?.cancel();
    
    final role = await MachineConfigService.instance.machineRole;
    if (role != MachineRole.servant) {
      return; // No sync timer needed for non-servant roles
    }
    
    final syncFrequency = await MachineConfigService.instance.syncFrequency;
    
    // Set timer interval based on sync frequency
    Duration interval;
    switch (syncFrequency) {
      case SyncFrequency.realTime:
        interval = const Duration(seconds: 30);
        break;
      case SyncFrequency.fiveMinutes:
        interval = const Duration(minutes: 5);
        break;
      case SyncFrequency.fifteenMinutes:
        interval = const Duration(minutes: 15);
        break;
      case SyncFrequency.hourly:
        interval = const Duration(hours: 1);
        break;
      case SyncFrequency.daily:
        interval = const Duration(hours: 24);
        break;
      case SyncFrequency.manual:
      default:
        return; // No timer for manual sync
    }
    
    _syncTimer = Timer.periodic(interval, (_) => syncWithMaster());
    debugPrint('Sync timer configured to run every ${interval.inSeconds} seconds');
  }
  
  // Queue a change for synchronization
  Future<void> queueChange({
    required String table, 
    required String recordId,
    required Map<String, dynamic> data,
    required SyncOperation operation,
    int priority = 5
  }) async {
    await _queueLock.synchronized(() async {
      // Create sync item
      final item = SyncItem(
        table: table,
        recordId: recordId,
        data: data,
        operation: operation,
        priority: priority,
        createdAt: DateTime.now(),
      );
      
      // Add to queue
      _syncQueue.add(item);
      
      // Sort queue by priority
      _sortQueue();
      
      // Save to database
      await _saveSyncItemToDatabase(item);
      
      // Attempt immediate sync for high priority items
      if (priority >= 8) {
        _triggerSync();
      }
    });
  }
  
  // Sort the sync queue by priority (highest first) and then by creation time
  void _sortQueue() {
    final sortedList = _syncQueue.toList()
      ..sort((a, b) {
        // First compare by priority (descending)
        final priorityComparison = b.priority.compareTo(a.priority);
        if (priorityComparison != 0) {
          return priorityComparison;
        }
        
        // Then by creation time (oldest first)
        return a.createdAt.compareTo(b.createdAt);
      });
    
    _syncQueue.clear();
    _syncQueue.addAll(sortedList);
  }
  
  // Save a sync item to the database
  Future<void> _saveSyncItemToDatabase(SyncItem item) async {
    final db = await DatabaseService.instance.database;
    
    try {
      // Check if item already exists in queue
      final existing = await db.query(
        'sync_queue',
        where: 'table_name = ? AND record_id = ? AND operation = ?',
        whereArgs: [item.table, item.recordId, item.operation.name],
        limit: 1
      );
      
      if (existing.isNotEmpty) {
        // Update existing item
        await db.update(
          'sync_queue',
          item.toMap(),
          where: 'id = ?',
          whereArgs: [existing.first['id']],
          conflictAlgorithm: ConflictAlgorithm.replace
        );
      } else {
        // Insert new item
        await db.insert(
          'sync_queue',
          item.toMap(),
          conflictAlgorithm: ConflictAlgorithm.replace
        );
      }
    } catch (e) {
      debugPrint('Error saving sync item to database: $e');
    }
  }
  
  // Trigger a sync operation
  void _triggerSync() {
    // Don't trigger if already syncing
    if (_isSyncing) return;
    
    // Check if we're in servant mode
    MachineConfigService.instance.machineRole.then((role) {
      if (role == MachineRole.servant) {
        syncWithMaster();
      }
    });
  }
  
  // Main sync function to synchronize with master
  Future<SyncResult> syncWithMaster() async {
    return await _syncLock.synchronized(() async {
      if (_isSyncing) {
        return SyncResult(
          success: false, 
          message: 'Sync already in progress',
          itemsSynced: 0,
          hasErrors: false
        );
      }
      
      _isSyncing = true;
      _lastSyncAttempt = DateTime.now();
      _syncEvents.add(SyncEvent(SyncEventType.started, 'Starting sync with master'));
      
      try {
        // Check if we have items to sync
        if (_syncQueue.isEmpty) {
          await _loadPendingSyncItems(); // Check for any items in database
          
          if (_syncQueue.isEmpty) {
            // Nothing to sync, check if we should pull from master anyway
            final lastSync = await MachineConfigService.instance.lastSyncTime;
            final now = DateTime.now();
            
            if (lastSync == null || now.difference(lastSync).inMinutes >= 30) {
              // It's been 30+ minutes, pull changes from master
              return await _pullFromMaster();
            } else {
              _isSyncing = false;
              _syncEvents.add(SyncEvent(SyncEventType.completed, 'No changes to sync'));
              return SyncResult(
                success: true, 
                message: 'No changes to sync', 
                itemsSynced: 0,
                hasErrors: false
              );
            }
          }
        }
        
        // Get master address
        final masterAddress = await MachineConfigService.instance.masterAddress;
        if (masterAddress == null || masterAddress.isEmpty) {
          _isSyncing = false;
          _lastSyncError = 'No master address configured';
          _syncEvents.add(SyncEvent(SyncEventType.error, _lastSyncError!));
          return SyncResult(
            success: false,
            message: _lastSyncError!,
            itemsSynced: 0,
            hasErrors: true
          );
        }
        
        // Test connection to master
        final masterInfo = await _getMasterInfo(masterAddress);
        if (masterInfo == null) {
          _isSyncing = false;
          _lastSyncError = 'Failed to connect to master at $masterAddress';
          _syncEvents.add(SyncEvent(SyncEventType.error, _lastSyncError!));
          return SyncResult(
            success: false,
            message: _lastSyncError!,
            itemsSynced: 0,
            hasErrors: true
          );
        }
        
        // Process sync queue and build changes payload
        final batchSize = 50; // Process up to 50 items at once
        final itemsToProcess = _syncQueue.length > batchSize ? 
            batchSize : _syncQueue.length;
        
        // Group changes by table for efficiency
        final Map<String, List<Map<String, dynamic>>> changes = {};
        final List<SyncItem> processedItems = [];
        
        for (int i = 0; i < itemsToProcess; i++) {
          final item = _syncQueue.elementAt(i);
          item.attempts++;
          item.lastAttempt = DateTime.now();
          
          final table = item.table;
          if (!changes.containsKey(table)) {
            changes[table] = [];
          }
          
          // Add operation type to data
          final data = Map<String, dynamic>.from(item.data);
          data['_sync_operation'] = item.operation.name;
          
          changes[table]!.add(data);
          processedItems.add(item);
        }
        
        // Build sync payload
        final syncPayload = {
          'machine_id': await MachineConfigService.instance.machineId,
          'changes': changes,
          'timestamp': DateTime.now().toIso8601String(),
          'last_sync': (await MachineConfigService.instance.lastSyncTime)?.toIso8601String()
        };
        
        // Send changes to master
        final url = '${masterInfo.connectionUrl}/api/sync';
        final authToken = await _generateAuthToken(masterInfo);
        
        final response = await http.post(
          Uri.parse(url),
          headers: {
            'Content-Type': 'application/json',
            'X-Machine-ID': await MachineConfigService.instance.machineId,
            'X-Auth-Token': authToken,
          },
          body: jsonEncode(syncPayload),
        ).timeout(const Duration(seconds: 30));
        
        if (response.statusCode == 200) {
          // Sync successful, remove items from queue
          _syncEvents.add(SyncEvent(
            SyncEventType.progress, 
            'Processed ${processedItems.length} items'
          ));
          
          await _removeItemsFromQueue(processedItems);
          
          // Process changes from master
          final masterChanges = await _processServerResponse(response.body);
          
          // Update last sync time
          _lastSuccessfulSync = DateTime.now();
          await MachineConfigService.instance.updateLastSyncTime(_lastSuccessfulSync);
          
          _isSyncing = false;
          _syncEvents.add(SyncEvent(
            SyncEventType.completed, 
            'Sync completed successfully. Sent ${processedItems.length} items, received ${masterChanges.itemCount} changes.'
          ));
          
          return SyncResult(
            success: true,
            message: 'Sync completed successfully',
            itemsSynced: processedItems.length,
            itemsReceived: masterChanges.itemCount,
            hasErrors: false
          );
        } else {
          // Sync failed
          _lastSyncError = 'Sync failed with status code ${response.statusCode}: ${response.body}';
          
          // Mark items as failed but keep them in the queue
          for (final item in processedItems) {
            item.error = _lastSyncError;
            await _saveSyncItemToDatabase(item);
          }
          
          _isSyncing = false;
          _syncEvents.add(SyncEvent(SyncEventType.error, _lastSyncError!));
          
          return SyncResult(
            success: false,
            message: _lastSyncError!,
            itemsSynced: 0,
            hasErrors: true
          );
        }
      } catch (e) {
        _lastSyncError = 'Sync error: $e';
        _isSyncing = false;
        _syncEvents.add(SyncEvent(SyncEventType.error, _lastSyncError!));
        
        debugPrint('Sync error: $e');
        
        return SyncResult(
          success: false,
          message: _lastSyncError!,
          itemsSynced: 0,
          hasErrors: true
        );
      }
    });
  }
  
  // Pull changes from master without sending any local changes
  Future<SyncResult> _pullFromMaster() async {
    final masterAddress = await MachineConfigService.instance.masterAddress;
    if (masterAddress == null || masterAddress.isEmpty) {
      _isSyncing = false;
      return SyncResult(
        success: false,
        message: 'No master address configured',
        itemsSynced: 0,
        hasErrors: true
      );
    }
    
    // Get master info and check connection
    final masterInfo = await _getMasterInfo(masterAddress);
    if (masterInfo == null) {
      _isSyncing = false;
      return SyncResult(
        success: false,
        message: 'Failed to connect to master',
        itemsSynced: 0,
        hasErrors: true
      );
    }
    
    try {
      // Send empty changes to trigger a pull from master
      final syncPayload = {
        'machine_id': await MachineConfigService.instance.machineId,
        'changes': {},
        'timestamp': DateTime.now().toIso8601String(),
        'last_sync': (await MachineConfigService.instance.lastSyncTime)?.toIso8601String(),
        'pull_only': true
      };
      
      final url = '${masterInfo.connectionUrl}/api/sync';
      final authToken = await _generateAuthToken(masterInfo);
      
      final response = await http.post(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
          'X-Machine-ID': await MachineConfigService.instance.machineId,
          'X-Auth-Token': authToken,
        },
        body: jsonEncode(syncPayload),
      ).timeout(const Duration(seconds: 30));
      
      if (response.statusCode == 200) {
        // Process changes from master
        final masterChanges = await _processServerResponse(response.body);
        
        // Update last sync time
        _lastSuccessfulSync = DateTime.now();
        await MachineConfigService.instance.updateLastSyncTime(_lastSuccessfulSync);
        
        _isSyncing = false;
        _syncEvents.add(SyncEvent(
          SyncEventType.completed, 
          'Pull completed successfully. Received ${masterChanges.itemCount} changes.'
        ));
        
        return SyncResult(
          success: true,
          message: 'Pull completed successfully',
          itemsSynced: 0,
          itemsReceived: masterChanges.itemCount,
          hasErrors: false
        );
      } else {
        _lastSyncError = 'Pull failed with status code ${response.statusCode}';
        _isSyncing = false;
        
        return SyncResult(
          success: false,
          message: _lastSyncError!,
          itemsSynced: 0,
          hasErrors: true
        );
      }
    } catch (e) {
      _lastSyncError = 'Pull error: $e';
      _isSyncing = false;
      
      return SyncResult(
        success: false,
        message: _lastSyncError!,
        itemsSynced: 0,
        hasErrors: true
      );
    }
  }
  
  // Generate authentication token for secure communication
  Future<String> _generateAuthToken(MasterInfo masterInfo) async {
    final machineId = await MachineConfigService.instance.machineId;
    final timestamp = DateTime.now().millisecondsSinceEpoch.toString();
    // In a production app, this secret should be more secure or exchanged using a proper key exchange
    final secretKey = 'MALBROSE_SYNC_SECRET_KEY';
    
    // Create HMAC signature
    final hmacInput = '$machineId:$timestamp:${masterInfo.machineId}';
    final hmac = Hmac(sha256, utf8.encode(secretKey));
    final digest = hmac.convert(utf8.encode(hmacInput));
    
    return '$machineId:$timestamp:${digest.toString()}';
  }
  
  // Get master info from address
  Future<MasterInfo?> _getMasterInfo(String address) async {
    // Try to connect directly
    try {
      final response = await http.get(
        Uri.parse('http://$address/api/ping'),
        headers: {'X-Machine-ID': await MachineConfigService.instance.machineId}
      ).timeout(const Duration(seconds: 5));
      
      if (response.statusCode == 200) {
        try {
          final data = jsonDecode(response.body);
          if (data is Map && data['role'] == 'master') {
            return MasterInfo(
              ip: address,
              machineId: data['machine_id'].toString(),
              deviceName: data['device_name']?.toString(),
              version: data['version']?.toString(),
              lastSeen: DateTime.now(),
              secure: data['secure'] == true,
              port: data['port'] != null ? int.tryParse(data['port'].toString()) ?? 8080 : 8080,
            );
          }
        } catch (e) {
          debugPrint('Error parsing master response: $e');
        }
      }
    } catch (e) {
      debugPrint('Error connecting to master at $address: $e');
    }
    
    // If direct connection fails, try discovery
    try {
      final masters = await NetworkDiscoveryService.instance.discoverMasters(useCache: false);
      final matchingMaster = masters.where((m) => m.ip == address).toList();
      
      if (matchingMaster.isNotEmpty) {
        return matchingMaster.first;
      }
      
      // If no matching master, check if any master is found
      if (masters.isNotEmpty) {
        // Update master address to use the discovered one
        await MachineConfigService.instance.setMasterAddress(masters.first.ip);
        return masters.first;
      }
    } catch (e) {
      debugPrint('Error discovering masters: $e');
    }
    
    return null;
  }
  
  // Process server response and apply changes
  Future<MasterChangesResult> _processServerResponse(String responseBody) async {
    try {
      final responseData = jsonDecode(responseBody);
      int itemCount = 0;
      
      if (responseData is Map && responseData.containsKey('changes')) {
        final changes = responseData['changes'] as Map<String, dynamic>;
        
        if (changes.isEmpty) {
          return MasterChangesResult(itemCount: 0);
        }
        
        // Get the database
        final db = await DatabaseService.instance.database;
        
        // Get conflict resolution strategy
        final conflictResolution = await MachineConfigService.instance.conflictResolution;
        
        // Process changes in a transaction
        await db.transaction((txn) async {
          for (final tableName in changes.keys) {
            final tableChanges = changes[tableName] as List<dynamic>;
            itemCount += tableChanges.length;
            
            for (final change in tableChanges) {
              final changeData = Map<String, dynamic>.from(change as Map);
              final String? operation = changeData.remove('_sync_operation');
              
              // Apply the change based on operation
              if (operation == 'delete') {
                // Handle delete
                final id = changeData['id'];
                if (id != null) {
                  await txn.delete(
                    tableName,
                    where: 'id = ?',
                    whereArgs: [id]
                  );
                }
              } else if (changeData.containsKey('id')) {
                // Handle insert or update
                final id = changeData['id'];
                
                // Check if record exists
                final existing = await txn.query(
                  tableName,
                  where: 'id = ?',
                  whereArgs: [id],
                  limit: 1
                );
                
                if (existing.isEmpty) {
                  // Insert
                  await txn.insert(tableName, changeData);
                } else {
                  // Update with conflict resolution
                  if (changeData.containsKey('version') && existing.first.containsKey('version')) {
                    final remoteVersion = changeData['version'] as int;
                    final localVersion = existing.first['version'] as int;
                    
                    if (remoteVersion > localVersion) {
                      // Remote is newer, update
                      await txn.update(
                        tableName,
                        changeData,
                        where: 'id = ?',
                        whereArgs: [id]
                      );
                    } else if (remoteVersion == localVersion) {
                      // Same version, resolve based on conflict resolution strategy
                      if (conflictResolution == 'last_write_wins') {
                        await txn.update(
                          tableName,
                          changeData,
                          where: 'id = ?',
                          whereArgs: [id]
                        );
                      } else {
                        // Manual merge would be handled by UI, we'd need to queue this for user review
                        // Simply log the conflict for now
                        await _logSyncEvent(
                          'Conflict detected for $tableName id=$id', 
                          'conflict'
                        );
                      }
                    }
                  } else {
                    // No version tracking, always update
                    await txn.update(
                      tableName,
                      changeData,
                      where: 'id = ?',
                      whereArgs: [id]
                    );
                  }
                }
              }
            }
          }
        });
        
        // Log success
        await _logSyncEvent(
          'Applied $itemCount changes from master', 
          'sync_applied'
        );
        
        return MasterChangesResult(itemCount: itemCount);
      }
      
      return MasterChangesResult(itemCount: 0);
    } catch (e) {
      debugPrint('Error processing server response: $e');
      await _logSyncEvent(
        'Error processing server response: $e', 
        'sync_error',
        {'error': e.toString()}
      );
      
      return MasterChangesResult(itemCount: 0, error: e.toString());
    }
  }
  
  // Remove processed items from the queue and database
  Future<void> _removeItemsFromQueue(List<SyncItem> items) async {
    await _queueLock.synchronized(() async {
      final db = await DatabaseService.instance.database;
      
      for (final item in items) {
        _syncQueue.remove(item);
        
        try {
          await db.delete(
            'sync_queue',
            where: 'table_name = ? AND record_id = ? AND operation = ?',
            whereArgs: [item.table, item.recordId, item.operation.name]
          );
        } catch (e) {
          debugPrint('Error removing sync item from database: $e');
        }
      }
    });
  }
  
  // Log sync event
  Future<void> _logSyncEvent(String message, String eventType, [Map<String, dynamic>? details]) async {
    try {
      final db = await DatabaseService.instance.database;
      
      await db.insert('sync_log', {
        'event_type': eventType,
        'message': message,
        'timestamp': DateTime.now().toIso8601String(),
        'details': details != null ? jsonEncode(details) : null
      });
    } catch (e) {
      debugPrint('Error logging sync event: $e');
    }
    
    // Also emit event
    _syncEvents.add(SyncEvent(
      _eventTypeFromString(eventType),
      message,
      details
    ));
  }
  
  SyncEventType _eventTypeFromString(String type) {
    switch (type) {
      case 'started': return SyncEventType.started;
      case 'progress': return SyncEventType.progress;
      case 'completed': return SyncEventType.completed;
      case 'error': return SyncEventType.error;
      case 'conflict': return SyncEventType.conflict;
      default: return SyncEventType.info;
    }
  }
  
  /// Get sync status
  SyncStatus getSyncStatus() {
    return SyncStatus(
      isSyncing: _isSyncing,
      pendingItems: _syncQueue.length,
      lastSyncAttempt: _lastSyncAttempt,
      lastSuccessfulSync: _lastSuccessfulSync,
      lastError: _lastSyncError,
    );
  }
  
  /// Force synchronization with master
  Future<SyncResult> forceSyncWithMaster() async {
    return syncWithMaster();
  }
  
  /// Get sync logs
  Future<List<Map<String, dynamic>>> getSyncLogs({int limit = 50}) async {
    final db = await DatabaseService.instance.database;
    
    return await db.query(
      'sync_log',
      orderBy: 'timestamp DESC',
      limit: limit
    );
  }
  
  /// Get pending sync items
  Future<List<SyncItem>> getPendingSyncItems() async {
    return await _queueLock.synchronized(() async {
      return List<SyncItem>.from(_syncQueue);
    });
  }
  
  /// Clear all pending sync items
  Future<int> clearPendingSyncItems() async {
    return await _queueLock.synchronized(() async {
      final db = await DatabaseService.instance.database;
      final count = _syncQueue.length;
      
      _syncQueue.clear();
      
      final deletedRows = await db.delete('sync_queue');
      
      await _logSyncEvent(
        'Cleared $deletedRows pending sync items', 
        'sync_cleared'
      );
      
      return count;
    });
  }
  
  /// Dispose resources
  void dispose() {
    _syncTimer?.cancel();
    _syncEvents.close();
  }
}

/// Sync item representing a change to be synchronized
class SyncItem {
  final String table;
  final String recordId;
  final Map<String, dynamic> data;
  final SyncOperation operation;
  final int priority;
  final DateTime createdAt;
  int attempts;
  DateTime? lastAttempt;
  String? error;
  
  SyncItem({
    required this.table,
    required this.recordId,
    required this.data,
    required this.operation,
    required this.priority,
    required this.createdAt,
    this.attempts = 0,
    this.lastAttempt,
    this.error,
  });
  
  factory SyncItem.fromMap(Map<String, dynamic> map) {
    return SyncItem(
      table: map['table_name'] as String,
      recordId: map['record_id'] as String,
      data: jsonDecode(map['data'] as String),
      operation: SyncOperation.values.firstWhere(
        (e) => e.name == map['operation'],
        orElse: () => SyncOperation.update
      ),
      priority: map['priority'] as int,
      createdAt: DateTime.parse(map['created_at'] as String),
      attempts: map['attempts'] as int,
      lastAttempt: map['last_attempt'] != null ? 
          DateTime.parse(map['last_attempt'] as String) : null,
      error: map['error'] as String?,
    );
  }
  
  Map<String, dynamic> toMap() {
    return {
      'table_name': table,
      'record_id': recordId,
      'data': jsonEncode(data),
      'operation': operation.name,
      'priority': priority,
      'created_at': createdAt.toIso8601String(),
      'attempts': attempts,
      'last_attempt': lastAttempt?.toIso8601String(),
      'error': error,
    };
  }
}

/// Sync operation type
enum SyncOperation {
  insert,
  update,
  delete
}

/// Sync result
class SyncResult {
  final bool success;
  final String message;
  final int itemsSynced;
  final int itemsReceived;
  final bool hasErrors;
  
  const SyncResult({
    required this.success,
    required this.message,
    required this.itemsSynced,
    this.itemsReceived = 0,
    required this.hasErrors,
  });
}

/// Master changes result
class MasterChangesResult {
  final int itemCount;
  final String? error;
  
  const MasterChangesResult({
    required this.itemCount,
    this.error,
  });
}

/// Sync status
class SyncStatus {
  final bool isSyncing;
  final int pendingItems;
  final DateTime? lastSyncAttempt;
  final DateTime? lastSuccessfulSync;
  final String? lastError;
  
  const SyncStatus({
    required this.isSyncing,
    required this.pendingItems,
    this.lastSyncAttempt,
    this.lastSuccessfulSync,
    this.lastError,
  });
}

/// Sync event type
enum SyncEventType {
  started,
  progress,
  completed,
  error,
  conflict,
  info
}

/// Sync event
class SyncEvent {
  final SyncEventType type;
  final String message;
  final Map<String, dynamic>? details;
  final DateTime timestamp;
  
  SyncEvent(
    this.type,
    this.message,
    [this.details]
  ) : timestamp = DateTime.now();
} 