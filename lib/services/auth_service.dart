import 'package:my_flutter_app/models/user_model.dart';
import 'package:my_flutter_app/services/database.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:bcrypt/bcrypt.dart';
import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'dart:async';
import 'package:uuid/uuid.dart';
import 'package:flutter/foundation.dart';
import 'package:my_flutter_app/services/encryption_service.dart';

class AuthService {
  static final AuthService instance = AuthService._internal();
  AuthService._internal() {
    // Initialize rate limiter map and clean up expired attempts periodically
    _startRateLimitCleanupTimer();
  }

  User? _currentUser;
  User? get currentUser => _currentUser;

  // Check if user is logged in
  bool get isLoggedIn => _currentUser != null;
  
  // Token-based session management
  final Map<String, SessionInfo> _activeSessions = {};
  
  // Rate limiting
  final Map<String, List<DateTime>> _loginAttempts = {};
  final int _maxAttemptsPerMinute = 5;
  Timer? _rateLimitCleanupTimer;
  
  // Password strength parameters
  static const int _minPasswordLength = 8;
  static const bool _requireUppercase = true;
  static const bool _requireLowercase = true;
  static const bool _requireNumbers = true;
  static const bool _requireSpecialChars = true;

  /// Validates password strength
  PasswordStrength validatePasswordStrength(String password) {
    int score = 0;
    List<String> weaknesses = [];
    
    // Check length
    if (password.length < _minPasswordLength) {
      weaknesses.add('Password must be at least $_minPasswordLength characters long');
    } else {
      score += 1;
    }
    
    // Check for uppercase
    if (_requireUppercase && !password.contains(RegExp(r'[A-Z]'))) {
      weaknesses.add('Password must contain at least one uppercase letter');
    } else {
      score += 1;
    }
    
    // Check for lowercase
    if (_requireLowercase && !password.contains(RegExp(r'[a-z]'))) {
      weaknesses.add('Password must contain at least one lowercase letter');
    } else {
      score += 1;
    }
    
    // Check for numbers
    if (_requireNumbers && !password.contains(RegExp(r'[0-9]'))) {
      weaknesses.add('Password must contain at least one number');
    } else {
      score += 1;
    }
    
    // Check for special characters
    if (_requireSpecialChars && !password.contains(RegExp(r'[!@#$%^&*(),.?":{}|<>]'))) {
      weaknesses.add('Password must contain at least one special character');
    } else {
      score += 1;
    }
    
    // Bonus for length
    if (password.length >= 12) score += 1;
    if (password.length >= 16) score += 1;
    
    // Determine strength based on score
    PasswordStrengthLevel level;
    if (score < 3) {
      level = PasswordStrengthLevel.weak;
    } else if (score < 5) {
      level = PasswordStrengthLevel.medium;
    } else {
      level = PasswordStrengthLevel.strong;
    }
    
    return PasswordStrength(level: level, weaknesses: weaknesses, score: score);
  }

  String hashPassword(String password) {
    try {
      final salt = BCrypt.gensalt(logRounds: 12);
      return BCrypt.hashpw(password, salt);
    } catch (e) {
      debugPrint('Error hashing password: $e');
      throw Exception('Password hashing failed');
    }
  }

  bool verifyPassword(String password, String hashedPassword) {
    try {
      return BCrypt.checkpw(password, hashedPassword);
    } catch (e) {
      debugPrint('Error verifying password: $e');
      return false;
    }
  }

  /// Starts a timer to clean up expired rate limiting records
  void _startRateLimitCleanupTimer() {
    _rateLimitCleanupTimer?.cancel();
    _rateLimitCleanupTimer = Timer.periodic(const Duration(minutes: 5), (_) {
      _cleanupExpiredLoginAttempts();
    });
  }
  
  /// Cleans up expired login attempts
  void _cleanupExpiredLoginAttempts() {
    final now = DateTime.now();
    _loginAttempts.forEach((username, attempts) {
      attempts.removeWhere((time) => now.difference(time).inMinutes > 60);
    });
    
    // Remove usernames with no attempts
    _loginAttempts.removeWhere((_, attempts) => attempts.isEmpty);
  }
  
  /// Check if login is rate limited
  bool _isRateLimited(String username) {
    if (!_loginAttempts.containsKey(username)) {
      _loginAttempts[username] = [];
      return false;
    }
    
    final attempts = _loginAttempts[username]!;
    
    // Clean up old attempts
    final now = DateTime.now();
    attempts.removeWhere((time) => now.difference(time).inMinutes > 1);
    
    // Check if rate limited
    return attempts.length >= _maxAttemptsPerMinute;
  }
  
  /// Record a login attempt
  void _recordLoginAttempt(String username) {
    if (!_loginAttempts.containsKey(username)) {
      _loginAttempts[username] = [];
    }
    
    _loginAttempts[username]!.add(DateTime.now());
  }

  /// Generate a secure session token
  Future<String> _generateSessionToken(int userId, String username) async {
    final uuid = const Uuid().v4();
    final timestamp = DateTime.now().millisecondsSinceEpoch.toString();
    final data = '$userId:$username:$timestamp:$uuid';
    
    // Encrypt the token data
    final encryptedToken = await EncryptionService.instance.encryptString(data);
    return encryptedToken;
  }

  Future<User?> login(String username, String password) async {
    try {
      // Check rate limiting
      if (_isRateLimited(username)) {
        debugPrint('Rate limited login attempt for user: $username');
        await DatabaseService.instance.logActivity(
          0, // System user ID
          'system',
          'login_rate_limited',
          'Rate Limited Login',
          'Rate limited login attempt for user: $username'
        );
        throw Exception('Too many login attempts. Please try again later.');
      }
      
      // Record the login attempt
      _recordLoginAttempt(username);
      
      final userMap = await DatabaseService.instance.getUserByUsername(username);
      debugPrint('User Map: $userMap');
      
      if (userMap != null) {
        final storedHash = userMap['password'] as String;
        debugPrint('Stored password hash: $storedHash');
        
        final user = User.fromMap(userMap);
        
        if (verifyPassword(password, storedHash)) {
          _currentUser = user;
          debugPrint('Password matched. Login successful.');
          
          final updatedUser = user.copyWith(lastLogin: DateTime.now());
          await DatabaseService.instance.updateUser(updatedUser);
          
          // Generate session token and save session
          final token = await _generateSessionToken(user.id!, user.username);
          final sessionInfo = SessionInfo(
            userId: user.id!,
            username: user.username,
            createdAt: DateTime.now(),
            expiresAt: DateTime.now().add(const Duration(hours: 24)), // 24-hour expiration
            ipAddress: await _getClientIp(),
            userAgent: await _getUserAgent(),
          );
          
          _activeSessions[token] = sessionInfo;
          await _saveSessionToken(token);
          
          await DatabaseService.instance.logActivity(
            user.id!,
            user.username,
            'login',
            'Login',
            'User logged in successfully'
          );
          return _currentUser;
        } else {
          debugPrint('Password mismatch. Login failed.');
          await DatabaseService.instance.logActivity(
            0, // System user ID
            'system',
            'login_failed',
            'Failed Login',
            'Failed login attempt for user: $username'
          );
        }
      } else {
        debugPrint('User not found: $username');
        await DatabaseService.instance.logActivity(
          0, // System user ID
          'system',
          'login_failed',
          'Failed Login',
          'Login attempt for non-existent user: $username'
        );
      }
      return null;
    } catch (e) {
      debugPrint('Login error: $e');
      rethrow;
    }
  }

  Future<void> logout() async {
    if (_currentUser != null) {
      try {
        await DatabaseService.instance.logActivity(
          _currentUser!.id!,
          _currentUser!.username,
          'LOGOUT',
          'LOGOUT',
          'User logged out'
        );
        
        // Clear session token
        await _clearSessionToken();
        
        // Clear active session
        final prefs = await SharedPreferences.getInstance();
        final token = prefs.getString('session_token');
        if (token != null) {
          _activeSessions.remove(token);
        }
        
        _currentUser = null;
      } catch (e) {
        debugPrint('Logout error: $e');
        rethrow;
      }
    }
  }

  /// Get client IP address for session tracking (basic implementation)
  Future<String> _getClientIp() async {
    try {
      return 'local'; // In a real app, you'd determine the client IP
    } catch (e) {
      return 'unknown';
    }
  }
  
  /// Get user agent for session tracking (basic implementation)
  Future<String> _getUserAgent() async {
    try {
      return 'Flutter App'; // In a real app, you'd determine the user agent
    } catch (e) {
      return 'unknown';
    }
  }

  Future<void> _saveSessionToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('session_token', token);
  }

  Future<User?> restoreSession() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('session_token');
      
      if (token != null) {
        // Verify token and check if session is valid
        final session = _activeSessions[token];
        
        if (session != null && DateTime.now().isBefore(session.expiresAt)) {
          // Session is valid, load user
          final userMap = await DatabaseService.instance.getUserById(session.userId);
        if (userMap != null) {
          _currentUser = User.fromMap(userMap);
            
            // Extend session if more than halfway through
            final sessionHalflife = session.createdAt.add(
              Duration(milliseconds: (session.expiresAt.difference(session.createdAt).inMilliseconds ~/ 2))
            );
            
            if (DateTime.now().isAfter(sessionHalflife)) {
              // Refresh the token
              final newToken = await _generateSessionToken(session.userId, session.username);
              final newSession = SessionInfo(
                userId: session.userId,
                username: session.username,
                createdAt: DateTime.now(),
                expiresAt: DateTime.now().add(const Duration(hours: 24)),
                ipAddress: session.ipAddress,
                userAgent: session.userAgent,
              );
              
              _activeSessions[newToken] = newSession;
              _activeSessions.remove(token);
              await _saveSessionToken(newToken);
            }
            
          return _currentUser;
          }
        } else if (session != null) {
          // Session expired, clean up
          _activeSessions.remove(token);
          await _clearSessionToken();
        }
      }
      return null;
    } catch (e) {
      debugPrint('Error restoring session: $e');
      return null;
    }
  }

  Future<void> _clearSessionToken() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('session_token');
  }
  
  /// Change user password with strength validation
  Future<bool> changePassword(int userId, String currentPassword, String newPassword) async {
    try {
      // Validate new password strength
      final passwordStrength = validatePasswordStrength(newPassword);
      if (passwordStrength.level == PasswordStrengthLevel.weak) {
        throw Exception('Password is too weak: ${passwordStrength.weaknesses.join(', ')}');
      }
      
      // Get user
      final userMap = await DatabaseService.instance.getUserById(userId);
      if (userMap == null) {
        throw Exception('User not found');
      }
      
      // Verify current password
      final storedHash = userMap['password'] as String;
      if (!verifyPassword(currentPassword, storedHash)) {
        throw Exception('Current password is incorrect');
      }
      
      // Hash and store new password
      final newHashedPassword = hashPassword(newPassword);
      final updatedUser = User.fromMap(userMap).copyWith(password: newHashedPassword);
      await DatabaseService.instance.updateUser(updatedUser);
      
      // Log activity
      await DatabaseService.instance.logActivity(
        userId,
        userMap['username'] as String,
        'password_change',
        'Password Change',
        'User changed their password'
      );
      
      return true;
    } catch (e) {
      debugPrint('Error changing password: $e');
      rethrow;
    }
  }
}

/// Session information class
class SessionInfo {
  final int userId;
  final String username;
  final DateTime createdAt;
  final DateTime expiresAt;
  final String ipAddress;
  final String userAgent;
  
  SessionInfo({
    required this.userId,
    required this.username,
    required this.createdAt,
    required this.expiresAt,
    required this.ipAddress,
    required this.userAgent,
  });
}

/// Password strength model
class PasswordStrength {
  final PasswordStrengthLevel level;
  final List<String> weaknesses;
  final int score;
  
  PasswordStrength({
    required this.level,
    required this.weaknesses,
    required this.score,
  });
}

enum PasswordStrengthLevel {
  weak,
  medium,
  strong,
} 