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
  final menuItems = [
    {'title': 'Dashboard', 'icon': Icons.dashboard, 'route': '/dashboard'},
    {'title': 'Orders', 'icon': Icons.shopping_cart, 'route': '/orders'},
    {'title': 'Sales', 'icon': Icons.point_of_sale, 'route': '/sales'},
    {'title': 'Products', 'icon': Icons.inventory, 'route': '/products'},
    {'title': 'Users', 'icon': Icons.people, 'route': '/users'},
    {'title': 'Activity Log', 'icon': Icons.history, 'route': '/activity'},
  ];

  @override
  Widget build(BuildContext context) {
    final currentUser = AuthService.instance.currentUser;

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
              'Welcome, ${currentUser?.username ?? "User"}',
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
                return ListTile(
                  leading: Icon(item['icon'] as IconData, color: Colors.white),
                  title: Text(
                    item['title'] as String,
                    style: const TextStyle(color: Colors.white, fontSize: 14),
                  ),
                  onTap: () {
                    Navigator.pushNamed(context, item['route'] as String);
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
              await AuthService.instance.logout();
              if (!context.mounted) return;
              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(builder: (_) => const HomeScreen()),
                (route) => false,
              );
            },
          ),
        ],
      ),
    );
  }
}
