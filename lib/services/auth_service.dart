import 'package:my_flutter_app/models/user_model.dart';
import 'package:my_flutter_app/services/database.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:crypto/crypto.dart';
import 'dart:convert';

class AuthService {
  static final AuthService instance = AuthService._internal();
  AuthService._internal();

  User? _currentUser;
  User? get currentUser => _currentUser;

  // Check if user is logged in
  bool get isLoggedIn => _currentUser != null;

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
        print('Input password hash: $hashedPassword');
        print('Stored password hash: ${userMap['password']}');
        
        // Convert Map to User object
        final user = User.fromMap(userMap);
        
        if (user.password == hashedPassword) {
          _currentUser = user;
          print('Password matched. Login successful.');
          
          // Update last login time
          final updatedUser = user.copyWith(lastLogin: DateTime.now());
          await DatabaseService.instance.updateUser(updatedUser);
          
          // Save session
          await _saveSession(user.id!);
          
          // Add activity log for login
          await DatabaseService.instance.logActivity(
            user.id!,
            user.username,
            'login',
            'Login',
            'User logged in successfully'
          );
          
          return _currentUser;
        } else {
          print('Password mismatch. Login failed.');
          // Compare character by character to identify the issue
          final storedHash = user.password;
          final inputHash = hashedPassword;
          if (storedHash.length != inputHash.length) {
            print('Hash length mismatch: stored=${storedHash.length}, input=${inputHash.length}');
          } else {
            for (int i = 0; i < storedHash.length; i++) {
              if (storedHash[i] != inputHash[i]) {
                print('First mismatch at position $i: ${storedHash[i]} vs ${inputHash[i]}');
                break;
              }
            }
          }
        }
      } else {
        print('User not found: $username');
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
          _currentUser!.id!,
          _currentUser!.username,
          'LOGOUT',
          'LOGOUT',
          'User logged out'
        );
        
        // Clear session
        await _clearSession();
        _currentUser = null;
      } catch (e) {
        print('Logout error: $e');
        rethrow;
      }
    }
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

  Future<void> _clearSession() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('user_id');
  }
} 