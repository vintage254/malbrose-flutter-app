import 'package:flutter/material.dart';
import 'package:my_flutter_app/const/constant.dart';
import 'package:my_flutter_app/widgets/app_logo.dart';
import 'package:my_flutter_app/widgets/login_form.dart';
import 'package:my_flutter_app/services/auth_service.dart';
import 'package:my_flutter_app/utils/ui_helpers.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  Widget build(BuildContext context) {
    final isLoggedIn = AuthService.instance.isLoggedIn;
    final currentUser = AuthService.instance.currentUser;
    final isAdmin = currentUser?.role == 'ADMIN';
    
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
          if (isLoggedIn)
            Row(
              children: [
                Text(
                  'Welcome, ${currentUser?.username ?? "User"}',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(width: defaultPadding),
                ElevatedButton.icon(
                  onPressed: () => _handleLogout(context),
                  icon: const Icon(Icons.logout),
                  label: const Text('Logout'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            )
          else
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
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _FeatureCard(
                        icon: Icons.dashboard,
                        title: 'Dashboard',
                        description: 'Monitor business performance at a glance',
                        buttons: [
                          _FeatureButton(
                            label: 'View Dashboard',
                            onPressed: () {
                              if (AuthService.instance.isLoggedIn) {
                                Navigator.pushNamed(context, '/main');
                              } else {
                                _redirectToLogin(context, '/main');
                              }
                            },
                          ),
                        ],
                      ),
                      const SizedBox(width: defaultPadding),
                      _FeatureCard(
                        icon: Icons.point_of_sale,
                        title: 'Point of Sale',
                        description: 'Fast and efficient sales processing',
                        buttons: [
                          _FeatureButton(
                            label: 'Make Order',
                            onPressed: () => _redirectToLogin(context, '/orders'),
                          ),
                          _FeatureButton(
                            label: 'Make Sale',
                            onPressed: () => _redirectToLogin(context, '/sales'),
                          ),
                          if (isAdmin) 
                            _FeatureButton(
                              label: 'Order History',
                              onPressed: () => _redirectToLogin(context, '/order-history'),
                            ),
                        ],
                      ),
                      const SizedBox(width: defaultPadding),
                      _FeatureCard(
                        icon: Icons.inventory,
                        title: 'Inventory Management',
                        description: 'Track and manage your stock effectively',
                        buttons: [
                          if (isAdmin)
                            _FeatureButton(
                              label: 'Add/Edit Product',
                              onPressed: () => _redirectToLogin(context, '/products'),
                            ),
                          _FeatureButton(
                            label: 'Creditors',
                            onPressed: () => _redirectToLogin(context, '/creditors'),
                          ),
                          _FeatureButton(
                            label: 'Debtors',
                            onPressed: () => _redirectToLogin(context, '/debtors'),
                          ),
                        ],
                      ),
                      const SizedBox(width: defaultPadding),
                      _FeatureCard(
                        icon: Icons.analytics,
                        title: 'Sales Analytics',
                        description: 'Detailed reports and insights',
                        buttons: [
                          _FeatureButton(
                            label: 'Customer Reports',
                            onPressed: () => _redirectToLogin(context, '/customer-reports'),
                          ),
                          if (isAdmin)
                            _FeatureButton(
                              label: 'Activity Log',
                              onPressed: () => _redirectToLogin(context, '/activity'),
                            ),
                          if (isAdmin)
                            _FeatureButton(
                              label: 'Sales Reports',
                              onPressed: () => _redirectToLogin(context, '/sales-report'),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _redirectToLogin(BuildContext context, String targetRoute) {
    // Check if user is already logged in
    final isLoggedIn = AuthService.instance.isLoggedIn;
    
    if (isLoggedIn) {
      // Navigate directly to the target route if user is logged in
      Navigator.pushNamed(context, targetRoute);
    } else {
      // Show login dialog if user is not logged in
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
                              'Login Required',
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
                      child: LoginForm(
                        targetRoute: targetRoute,
                      ),
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

  void _handleLogout(BuildContext context) async {
    try {
      // Show loading dialog
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: CircularProgressIndicator(),
        ),
      );

      await AuthService.instance.logout();
      
      if (!context.mounted) return;
      
      // Close loading dialog
      Navigator.pop(context);
      
      // Refresh the current page to update UI
      setState(() {});
      
      UIHelpers.showSnackBarWithContext(
        context,
        'Logged out successfully',
        isError: false,
      );
    } catch (e) {
      if (!context.mounted) return;
      
      // Close loading dialog if it's showing
      Navigator.pop(context);
      
      UIHelpers.showSnackBarWithContext(
        context,
        'Error logging out: $e',
        isError: true,
      );
    }
  }
}

class _FeatureButton extends StatelessWidget {
  final String label;
  final VoidCallback onPressed;

  const _FeatureButton({
    required this.label,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 8.0),
      child: SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          onPressed: onPressed,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.orange.shade800,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
          ),
          child: Text(label),
        ),
      ),
    );
  }
}

class _FeatureCard extends StatefulWidget {
  final IconData icon;
  final String title;
  final String description;
  final List<_FeatureButton> buttons;

  const _FeatureCard({
    required this.icon,
    required this.title,
    required this.description,
    required this.buttons,
  });

  @override
  State<_FeatureCard> createState() => _FeatureCardState();
}

class _FeatureCardState extends State<_FeatureCard> {
  bool _expanded = false;

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
            InkWell(
              onTap: () {
                setState(() {
                  _expanded = !_expanded;
                });
              },
              child: Column(
                children: [
                  Icon(
                    widget.icon,
                    size: 48,
                    color: Colors.orange.shade900,
                  ),
                  const SizedBox(height: defaultPadding),
                  Text(
                    widget.title,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: defaultPadding / 2),
                  Text(
                    widget.description,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey.shade700,
                    ),
                  ),
                  const SizedBox(height: defaultPadding),
                  Icon(
                    _expanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                    color: Colors.orange.shade900,
                  ),
                ],
              ),
            ),
            AnimatedSize(
              duration: const Duration(milliseconds: 300),
              child: Container(
                height: _expanded ? null : 0,
                constraints: BoxConstraints(
                  maxHeight: _expanded ? double.infinity : 0,
                ),
                child: Column(
                  children: [
                    if (_expanded) ...[
                      const Divider(),
                      ...widget.buttons,
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
} 