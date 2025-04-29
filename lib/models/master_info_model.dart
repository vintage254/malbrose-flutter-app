import 'package:flutter/foundation.dart';

/// Model representing a discovered master device in the network
class MasterInfo {
  /// IP address of the master device
  final String ip;
  
  /// Device name of the master (hostname)
  final String? deviceName;
  
  /// Version of the application running on the master
  final String? version;
  
  /// Signal strength indicator (for WiFi connections)
  final int? signalStrength;
  
  /// Whether the master is connected
  final bool isConnected;

  MasterInfo({
    required this.ip,
    this.deviceName,
    this.version,
    this.signalStrength,
    this.isConnected = false,
  });
  
  /// Create a MasterInfo instance from a JSON object
  factory MasterInfo.fromJson(Map<String, dynamic> json) {
    return MasterInfo(
      ip: json['ip'] as String,
      deviceName: json['deviceName'] as String?,
      version: json['version'] as String?,
      signalStrength: json['signalStrength'] as int?,
      isConnected: json['isConnected'] as bool? ?? false,
    );
  }
  
  /// Convert this MasterInfo instance to a JSON object
  Map<String, dynamic> toJson() {
    return {
      'ip': ip,
      'deviceName': deviceName,
      'version': version,
      'signalStrength': signalStrength,
      'isConnected': isConnected,
    };
  }
  
  /// Create a copy of this MasterInfo with some modified fields
  MasterInfo copyWith({
    String? ip,
    String? deviceName,
    String? version,
    int? signalStrength,
    bool? isConnected,
  }) {
    return MasterInfo(
      ip: ip ?? this.ip,
      deviceName: deviceName ?? this.deviceName,
      version: version ?? this.version,
      signalStrength: signalStrength ?? this.signalStrength,
      isConnected: isConnected ?? this.isConnected,
    );
  }
  
  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    
    return other is MasterInfo &&
        other.ip == ip &&
        other.deviceName == deviceName &&
        other.version == version &&
        other.signalStrength == signalStrength &&
        other.isConnected == isConnected;
  }
  
  @override
  int get hashCode => ip.hashCode ^ deviceName.hashCode ^ version.hashCode ^ signalStrength.hashCode ^ isConnected.hashCode;
} 