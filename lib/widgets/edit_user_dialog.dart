import 'package:flutter/material.dart';
import 'package:my_flutter_app/models/user_model.dart';
import 'package:my_flutter_app/services/database.dart';
import 'package:my_flutter_app/services/auth_service.dart';

class EditUserDialog extends StatefulWidget {
  final User user;
  final bool currentUserIsAdmin;

  const EditUserDialog({
    super.key,
    required this.user,
    required this.currentUserIsAdmin,
  });

  @override
  State<EditUserDialog> createState() => _EditUserDialogState();
}

class _EditUserDialogState extends State<EditUserDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _fullNameController;
  late final TextEditingController _emailController;
  final TextEditingController _passwordController = TextEditingController();
  late bool _isAdmin;
  bool _obscurePassword = true;

  @override
  void initState() {
    super.initState();
    _fullNameController = TextEditingController(text: widget.user.fullName);
    _emailController = TextEditingController(text: widget.user.email);
    _isAdmin = widget.user.isAdmin;
  }

  Future<void> _handleSubmit() async {
    if (_formKey.currentState!.validate()) {
      try {
        // Create updated user with proper role and permissions
        final updatedUser = widget.user.copyWith(
          fullName: _fullNameController.text,
          email: _emailController.text,
          role: _isAdmin ? DatabaseService.ROLE_ADMIN : 'USER',
          permissions: _isAdmin ? DatabaseService.PERMISSION_FULL_ACCESS : DatabaseService.PERMISSION_BASIC,
        );

        // Log the update details
        print('Updating user: ${updatedUser.username}');
        print('New role: ${updatedUser.role}, New permissions: ${updatedUser.permissions}');

        // First update the user details
        await DatabaseService.instance.updateUser(updatedUser);
        
        // Only update password if a new one was provided
        if (_passwordController.text.isNotEmpty) {
          // Update password directly using a raw query instead of User.fromMap
          final db = await DatabaseService.instance.database;
          final hashedPassword = AuthService.instance.hashPassword(_passwordController.text);
          
          await db.update(
            DatabaseService.tableUsers,
            {'password': hashedPassword},
            where: 'id = ?',
            whereArgs: [updatedUser.id],
          );
          
          print('Updated user password');
        }
        
        // Log the update activity
        final currentUser = AuthService.instance.currentUser;
        if (currentUser != null) {
          await DatabaseService.instance.logActivity(
            currentUser.id!,
            currentUser.username,
            'update_user',
            'Update user',
            'Updated user: ${updatedUser.username}, role: ${updatedUser.role}'
          );
        }
        
        if (!mounted) return;
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('User updated successfully'),
            backgroundColor: Colors.green,
          ),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error updating user: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Edit User'),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _fullNameController,
                decoration: const InputDecoration(labelText: 'Full Name'),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter full name';
                  }
                  return null;
                },
              ),
              TextFormField(
                controller: _emailController,
                decoration: const InputDecoration(labelText: 'Email'),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter email';
                  }
                  if (!value.contains('@')) {
                    return 'Please enter a valid email';
                  }
                  return null;
                },
              ),
              TextFormField(
                controller: _passwordController,
                decoration: InputDecoration(
                  labelText: 'New Password (Optional)',
                  helperText: 'Leave blank to keep current password. Min 6 chars with 1 number.',
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscurePassword ? Icons.visibility_off : Icons.visibility,
                      color: Colors.grey,
                    ),
                    onPressed: () {
                      setState(() {
                        _obscurePassword = !_obscurePassword;
                      });
                    },
                  ),
                ),
                obscureText: _obscurePassword,
                validator: (value) {
                  // Skip validation if field is empty (password not being changed)
                  if (value == null || value.isEmpty) {
                    return null;
                  }
                  // Validate password if provided
                  if (value.length < 6) {
                    return 'Password must be at least 6 characters';
                  }
                  if (!value.contains(RegExp(r'[0-9]'))) {
                    return 'Password must contain at least one number';
                  }
                  return null;
                },
              ),
              if (widget.currentUserIsAdmin)
                SwitchListTile(
                  title: const Text('Admin'),
                  value: _isAdmin,
                  onChanged: (value) {
                    setState(() {
                      _isAdmin = value;
                    });
                  },
                ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _handleSubmit,
          child: const Text('Save'),
        ),
      ],
    );
  }

  @override
  void dispose() {
    _fullNameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }
} 