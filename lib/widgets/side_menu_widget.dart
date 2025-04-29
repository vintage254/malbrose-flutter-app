import 'package:flutter/material.dart';
import 'dart:developer';
import 'package:my_flutter_app/const/constant.dart';
import 'package:my_flutter_app/services/auth_service.dart';
import 'package:my_flutter_app/screens/home_screen.dart';
import 'package:my_flutter_app/utils/ui_helpers.dart';

class SideMenuWidget extends StatefulWidget {
  const SideMenuWidget({super.key});

  @override
  State<SideMenuWidget> createState() => _SideMenuWidgetState();
}

class _SideMenuWidgetState extends State<SideMenuWidget> {
  List<Map<String, dynamic>> _getMenuItems() {
    final currentUser = AuthService.instance.currentUser;
    final isAdmin = currentUser?.role == 'ADMIN';

    // Debug logging for development only. Remove or wrap with assert for production.
    assert(() {
      log('Current User:  24{currentUser?.username}');
      log('User Role:  24{currentUser?.role}');
      log('Is Admin:  24isAdmin');
      return true;
    }());

    // Create list following the proposed structure
    final List<Map<String, dynamic>> items = [
      // Core navigation
      {'title': 'Home', 'icon': Icons.home, 'route': '/home'},
      {'title': 'Dashboard', 'icon': Icons.dashboard, 'route': '/main'},
      
      // Order workflow (basic)
      {'title': 'Create Orders', 'icon': Icons.shopping_cart, 'route': '/orders'},
      {'title': 'Held Orders', 'icon': Icons.pause_circle_filled, 'route': '/held-orders'},
      {'title': 'Complete Sales', 'icon': Icons.point_of_sale, 'route': '/sales'},
      
      // Order history (admin only)
      if (isAdmin)
        {'title': 'Order History', 'icon': Icons.history, 'route': '/order-history'},
      
      // Product and finance management
      {'title': 'Product Management', 'icon': Icons.inventory, 'route': '/products'},
      {'title': 'Creditors', 'icon': Icons.account_balance_wallet, 'route': '/creditors'},
      {'title': 'Debtors', 'icon': Icons.money_off, 'route': '/debtors'},
      
      // Reports
      {'title': 'Customer Reports', 'icon': Icons.receipt_long, 'route': '/customer-reports'},
      if (isAdmin)
        {'title': 'Sales Reports', 'icon': Icons.bar_chart, 'route': '/sales-report'},
      
      // Settings and system (admin only)
      if (isAdmin)
        {'title': 'Settings', 'icon': Icons.settings, 'route': '/settings'},
      if (isAdmin)
        {'title': 'Printer Settings', 'icon': Icons.print, 'route': '/printer-settings'},
      if (isAdmin)
        {'title': 'Backup & Restore', 'icon': Icons.backup, 'route': '/backup'},
      if (isAdmin)
        {'title': 'Activity Log', 'icon': Icons.history, 'route': '/activity'},
    ];

    return items;
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = AuthService.instance.currentUser;
    final menuItems = _getMenuItems();

    return SizedBox(
      width: 250, // Fixed width for the side menu
      child: Container(
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
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(defaultPadding),
              child: Text(
                'Welcome, ${currentUser?.username ?? "Guest"}',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const Divider(color: Colors.white60),
            Expanded(
              child: ListView.builder(
                itemCount: menuItems.length,
                itemBuilder: (context, index) {
                  final item = menuItems[index];
                  return _buildMenuItem(
                    context,
                    item['title'] as String,
                    item['icon'] as IconData,
                    () {
                      if (item['route'] == '/home') {
                        Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(builder: (context) => const HomeScreen())
                        );
                      } else {
                        Navigator.pushNamed(context, item['route'] as String);
                      }
                    },
                  );
                },
              ),
            ),
            const Divider(color: Colors.white60),
            ListTile(
              leading: const Icon(Icons.logout, color: Colors.white),
              title: const Text(
                'Logout',
                style: TextStyle(color: Colors.white, fontSize: 14),
              ),
              onTap: () async {
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
                  
                  // Navigate to home screen
                  Navigator.of(context).pushAndRemoveUntil(
                    MaterialPageRoute(builder: (_) => const HomeScreen()),
                    (route) => false,
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
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMenuItem(BuildContext context, String title, IconData icon, VoidCallback onTap) {
    return ListTile(
      leading: Icon(icon, color: Colors.white),
      title: Text(
        title,
        style: const TextStyle(color: Colors.white, fontSize: 14),
        overflow: TextOverflow.ellipsis,
      ),
      onTap: onTap,
    );
  }
}
