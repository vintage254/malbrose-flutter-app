class ActivityLog {
  final int id;
  final String username;
  final String action;
  final String? eventType;
  final String details;
  final DateTime timestamp;

  ActivityLog({
    required this.id,
    required this.username,
    required this.action,
    this.eventType,
    required this.details,
    required this.timestamp,
  });

  factory ActivityLog.fromMap(Map<String, dynamic> map) {
    return ActivityLog(
      id: map['id'],
      username: map['username'] ?? 'system',
      action: map['action'] ?? '',
      eventType: map['event_type'],
      details: map['details'] ?? '',
      timestamp: DateTime.parse(map['timestamp']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'username': username,
      'action': action,
      'event_type': eventType,
      'details': details,
      'timestamp': timestamp.toIso8601String(),
    };
  }
}


