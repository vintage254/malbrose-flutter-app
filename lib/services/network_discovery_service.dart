import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:async/async.dart';
import 'package:http/http.dart' as http;
import 'package:my_flutter_app/services/machine_config_service.dart';

/// Service for discovering master devices on the network using efficient broadcast-based methods
class NetworkDiscoveryService {
  static final NetworkDiscoveryService _instance = NetworkDiscoveryService._internal();
  static NetworkDiscoveryService get instance => _instance;
  
  NetworkDiscoveryService._internal();
  
  // For testing purposes
  factory NetworkDiscoveryService() => _instance;
  
  // Discovery constants - now configurable
  static int _configuredDiscoveryPort = 8765;
  static int get DISCOVERY_PORT => _configuredDiscoveryPort;
  static const String DISCOVERY_ACTION = 'discover_master';
  static const Duration DISCOVERY_TIMEOUT = Duration(seconds: 3);
  static const Duration SOCKET_INIT_TIMEOUT = Duration(seconds: 5);
  static const Duration CONNECTION_TEST_TIMEOUT = Duration(seconds: 5);
  static const int MAX_RETRIES = 3;
  
  // Allow configuration of discovery port
  static void setDiscoveryPort(int port) {
    _configuredDiscoveryPort = port;
  }
  
  // Network diagnostics
  final Map<String, dynamic> _discoveryStatistics = {
    'broadcasts_sent': 0,
    'responses_received': 0,
    'successful_connections': 0,
    'failed_connections': 0,
    'average_response_time_ms': 0,
    'last_discovery_time': null,
  };
  
  // Expose statistics with immutable map
  Map<String, dynamic> get discoveryStatistics => 
    Map.unmodifiable(_discoveryStatistics);
  
  // Socket for UDP communication
  RawDatagramSocket? _socket;
  
  // Flag to prevent concurrent operations
  bool _busy = false;
  bool _isServerMode = false;
  bool _isDisposed = false;
  
  // Cache discovered masters to reduce network traffic
  final Map<String, MasterInfo> _cache = {};
  DateTime _lastFullDiscovery = DateTime.fromMillisecondsSinceEpoch(0);
  
  // For preventing duplicate initializations
  Future<void>? _initializeFuture;
  
  // Discovery events
  final StreamController<MasterInfo> _discoveryEvents = StreamController<MasterInfo>.broadcast();
  Stream<MasterInfo> get onMasterDiscovered => _discoveryEvents.stream;
  
  // Master disconnection events
  final StreamController<MasterInfo> _masterDisconnectedEvents = StreamController<MasterInfo>.broadcast();
  Stream<MasterInfo> get onMasterDisconnected => _masterDisconnectedEvents.stream;
  
  // Initialize discovery service for client mode
  Future<void> initialize() {
    if (_isDisposed) {
      throw StateError('Cannot initialize a disposed NetworkDiscoveryService');
    }
    
    if (_initializeFuture != null) {
      return _initializeFuture!;
    }

    _initializeFuture = _doInitialize()
        .timeout(SOCKET_INIT_TIMEOUT, onTimeout: () {
          debugPrint('Socket initialization timed out');
          return;
        });
    return _initializeFuture!;
  }
  
  Future<void> _doInitialize() async {
    // Skip initialization if we're already in server mode
    if (_isServerMode) {
      return;
    }
    
    // Safely close existing socket if present
    if (_socket != null) {
      try {
        final socket = _socket;
        if (socket != null) {
          socket.close();
        }
      } catch (e) {
        debugPrint('Error closing existing socket: $e');
      } finally {
        _socket = null;
      }
    }
    
    try {
      // Try to bind to the socket with preferred ports first
      _socket = await _bindToAvailablePort([0]); // For client mode, dynamic port is fine
      
      if (_socket != null) {
        _socket!.broadcastEnabled = true;
        _setupSocketListener();
        debugPrint('Network discovery service initialized on port ${_socket!.port}');
      } else {
        debugPrint('Failed to initialize socket for network discovery');
      }
    } catch (e) {
      debugPrint('Error initializing network discovery service: $e');
      // Reset initialization future to allow retry
      _initializeFuture = null;
    }
  }
  
  // Helper method to bind to first available port from a list
  Future<RawDatagramSocket?> _bindToAvailablePort(List<int> preferredPorts) async {
    RawDatagramSocket? socket;
    Exception? lastError;
    
    // Try each preferred port
    for (final port in preferredPorts) {
      try {
        socket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, port);
        debugPrint('Successfully bound to port $port');
        return socket;
      } catch (e) {
        lastError = e is Exception ? e : Exception(e.toString());
        debugPrint('Could not bind to port $port: $e');
      }
    }
    
    // If we couldn't bind to any preferred port, try dynamic assignment (port 0)
    if (!preferredPorts.contains(0)) {
      try {
        socket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);
        debugPrint('Bound to dynamically assigned port ${socket.port}');
        return socket;
      } catch (e) {
        lastError = e is Exception ? e : Exception(e.toString());
        debugPrint('Could not bind to dynamic port: $e');
      }
    }
    
    if (lastError != null) {
      throw lastError;
    }
    
    return null; // This should never happen due to the exception above
  }
  
  // Set up socket listener with proper error handling
  void _setupSocketListener() {
    final socket = _socket;
    if (socket == null) {
      debugPrint('Cannot set up listener on null socket');
      return;
    }
    
    socket.listen(
      (RawSocketEvent event) {
        if (_isDisposed) return;
        if (event == RawSocketEvent.read) {
          final currentSocket = _socket;
          if (currentSocket == null) return;
          
          final datagram = currentSocket.receive();
          if (datagram != null) {
            if (_isServerMode) {
              // For server mode, handle discovery requests
              // Use a separate method call instead of direct await
              _handleDiscoveryRequestSafely(currentSocket, datagram);
            } else {
              _processDiscoveryResponse(datagram);
            }
          }
        }
      },
      onError: (error) {
        debugPrint('Socket error: $error');
      },
      onDone: () {
        debugPrint('Socket listener closed');
      },
      cancelOnError: false,
    );
  }
  
  // Non-blocking wrapper for handling discovery requests
  void _handleDiscoveryRequestSafely(RawDatagramSocket socket, Datagram datagram) {
    // Start a new zone-isolated future to handle the request
    // ignore: unawaited_futures
    () async {
      try {
        await _handleDiscoveryRequest(socket, datagram);
      } catch (e) {
        debugPrint('Error handling discovery request: $e');
      }
    }();
  }
  
  void _processDiscoveryResponse(Datagram datagram) {
    try {
      final data = utf8.decode(datagram.data);
      final response = jsonDecode(data);
      
      // Update statistics safely
      _incrementStatistic('responses_received');
      
      // Validate response format with safer null checks
      if (response is Map<String, dynamic> && 
          response['role'] == 'master' &&
          response.containsKey('machine_id')) {
        
        final masterInfo = MasterInfo(
          ip: datagram.address.address,
          machineId: response['machine_id']?.toString() ?? '',
          deviceName: response['device_name']?.toString(),
          version: response['version']?.toString(),
          lastSeen: DateTime.now(),
          secure: response['secure'] == true,
          port: _parsePortSafely(response['port']),
        );
        
        // Update cache
        _cache[masterInfo.ip] = masterInfo;
        
        // Notify listeners
        if (!_discoveryEvents.isClosed) {
          _discoveryEvents.add(masterInfo);
        }
        
        debugPrint('Discovered master: ${masterInfo.ip} (${masterInfo.deviceName})');
      } else {
        debugPrint('Received invalid discovery response: $response');
      }
    } catch (e) {
      debugPrint('Error processing discovery response: $e');
    }
  }
  
  // Helper to safely parse port values
  int _parsePortSafely(dynamic portValue) {
    if (portValue == null) return 8080;
    
    if (portValue is int) {
      return portValue;
    }
    
    try {
      return int.parse(portValue.toString());
    } catch (e) {
      return 8080; // Default port
    }
  }
  
  // Helper to safely increment statistics
  void _incrementStatistic(String key, [int amount = 1]) {
    try {
      if (_discoveryStatistics.containsKey(key)) {
        final currentValue = _discoveryStatistics[key];
        if (currentValue is int) {
          _discoveryStatistics[key] = currentValue + amount;
        }
      }
    } catch (e) {
      debugPrint('Error updating statistic $key: $e');
    }
  }
  
  /// Discover master devices on the network
  /// Returns a list of discovered master devices
  Future<List<MasterInfo>> discoverMasters({bool useCache = true}) {
    // Check if we have a recent cache and useCache is true
    final now = DateTime.now();
    if (useCache && 
        _cache.isNotEmpty && 
        now.difference(_lastFullDiscovery).inSeconds < 30) {
      return Future.value(_cache.values.toList());
    }
    
    // Check if we're already busy
    if (_busy || _isDisposed) {
      return Future.value(_cache.values.toList());
    }
    
    _setBusy(true);
    
    // Clear cache for fresh discovery
    if (!useCache) {
      _cache.clear();
    }
    
    return _doDiscoverMasters(now).whenComplete(() {
      _setBusy(false);
    });
  }
  
  Future<List<MasterInfo>> _doDiscoverMasters(DateTime startTime) async {
    // Ensure socket is initialized
    if (_socket == null) {
      try {
        await initialize();
      } catch (e) {
        debugPrint('Failed to initialize for discovery: $e');
        return _cache.values.toList();
      }
    }
    
    // Update statistics
    _discoveryStatistics['last_discovery_time'] = startTime.toIso8601String();
    _lastFullDiscovery = startTime;
    
    // Create the completer for async result
    final resultCompleter = Completer<List<MasterInfo>>();
    
    // Set timeout for discovery operation
    Timer? timeoutTimer;
    timeoutTimer = Timer(DISCOVERY_TIMEOUT, () {
      if (!resultCompleter.isCompleted) {
        resultCompleter.complete(_cache.values.toList());
        debugPrint('Discovery operation timed out');
      }
    });
    
    try {
      // Make sure we have a socket
      final socket = _socket;
      if (socket == null) {
        if (!resultCompleter.isCompleted) {
          resultCompleter.complete([]);
        }
        timeoutTimer.cancel();
        return [];
      }
      
      // Get machine ID safely
      final machineId = await MachineConfigService.instance.machineId;
      
      if (_isDisposed || resultCompleter.isCompleted) {
        timeoutTimer.cancel();
        return _cache.values.toList();
      }
        
      try {
        // Discovery message
        final message = jsonEncode({
          'action': DISCOVERY_ACTION,
          'machine_id': machineId,
          'timestamp': DateTime.now().millisecondsSinceEpoch,
        });
        
        // Check if socket is still available
        if (_socket == null || _isDisposed) {
          if (!resultCompleter.isCompleted) {
            resultCompleter.complete(_cache.values.toList());
          }
          timeoutTimer.cancel();
          return _cache.values.toList();
        }
        
        // Send broadcast message to all devices on network
        final broadcastBytes = socket.send(
          utf8.encode(message),
          InternetAddress('255.255.255.255'),
          DISCOVERY_PORT
        );
        debugPrint('Sent broadcast message ($broadcastBytes bytes)');
        
        // Update statistics
        _incrementStatistic('broadcasts_sent');
        
        // Also try common subnet broadcasts for networks that block global broadcast
        for (final subnet in ['192.168.1.255', '192.168.0.255', '10.0.0.255']) {
          // Check if socket is still valid
          if (_socket == null || _isDisposed) break;
          
          final subnetBytes = socket.send(
            utf8.encode(message),
            InternetAddress(subnet),
            DISCOVERY_PORT
          );
          debugPrint('Sent subnet broadcast to $subnet ($subnetBytes bytes)');
          
          // Update statistics
          _incrementStatistic('broadcasts_sent');
        }
        
        // Schedule completion after timeout
        Future.delayed(DISCOVERY_TIMEOUT).then((_) {
          if (!resultCompleter.isCompleted) {
            resultCompleter.complete(_cache.values.toList());
          }
        });
          
      } catch (e) {
        debugPrint('Error sending discovery broadcast: $e');
        if (!resultCompleter.isCompleted) {
          resultCompleter.complete(_cache.values.toList());
        }
      }
    } catch (e) {
      debugPrint('Error in discovery process: $e');
      if (!resultCompleter.isCompleted) {
        resultCompleter.complete(_cache.values.toList());
      }
    }
    
    // Wait for completion (either by responses or timeout)
    final result = await resultCompleter.future;
    timeoutTimer.cancel();
    return result;
  }
  
  /// Test connection to a master by IP address
  Future<bool> testMasterConnection(String ip, [int port = 8080]) async {
    if (_isDisposed) {
      return false;
    }
    
    try {
      // Build the URL
      final uri = Uri.parse('http://$ip:$port/api/status');
      
      // Set a timeout to avoid hanging
      final response = await http.get(uri)
          .timeout(CONNECTION_TEST_TIMEOUT, onTimeout: () {
            throw TimeoutException('Connection timed out');
          });
      
      // Update statistics
      _incrementStatistic('successful_connections');
      
      // Check if master is in our cache and notify if connection was successful
      if (_cache.containsKey(ip) && !_masterDisconnectedEvents.isClosed) {
        // Don't notify here - this is a successful connection
      }
      
      return response.statusCode == 200;
    } catch (e) {
      debugPrint('Error testing connection to master at $ip:$port: $e');
      
      // Update statistics
      _incrementStatistic('failed_connections');
      
      // If we have this master in our cache, send a disconnection event
      if (_cache.containsKey(ip) && !_masterDisconnectedEvents.isClosed) {
        _masterDisconnectedEvents.add(_cache[ip]!);
      }
      
      return false;
    }
  }
  
  /// Test connection with retry logic for more reliability
  Future<bool> testMasterConnectionWithRetry(String ip, [int port = 8080, int retries = 3]) async {
    if (_isDisposed) return false;
    
    final actualRetries = retries.clamp(1, MAX_RETRIES);
    
    for (int i = 0; i < actualRetries; i++) {
      final result = await testMasterConnection(ip, port);
      if (result) return true;
      
      // Wait before retrying with exponential backoff
      if (i < actualRetries - 1) {
        await Future.delayed(Duration(milliseconds: 500 * (i + 1)));
      }
      
      // Check if service has been disposed during retry
      if (_isDisposed) return false;
    }
    return false;
  }
  
  /// Start master discovery server to listen for discovery requests
  Future<void> startMasterDiscoveryServer() async {
    if (_isDisposed) {
      debugPrint('Cannot start server on disposed NetworkDiscoveryService');
      return;
    }
    
    if (_busy) {
      debugPrint('Network discovery service busy. Skipping startMasterDiscoveryServer');
      return;
    }

    try {
      _setBusy(true);
      await _startDiscoveryServer();
    } catch (e) {
      debugPrint('Error in startMasterDiscoveryServer: $e');
    } finally {
      _setBusy(false);
    }
  }
  
  Future<void> _startDiscoveryServer() async {
    // Close any existing socket first
    if (_socket != null) {
      try {
        final socket = _socket;
        if (socket != null) {
          socket.close();
        }
      } catch (e) {
        debugPrint('Error closing existing socket: $e');
      } finally {
        _socket = null;
      }
    }
    
    try {
      // Try to bind to preferred ports for server mode
      _socket = await _bindToAvailablePort([DISCOVERY_PORT, 8766, 8767]);
      
      if (_socket == null) {
        debugPrint('Failed to create socket for discovery server');
        return;
      }
      
      _isServerMode = true;
      _socket!.broadcastEnabled = true;
      
      _setupSocketListener();
      
      debugPrint('Master discovery server started on port ${_socket!.port}');
    } catch (e) {
      debugPrint('Failed to start master discovery server: $e');
    }
  }
  
  Future<void> _handleDiscoveryRequest(RawDatagramSocket socket, Datagram datagram) async {
    if (_isDisposed || socket != _socket) return;
    
    try {
      final data = utf8.decode(datagram.data);
      final request = jsonDecode(data);
      
      // Validate request
      if (request is Map<String, dynamic> && 
          request['action'] == DISCOVERY_ACTION) {
        
        // Get machine info
        final String machineId;
        final String deviceName;
        
        try {
          machineId = await MachineConfigService.instance.machineId;
          deviceName = await MachineConfigService.instance.getDeviceName();
        } catch (e) {
          debugPrint('Error fetching machine info: $e');
          return;
        }
        
        const httpPort = 8080; // This should be the actual port your HTTP server is running on
        const secureMode = false; // Replace with actual implementation
        
        // Create response with all required fields
        final response = jsonEncode({
          'role': 'master',
          'machine_id': machineId,
          'device_name': deviceName,
          'version': '1.0.0', // App version
          'timestamp': DateTime.now().millisecondsSinceEpoch,
          'secure': secureMode,
          'port': httpPort,
        });
        
        // Verify socket is still valid
        if (_socket == null || _isDisposed) return;
        
        // Send response directly to requesting device
        final sentBytes = socket.send(
          utf8.encode(response),
          datagram.address,
          datagram.port
        );
        debugPrint('Sent $sentBytes bytes to ${datagram.address.address}:${datagram.port}');
      }
    } catch (e) {
      debugPrint('Error handling discovery request: $e');
    }
  }
  
  /// Clear the discovered masters cache
  void clearCache() {
    _cache.clear();
    _lastFullDiscovery = DateTime.fromMillisecondsSinceEpoch(0);
  }
  
  /// Reset discovery statistics
  void resetStatistics() {
    _discoveryStatistics['broadcasts_sent'] = 0;
    _discoveryStatistics['responses_received'] = 0;
    _discoveryStatistics['successful_connections'] = 0;
    _discoveryStatistics['failed_connections'] = 0;
    _discoveryStatistics['average_response_time_ms'] = 0;
    _discoveryStatistics['last_discovery_time'] = null;
  }
  
  void _setBusy(bool value) {
    _busy = value;
  }
  
  /// Dispose of resources
  void dispose() {
    if (_isDisposed) return;
    
    _isDisposed = true;
    
    // Close event streams
    if (!_discoveryEvents.isClosed) {
      _discoveryEvents.close();
    }
    
    if (!_masterDisconnectedEvents.isClosed) {
      _masterDisconnectedEvents.close();
    }
    
    // Close socket safely
    final socket = _socket;
    if (socket != null) {
      try {
        socket.close();
        _socket = null;
      } catch (e) {
        debugPrint('Error in socket disposal: $e');
        _socket = null;
      }
    }
    
    _cache.clear();
    _initializeFuture = null;
    _isServerMode = false;
    _busy = false;
  }
}

/// Class to hold information about discovered master devices
class MasterInfo {
  final String ip;
  final String machineId;
  final String? deviceName;
  final String? version;
  final DateTime lastSeen;
  final bool secure;
  final int port;
  
  const MasterInfo({
    required this.ip,
    required this.machineId,
    this.deviceName,
    this.version,
    required this.lastSeen,
    this.secure = false,
    this.port = 8080,
  });
  
  /// Get the connection URL for this master
  String get connectionUrl {
    final protocol = secure ? 'https' : 'http';
    return '$protocol://$ip:$port';
  }
  
  /// Create a full URI for a specific API endpoint
  Uri getApiEndpointUri(String path) {
    final protocol = secure ? 'https' : 'http';
    return Uri.parse('$protocol://$ip:$port$path');
  }
  
  /// Check if secure connection is required
  bool get isSecureConnectionRequired => secure;
  
  /// Format a display name for this master
  String get displayName {
    return deviceName != null && deviceName!.isNotEmpty 
        ? '$deviceName ($ip)' 
        : ip;
  }
  
  @override
  String toString() {
    return displayName;
  }
}