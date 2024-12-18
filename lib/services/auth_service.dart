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
      final hashedPassword = hashPassword(password);
      
      print('Login attempt:');
      print('Username: $username');
      print('Input Password Hash: $hashedPassword');
      
      final user = await DatabaseService.instance.getUserByUsername(username);
      
      if (user != null) {
        print('Found user with password hash: ${user.password}');
        
        if (user.password == hashedPassword) {
          _currentUser = user;
          
          final updatedUser = User(
            id: user.id,
            username: user.username,
            password: user.password,
            fullName: user.fullName,
            email: user.email,
            isAdmin: user.isAdmin,
            createdAt: user.createdAt,
            lastLogin: DateTime.now(),
          );
          await DatabaseService.instance.updateUser(updatedUser);
          
          await DatabaseService.instance.logActivity(
            ActivityLog(
              userId: user.id!,
              actionType: 'LOGIN',
              details: 'User logged in successfully',
            ),
          );
          
          return user;
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
      await DatabaseService.instance.logActivity(
        ActivityLog(
          userId: _currentUser!.id!,
          actionType: 'LOGOUT',
          details: 'User logged out',
        ),
      );
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
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getInt('user_id');
    
    if (userId != null) {
      final users = await DatabaseService.instance.getAllUsers();
      _currentUser = users.firstWhere((user) => user.id == userId);
      return _currentUser;
    }
    
    return null;
  }
} 