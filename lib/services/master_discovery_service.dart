import 'dart:async';
import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:network_info_plus/network_info_plus.dart';
import '../models/master_info_model.dart';

/// Enum representing different connection types
enum ConnectionType {
  wifi,
  ethernet,
}

/// Enum representing the current status of master discovery
enum DiscoveryStatus {
  idle,
  scanning,
  found,
  failed,
  connected,
}

class MasterDiscoveryService extends ChangeNotifier {
  List<MasterInfo> _discoveredMasters = [];
  MasterInfo? _selectedMaster;
  bool _isScanning = false;
  String _errorMessage = '';
  Timer? _scanTimer;
  final int _discoveryPort = 8080;
  final Duration _scanTimeout = const Duration(seconds: 10);
  final Duration _refreshInterval = const Duration(seconds: 30);
  DiscoveryStatus _status = DiscoveryStatus.idle;
  ConnectionType _connectionType = ConnectionType.wifi;

  /// Get the list of discovered masters
  List<MasterInfo> get discoveredMasters => _discoveredMasters;

  /// Get the currently selected master
  MasterInfo? get selectedMaster => _selectedMaster;

  /// Check if discovery is in progress
  bool get isScanning => _isScanning;

  /// Get the last error message
  String get errorMessage => _errorMessage;

  /// Get the current discovery status
  DiscoveryStatus get status => _status;

  /// Get the current connection type
  ConnectionType get connectionType => _connectionType;

  /// Set the connection type for discovery
  void setConnectionType(ConnectionType type) {
    _connectionType = type;
    notifyListeners();
    
    // If we're already scanning, restart it with the new connection type
    if (_isScanning) {
      stopDiscovery();
      startDiscovery();
    }
  }

  /// Start discovering masters on the network
  Future<void> startDiscovery() async {
    if (_isScanning) return;
    
    _isScanning = true;
    _status = DiscoveryStatus.scanning;
    _discoveredMasters = [];
    _errorMessage = '';
    notifyListeners();
    
    try {
      final connectivityResult = await Connectivity().checkConnectivity();
      
      // Check if the device is connected to a network
      if (connectivityResult == ConnectivityResult.none) {
        _errorMessage = 'No network connection available';
        _status = DiscoveryStatus.failed;
        _isScanning = false;
        notifyListeners();
        return;
      }
      
      // Perform discovery based on connection type
      if (_connectionType == ConnectionType.wifi) {
        await _discoverMastersWifi();
      } else {
        await _discoverMastersEthernet();
      }
      
      // Set a timer to cancel the discovery after the timeout
      _scanTimer = Timer(_scanTimeout, () {
        if (_isScanning) {
          stopDiscovery();
          if (_discoveredMasters.isEmpty) {
            _status = DiscoveryStatus.failed;
            _errorMessage = 'No masters found';
          } else {
            _status = DiscoveryStatus.found;
          }
          notifyListeners();
        }
      });
    } catch (e) {
      _errorMessage = 'Error during discovery: $e';
      _status = DiscoveryStatus.failed;
      _isScanning = false;
      notifyListeners();
    }
  }

  /// Discover masters on WiFi networks
  Future<void> _discoverMastersWifi() async {
    try {
      final info = NetworkInfo();
      final wifiIP = await info.getWifiIP();
      
      if (wifiIP == null) {
        _errorMessage = 'Could not get WiFi IP address';
        _status = DiscoveryStatus.failed;
        _isScanning = false;
        notifyListeners();
        return;
      }
      
      // Determine network range from the WiFi IP
      final ipParts = wifiIP.split('.');
      if (ipParts.length != 4) {
        _errorMessage = 'Invalid IP address format';
        _status = DiscoveryStatus.failed;
        _isScanning = false;
        notifyListeners();
        return;
      }
      
      // Scan addresses in the same subnet
      final baseIP = '${ipParts[0]}.${ipParts[1]}.${ipParts[2]}';
      
      // Scan 1-254 (typical range for local networks)
      for (int i = 1; i <= 254; i++) {
        if (!_isScanning) break; // Stop if discovery was cancelled
        
        final targetIP = '$baseIP.$i';
        if (targetIP == wifiIP) continue; // Skip own IP
        
        _probeIP(targetIP);
      }
    } catch (e) {
      _errorMessage = 'WiFi discovery error: $e';
      notifyListeners();
    }
  }

  /// Discover masters on Ethernet networks
  Future<void> _discoverMastersEthernet() async {
    try {
      // Get network interfaces
      final interfaces = await NetworkInterface.list(
        includeLoopback: false,
        type: InternetAddressType.IPv4,
      );
      
      // Find Ethernet interfaces
      final ethernetInterfaces = interfaces.where(
        (interface) => !interface.name.toLowerCase().contains('wifi')
      );
      
      if (ethernetInterfaces.isEmpty) {
        _errorMessage = 'No Ethernet connection found';
        _status = DiscoveryStatus.failed;
        _isScanning = false;
        notifyListeners();
        return;
      }
      
      // Probe on each Ethernet interface
      for (final interface in ethernetInterfaces) {
        for (final addr in interface.addresses) {
          if (addr.type == InternetAddressType.IPv4) {
            final ipParts = addr.address.split('.');
            if (ipParts.length != 4) continue;
            
            // Scan addresses in the same subnet
            final baseIP = '${ipParts[0]}.${ipParts[1]}.${ipParts[2]}';
            
            // Scan 1-254 (typical range for local networks)
            for (int i = 1; i <= 254; i++) {
              if (!_isScanning) break; // Stop if discovery was cancelled
              
              final targetIP = '$baseIP.$i';
              if (targetIP == addr.address) continue; // Skip own IP
              
              _probeIP(targetIP);
            }
          }
        }
      }
    } catch (e) {
      _errorMessage = 'Ethernet discovery error: $e';
      notifyListeners();
    }
  }

  /// Probe a specific IP address to check if it's a master
  Future<void> _probeIP(String ip) async {
    try {
      // Create a socket with a short timeout
      final socket = await Socket.connect(
        ip,
        _discoveryPort,
        timeout: const Duration(milliseconds: 300),
      );
      
      // Send discovery request
      socket.write(json.encode({
        'action': 'discovery',
        'client_info': {
          'name': 'Flutter Client',
          'version': '1.0.0',
        }
      }));
      
      // Wait for response
      socket.listen(
        (data) {
          final response = utf8.decode(data);
          try {
            final Map<String, dynamic> jsonResponse = json.decode(response);
            
            if (jsonResponse.containsKey('device_type') && 
                jsonResponse['device_type'] == 'master') {
              
              // Create master info
              final MasterInfo masterInfo = MasterInfo(
                ip: ip,
                deviceName: jsonResponse['device_name'],
                version: jsonResponse['version'],
                signalStrength: jsonResponse['signal_strength'],
              );
              
              // Add to discovered masters if not already present
              if (!_discoveredMasters.any((m) => m.ip == ip)) {
                _discoveredMasters.add(masterInfo);
                _status = DiscoveryStatus.found;
                notifyListeners();
              }
            }
          } catch (e) {
            // Invalid response format, ignore
          }
          
          socket.close();
        },
        onDone: () {
          socket.close();
        },
        onError: (e) {
          socket.close();
        },
      );
    } catch (e) {
      // Connection failed, not a master or not reachable
    }
  }

  /// Stop the discovery process
  void stopDiscovery() {
    _isScanning = false;
    _scanTimer?.cancel();
    _scanTimer = null;
    notifyListeners();
  }

  /// Select a master from the discovered list
  void selectMaster(MasterInfo master) {
    _selectedMaster = master;
    _status = DiscoveryStatus.connected;
    notifyListeners();
  }

  /// Connect to a master by IP address directly
  Future<void> connectToMaster(String ip) async {
    try {
      _status = DiscoveryStatus.scanning;
      notifyListeners();
      
      // Attempt to connect to the master
      final socket = await Socket.connect(
        ip,
        _discoveryPort,
        timeout: const Duration(seconds: 5),
      );
      
      // Send discovery request
      socket.write(json.encode({
        'action': 'discovery',
        'client_info': {
          'name': 'Flutter Client',
          'version': '1.0.0',
        }
      }));
      
      // Create a completer to handle the async response
      final completer = Completer<MasterInfo?>();
      
      // Wait for response
      socket.listen(
        (data) {
          final response = utf8.decode(data);
          try {
            final Map<String, dynamic> jsonResponse = json.decode(response);
            
            if (jsonResponse.containsKey('device_type') && 
                jsonResponse['device_type'] == 'master') {
              
              // Create master info
              final MasterInfo masterInfo = MasterInfo(
                ip: ip,
                deviceName: jsonResponse['device_name'],
                version: jsonResponse['version'],
              );
              
              completer.complete(masterInfo);
            } else {
              completer.complete(null);
            }
          } catch (e) {
            completer.complete(null);
          }
          
          socket.close();
        },
        onDone: () {
          if (!completer.isCompleted) {
            completer.complete(null);
          }
          socket.close();
        },
        onError: (e) {
          if (!completer.isCompleted) {
            completer.complete(null);
          }
          socket.close();
        },
      );
      
      // Wait for the response or timeout
      final masterInfo = await completer.future;
      
      if (masterInfo != null) {
        _selectedMaster = masterInfo;
        
        // Add to discovered masters if not already present
        if (!_discoveredMasters.any((m) => m.ip == ip)) {
          _discoveredMasters.add(masterInfo);
        }
        
        _status = DiscoveryStatus.connected;
      } else {
        _errorMessage = 'No master found at $ip';
        _status = DiscoveryStatus.failed;
      }
    } catch (e) {
      _errorMessage = 'Connection failed: $e';
      _status = DiscoveryStatus.failed;
    }
    
    notifyListeners();
  }

  @override
  void dispose() {
    stopDiscovery();
    super.dispose();
  }
}