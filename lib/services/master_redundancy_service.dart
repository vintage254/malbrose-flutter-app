import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:my_flutter_app/services/database.dart';
import 'package:my_flutter_app/services/machine_config_service.dart';
import 'package:my_flutter_app/services/network_discovery_service.dart';
import 'package:synchronized/synchronized.dart';

/// Service that manages master redundancy and failover
class MasterRedundancyService {
  static final MasterRedundancyService _instance = MasterRedundancyService._internal();
  static MasterRedundancyService get instance => _instance;

  MasterRedundancyService._internal();
  
  // For testing purposes
  factory MasterRedundancyService() => _instance;
  
  // Key constants for database settings
  static const String _currentLeaderKey = 'current_leader';
  static const String _leaderHeartbeatKey = 'leader_heartbeat';
  static const String _leaderElectionKey = 'leader_election_in_progress';
  static const String _lastFailoverKey = 'last_failover_time';
  
  // Locks for thread safety
  final Lock _electionLock = Lock();
  
  // Heartbeat interval
  static const Duration _heartbeatInterval = Duration(seconds: 20);
  static const Duration _leaderInactiveThreshold = Duration(seconds: 60);
  
  // Timers
  Timer? _leaderHeartbeatTimer;
  Timer? _leaderCheckTimer;
  
  // Election in progress flag
  bool _electionInProgress = false;
  
  // Stream controller for leader change events
  final StreamController<LeaderChangeEvent> _leaderChangeEvents = 
      StreamController<LeaderChangeEvent>.broadcast();
  
  Stream<LeaderChangeEvent> get onLeaderChange => _leaderChangeEvents.stream;
  
  /// Initialize the master redundancy service
  Future<void> initialize() async {
    // Create required tables if they don't exist
    final db = await DatabaseService.instance.database;
    
    await db.execute('''
      CREATE TABLE IF NOT EXISTS settings (
        key TEXT PRIMARY KEY,
        value TEXT,
        updated_at TEXT NOT NULL
      )
    ''');
    
    // Start timers based on machine role
    final role = await MachineConfigService.instance.machineRole;
    
    if (role == MachineRole.master) {
      // Start heartbeat timer if this machine is a master
      _startHeartbeatTimer();
      
      // Start leader check timer
      _startLeaderCheckTimer();
    }
  }
  
  /// Start the heartbeat timer to update this machine's heartbeat
  void _startHeartbeatTimer() {
    _leaderHeartbeatTimer?.cancel();
    
    _leaderHeartbeatTimer = Timer.periodic(_heartbeatInterval, (_) async {
      try {
        // Only update heartbeat if this machine is the current leader
        final isLeader = await _isCurrentMachineLeader();
        if (isLeader) {
          await _updateLeaderHeartbeat();
        }
      } catch (e) {
        debugPrint('Error updating leader heartbeat: $e');
      }
    });
  }
  
  /// Start the leader check timer to detect leader failures
  void _startLeaderCheckTimer() {
    _leaderCheckTimer?.cancel();
    
    _leaderCheckTimer = Timer.periodic(_heartbeatInterval, (_) async {
      try {
        await _checkLeadership();
      } catch (e) {
        debugPrint('Error checking leadership: $e');
      }
    });
  }
  
  /// Check if this machine is the current leader
  Future<bool> _isCurrentMachineLeader() async {
    final db = await DatabaseService.instance.database;
    final machineId = await MachineConfigService.instance.machineId;
    
    final rows = await db.query(
      'settings',
      where: 'key = ?',
      whereArgs: [_currentLeaderKey],
      limit: 1
    );
    
    if (rows.isEmpty) {
      return false;
    }
    
    final leaderId = rows.first['value'] as String?;
    return leaderId == machineId;
  }
  
  /// Update the leader heartbeat timestamp
  Future<void> _updateLeaderHeartbeat() async {
    final db = await DatabaseService.instance.database;
    final now = DateTime.now().toIso8601String();
    
    final rows = await db.query(
      'settings',
      where: 'key = ?',
      whereArgs: [_leaderHeartbeatKey],
      limit: 1
    );
    
    if (rows.isEmpty) {
      await db.insert('settings', {
        'key': _leaderHeartbeatKey,
        'value': now,
        'updated_at': now
      });
    } else {
      await db.update(
        'settings',
        {'value': now, 'updated_at': now},
        where: 'key = ?',
        whereArgs: [_leaderHeartbeatKey]
      );
    }
  }
  
  /// Check leadership status and initiate election if needed
  Future<void> _checkLeadership() async {
    // Only run if this machine is in master mode
    final role = await MachineConfigService.instance.machineRole;
    if (role != MachineRole.master) {
      return;
    }
    
    await _electionLock.synchronized(() async {
      if (_electionInProgress) {
        return; // Don't run multiple elections simultaneously
      }
      
      final db = await DatabaseService.instance.database;
      
      // Check if there's a current leader
      final leaderRows = await db.query(
        'settings',
        where: 'key = ?',
        whereArgs: [_currentLeaderKey],
        limit: 1
      );
      
      final String? currentLeaderId = leaderRows.isNotEmpty ? 
          leaderRows.first['value'] as String? : null;
      
      // Check if leader heartbeat is recent
      bool leaderIsActive = false;
      final heartbeatRows = await db.query(
        'settings',
        where: 'key = ?',
        whereArgs: [_leaderHeartbeatKey],
        limit: 1
      );
      
      if (heartbeatRows.isNotEmpty) {
        final heartbeatStr = heartbeatRows.first['value'] as String?;
        if (heartbeatStr != null) {
          try {
            final heartbeat = DateTime.parse(heartbeatStr);
            final now = DateTime.now();
            leaderIsActive = now.difference(heartbeat) < _leaderInactiveThreshold;
          } catch (e) {
            leaderIsActive = false;
          }
        }
      }
      
      // Get this machine's ID
      final myMachineId = await MachineConfigService.instance.machineId;
      
      // Check if this machine is already the leader
      final isLeader = currentLeaderId == myMachineId;
      
      if (isLeader && !leaderIsActive) {
        // I'm the leader but my heartbeat is old - refresh it
        await _updateLeaderHeartbeat();
      } else if (!leaderIsActive || currentLeaderId == null) {
        // Leader is inactive or there is no leader - initiate election
        await _initiateElection();
      }
    });
  }
  
  /// Initiate a leader election
  Future<void> _initiateElection() async {
    final db = await DatabaseService.instance.database;
    
    try {
      _electionInProgress = true;
      
      // Mark election as in progress
      final now = DateTime.now().toIso8601String();
      await _setSettingValue(_leaderElectionKey, 'true', now);
      
      // Try to avoid race conditions by checking if another election is happening
      await Future.delayed(Duration(milliseconds: 500 + (DateTime.now().millisecondsSinceEpoch % 1000)));
      
      // Get participating machines (masters)
      final masters = await _getAvailableMasters();
      
      // Include this machine
      final myMachineId = await MachineConfigService.instance.machineId;
      
      // Select a leader based on machine ID (lowest wins for simplicity)
      String? newLeaderId;
      if (masters.isEmpty) {
        // Only this machine is available
        newLeaderId = myMachineId;
      } else {
        // Sort machine IDs
        final allMachineIds = [...masters.map((m) => m.machineId), myMachineId]
          ..sort(); // Simple string sort
        
        newLeaderId = allMachineIds.first;
      }
      
      // Set new leader
      final oldLeaderRows = await db.query(
        'settings',
        where: 'key = ?',
        whereArgs: [_currentLeaderKey],
        limit: 1
      );
      
      final oldLeaderId = oldLeaderRows.isNotEmpty ? 
          oldLeaderRows.first['value'] as String? : null;
      
      await _setSettingValue(_currentLeaderKey, newLeaderId!, now);
      
      // Set heartbeat time
      await _setSettingValue(_leaderHeartbeatKey, now, now);
      
      // Log the leader change
      if (oldLeaderId != newLeaderId) {
        await _logLeaderChange(oldLeaderId, newLeaderId);
        
        // Record failover time if this wasn't the first election
        if (oldLeaderId != null) {
          await _setSettingValue(_lastFailoverKey, now, now);
        }
        
        // Emit leader change event
        _leaderChangeEvents.add(LeaderChangeEvent(
          oldLeaderId: oldLeaderId,
          newLeaderId: newLeaderId,
          timestamp: DateTime.now()
        ));
      }
      
    } finally {
      // Clear election in progress
      await _setSettingValue(_leaderElectionKey, 'false', DateTime.now().toIso8601String());
      _electionInProgress = false;
    }
  }
  
  /// Get a list of available master machines on the network
  Future<List<MasterInfo>> _getAvailableMasters() async {
    try {
      return await NetworkDiscoveryService.instance.discoverMasters();
    } catch (e) {
      debugPrint('Error discovering masters: $e');
      return [];
    }
  }
  
  /// Utility to set a setting value
  Future<void> _setSettingValue(String key, String value, String timestamp) async {
    final db = await DatabaseService.instance.database;
    
    final rows = await db.query(
      'settings',
      where: 'key = ?',
      whereArgs: [key],
      limit: 1
    );
    
    if (rows.isEmpty) {
      await db.insert('settings', {
        'key': key,
        'value': value,
        'updated_at': timestamp
      });
    } else {
      await db.update(
        'settings',
        {'value': value, 'updated_at': timestamp},
        where: 'key = ?',
        whereArgs: [key]
      );
    }
  }
  
  /// Log a leader change event
  Future<void> _logLeaderChange(String? oldLeaderId, String newLeaderId) async {
    final db = await DatabaseService.instance.database;
    
    await db.insert('activity_logs', {
      'user_id': 0,
      'username': 'system',
      'action': 'system_event',
      'event_type': DatabaseService.eventLeaderChange,
      'details': jsonEncode({
        'old_leader': oldLeaderId,
        'new_leader': newLeaderId,
        'message': 'Leader changed from ${oldLeaderId ?? 'none'} to $newLeaderId'
      }),
      'timestamp': DateTime.now().toIso8601String(),
    });
    
    debugPrint('Leader changed from ${oldLeaderId ?? 'none'} to $newLeaderId');
  }
  
  /// Get the current leader information
  Future<LeaderInfo?> getCurrentLeader() async {
    final db = await DatabaseService.instance.database;
    
    final leaderRows = await db.query(
      'settings',
      where: 'key = ?',
      whereArgs: [_currentLeaderKey],
      limit: 1
    );
    
    if (leaderRows.isEmpty) {
      return null;
    }
    
    final leaderId = leaderRows.first['value'] as String?;
    if (leaderId == null) {
      return null;
    }
    
    // Check heartbeat time
    final heartbeatRows = await db.query(
      'settings',
      where: 'key = ?',
      whereArgs: [_leaderHeartbeatKey],
      limit: 1
    );
    
    DateTime? heartbeatTime;
    bool isActive = false;
    
    if (heartbeatRows.isNotEmpty) {
      final heartbeatStr = heartbeatRows.first['value'] as String?;
      if (heartbeatStr != null) {
        try {
          heartbeatTime = DateTime.parse(heartbeatStr);
          final now = DateTime.now();
          isActive = now.difference(heartbeatTime!) < _leaderInactiveThreshold;
        } catch (e) {
          // Invalid heartbeat time
        }
      }
    }
    
    // Check if this is the local machine
    final myMachineId = await MachineConfigService.instance.machineId;
    final isLocalMachine = leaderId == myMachineId;
    
    return LeaderInfo(
      machineId: leaderId,
      lastHeartbeat: heartbeatTime,
      isActive: isActive,
      isLocalMachine: isLocalMachine
    );
  }
  
  /// Force a leadership election (for manual failover)
  Future<LeaderInfo?> forceElection() async {
    await _initiateElection();
    return await getCurrentLeader();
  }
  
  /// Get the failover history
  Future<List<Map<String, dynamic>>> getFailoverHistory({int limit = 50}) async {
    final db = await DatabaseService.instance.database;
    
    return await db.query(
      'activity_logs',
      where: 'event_type = ?',
      whereArgs: ['leader_change'],
      orderBy: 'timestamp DESC',
      limit: limit
    );
  }
  
  /// Get time of last failover
  Future<DateTime?> getLastFailoverTime() async {
    final db = await DatabaseService.instance.database;
    
    final rows = await db.query(
      'settings',
      where: 'key = ?',
      whereArgs: [_lastFailoverKey],
      limit: 1
    );
    
    if (rows.isEmpty) {
      return null;
    }
    
    final timeStr = rows.first['value'] as String?;
    if (timeStr == null) {
      return null;
    }
    
    try {
      return DateTime.parse(timeStr);
    } catch (e) {
      return null;
    }
  }
  
  /// Dispose resources
  void dispose() {
    _leaderHeartbeatTimer?.cancel();
    _leaderCheckTimer?.cancel();
    _leaderChangeEvents.close();
  }
}

/// Information about the current leader
class LeaderInfo {
  final String machineId;
  final DateTime? lastHeartbeat;
  final bool isActive;
  final bool isLocalMachine;
  
  const LeaderInfo({
    required this.machineId,
    this.lastHeartbeat,
    required this.isActive,
    required this.isLocalMachine,
  });
}

/// Event fired when leader changes
class LeaderChangeEvent {
  final String? oldLeaderId;
  final String newLeaderId;
  final DateTime timestamp;
  
  const LeaderChangeEvent({
    this.oldLeaderId,
    required this.newLeaderId,
    required this.timestamp,
  });
} 