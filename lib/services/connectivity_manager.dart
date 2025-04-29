import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:my_flutter_app/services/machine_config_service.dart';
import 'package:my_flutter_app/services/master_redundancy_service.dart';
import 'package:my_flutter_app/services/network_discovery_service.dart';
import 'package:my_flutter_app/services/sync_manager.dart';

/// Manages all connectivity-related services, initializing them and handling network state changes
class ConnectivityManager {
  static final ConnectivityManager _instance = ConnectivityManager._internal();
  static ConnectivityManager get instance => _instance;
  
  ConnectivityManager._internal();
  
  // For testing purposes
  factory ConnectivityManager() => _instance;
  
  // Services
  final NetworkDiscoveryService _discoveryService = NetworkDiscoveryService.instance;
  final SyncManager _syncManager = SyncManager.instance;
  final MasterRedundancyService _redundancyService = MasterRedundancyService.instance;
  
  // Network status
  ConnectivityResult _currentConnectivity = ConnectivityResult.none;
  bool _isInitialized = false;
  bool _isNetworkAvailable = false;
  MachineRole? _currentRole;
  
  // Event controllers
  final StreamController<bool> _networkStatusController = StreamController<bool>.broadcast();
  Stream<bool> get onNetworkStatusChanged => _networkStatusController.stream;
  
  final StreamController<ConnectivityStatusEvent> _connectivityEventController = 
      StreamController<ConnectivityStatusEvent>.broadcast();
  Stream<ConnectivityStatusEvent> get onConnectivityEvent => _connectivityEventController.stream;
  
  // Status getters
  bool get isNetworkAvailable => _isNetworkAvailable;
  bool get isInitialized => _isInitialized;
  ConnectivityResult get currentConnectivity => _currentConnectivity;
  
  /// Initialize all connectivity-related services
  Future<void> initialize() async {
    if (_isInitialized) return;
    
    try {
      // Get current machine role
      _currentRole = await MachineConfigService.instance.machineRole;
      
      // Initialize network connectivity monitoring
      await _initializeNetworkMonitoring();
      
      // Initialize discovery service
      await _discoveryService.initialize();
      
      // Initialize sync manager
      await _syncManager.initialize();
      
      // Setup listeners for events from services
      _setupEventListeners();
      
      _isInitialized = true;
      _emitEvent(
        ConnectivityEventType.initialized,
        'Connectivity manager initialized'
      );
      
      // Start appropriate services based on role
      await _startServicesBasedOnRole();
      
    } catch (e) {
      debugPrint('Error initializing connectivity manager: $e');
      _emitEvent(
        ConnectivityEventType.error,
        'Error initializing connectivity manager: $e'
      );
      rethrow;
    }
  }
  
  /// Set up network connectivity monitoring
  Future<void> _initializeNetworkMonitoring() async {
    // Get current connectivity status
    _currentConnectivity = await Connectivity().checkConnectivity();
    _isNetworkAvailable = _currentConnectivity != ConnectivityResult.none;
    
    // Listen for connectivity changes
    Connectivity().onConnectivityChanged.listen((ConnectivityResult result) {
      final wasConnected = _isNetworkAvailable;
      _currentConnectivity = result;
      _isNetworkAvailable = result != ConnectivityResult.none;
      
      // Notify listeners if connectivity status changed
      if (wasConnected != _isNetworkAvailable) {
        _networkStatusController.add(_isNetworkAvailable);
        
        _emitEvent(
          _isNetworkAvailable 
              ? ConnectivityEventType.networkConnected 
              : ConnectivityEventType.networkDisconnected,
          'Network ${_isNetworkAvailable ? 'connected' : 'disconnected'}'
        );
        
        // If network became available, trigger actions
        if (_isNetworkAvailable && wasConnected == false) {
          _onNetworkRestored();
        }
      }
    });
  }
  
  /// Start appropriate services based on machine role
  Future<void> _startServicesBasedOnRole() async {
    if (_currentRole == null) {
      _currentRole = await MachineConfigService.instance.machineRole;
    }
    
    switch (_currentRole!) {
      case MachineRole.master:
        await _startMasterServices();
        break;
      case MachineRole.servant:
        await _startServantServices();
        break;
      case MachineRole.single:
        // No special services needed for single mode
        break;
    }
  }
  
  /// Start services needed for master mode
  Future<void> _startMasterServices() async {
    try {
      // Start redundancy service if not already running
      await _redundancyService.initialize();
      
      // Start discovery server to advertise presence
      await _discoveryService.startMasterDiscoveryServer();
      
      _emitEvent(
        ConnectivityEventType.info,
        'Master services started'
      );
    } catch (e) {
      debugPrint('Error starting master services: $e');
      _emitEvent(
        ConnectivityEventType.error,
        'Error starting master services: $e'
      );
    }
  }
  
  /// Start services needed for servant mode
  Future<void> _startServantServices() async {
    try {
      // Schedule periodic syncs based on settings
      await _syncManager.initialize();
      
      // If network is available, attempt initial sync
      if (_isNetworkAvailable) {
        unawaited(_attemptInitialSync());
      }
      
      _emitEvent(
        ConnectivityEventType.info,
        'Servant services started'
      );
    } catch (e) {
      debugPrint('Error starting servant services: $e');
      _emitEvent(
        ConnectivityEventType.error,
        'Error starting servant services: $e'
      );
    }
  }
  
  /// Set up listeners for events from various services
  void _setupEventListeners() {
    // Listen for sync events
    _syncManager.onSyncEvent.listen((syncEvent) {
      ConnectivityEventType eventType;
      
      switch (syncEvent.type) {
        case SyncEventType.error:
          eventType = ConnectivityEventType.syncError;
          break;
        case SyncEventType.completed:
          eventType = ConnectivityEventType.syncCompleted;
          break;
        case SyncEventType.started:
          eventType = ConnectivityEventType.syncStarted;
          break;
        case SyncEventType.conflict:
          eventType = ConnectivityEventType.syncConflict;
          break;
        case SyncEventType.progress:
        case SyncEventType.info:
        default:
          eventType = ConnectivityEventType.syncInfo;
          break;
      }
      
      _emitEvent(eventType, syncEvent.message, syncEvent.details);
    });
    
    // Listen for leader change events in master mode
    if (_currentRole == MachineRole.master) {
      _redundancyService.onLeaderChange.listen((leaderEvent) {
        final isNewLeader = leaderEvent.newLeaderId == 
            MachineConfigService.instance.machineId.toString();
        
        _emitEvent(
          isNewLeader 
              ? ConnectivityEventType.becameLeader 
              : ConnectivityEventType.leaderChanged,
          'Leader changed from ${leaderEvent.oldLeaderId ?? 'none'} to ${leaderEvent.newLeaderId}',
          {
            'old_leader': leaderEvent.oldLeaderId,
            'new_leader': leaderEvent.newLeaderId,
            'timestamp': leaderEvent.timestamp.toIso8601String()
          }
        );
      });
    }
    
    // Listen for discovery events
    _discoveryService.onMasterDiscovered.listen((masterInfo) {
      _emitEvent(
        ConnectivityEventType.masterDiscovered,
        'Discovered master: ${masterInfo.ip} (${masterInfo.deviceName})',
        {
          'ip': masterInfo.ip,
          'device_name': masterInfo.deviceName,
          'machine_id': masterInfo.machineId
        }
      );
    });
  }
  
  /// Emit a connectivity event
  void _emitEvent(ConnectivityEventType type, String message, [Map<String, dynamic>? details]) {
    _connectivityEventController.add(ConnectivityStatusEvent(
      type: type,
      message: message,
      details: details,
      timestamp: DateTime.now()
    ));
  }
  
  /// Handle network restoration
  Future<void> _onNetworkRestored() async {
    _emitEvent(
      ConnectivityEventType.networkRestored,
      'Network connectivity restored'
    );
    
    // If in servant mode, attempt to sync
    if (_currentRole == MachineRole.servant) {
      unawaited(_attemptInitialSync());
    }
    
    // If in master mode, check leadership status
    if (_currentRole == MachineRole.master) {
      final currentLeader = await _redundancyService.getCurrentLeader();
      if (currentLeader == null || !currentLeader.isActive) {
        // No active leader, initiate election
        unawaited(_redundancyService.forceElection());
      }
    }
  }
  
  /// Attempt initial sync after connectivity is established
  Future<void> _attemptInitialSync() async {
    try {
      // Wait a bit to ensure network is stable
      await Future.delayed(const Duration(seconds: 2));
      
      // Check if master address is configured
      final masterAddress = await MachineConfigService.instance.masterAddress;
      if (masterAddress == null || masterAddress.isEmpty) {
        // Try to discover masters
        final masters = await _discoveryService.discoverMasters();
        if (masters.isNotEmpty) {
          // Use first discovered master
          await MachineConfigService.instance.setMasterAddress(masters.first.ip);
          
          _emitEvent(
            ConnectivityEventType.masterDiscovered,
            'Automatically configured master: ${masters.first.ip} (${masters.first.deviceName})'
          );
        } else {
          _emitEvent(
            ConnectivityEventType.warning,
            'No master discovered, sync not possible'
          );
          return;
        }
      }
      
      // Attempt sync
      final result = await _syncManager.syncWithMaster();
      
      if (result.success) {
        _emitEvent(
          ConnectivityEventType.syncCompleted,
          'Initial sync completed: ${result.itemsSynced} items sent, ${result.itemsReceived} received'
        );
      } else {
        _emitEvent(
          ConnectivityEventType.syncError,
          'Initial sync failed: ${result.message}'
        );
      }
    } catch (e) {
      debugPrint('Error during initial sync: $e');
      _emitEvent(
        ConnectivityEventType.syncError,
        'Error during initial sync: $e'
      );
    }
  }
  
  /// Handle role change
  Future<void> handleRoleChange(MachineRole newRole) async {
    if (_currentRole == newRole) return;
    
    _currentRole = newRole;
    
    // Stop all services
    await _stopAllServices();
    
    // Start appropriate services for new role
    await _startServicesBasedOnRole();
    
    _emitEvent(
      ConnectivityEventType.roleChanged,
      'Machine role changed to ${newRole.toString().split('.').last}'
    );
  }
  
  /// Stop all running services
  Future<void> _stopAllServices() async {
    // Nothing to do for discovery service and redundancy service yet
    // They'll be reinitialized when needed
  }
  
  /// Get current sync status
  SyncStatus getSyncStatus() {
    return _syncManager.getSyncStatus();
  }
  
  /// Force sync with master
  Future<SyncResult> forceSyncWithMaster() {
    return _syncManager.forceSyncWithMaster();
  }
  
  /// Force leader election (in master mode)
  Future<LeaderInfo?> forceLeaderElection() {
    if (_currentRole != MachineRole.master) {
      throw Exception('Leader election can only be forced in master mode');
    }
    
    return _redundancyService.forceElection();
  }
  
  /// Get current leader info (in master mode)
  Future<LeaderInfo?> getCurrentLeader() {
    return _redundancyService.getCurrentLeader();
  }
  
  /// Get a list of discovered masters
  Future<List<MasterInfo>> discoverMasters() {
    return _discoveryService.discoverMasters();
  }
  
  /// Dispose resources
  void dispose() {
    _networkStatusController.close();
    _connectivityEventController.close();
    _syncManager.dispose();
    _redundancyService.dispose();
    _discoveryService.dispose();
  }
}

/// Connectivity event type
enum ConnectivityEventType {
  initialized,
  networkConnected,
  networkDisconnected,
  networkRestored,
  syncStarted,
  syncCompleted,
  syncError,
  syncInfo,
  syncConflict,
  masterDiscovered,
  leaderChanged,
  becameLeader,
  roleChanged,
  info,
  warning,
  error
}

/// Connectivity status event
class ConnectivityStatusEvent {
  final ConnectivityEventType type;
  final String message;
  final Map<String, dynamic>? details;
  final DateTime timestamp;
  
  const ConnectivityStatusEvent({
    required this.type,
    required this.message,
    this.details,
    required this.timestamp,
  });
} 