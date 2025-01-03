import 'package:flutter/material.dart';
import 'package:my_flutter_app/const/constant.dart';
import 'package:my_flutter_app/services/auth_service.dart';
import 'package:my_flutter_app/screens/home_screen.dart';

class SideMenuWidget extends StatefulWidget {
  const SideMenuWidget({super.key});

  @override
  State<SideMenuWidget> createState() => _SideMenuWidgetState();
}

class _SideMenuWidgetState extends State<SideMenuWidget> {
  List<Map<String, dynamic>> _getMenuItems() {
    final currentUser = AuthService.instance.currentUser;
    final isAdmin = currentUser?.role == 'ADMIN';

    print('Current User: ${currentUser?.username}');
    print('User Role: ${currentUser?.role}');
    print('Is Admin: $isAdmin');

    final List<Map<String, dynamic>> items = [
      {'title': 'Dashboard', 'icon': Icons.dashboard, 'route': '/main'},
      {'title': 'Orders', 'icon': Icons.shopping_cart, 'route': '/orders'},
      {'title': 'Products', 'icon': Icons.inventory, 'route': '/products'},
      {'title': 'Creditors', 'icon': Icons.account_balance_wallet, 'route': '/creditors'},
      {'title': 'Debtors', 'icon': Icons.money_off, 'route': '/debtors'},
    ];

    // Add admin-only menu items
    if (isAdmin) {
      items.addAll([
        {'title': 'Sales', 'icon': Icons.point_of_sale, 'route': '/sales'},
        {'title': 'Users', 'icon': Icons.people, 'route': '/users'},
        {'title': 'Activity Log', 'icon': Icons.history, 'route': '/activity'},
      ]);
    }

    return items;
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = AuthService.instance.currentUser;
    final menuItems = _getMenuItems();

    return Container(
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
                  () => Navigator.pushNamed(context, item['route'] as String),
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
                
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Error logging out: $e'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _buildMenuItem(BuildContext context, String title, IconData icon, VoidCallback onTap) {
    return ListTile(
      leading: Icon(icon, color: Colors.white),
      title: Text(
        title,
        style: const TextStyle(color: Colors.white, fontSize: 14),
      ),
      onTap: onTap,
    );
  }
}
