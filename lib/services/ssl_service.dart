import 'dart:io';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:dio/dio.dart';
import 'package:dio/io.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:collection/collection.dart';

/// Mock implementation of X509Certificate for compatibility
class X509Certificate {
  final Uint8List data;
  
  X509Certificate(this.data);
  
  // These properties are needed for proper certificate comparison
  List<int> get der => data.toList();
  String get subject => 'CN=mock';
  String get issuer => 'CN=mock';
}

// Type alias to handle both dart:io and custom X509Certificate classes
typedef CertificateType = X509Certificate;

/// Mock implementation of HttpClientAdapter for compatibility
class HttpClientAdapter {
  Function(HttpClient)? onHttpClientCreate;
}

/// Service for managing SSL/TLS security for network communications
class SSLService {
  static final SSLService _instance = SSLService._internal();
  static SSLService get instance => _instance;
  
  SSLService._internal();
  
  // Certificate management
  String? _certificatePath;
  bool _strictCertificateChecking = false;
  List<X509Certificate>? _trustedCertificates;
  
  // Configure development vs production mode
  bool _isDevelopmentMode = false;
  
  // HTTP client with SSL configuration
  IOClient? _secureClient;
  
  // Dio HTTP client with SSL configuration
  Dio? _dioCLient;
  
  // Certificate paths
  String? _certPath;
  String? _keyPath;
  
  /// Initialize the SSL service
  Future<void> initialize({bool developmentMode = false}) async {
    _isDevelopmentMode = developmentMode;
    _strictCertificateChecking = !developmentMode;
    
    await _loadTrustedCertificates();
    await _generateSelfSignedCertificateIfNeeded();
    _createSecureClient();
    _createDioClient();
    
    debugPrint('SSL Service initialized. Development mode: $_isDevelopmentMode');
  }
  
  /// Get the secure HTTP client
  http.Client getClient() {
    if (_secureClient == null) {
      _createSecureClient();
    }
    return _secureClient ?? http.Client();
  }
  
  /// Get the Dio HTTP client
  Dio getDioClient() {
    if (_dioCLient == null) {
      _createDioClient();
    }
    return _dioCLient ?? Dio();
  }
  
  /// Set whether to use strict certificate checking
  void setStrictCertificateChecking(bool strictChecking) {
    _strictCertificateChecking = strictChecking;
    // Recreate the client with new settings
    _createSecureClient();
    _createDioClient();
  }
  
  /// Generate a self-signed certificate if one doesn't exist
  Future<void> _generateSelfSignedCertificateIfNeeded() async {
    try {
      final certDir = await _getCertificateDirectory();
      _certPath = p.join(certDir, 'server.crt');
      _keyPath = p.join(certDir, 'server.key');
      
      // Check if cert and key already exist
      final certFile = File(_certPath!);
      final keyFile = File(_keyPath!);
      
      if (await certFile.exists() && await keyFile.exists()) {
        debugPrint('Self-signed certificate already exists');
        // Add these certs to trusted certificates
        final certData = await certFile.readAsBytes();
        if (_trustedCertificates == null) {
          _trustedCertificates = [];
        }
        try {
          _trustedCertificates!.add(X509Certificate(certData));
        } catch (e) {
          debugPrint('Error adding existing cert to trusted list: $e');
        }
        return;
      }
      
      // For actual deployment, we would generate the certificate here using platform channels
      // For Windows, this would involve calling OpenSSL through a process
      
      // For development, we'll create a placeholder certificate from a PEM string
      // In production, you should replace this with proper certificate generation
      
      const String dummyCertPem = '''
-----BEGIN CERTIFICATE-----
MIIDvTCCAqWgAwIBAgIUBYuky3ht+dWr1B71qL5Rk/t6mrowDQYJKoZIhvcNAQEL
BQAwbjELMAkGA1UEBhMCVVMxCzAJBgNVBAgMAkNBMRYwFAYDVQQHDA1TYW4gRnJh
bmNpc2NvMRIwEAYDVQQKDAlNYWxicm9zZSAxDDAKBgNVBAsMA1BPUzEYMBYGA1UE
AwwPbWFsYnJvc2UubG9jYWwgMB4XDTIzMDYxMTE2MTUwMFoXDTI0MDYxMDE2MTUw
MFowbjELMAkGA1UEBhMCVVMxCzAJBgNVBAgMAkNBMRYwFAYDVQQHDA1TYW4gRnJh
bmNpc2NvMRIwEAYDVQQKDAlNYWxicm9zZSAxDDAKBgNVBAsMA1BPUzEYMBYGA1UE
AwwPbWFsYnJvc2UubG9jYWwgMIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKC
AQEAwJN5Lyj6ZI8n1yoJg1G3JE69x3LBGp4nDQRMV7HG1y7yoCJXBvzRyzzwFbkx
F31CU8QPfdAsZFHhSi/YuuHD8m/rzrV9rWU/sZXAqo8vvYo6nBhjGtJBGcZLFO/N
v59Df3PwTrXdXI76n7Ef3rr6P2SSFhLxrKTcAz3vn9UUr9UvxKTjpHwn1bdmrYwS
vJCQyjk5lxwQ7cB8IHENnpWgfA+NzCUyTr4DQQEZy/WYOTc1t8U1XxMuJFu5AupZ
u/5UrHwgJDLyPDyN7UPVXqNVfOZ7+y/xXYhb6FQOSmEJhNOOYXKNQ4ZOI6CbD9co
KyG6ZTmJGGu+33MvXfEBJyvH2QIDAQABo1MwUTAdBgNVHQ4EFgQUMwcPjAa6E5OG
yP4G0UBN0JWx6qUwHwYDVR0jBBgwFoAUMwcPjAa6E5OGyP4G0UBN0JWx6qUwDwYD
VR0TAQH/BAUwAwEB/zANBgkqhkiG9w0BAQsFAAOCAQEAX/SBbL9jJsF3IuQnxLgB
B/CcgJcUCtSYEt+LMBGjGMWX8vIqWWnnRY5PVroUkZtGEI5WCCSnrNdN0lFTE3FN
+l2PUW2lZuZ5Fh7WVITekKpVmBDCJj/C39iyOIPtZQJU5e+hrADgQnV0E/NLQFcn
LtQMMCekOZlLTXD0Cz1AY4USm9pDfD0Nv10iHIBPb/49XCH9h1O0jcuS3WLQgYnX
gOPP3MUs+G2xnT8+HIVLTcujd4BWXeoqLeJm2B+Qt9vJ1a9mOxzBHJOB3kFQMPOT
Mh7Zn5m+ZOzH/yrBymT3z1gCYrwqgrtnlj+fxm9TBL5x8bnz5YUXIXBdaZSQ23TQ
Zw==
-----END CERTIFICATE-----
''';

      const String dummyKeyPem = '''
-----BEGIN PRIVATE KEY-----
MIIEvQIBADANBgkqhkiG9w0BAQEFAASCBKcwggSjAgEAAoIBAQDAk3kvKPpkjyfX
KgmDUbckTr3HcsEanicNBExXscbXLvKgIlcG/NHLPPAVuTEXfUJTxA990CxkUeFK
L9i64cPyb+vOtX2tZT+xlcCqjy+9ijqcGGMa0kEZxksU782/n0N/c/BOtd1cjvqf
sR/euvo/ZJIW1EsptADPe+f1RSv1S/EpOOkfCfVt2atjBK8kJDKOTmXHBDtwHwgc
Q2elaB8D43MJTJO1gNBARnL9Zg5NzW3xTVfEy4kW7kC6lm7/lSsfCAkMvI8PI3tQ
9Veo1V85nv7L/FdiFvoVA5KYQmE0445hco1Dhk4joJsP1ygrIbplOYkYa77fcy9d
8QEnK8fZAgMBAAECggEAdkKZ+H8deMGJ40Xdm8BuGJxZ7iFqcovwPVeqQs5Ylyyn
WAIkuYXz+Db1hTVWdwJxVUHBE1ZNdUeW5DLjEcN92SL7E2GrtrB8Dma0xJXiEFgc
vqz9dQBXa8EXx8KYnlZ6+g7Ee+Kc/p2Fd3kE10K0RQpZSORdqnFaYFHU5S/YS/NG
xmPGiXXUVWZ9WNaCq1HiWmiPHYLcfCcYiIJL4I6cDLEYWYnqq2NzNCh1D4BwTHSv
Wbw0GSO9D8+3i3wy3lYwYX8hXRfGpz0qpV7i/6yiFBT15lLkEhYDLfCQUJt/sGpX
3JLn9VHsHNxK3CNnbhMfv2TqW85lJPnJP76Hn1zKXQKBgQDnL7tJAv1fwxLr1ymf
ggS6oNpZVYU+Q0Pnrwtxs9w8wdxLfI8tD8KY2JfBHoe0232ZkzIjbxQhkKWUEp3p
Lk47YWWWLrFZ6UBlOvZ8FxFT3hCJMVdkJSqm8WHGzpbFqrXnpg3BbBb8mGDwOOWe
IG2vFiLfSXeWm27nqLxARDydOWKUwwKBgQDVCYbC/f0FZ91l1xEz9JhXqCRIuYlD
eSwxXwOLzAZupnRvGVXQ9JZx37XNs1FY54mLCxU8/DPVpC2Qv/iAazp7+7XBkqLy
p1mtf264qH9YI97G70vTdBYsv25FS8QlQ5zOEzHJO8XvXP6mbErP0x1wWEOeBEfV
8s2gSj3QDTjCcwKBgCTBU5x84V5SuWp/wQfHLBjaYJN9YR9XTBuTnOUUHiOAkzB0
+ZVDW20qZXcCVEGV1KHYODSRJgGBp1NWWBvzH4R4KQ0A5XYYqPxL1VyZcbqDIuqD
JPMCYVFXf5v5Rw1hGNJ33yElPiwujDTRQ5MOG1Tpn1vGspLJL6G9mZF8R7+TAoGB
AK6d6fIcKRVcEwF81M3qGtE0hNsowCe0z0VouSCEA4LfvYJFdtbYWQq2aZhXnYOp
wv4tHdDLGG5IEShwVlYNFwpJI0RgiLWWO5iiRzjqT6UGAb7RIK4HFww+3X4KOlsN
mYPn5ISbtbvpnl3X4XWXIpZUj2bI4CCswQYx/U/H5+SHAoGAIbj/IdmF8ZYn2YLG
ywgxhzKZTc+pDpDffJIWM/WrOCQnD7cNGLwekIhFzVYdQFFTjdlBFWbT60HdkDuI
q8vQeQmLLOes8xqgVZtXpouzvmS5BYTX8qB5awdv9L1/9Tj1QJCoATtPGgRa8eQf
JfWmx/wDzQbxJVAawKm/zNLe2uI=
-----END PRIVATE KEY-----
''';

      // Write the certificates to disk
      await certFile.writeAsString(dummyCertPem);
      await keyFile.writeAsString(dummyKeyPem);
      
      debugPrint('Self-signed certificate generated at ${certFile.path}');
      
      // Add to trusted certificates
      if (_trustedCertificates == null) {
        _trustedCertificates = [];
      }
      
      try {
        final certData = utf8.encode(dummyCertPem);
        _trustedCertificates!.add(X509Certificate(Uint8List.fromList(certData)));
      } catch (e) {
        debugPrint('Error adding generated cert to trusted list: $e');
      }
      
    } catch (e) {
      debugPrint('Error generating self-signed certificate: $e');
    }
  }
  
  /// Load trusted certificates from app storage
  Future<void> _loadTrustedCertificates() async {
    try {
      final certificatePath = await _getCertificatePath();
      final certFile = File(certificatePath);
      
      if (await certFile.exists()) {
        final certData = await certFile.readAsBytes();
        _trustedCertificates = _parseCertificates(certData);
        debugPrint('Loaded ${_trustedCertificates?.length ?? 0} trusted certificates');
      } else {
        debugPrint('No trusted certificates found');
        _trustedCertificates = [];
      }
    } catch (e) {
      debugPrint('Error loading trusted certificates: $e');
      _trustedCertificates = [];
    }
  }
  
  /// Parse certificate data into X509Certificate objects
  List<X509Certificate> _parseCertificates(Uint8List certData) {
    try {
      // Creating a cert from data by using the default constructor
      return [X509Certificate(certData)];
    } catch (e) {
      debugPrint('Error parsing certificates: $e');
      return [];
    }
  }
  
  /// Create a secure HTTP client with proper SSL configuration
  void _createSecureClient() {
    try {
      // Create a HttpClient with custom security settings
      final httpClient = HttpClient();
      
      // Configure SSL verification
      httpClient.badCertificateCallback = (cert, String host, int port) {
        if (!_strictCertificateChecking) {
          // In development mode, accept all certificates
          debugPrint('Accepting certificate in development mode for $host:$port');
          return true;
        }
        
        if (_trustedCertificates != null) {
          // Check if the certificate is in our trusted list
          for (final trustedCert in _trustedCertificates!) {
            if (_compareCertificates(cert as CertificateType, trustedCert)) {
              debugPrint('Certificate for $host:$port matches trusted certificate');
              return true;
            }
          }
        }
        
        debugPrint('Rejecting untrusted certificate for $host:$port');
        return false;
      };
      
      // Create IOClient from the configured HttpClient
      _secureClient = IOClient(httpClient);
    } catch (e) {
      debugPrint('Error creating secure client: $e');
    }
  }
  
  /// Create a Dio client with SSL configuration
  void _createDioClient() {
    try {
      final dio = Dio();
      
      // Configure Dio to accept self-signed certificates in development mode
      final adapter = DefaultHttpClientAdapter();
      adapter.onHttpClientCreate = (HttpClient client) {
        client.badCertificateCallback = (cert, String host, int port) {
            if (!_strictCertificateChecking) {
              // In development mode, accept all certificates
              debugPrint('Dio accepting certificate in development mode for $host:$port');
              return true;
            }
            
            if (_trustedCertificates != null) {
              // Check if the certificate is in our trusted list
              for (final trustedCert in _trustedCertificates!) {
              if (_compareCertificates(cert as CertificateType, trustedCert)) {
                  debugPrint('Dio certificate for $host:$port matches trusted certificate');
                  return true;
                }
              }
            }
            
            debugPrint('Dio rejecting untrusted certificate for $host:$port');
            return false;
          };
          return client;
        };
      dio.httpClientAdapter = adapter;
      
      _dioCLient = dio;
    } catch (e) {
      debugPrint('Error creating Dio client: $e');
    }
  }
  
  /// Compare two X509Certificate objects to see if they're the same
  bool _compareCertificates(CertificateType cert1, CertificateType cert2) {
    try {
      // Use ListEquality directly from collection package
      return const ListEquality().equals(cert1.der, cert2.der);
    } catch (e) {
      debugPrint('Error comparing certificates: $e');
      return false;
    }
  }
  
  /// Get the path where certificates are stored
  Future<String> _getCertificatePath() async {
    if (_certificatePath != null) {
      return _certificatePath!;
    }
    
    final certDir = await _getCertificateDirectory();
    _certificatePath = p.join(certDir, 'trusted_certs.pem');
    
    return _certificatePath!;
  }
  
  /// Get the directory where certificates are stored
  Future<String> _getCertificateDirectory() async {
    final appDocDir = await getApplicationDocumentsDirectory();
    final certDir = p.join(appDocDir.path, 'certificates');
    
    // Create directory if it doesn't exist
    await Directory(certDir).create(recursive: true);
    
    return certDir;
  }
  
  /// Add a trusted certificate from PEM data
  Future<bool> addTrustedCertificate(String pemData) async {
    try {
      final certPath = await _getCertificatePath();
      final certFile = File(certPath);
      
      // Convert PEM to DER for storage
      final lines = pemData.split('\n')
          .where((line) => !line.startsWith('-----'))
          .join('');
      final certData = base64.decode(lines);
      
      // Store the certificate
      await certFile.writeAsBytes(certData, flush: true);
      
      // Reload certificates
      await _loadTrustedCertificates();
      _createSecureClient();
      _createDioClient();
      
      return true;
    } catch (e) {
      debugPrint('Error adding trusted certificate: $e');
      return false;
    }
  }
  
  /// Make a secure HTTPS request
  Future<http.Response> secureGet(String url, {Map<String, String>? headers}) async {
    final client = getClient();
    return client.get(Uri.parse(url), headers: headers);
  }
  
  /// Make a secure HTTPS POST request
  Future<http.Response> securePost(
    String url, 
    {Map<String, String>? headers, dynamic body}
  ) async {
    final client = getClient();
    return client.post(Uri.parse(url), headers: headers, body: body);
  }
  
  /// Get certificate file path - used by other services
  Future<String?> getCertificatePath() async {
    return _certPath;
  }
  
  /// Get key file path - used by other services
  Future<String?> getKeyPath() async {
    return _keyPath;
  }
  
  /// Get HTTP server SecurityContext for HTTPS
  Future<SecurityContext?> getServerSecurityContext() async {
    if (_certPath == null || _keyPath == null) {
      await _generateSelfSignedCertificateIfNeeded();
    }
    
    try {
      final context = SecurityContext();
      context.useCertificateChain(_certPath!);
      context.usePrivateKey(_keyPath!);
      return context;
    } catch (e) {
      debugPrint('Error creating security context: $e');
      return null;
    }
  }

  // Start an HTTPS server for master mode
  Future<HttpServer> startHttpsServer({
    required Handler handler,
    String address = '0.0.0.0',
    int port = 8443,
  }) async {
    // Create security context with certificates
    final securityContext = SecurityContext()
      ..useCertificateChain(_certPath!)
      ..usePrivateKey(_keyPath!);
    
    // Start HTTPS server
    final server = await shelf_io.serve(
      handler,
      address,
      port,
      securityContext: securityContext,
    );
    
    debugPrint('HTTPS server started at https://${server.address.host}:${server.port}');
    return server;
  }
} 