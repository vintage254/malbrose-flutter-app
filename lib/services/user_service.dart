import 'package:my_flutter_app/models/user_model.dart';
import 'package:my_flutter_app/services/database.dart';
import 'package:my_flutter_app/services/auth_service.dart';

class UserService {
  Future<void> updateUser(User user) async {
    try {
      final currentUser = AuthService.instance.currentUser;
      if (currentUser == null) throw Exception('User not authenticated');

      // Get the existing user to check if password has changed
      final existingUser = await DatabaseService.instance.getUserById(user.id!);
      if (existingUser == null) throw Exception('User not found');

      // Prepare update data
      final userData = user.toMap();
      
      // Only hash password if it has changed
      if (existingUser['password'] != user.password) {
        userData['password'] = AuthService.instance.hashPassword(user.password);
      }

      await DatabaseService.instance.updateUser(userData);
      
      // Log activity
      await DatabaseService.instance.logActivity({
        'user_id': currentUser.id!,
        'username': currentUser.username,
        'action': 'UPDATE_USER',
        'action_type': 'UPDATE',
        'details': 'Updated user: ${user.username}',
        'timestamp': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      print('Error updating user: $e');
      rethrow;
    }
  }

  Future<void> createUser(User user) async {
    try {
      final currentUser = AuthService.instance.currentUser;
      if (currentUser == null) throw Exception('User not authenticated');

      // Hash the password before storing
      final hashedPassword = AuthService.instance.hashPassword(user.password);
      
      // Create user with appropriate permissions and hashed password
      final userData = {
        ...user.toMap(),
        'password': hashedPassword,
        'permissions': user.isAdmin ? DatabaseService.PERMISSION_FULL_ACCESS : DatabaseService.PERMISSION_BASIC,
        'created_at': DateTime.now().toIso8601String(),
      };

      final createdUser = await DatabaseService.instance.createUser(userData);
      if (createdUser == null) {
        throw Exception('Failed to create user');
      }
      
      // Log activity
      await DatabaseService.instance.logActivity({
        'user_id': currentUser.id!,
        'username': currentUser.username,
        'action': 'CREATE_USER',
        'action_type': 'CREATE',
        'details': 'Created new user: ${user.username}',
        'timestamp': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      print('Error creating user: $e');
      rethrow;
    }
  }

  Future<void> deleteUser(int userId) async {
    try {
      final currentUser = AuthService.instance.currentUser;
      if (currentUser == null) throw Exception('User not authenticated');

      final userToDelete = await DatabaseService.instance.getUserById(userId);
      if (userToDelete == null) throw Exception('User not found');

      await DatabaseService.instance.deleteUser(userId);
      
      // Log activity
      await DatabaseService.instance.logActivity({
        'user_id': currentUser.id!,
        'username': currentUser.username,
        'action': 'DELETE_USER',
        'action_type': 'DELETE',
        'details': 'Deleted user: ${userToDelete['username']}',
        'timestamp': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      print('Error deleting user: $e');
      rethrow;
    }
  }
} 