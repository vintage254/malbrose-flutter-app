  Future<void> updateUser(User user) async {
    try {
      final currentUser = AuthService.instance.currentUser;
      if (currentUser == null) throw Exception('User not authenticated');

      await DatabaseService.instance.updateUser(user.toMap());
      
      // Log activity
      await DatabaseService.instance.logUserActivity(
        userId: currentUser.id!,
        username: currentUser.username,
        actionType: 'UPDATE',
        targetType: 'USER',
        targetId: user.id,
        details: 'Updated user: ${user.username}',
      );
    } catch (e) {
      print('Error updating user: $e');
      rethrow;
    }
  }

  Future<void> createUser(User user) async {
    try {
      final currentUser = AuthService.instance.currentUser;
      if (currentUser == null) throw Exception('User not authenticated');

      final userId = await DatabaseService.instance.createUser(user.toMap());
      
      // Log activity
      await DatabaseService.instance.logUserActivity(
        userId: currentUser.id!,
        username: currentUser.username,
        actionType: 'CREATE',
        targetType: 'USER',
        targetId: userId,
        details: 'Created new user: ${user.username}',
      );
    } catch (e) {
      print('Error creating user: $e');
      rethrow;
    }
  }

  Future<void> deleteUser(int userId) async {
    try {
      final currentUser = AuthService.instance.currentUser;
      if (currentUser == null) throw Exception('User not authenticated');

      await DatabaseService.instance.deleteUser(userId);
      
      // Log activity
      await DatabaseService.instance.logUserActivity(
        userId: currentUser.id!,
        username: currentUser.username,
        actionType: 'DELETE',
        targetType: 'USER',
        targetId: userId,
        details: 'Deleted user ID: $userId',
      );
    } catch (e) {
      print('Error deleting user: $e');
      rethrow;
    }
  } 