import 'package:flutter/material.dart';
import 'package:my_flutter_app/screens/login_screen.dart';
import 'package:my_flutter_app/const/constant.dart';
import 'package:my_flutter_app/widgets/app_logo.dart';
import 'package:my_flutter_app/widgets/login_form.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            const AppLogo(size: 40),
            const SizedBox(width: defaultPadding),
            const Text('Malbrose POS System'),
          ],
        ),
        actions: [
          ElevatedButton.icon(
            onPressed: () => _showLoginDialog(context),
            icon: const Icon(Icons.login),
            label: const Text('Login'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
            ),
          ),
          const SizedBox(width: defaultPadding),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.amber.withOpacity(0.7),
              Colors.orange.shade900,
            ],
          ),
        ),
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(defaultPadding),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const AppLogo(size: 150),
                const SizedBox(height: defaultPadding * 2),
                const Text(
                  'Welcome to Malbrose POS System',
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: defaultPadding),
                const Text(
                  'Your Complete Hardware Store Management Solution',
                  style: TextStyle(
                    fontSize: 18,
                    color: Colors.white70,
                  ),
                ),
                const SizedBox(height: defaultPadding * 3),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _FeatureCard(
                      icon: Icons.point_of_sale,
                      title: 'Point of Sale',
                      description: 'Fast and efficient sales processing',
                    ),
                    const SizedBox(width: defaultPadding),
                    _FeatureCard(
                      icon: Icons.inventory,
                      title: 'Inventory Management',
                      description: 'Track and manage your stock effectively',
                    ),
                    const SizedBox(width: defaultPadding),
                    _FeatureCard(
                      icon: Icons.analytics,
                      title: 'Sales Analytics',
                      description: 'Detailed reports and insights',
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showLoginDialog(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          width: 400,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.2),
                blurRadius: 10,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    height: 150,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          Colors.amber.shade300,
                          Colors.orange.shade900,
                        ],
                      ),
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(20),
                      ),
                    ),
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.store,
                            size: 50,
                            color: Colors.white,
                          ),
                          const SizedBox(height: defaultPadding),
                          Text(
                            'Welcome Back!',
                            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(defaultPadding),
                    child: LoginForm(),
                  ),
                ],
              ),
              Positioned(
                right: -10,
                top: -10,
                child: IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 5,
                        ),
                      ],
                    ),
                    child: const Icon(Icons.close),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FeatureCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;

  const _FeatureCard({
    required this.icon,
    required this.title,
    required this.description,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 8,
      color: Colors.white.withOpacity(0.9),
      child: Container(
        width: 300,
        padding: const EdgeInsets.all(defaultPadding),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 48,
              color: Colors.orange.shade900,
            ),
            const SizedBox(height: defaultPadding),
            Text(
              title,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: defaultPadding / 2),
            Text(
              description,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey.shade700,
              ),
            ),
          ],
        ),
      ),
    );
  }
} 