import 'package:intl/intl.dart';

class SyncLog {
  final int? id;
  final DateTime timestamp;
  final String type; // 'sync', 'conflict', 'error'
  final String status; // 'success', 'failed', 'partial'
  final String machineId;
  final String? tableName;
  final String? details;
  
  SyncLog({
    this.id,
    required this.timestamp,
    required this.type,
    required this.status,
    required this.machineId,
    this.tableName,
    this.details,
  });
  
  factory SyncLog.fromMap(Map<String, dynamic> map) {
    return SyncLog(
      id: map['id'] as int?,
      timestamp: DateTime.parse(map['timestamp']),
      type: map['type'],
      status: map['status'],
      machineId: map['machine_id'],
      tableName: map['table_name'],
      details: map['details'],
    );
  }
  
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'timestamp': timestamp.toIso8601String(),
      'type': type,
      'status': status,
      'machine_id': machineId,
      'table_name': tableName,
      'details': details,
    };
  }
  
  String get formattedTimestamp {
    return DateFormat('yyyy-MM-dd HH:mm:ss').format(timestamp);
  }
  
  @override
  String toString() {
    return 'SyncLog(id: $id, timestamp: $formattedTimestamp, type: $type, status: $status, machineId: $machineId, tableName: $tableName)';
  }
} 