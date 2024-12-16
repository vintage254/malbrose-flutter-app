import 'package:flutter/material.dart';
import 'package:my_flutter_app/screens/login_screen.dart';
import 'package:my_flutter_app/const/constant.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Malbrose POS System'),
        actions: [
          ElevatedButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const LoginScreen()),
              );
            },
            child: const Text('Login'),
          ),
          const SizedBox(width: defaultPadding),
        ],
      ),
      body: const Center(
        child: Text('Welcome to Malbrose POS System'),
      ),
    );
  }
} 