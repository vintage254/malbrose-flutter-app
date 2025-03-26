import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:network_info_plus/network_info_plus.dart';

class ConfigService {
  static final ConfigService instance = ConfigService._init();
  ConfigService._init();
  
  // Database configuration
  bool _isMaster = false;
  String _masterIp = 'localhost';
  int _dbPort = 3306;
  String _dbUsername = 'root';
  String _dbPassword = '';
  String _dbName = 'malbrose_pos';
  
  // Business information
  String _businessName = 'Malbrose Hardware Store';
  String _businessAddress = 'Eldoret';
  String _businessPhone = '0720319340, 0721705613';
  String _businessEmail = '';
  String _businessLogo = '';
  
  // App configuration
  final String _appVersion = '1.0.0';
  bool _setupCompleted = false;
  
  // Getters
  bool get isMaster => _isMaster;
  String get masterIp => _masterIp;
  int get dbPort => _dbPort;
  String get dbUsername => _dbUsername;
  String get dbPassword => _dbPassword;
  String get dbName => _dbName;
  String get businessName => _businessName;
  String get businessAddress => _businessAddress;
  String get businessPhone => _businessPhone;
  String get businessEmail => _businessEmail;
  String get businessLogo => _businessLogo;
  String get appVersion => _appVersion;
  bool get setupCompleted => _setupCompleted;
  
  // Setters
  set isMaster(bool value) {
    _isMaster = value;
    _saveConfig();
  }
  
  set masterIp(String value) {
    _masterIp = value;
    _saveConfig();
  }
  
  set dbPort(int value) {
    _dbPort = value;
    _saveConfig();
  }
  
  set dbUsername(String value) {
    _dbUsername = value;
    _saveConfig();
  }
  
  set dbPassword(String value) {
    _dbPassword = value;
    _saveConfig();
  }
  
  set dbName(String value) {
    _dbName = value;
    _saveConfig();
  }
  
  set businessName(String value) {
    _businessName = value;
    _saveConfig();
  }
  
  set businessAddress(String value) {
    _businessAddress = value;
    _saveConfig();
  }
  
  set businessPhone(String value) {
    _businessPhone = value;
    _saveConfig();
  }
  
  set businessEmail(String value) {
    _businessEmail = value;
    _saveConfig();
  }
  
  set businessLogo(String value) {
    _businessLogo = value;
    _saveConfig();
  }
  
  set setupCompleted(bool value) {
    _setupCompleted = value;
    _saveConfig();
  }
  
  // Initialize configuration
  Future<void> initialize() async {
    await _loadConfig();
  }
  
  // Load configuration from file
  Future<void> _loadConfig() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // Load database configuration
      _isMaster = prefs.getBool('is_master') ?? false;
      _masterIp = prefs.getString('master_ip') ?? 'localhost';
      _dbPort = prefs.getInt('db_port') ?? 3306;
      _dbUsername = prefs.getString('db_username') ?? 'root';
      _dbPassword = prefs.getString('db_password') ?? '';
      _dbName = prefs.getString('db_name') ?? 'malbrose_pos';
      
      // Load business information
      _businessName = prefs.getString('business_name') ?? 'Malbrose Hardware Store';
      _businessAddress = prefs.getString('business_address') ?? 'Eldoret';
      _businessPhone = prefs.getString('business_phone') ?? '0720319340, 0721705613';
      _businessEmail = prefs.getString('business_email') ?? '';
      _businessLogo = prefs.getString('business_logo') ?? '';
      
      // Load app configuration
      _setupCompleted = prefs.getBool('setup_completed') ?? false;
      
      debugPrint('Configuration loaded successfully');
    } catch (e) {
      debugPrint('Error loading configuration: $e');
    }
  }
  
  // Save configuration to file
  Future<void> _saveConfig() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // Save database configuration
      await prefs.setBool('is_master', _isMaster);
      await prefs.setString('master_ip', _masterIp);
      await prefs.setInt('db_port', _dbPort);
      await prefs.setString('db_username', _dbUsername);
      await prefs.setString('db_password', _dbPassword);
      await prefs.setString('db_name', _dbName);
      
      // Save business information
      await prefs.setString('business_name', _businessName);
      await prefs.setString('business_address', _businessAddress);
      await prefs.setString('business_phone', _businessPhone);
      await prefs.setString('business_email', _businessEmail);
      await prefs.setString('business_logo', _businessLogo);
      
      // Save app configuration
      await prefs.setBool('setup_completed', _setupCompleted);
      
      debugPrint('Configuration saved successfully');
    } catch (e) {
      debugPrint('Error saving configuration: $e');
    }
  }
  
  // Get the local IP address
  Future<String> getLocalIpAddress() async {
    try {
      final info = NetworkInfo();
      String? ip = await info.getWifiIP();
      return ip ?? 'Unknown';
    } catch (e) {
      debugPrint('Error getting local IP address: $e');
      return 'Unknown';
    }
  }
  
  // Export configuration to JSON file
  Future<String> exportConfig() async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final file = File('${directory.path}/malbrose_config.json');
      
      final configMap = {
        'is_master': _isMaster,
        'master_ip': _masterIp,
        'db_port': _dbPort,
        'db_username': _dbUsername,
        'db_password': _dbPassword,
        'db_name': _dbName,
        'business_name': _businessName,
        'business_address': _businessAddress,
        'business_phone': _businessPhone,
        'business_email': _businessEmail,
        'business_logo': _businessLogo,
        'app_version': _appVersion,
        'setup_completed': _setupCompleted,
      };
      
      await file.writeAsString(jsonEncode(configMap));
      return file.path;
    } catch (e) {
      debugPrint('Error exporting configuration: $e');
      return '';
    }
  }
  
  // Import configuration from JSON file
  Future<bool> importConfig(String filePath) async {
    try {
      final file = File(filePath);
      if (await file.exists()) {
        final jsonString = await file.readAsString();
        final configMap = jsonDecode(jsonString) as Map<String, dynamic>;
        
        // Load database configuration
        _isMaster = configMap['is_master'] ?? false;
        _masterIp = configMap['master_ip'] ?? 'localhost';
        _dbPort = configMap['db_port'] ?? 3306;
        _dbUsername = configMap['db_username'] ?? 'root';
        _dbPassword = configMap['db_password'] ?? '';
        _dbName = configMap['db_name'] ?? 'malbrose_pos';
        
        // Load business information
        _businessName = configMap['business_name'] ?? 'Malbrose Hardware Store';
        _businessAddress = configMap['business_address'] ?? 'Eldoret';
        _businessPhone = configMap['business_phone'] ?? '0720319340, 0721705613';
        _businessEmail = configMap['business_email'] ?? '';
        _businessLogo = configMap['business_logo'] ?? '';
        
        // Save the imported configuration
        await _saveConfig();
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('Error importing configuration: $e');
      return false;
    }
  }
  
  // Reset configuration to defaults
  Future<void> resetConfig() async {
    _isMaster = false;
    _masterIp = 'localhost';
    _dbPort = 3306;
    _dbUsername = 'root';
    _dbPassword = '';
    _dbName = 'malbrose_pos';
    _businessName = 'Malbrose Hardware Store';
    _businessAddress = 'Eldoret';
    _businessPhone = '0720319340, 0721705613';
    _businessEmail = '';
    _businessLogo = '';
    _setupCompleted = false;
    
    await _saveConfig();
  }
  
  // Test database connection
  Future<bool> testDatabaseConnection() async {
    // This is a placeholder. You'll need to implement actual database connection testing
    // based on your database implementation (MySQL, PostgreSQL, etc.)
    try {
      // For MySQL, you would use something like:
      // final conn = await MySqlConnection.connect(ConnectionSettings(
      //   host: _isMaster ? 'localhost' : _masterIp,
      //   port: _dbPort,
      //   user: _dbUsername,
      //   password: _dbPassword,
      //   db: _dbName,
      // ));
      // await conn.close();
      return true;
    } catch (e) {
      debugPrint('Error testing database connection: $e');
      return false;
    }
  }
} 