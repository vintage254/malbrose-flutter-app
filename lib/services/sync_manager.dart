import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import 'package:synchronized/synchronized.dart';
import 'package:dio/dio.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

import 'package:my_flutter_app/services/database.dart';
import 'package:my_flutter_app/services/machine_config_service.dart';
import 'package:my_flutter_app/services/network_discovery_service.dart';
import 'package:my_flutter_app/services/ssl_service.dart';
import 'package:my_flutter_app/services/encryption_service.dart';
import 'package:my_flutter_app/services/audit_service.dart';

/// Manages data synchronization between master and servant devices
class SyncManager {
  static final SyncManager _instance = SyncManager._internal();
  static SyncManager get instance => _instance;
  
  SyncManager._internal();
  
  // For testing purposes
  factory SyncManager() => _instance;
  
  // Add missing field
  bool _isInitialized = false;
  
  // Queue for pending sync operations
  final Queue<SyncItem> _syncQueue = Queue<SyncItem>();
  
  // Lock for queue operations
  final Lock _queueLock = Lock();
  
  // Lock for sync operations
  final Lock _syncLock = Lock();
  
  // Lock for key operations
  final Lock _keyLock = Lock();
  
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
  
  // HMAC key cache
  String? _cachedHmacKey;
  
  // Platform channel for Windows Credential Manager integration
  static const _platform = MethodChannel('com.malbrose.pos/secure_storage');
  
  // Add validation cache for performance optimization
  final Map<String, bool> _validationCache = {};
  static const int _maxCacheSize = 100; // Limit cache size to prevent memory issues
  
  // Initialize the sync manager
  Future<void> initialize() async {
    if (_isInitialized) return;
    
    try {
      // Ensure database tables exist
      await _createSyncTables();
      
      // Ensure HMAC key is available
      await _getOrCreateHmacKey();
      
      // Load any pending sync items from database
      await _loadPendingSyncItems();
      
      // Start periodic sync if in servant mode
      await _configureSyncTimer();
      
      _logSyncEvent('Sync manager initialized', 'init', <String, dynamic>{'status': 'success'});
    } catch (e) {
      debugPrint('Error initializing sync manager: $e');
      throw e;
    }
    _isInitialized = true;
  }
  
  /// Create sync tables if they don't exist
  Future<void> _createSyncTables() async {
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
  }
  
  /// Get or create an HMAC key for secure synchronization
  Future<String> _getOrCreateHmacKey() async {
    return await _keyLock.synchronized(() async {
      // Return cached key if available
      if (_cachedHmacKey != null) {
        return _cachedHmacKey!;
      }
      
      String? hmacKey;
      
      try {
        if (Platform.isWindows) {
          // Try to get key from Windows Credential Manager
          try {
            hmacKey = await _platform.invokeMethod<String>('getCredential', {'key': 'malbrose_hmac_key'});
          } on PlatformException catch (e) {
            debugPrint('Error getting HMAC key from Windows Credential Manager: $e');
            // Fall back to encrypted storage
            hmacKey = await _getHmacKeyFromSecureStorage();
          }
        } else {
          // Use encrypted storage for non-Windows platforms
          hmacKey = await _getHmacKeyFromSecureStorage();
        }
        
        // If no key exists, create a new one
        if (hmacKey == null) {
          // Generate a secure random key
          final random = List<int>.generate(32, (_) => DateTime.now().microsecondsSinceEpoch % 256);
          final newKey = base64.encode(random);
          
          // Store the key securely
          await _storeHmacKey(newKey);
          
          _cachedHmacKey = newKey;
          return newKey;
        }
        
        _cachedHmacKey = hmacKey;
        return hmacKey;
      } catch (e) {
        debugPrint('Error getting or creating HMAC key: $e');
        // Use a fallback key if all else fails (this is not secure but prevents crashes)
        final fallbackKey = 'fallback_hmac_key_${DateTime.now().millisecondsSinceEpoch}';
        _cachedHmacKey = fallbackKey;
        return fallbackKey;
      }
    });
  }
  
  /// Store HMAC key in the appropriate secure storage
  Future<void> _storeHmacKey(String key) async {
    try {
      if (Platform.isWindows) {
        // Try to store in Windows Credential Manager
        try {
          await _platform.invokeMethod<void>(
            'setCredential', 
            {
              'key': 'malbrose_hmac_key',
              'value': key,
              'description': 'HMAC key for Malbrose POS sync'
            }
          );
          return;
        } on PlatformException catch (e) {
          debugPrint('Error storing HMAC key in Windows Credential Manager: $e');
          // Fall back to encrypted storage
        }
      }
      
      // Store in encrypted storage as fallback
      await _storeHmacKeyInSecureStorage(key);
    } catch (e) {
      debugPrint('Error storing HMAC key: $e');
    }
  }
  
  /// Get HMAC key from encrypted secure storage
  Future<String?> _getHmacKeyFromSecureStorage() async {
    try {
      // Use alternative method if getConfigValue isn't available
      final db = await DatabaseService.instance.database;
      final results = await db.query(
        'config',
        columns: ['value'],
        where: 'key = ?',
        whereArgs: ['hmac_key'],
        limit: 1
      );
      
      if (results.isNotEmpty) {
        final encryptedKey = results.first['value'] as String?;
        if (encryptedKey != null && encryptedKey.isNotEmpty) {
          return await EncryptionService.instance.decryptString(encryptedKey);
        }
      }
      return null;
    } catch (e) {
      debugPrint('Error getting HMAC key from secure storage: $e');
      return null;
    }
  }
  
  /// Store HMAC key in encrypted secure storage
  Future<void> _storeHmacKeyInSecureStorage(String key) async {
    try {
      final encryptedKey = await EncryptionService.instance.encryptString(key);
      
      // Use alternative method if setConfigValue isn't available
      final db = await DatabaseService.instance.database;
      await db.insert(
        'config',
        {'key': 'hmac_key', 'value': encryptedKey},
        conflictAlgorithm: ConflictAlgorithm.replace
      );
    } catch (e) {
      debugPrint('Error storing HMAC key in secure storage: $e');
    }
  }
  
  /// Generate HMAC for data authentication
  Future<String> generateHmac(String data) async {
    final key = await _getOrCreateHmacKey();
    final hmacKey = utf8.encode(key);
    final dataBytes = utf8.encode(data);
    final hmac = Hmac(sha256, hmacKey);
    final digest = hmac.convert(dataBytes);
    return digest.toString();
  }
  
  /// Verify HMAC signature
  Future<bool> verifyHmac(String data, String signature) async {
    final expectedSignature = await generateHmac(data);
    return expectedSignature == signature;
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
  
  // Sync with master server with retry logic
  Future<SyncResult> syncWithMaster() async {
    if (_isSyncing) {
      return SyncResult(
        success: false,
        message: 'Sync already in progress',
        hasErrors: true
      );
    }
    
    _isSyncing = true;
    _lastSyncAttempt = DateTime.now();
    
    try {
      // Log sync start
      await AuditService.instance.logEvent(
        eventType: 'sync',
        action: 'sync_start',
        message: 'Starting sync with master',
      );
      
      // Find the master server
      final masterAddress = await MachineConfigService.instance.masterAddress;
      if (masterAddress == null || masterAddress.isEmpty) {
        throw Exception('Master address not configured');
      }
      
      // Try to get master info (will try HTTP, then HTTPS)
      final masterInfo = await _getMasterInfo(masterAddress);
      if (masterInfo == null) {
        throw Exception('Could not connect to master at $masterAddress');
      }
      
      // Get items to sync from queue
      final items = await _getItemsToSync();
      if (items.isEmpty) {
        _emitEvent(SyncEventType.completed, 'No items to sync');
        _lastSuccessfulSync = DateTime.now();
        _isSyncing = false;
        
        // Log empty sync completion
        await AuditService.instance.logEvent(
          eventType: 'sync',
          action: 'sync_completed',
          message: 'Sync completed - no items to sync',
        );
        
        return SyncResult(
          success: true,
          message: 'Sync completed successfully',
          itemsSynced: 0,
          itemsReceived: 0
        );
      }
      
      // Prepare data for sync
      final syncData = {
        'machine_id': await MachineConfigService.instance.machineId,
        'device_name': await MachineConfigService.instance.getDeviceName(),
        'timestamp': DateTime.now().toIso8601String(),
        'items': items.map((item) => item.toMap()).toList(),
      };
      
      // Get connection URL (prefer HTTPS)
      final url = masterInfo.connectionUrl;
      
      // Log sync attempt
      await AuditService.instance.logEvent(
        eventType: 'sync',
        action: 'sync_request',
        message: 'Sending ${items.length} items to $url',
        details: {'item_count': items.length, 'url': url}
      );
      
      // Add HMAC signature for security
      final sortedKeys = syncData.keys.toList()..sort();
      final dataString = sortedKeys.map((key) => '$key=${syncData[key]}').join('&');
      final signature = await generateHmac(dataString);
      
      // Use our retry logic for the request
      final response = await retryRequest(
        '$url/sync',
        method: 'POST',
        data: syncData,
        headers: {
        'Content-Type': 'application/json',
        'X-Machine-ID': await MachineConfigService.instance.machineId,
          'X-Auth-Signature': signature,
          'X-Auth-Timestamp': syncData['timestamp'] as String,
        },
      );
      
      if (response.statusCode == 200) {
        // Process server response
        _emitEvent(SyncEventType.progress, 'Processing server response', {'status': 'processing'});
        
        // Mark items as synced
        for (final item in items) {
          await _markItemSynced(item);
        }
        
        // Update last sync time
        await MachineConfigService.instance.updateLastSyncTime();
        _lastSuccessfulSync = DateTime.now();
        
        // Log sync success
        await AuditService.instance.logEvent(
          eventType: 'sync',
          action: 'sync_success',
          message: 'Sync completed successfully',
          details: {'synced_items': items.length}
        );
        
        _emitEvent(
          SyncEventType.completed, 
          'Sync completed successfully', 
          {'synced_items': items.length}
        );
        
        _isSyncing = false;
        return SyncResult(
          success: true,
          message: 'Sync completed successfully',
          itemsSynced: items.length,
          itemsReceived: items.length
        );
      } else {
        throw Exception('Sync failed with status code: ${response.statusCode}');
      }
    } catch (e) {
      _lastSyncError = e.toString();
      _emitEvent(SyncEventType.error, 'Sync error: $e');
      
      // Log sync error
      await AuditService.instance.logEvent(
        eventType: 'sync',
        action: 'sync_error',
        message: 'Sync failed',
        details: {'error': e.toString()}
      );
      
    _isSyncing = false;
      return SyncResult(
        success: false,
        message: 'Sync failed: $e',
        hasErrors: true
      );
    }
  }
  
  // Get master info from address
  Future<MasterInfo?> _getMasterInfo(String address) async {
    // Try to connect directly
    try {
      // Try HTTPS first
      final secureClient = SSLService.instance.getDioClient();
      final headers = {'X-Machine-ID': await MachineConfigService.instance.machineId};
      
      // Try HTTPS first, then HTTP if HTTPS fails
      Response<dynamic>? response;
      bool isSecure = true;
      int? port;
      
      try {
        // Try standard HTTPS port first
        response = await secureClient.get(
          'https://$address:8443/ping',
          options: Options(headers: headers)
        ).timeout(const Duration(seconds: 5));
        port = 8443;
      } catch (e) {
        // Try fallback HTTPS port
        try {
          response = await secureClient.get(
            'https://$address:8444/ping',
            options: Options(headers: headers)
          ).timeout(const Duration(seconds: 5));
          port = 8444;
        } catch (e) {
          // If HTTPS fails, try HTTP
          debugPrint('HTTPS connection failed, trying HTTP: $e');
          try {
            final httpClient = Dio();
            // Try standard HTTP port
            response = await httpClient.get(
              'http://$address:8080/ping',
              options: Options(headers: headers)
            ).timeout(const Duration(seconds: 5));
            isSecure = false;
            port = 8080;
          } catch (e) {
            // Try fallback HTTP port
            try {
              final httpClient = Dio();
              response = await httpClient.get(
                'http://$address:8081/ping',
                options: Options(headers: headers)
              ).timeout(const Duration(seconds: 5));
              isSecure = false;
              port = 8081;
            } catch (e) {
              debugPrint('HTTP connection failed: $e');
            }
          }
        }
      }
      
      if (response != null && response.statusCode == 200) {
        try {
          final data = response.data;
          if (data is Map) {
            return MasterInfo(
              ip: address,
              machineId: data['machineId']?.toString() ?? '',
              deviceName: data['deviceName']?.toString(),
              version: data['version']?.toString(),
              lastSeen: DateTime.now(),
              secure: isSecure,
              port: port ?? (isSecure ? 8443 : 8080),
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
      final discoveredMasters = await NetworkDiscoveryService.instance.discoverMasters(forceFullDiscovery: true);
      for (final master in discoveredMasters) {
        if (master.ip == address) {
          return master;
        }
      }
    } catch (e) {
      debugPrint('Error discovering master: $e');
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
                          'conflict',
                          <String, dynamic>{'table': tableName, 'id': id}
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
          'sync_applied',
          <String, dynamic>{'item_count': itemCount}
        );
        
        return MasterChangesResult(itemCount: itemCount);
      }
      
      return MasterChangesResult(itemCount: 0);
    } catch (e) {
      debugPrint('Error processing server response: $e');
      await _logSyncEvent(
        'Error processing server response: $e', 
        'sync_error',
        <String, dynamic>{'error': e.toString()}
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
  
  /// Log a sync event to the database
  Future<void> _logSyncEvent(String message, String eventType, [Map<String, dynamic>? details]) async {
    try {
      // Add to database
      final db = await DatabaseService.instance.database;
      await db.insert('sync_log', {
        'event_type': eventType,
        'message': message,
        'timestamp': DateTime.now().toIso8601String(),
        'details': details != null ? jsonEncode(details) : null
      });
      
      // Also emit an event with the appropriate event type
      final syncEventType = _eventTypeFromString(eventType);
      _emitEvent(syncEventType, message, details);
      
      // Log to console for debugging
      debugPrint('SYNC LOG: [$eventType] $message');
    } catch (e) {
      debugPrint('Failed to log sync event: $e');
    }
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
        'sync_cleared',
        <String, dynamic>{'deleted_rows': deletedRows}
      );
      
      return count;
    });
  }
  
  /// Dispose resources
  void dispose() {
    _syncTimer?.cancel();
    _syncEvents.close();
  }
  
  // Emit a sync event
  void _emitEvent(SyncEventType type, String message, [Map<String, dynamic>? details]) {
    _syncEvents.add(SyncEvent(type, message, details));
  }
  
  // Get items to sync from the queue
  Future<List<SyncItem>> _getItemsToSync() async {
    return await _queueLock.synchronized(() async {
      // Load items from database if queue is empty
      if (_syncQueue.isEmpty) {
        await _loadPendingSyncItems();
      }
      
      // Get up to 50 items at a time
      final batchSize = 50;
      final itemsToProcess = _syncQueue.length > batchSize ? 
          batchSize : _syncQueue.length;
      
      final items = <SyncItem>[];
      for (int i = 0; i < itemsToProcess; i++) {
        items.add(_syncQueue.elementAt(i));
      }
      
      return items;
    });
  }
  
  // Mark an item as synced (remove from queue)
  Future<void> _markItemSynced(SyncItem item) async {
    await _queueLock.synchronized(() async {
      // Remove from queue
      _syncQueue.remove(item);
      
      // Remove from database
      final db = await DatabaseService.instance.database;
      await db.delete(
        'sync_queue',
        where: 'table_name = ? AND record_id = ? AND operation = ?',
        whereArgs: [item.table, item.recordId, item.operation.name]
      );
      
      // Log the sync
      await _logSync(item, true);
    });
  }
  
  // Log sync operation
  Future<void> _logSync(SyncItem item, bool success) async {
    try {
      final db = await DatabaseService.instance.database;
      await db.insert('sync_log', {
        'event_type': success ? 'sync_success' : 'sync_failure',
        'message': 'Sync ${success ? 'succeeded' : 'failed'} for ${item.table}:${item.recordId}',
        'timestamp': DateTime.now().toIso8601String(),
        'details': jsonEncode({
          'table': item.table,
          'record_id': item.recordId,
          'operation': item.operation.name,
          'data': item.data
        })
      });
    } catch (e) {
      debugPrint('Error logging sync: $e');
    }
  }
  
  /// Send data to the master server with HMAC authentication
  Future<ApiResponse> _sendToMaster(String endpoint, Map<String, dynamic> data) async {
    try {
      // Use the masterAddress property instead of masterServerUrl
      final masterAddress = await MachineConfigService.instance.masterAddress;
      if (masterAddress == null || masterAddress.isEmpty) {
        return ApiResponse(success: false, message: 'Master server URL not configured');
      }
      
      // Construct the master URL using the address
      final masterUrl = 'https://$masterAddress:8443';
      
      // Add timestamp to prevent replay attacks
      data['timestamp'] = DateTime.now().toIso8601String();
      
      // Serialize data for HMAC generation
      final sortedKeys = data.keys.toList()..sort();
      final dataString = sortedKeys.map((key) => '$key=${data[key]}').join('&');
      
      // Generate HMAC signature
      final signature = await generateHmac(dataString);
      
      // Create headers with authentication
      final headers = {
        'Content-Type': 'application/json',
        'X-Auth-Signature': signature,
        'X-Auth-Timestamp': data['timestamp'],
        'X-Device-ID': await _getDeviceIdentifier(),
      };
      
      // Make the request
      final dio = Dio();
      final url = '$masterUrl/api/$endpoint';
      
      final response = await dio.post(
        url,
        data: jsonEncode(data),
        options: Options(
          headers: headers,
          validateStatus: (status) => true, // Accept any status
          receiveTimeout: const Duration(seconds: 30),
          sendTimeout: const Duration(seconds: 30),
        ),
      );
      
      if (response.statusCode == 200) {
        final responseData = response.data;
        return ApiResponse(
          success: responseData['success'] ?? false,
          message: responseData['message'] ?? 'No message',
          data: responseData['data'],
        );
      } else {
        return ApiResponse(
          success: false,
          message: 'HTTP Error: ${response.statusCode}',
          data: {'error': response.data},
        );
      }
    } catch (e) {
      debugPrint('Error sending data to master: $e');
      return ApiResponse(
        success: false,
        message: 'Connection error: $e',
      );
    }
  }
  
  /// Verify incoming data request (for master mode)
  Future<bool> verifyIncomingRequest(Map<String, dynamic> data, Map<String, String> headers) async {
    try {
      // Extract authentication information
      final signature = headers['X-Auth-Signature'];
      final timestamp = headers['X-Auth-Timestamp'];
      final deviceId = headers['X-Device-ID'];
      
      // Validate required fields
      if (signature == null || timestamp == null || deviceId == null) {
        debugPrint('Missing authentication headers');
        return false;
      }
      
      // Check if timestamp is recent (within 5 minutes)
      final requestTime = DateTime.parse(timestamp);
      final now = DateTime.now();
      if (now.difference(requestTime).inMinutes > 5) {
        debugPrint('Request timestamp too old');
        return false;
      }
      
      // Get device from database to verify it's authorized
      final deviceName = await MachineConfigService.instance.getDeviceName();
      final configDeviceId = await MachineConfigService.instance.deviceId;
      
      // Check if this is a registered device
      if (deviceId != configDeviceId) {
        debugPrint('Unknown device: $deviceId');
        return false;
      }
      
      // Serialize data for HMAC verification
      final sortedKeys = data.keys.toList()..sort();
      final dataString = sortedKeys.map((key) => '$key=${data[key]}').join('&');
      
      // Verify signature
      final isValid = await verifyHmac(dataString, signature);
      if (!isValid) {
        debugPrint('Invalid HMAC signature');
        return false;
      }
      
      return true;
    } catch (e) {
      debugPrint('Error verifying request: $e');
      return false;
    }
  }
  
  // Update the retry function to use proper logging and error handling
  Future<Response> retryRequest(String url, {
    int maxRetries = 3,
    String method = 'GET',
    Map<String, dynamic>? data,
    Map<String, String>? headers,
  }) async {
    final dio = SSLService.instance.getDioClient();
    
    // Add default headers
    headers = headers ?? {};
    headers['X-Device-ID'] = await MachineConfigService.instance.deviceId;
    headers['X-Request-Time'] = DateTime.now().toIso8601String();
    
    // Configure timeout
    dio.options.connectTimeout = const Duration(seconds: 15);
    dio.options.receiveTimeout = const Duration(seconds: 30);
    
    // Log the request attempt
    await AuditService.instance.logEvent(
      eventType: 'network',
      action: 'api_request',
      message: 'API request to $url',
      details: {'method': method, 'url': url}
    );
    
    for (var i = 0; i < maxRetries; i++) {
      try {
        Response response;
        
        if (method.toUpperCase() == 'GET') {
          response = await dio.get(url, options: Options(headers: headers));
        } else if (method.toUpperCase() == 'POST') {
          response = await dio.post(url, data: data, options: Options(headers: headers));
        } else {
          throw Exception('Unsupported HTTP method: $method');
        }
        
        // Log successful response
        await AuditService.instance.logEvent(
          eventType: 'network',
          action: 'api_response',
          message: 'API response from $url',
          details: {'status': response.statusCode, 'success': true}
        );
        
        return response;
      } catch (e) {
        debugPrint('Request attempt ${i+1} failed: $e');
        
        // Log retry attempt
        await AuditService.instance.logEvent(
          eventType: 'network',
          action: 'api_retry',
          message: 'API retry for $url',
          details: {
            'attempt': i+1, 
            'max_retries': maxRetries,
            'error': e.toString(),
            'backoff_seconds': pow(2, i).toInt()
          }
        );
        
        // Only retry on network-related errors
        if (e is DioException) {
          if (e.type == DioExceptionType.connectionTimeout ||
              e.type == DioExceptionType.receiveTimeout ||
              e.type == DioExceptionType.connectionError) {
            
            // Wait with exponential backoff before retrying
            if (i < maxRetries - 1) {
              await Future.delayed(Duration(seconds: pow(2, i).toInt()));
              continue;
            }
          }
        }
        
        // Log final failure
        if (i == maxRetries - 1) {
          await AuditService.instance.logEvent(
            eventType: 'network',
            action: 'api_failure',
            message: 'API request failed after $maxRetries retries',
            details: {'url': url, 'error': e.toString()}
          );
        }
        
        // Rethrow if max retries reached or not a retryable error
        rethrow;
      }
    }
    
    // This code should never be reached but is required for compilation
    throw Exception('All retry attempts failed');
  }
  
  // Check connectivity using Connectivity Plus
  Future<ConnectivityResult> _checkConnectivity() async {
    try {
      // First check using Connectivity Plus
      final connectivityResult = await Connectivity().checkConnectivity();
      
      if (connectivityResult == ConnectivityResult.none) {
        return ConnectivityResult.none;
      }
      
      // If we have connectivity, try to ping the master
      final masterAddress = await MachineConfigService.instance.masterAddress;
      if (masterAddress == null || masterAddress.isEmpty) {
        return connectivityResult; // Return what we got from Connectivity
      }
      
      try {
        // Try to ping the master using our retry logic
        final url = 'https://$masterAddress:8443/ping';
        await retryRequest(url, maxRetries: 1); // Just one retry for ping
        return connectivityResult; // Master is reachable
      } catch (e) {
        debugPrint('Master not reachable: $e');
        
        // Try HTTP as a fallback
        try {
          final url = 'http://$masterAddress:8080/ping';
          await retryRequest(url, maxRetries: 1);
          return connectivityResult; // Master is reachable via HTTP
        } catch (e) {
          debugPrint('Master not reachable via HTTP either: $e');
          return ConnectivityResult.none; // Master not reachable
        }
      }
    } catch (e) {
      debugPrint('Error checking connectivity: $e');
      return ConnectivityResult.none;
    }
  }
  
  // Queue a transaction for sync with validation and better error handling
  Future<void> queueTransactionForSync(Map<String, dynamic> transactionData) async {
    try {
      // Validate data before queuing
      if (!isValidTransaction(transactionData)) {
        await AuditService.instance.logEvent(
          eventType: 'sync',
          action: 'queue_error',
          message: 'Invalid transaction data rejected',
          details: {'id': transactionData['id'] ?? 'unknown'}
        );
        throw Exception('Invalid transaction data');
      }
      
      // Add to sync queue with high priority
      await queueChange(
        table: 'transactions',
        recordId: transactionData['id'] as String,
        data: transactionData,
        operation: SyncOperation.insert,
        priority: 8 // High priority for transactions
      );
      
      // Log queued transaction
      await AuditService.instance.logTransactionEvent(
        action: 'transaction_queued',
        message: 'Transaction queued for sync',
        transactionId: transactionData['id'] as String,
        amount: transactionData['totalAmount'] as num?,
      );
      
      // Try immediate sync if connected
      final connectivityResult = await _checkConnectivity();
      if (connectivityResult == ConnectivityResult.wifi || 
          connectivityResult == ConnectivityResult.ethernet) {
        syncWithMaster();
      }
    } catch (e) {
      debugPrint('Error queueing transaction for sync: $e');
      await AuditService.instance.logEvent(
        eventType: 'sync',
        action: 'queue_error',
        message: 'Error queueing transaction',
        details: {'error': e.toString()}
      );
      rethrow;
    }
  }
  
  // Enhanced transaction validation with caching
  bool isValidTransaction(Map<String, dynamic> data) {
    try {
      // Generate a cache key from transaction ID or content hash
      final cacheKey = data.containsKey('id') 
          ? data['id'] as String 
          : json.encode(data['items'] ?? []);
      
      // Check if we've already validated this transaction
      if (_validationCache.containsKey(cacheKey)) {
        return _validationCache[cacheKey]!;
      }
      
      // Check required fields
      if (!data.containsKey('id') || 
          !data.containsKey('timestamp') ||
          !data.containsKey('totalAmount') ||
          !data.containsKey('items')) {
        debugPrint('Transaction missing required fields');
        _cacheValidationResult(cacheKey, false);
        return false;
      }
      
      // Validate field types
      if (!(data['totalAmount'] is num) || 
          !(data['items'] is List)) {
        debugPrint('Transaction has invalid field types');
        _cacheValidationResult(cacheKey, false);
        return false;
      }
      
      // Validate timestamp format
      try {
        DateTime.parse(data['timestamp'] as String);
      } catch (e) {
        debugPrint('Transaction has invalid timestamp format');
        _cacheValidationResult(cacheKey, false);
        return false;
      }
      
      // Validate items in transaction
      final items = data['items'] as List;
      for (final item in items) {
        if (item is! Map<String, dynamic> ||
            !item.containsKey('id') ||
            !item.containsKey('quantity') ||
            !item.containsKey('price') ||
            !(item['quantity'] is num) ||
            !(item['price'] is num)) {
          debugPrint('Transaction has invalid item format');
          _cacheValidationResult(cacheKey, false);
          return false;
        }
      }
      
      // Cache successful validation
      _cacheValidationResult(cacheKey, true);
      return true;
    } catch (e) {
      debugPrint('Error validating transaction: $e');
      return false;
    }
  }
  
  // Store validation result in cache with size management
  void _cacheValidationResult(String key, bool result) {
    // Manage cache size - remove oldest entries if cache gets too large
    if (_validationCache.length >= _maxCacheSize) {
      final keysToRemove = _validationCache.keys.take(_maxCacheSize ~/ 4).toList();
      for (final oldKey in keysToRemove) {
        _validationCache.remove(oldKey);
      }
    }
    
    // Store the result
    _validationCache[key] = result;
  }
  
  // Clear validation cache (useful when validation rules change)
  void clearValidationCache() {
    _validationCache.clear();
  }
  
  // Helper method to safely get device identifier
  Future<String> _getDeviceIdentifier() async {
    try {
      // Try to get device ID from MachineConfigService
      final deviceId = await MachineConfigService.instance.getDeviceId();
      if (deviceId != null && deviceId.isNotEmpty) {
        return deviceId;
      }
      
      // Fallback to a generated ID
      return 'device-${DateTime.now().millisecondsSinceEpoch}';
    } catch (e) {
      debugPrint('Error getting device ID: $e');
      return 'unknown-device';
    }
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
  final Map<String, dynamic>? details;
  
  SyncResult({
    required this.success,
    this.message = '',
    this.itemsSynced = 0,
    this.itemsReceived = 0,
    this.hasErrors = false,
    this.details,
  });
  
  // Convert Map to SyncResult
  factory SyncResult.fromMap(Map<String, dynamic> map) {
    return SyncResult(
      success: map['success'] ?? false,
      message: map['message'] ?? '',
      itemsSynced: map['items_synced'] ?? 0,
      itemsReceived: map['items_received'] ?? 0,
      hasErrors: map['has_errors'] ?? false,
      details: map['details'],
    );
  }
  
  // Convert SyncResult to Map
  Map<String, dynamic> toMap() {
    return {
      'success': success,
      'message': message,
      'items_synced': itemsSynced,
      'items_received': itemsReceived,
      'has_errors': hasErrors,
      if (details != null) 'details': details,
    };
  }
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

/// API Response wrapper class
class ApiResponse {
  final bool success;
  final String message;
  final dynamic data;
  final int? itemsSynced;
  final int? itemsReceived;
  final bool hasErrors;

  ApiResponse({
    required this.success,
    required this.message,
    this.data,
    this.itemsSynced = 0,
    this.itemsReceived = 0,
    this.hasErrors = false,
  });

  factory ApiResponse.success({
    String message = 'Operation successful',
    dynamic data,
    int? itemsSynced,
    int? itemsReceived,
  }) {
    return ApiResponse(
      success: true,
      message: message,
      data: data,
      itemsSynced: itemsSynced,
      itemsReceived: itemsReceived,
      hasErrors: false,
    );
  }

  factory ApiResponse.error({
    String message = 'Operation failed',
    dynamic data,
  }) {
    return ApiResponse(
      success: false,
      message: message,
      data: data,
      hasErrors: true,
    );
  }

  factory ApiResponse.fromJson(Map<String, dynamic> json) {
    return ApiResponse(
      success: json['success'] ?? false,
      message: json['message'] ?? 'No message provided',
      data: json['data'],
      itemsSynced: json['itemsSynced'],
      itemsReceived: json['itemsReceived'],
      hasErrors: json['hasErrors'] ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'success': success,
      'message': message,
      'data': data,
      'itemsSynced': itemsSynced,
      'itemsReceived': itemsReceived,
      'hasErrors': hasErrors,
    };
  }
} 