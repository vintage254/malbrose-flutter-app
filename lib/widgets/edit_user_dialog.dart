import 'package:flutter/material.dart';
import 'package:my_flutter_app/models/user_model.dart';
import 'package:my_flutter_app/services/database.dart';
import 'package:my_flutter_app/const/constant.dart';

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
  late bool _isAdmin;

  @override
  void initState() {
    super.initState();
    _fullNameController = TextEditingController(text: widget.user.fullName);
    _emailController = TextEditingController(text: widget.user.email);
    _isAdmin = widget.user.isAdmin;
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
              Text('Username: ${widget.user.username}', 
                style: const TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: defaultPadding),
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
              if (widget.currentUserIsAdmin)
                CheckboxListTile(
                  title: const Text('Admin Privileges'),
                  value: _isAdmin,
                  onChanged: (value) {
                    setState(() {
                      _isAdmin = value ?? false;
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
          onPressed: _saveUser,
          child: const Text('Save'),
        ),
      ],
    );
  }

  Future<void> _saveUser() async {
    if (_formKey.currentState!.validate()) {
      try {
        final updatedUser = User(
          id: widget.user.id,
          username: widget.user.username,
          password: widget.user.password,
          fullName: _fullNameController.text,
          email: _emailController.text,
          isAdmin: _isAdmin,
          createdAt: widget.user.createdAt,
          lastLogin: widget.user.lastLogin,
        );

        await DatabaseService.instance.updateUser(updatedUser);
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
  void dispose() {
    _fullNameController.dispose();
    _emailController.dispose();
    super.dispose();
  }
} 