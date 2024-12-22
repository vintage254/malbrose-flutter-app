import 'package:my_flutter_app/models/user_model.dart';
import 'package:my_flutter_app/services/database.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:crypto/crypto.dart';
import 'dart:convert';
import 'package:my_flutter_app/models/activity_log_model.dart';

class AuthService {
  static final AuthService instance = AuthService._internal();
  AuthService._internal();

  User? _currentUser;
  User? get currentUser => _currentUser;

  String hashPassword(String password) {
    final bytes = utf8.encode(password);
    final hash = sha256.convert(bytes);
    return hash.toString();
  }

  Future<User?> login(String username, String password) async {
    try {
      final userMap = await DatabaseService.instance.getUserByUsername(username);
      print('User Map: $userMap');
      
      if (userMap != null) {
        final hashedPassword = hashPassword(password);
        
        // Convert Map to User object
        final user = User.fromMap(userMap);
        print('User Object: ${user.toMap()}');
        
        if (user.password == hashedPassword) {
          _currentUser = user;
          print('Current User Role: ${_currentUser?.role}');
          
          // Update last login time
          final updatedUser = user.copyWith(lastLogin: DateTime.now());
          await DatabaseService.instance.updateUser(updatedUser);
          
          // Save session
          await _saveSession(user.id!);
          
          // Add activity log for login
          await DatabaseService.instance.logActivity({
            'user_id': user.id!,
            'action': 'login',
            'details': 'User logged in successfully',
            'timestamp': DateTime.now().toIso8601String(),
          });
          
          return _currentUser;
        }
      }
      return null;
    } catch (e) {
      print('Login error: $e');
      rethrow;
    }
  }

  Future<void> logout() async {
    if (_currentUser != null) {
      try {
        await DatabaseService.instance.logActivity(
          {
            'user_id': _currentUser!.id!,
            'action_type': 'LOGOUT',
            'details': 'User logged out',
            'timestamp': DateTime.now().toIso8601String(),
          },
        );
      } catch (e) {
        print('Error logging activity: $e');
        // Continue with logout even if logging fails
      }
    }
    
    _currentUser = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('user_id');
  }

  Future<void> _saveSession(int userId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('user_id', userId);
  }

  Future<User?> restoreSession() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getInt('user_id');
      
      if (userId != null) {
        final userMap = await DatabaseService.instance.getUserById(userId);
        if (userMap != null) {
          _currentUser = User.fromMap(userMap);
          return _currentUser;
        }
      }
      return null;
    } catch (e) {
      print('Error restoring session: $e');
      return null;
    }
  }
} 