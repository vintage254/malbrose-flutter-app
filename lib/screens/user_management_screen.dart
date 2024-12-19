import 'package:flutter/material.dart';
import 'package:my_flutter_app/const/constant.dart';
import 'package:my_flutter_app/models/user_model.dart';
import 'package:my_flutter_app/services/database.dart';
import 'package:my_flutter_app/services/auth_service.dart';
import 'package:my_flutter_app/widgets/side_menu_widget.dart';
import 'package:my_flutter_app/widgets/add_user_dialog.dart';
import 'package:my_flutter_app/widgets/edit_user_dialog.dart';

class UserManagementScreen extends StatefulWidget {
  const UserManagementScreen({super.key});

  @override
  State<UserManagementScreen> createState() => _UserManagementScreenState();
}

class _UserManagementScreenState extends State<UserManagementScreen> {
  List<User> _users = [];
  bool _isLoading = true;
  final currentUser = AuthService.instance.currentUser;

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  Future<void> _loadUsers() async {
    try {
      final usersData = await DatabaseService.instance.getAllUsers();
      if (mounted) {
        setState(() {
          _users = usersData.map((map) => User.fromMap(map)).toList();
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading users: $e')),
        );
      }
    }
  }

  Future<void> _handleAddUser() async {
    final result = await showDialog(
      context: context,
      builder: (context) => AddUserDialog(
        currentUserIsAdmin: currentUser?.isAdmin ?? false,
      ),
    );

    if (result == true) {
      _loadUsers();
    }
  }

  Future<void> _handleEditUser(User user) async {
    final result = await showDialog(
      context: context,
      builder: (context) => EditUserDialog(
        user: user,
        currentUserIsAdmin: currentUser?.isAdmin ?? false,
      ),
    );

    if (result == true) {
      _loadUsers();
    }
  }

  Future<void> _handleDeleteUser(User user) async {
    // Prevent deleting yourself
    if (user.id == currentUser?.id) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('You cannot delete your own account'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Delete'),
        content: Text('Are you sure you want to delete ${user.username}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await DatabaseService.instance.deleteUser(user.id!);
        _loadUsers();
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('User deleted successfully'),
            backgroundColor: Colors.green,
          ),
        );
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error deleting user: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _toggleAdminStatus(User user) async {
    try {
      final updatedUser = User(
        id: user.id,
        username: user.username,
        password: user.password,
        fullName: user.fullName,
        email: user.email,
        isAdmin: !user.isAdmin,
        createdAt: user.createdAt,
        lastLogin: user.lastLogin,
      );

      await DatabaseService.instance.updateUser(updatedUser);
      _loadUsers();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error updating user: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Row(
        children: [
          const Expanded(
            flex: 1,
            child: SideMenuWidget(),
          ),
          Expanded(
            flex: 5,
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.green.shade300.withOpacity(0.7),
                    Colors.green.shade700,
                  ],
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.all(defaultPadding),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'User Management',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (currentUser?.isAdmin ?? false)
                          ElevatedButton.icon(
                            onPressed: _handleAddUser,
                            icon: const Icon(Icons.add),
                            label: const Text('Add User'),
                          ),
                      ],
                    ),
                    const SizedBox(height: defaultPadding),
                    Expanded(
                      child: _isLoading
                          ? const Center(child: CircularProgressIndicator())
                          : Card(
                              child: SingleChildScrollView(
                                scrollDirection: Axis.horizontal,
                                child: DataTable(
                                  columns: const [
                                    DataColumn(label: Text('Username')),
                                    DataColumn(label: Text('Full Name')),
                                    DataColumn(label: Text('Email')),
                                    DataColumn(label: Text('Admin')),
                                    DataColumn(label: Text('Last Login')),
                                    DataColumn(label: Text('Actions')),
                                  ],
                                  rows: _users.map((user) {
                                    return DataRow(
                                      cells: [
                                        DataCell(Text(user.username)),
                                        DataCell(Text(user.fullName)),
                                        DataCell(Text(user.email)),
                                        DataCell(
                                          Switch(
                                            value: user.isAdmin,
                                            onChanged: currentUser?.isAdmin ?? false
                                                ? (value) => _toggleAdminStatus(user)
                                                : null,
                                          ),
                                        ),
                                        DataCell(Text(user.lastLogin?.toString() ?? 'Never')),
                                        DataCell(
                                          Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              IconButton(
                                                icon: const Icon(Icons.edit),
                                                onPressed: currentUser?.isAdmin ?? false
                                                    ? () => _handleEditUser(user)
                                                    : null,
                                                tooltip: 'Edit User',
                                              ),
                                              IconButton(
                                                icon: const Icon(Icons.delete),
                                                onPressed: currentUser?.isAdmin ?? false
                                                    ? () => _handleDeleteUser(user)
                                                    : null,
                                                tooltip: 'Delete User',
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    );
                                  }).toList(),
                                ),
                              ),
                            ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
} 