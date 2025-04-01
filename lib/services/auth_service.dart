import 'package:my_flutter_app/models/user_model.dart';
import 'package:my_flutter_app/services/database.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:bcrypt/bcrypt.dart';

class AuthService {
  static final AuthService instance = AuthService._internal();
  AuthService._internal();

  User? _currentUser;
  User? get currentUser => _currentUser;

  // Check if user is logged in
  bool get isLoggedIn => _currentUser != null;

  String hashPassword(String password) {
    try {
      final salt = BCrypt.gensalt(logRounds: 12);
      return BCrypt.hashpw(password, salt);
    } catch (e) {
      print('Error hashing password: $e');
      throw Exception('Password hashing failed');
    }
  }

  bool verifyPassword(String password, String hashedPassword) {
    try {
      return BCrypt.checkpw(password, hashedPassword);
    } catch (e) {
      print('Error verifying password: $e');
      return false;
    }
  }

  Future<User?> login(String username, String password) async {
    try {
      final userMap = await DatabaseService.instance.getUserByUsername(username);
      print('User Map: $userMap');
      
      if (userMap != null) {
        final storedHash = userMap['password'] as String;
        print('Stored password hash: $storedHash');
        
        final user = User.fromMap(userMap);
        
        if (verifyPassword(password, storedHash)) {
          _currentUser = user;
          print('Password matched. Login successful.');
          
          final updatedUser = user.copyWith(lastLogin: DateTime.now());
          await DatabaseService.instance.updateUser(updatedUser);
          await _saveSession(user.id!);
          
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