import 'package:flutter/material.dart';
import 'package:my_flutter_app/const/constant.dart';
import 'package:my_flutter_app/data/side_menu_data.dart';
import 'package:my_flutter_app/screens/main_screen.dart';
import 'package:my_flutter_app/screens/product_form_screen.dart';
import 'package:my_flutter_app/screens/order_screen.dart';
import 'package:my_flutter_app/screens/sales_screen.dart';
import 'package:my_flutter_app/screens/user_management_screen.dart';
import 'package:my_flutter_app/screens/home_screen.dart';
import 'package:my_flutter_app/services/auth_service.dart';
import 'package:my_flutter_app/widgets/app_logo.dart';

class SideMenuWidget extends StatefulWidget {
  final VoidCallback? onProductsUpdated;
  
  const SideMenuWidget({
    super.key,
    this.onProductsUpdated,
  });

  @override
  State<SideMenuWidget> createState() => _SideMenuWidgetState();
}

class _SideMenuWidgetState extends State<SideMenuWidget> {
  final menuData = SideMenuData();
  int _selectedIndex = 0;

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
      child: Card(
        color: Colors.transparent,
        elevation: 0,
        child: ListView(
          children: [
            DrawerHeader(
              child: const AppLogo(),
            ),
            ...List.generate(
              menuData.menu.length,
              (index) {
                final menu = menuData.menu[index];
                
                // Skip admin-only items for non-admin users
                if (!currentUser!.isAdmin && 
                    (menu.title == 'user management' || menu.title == 'Activity Logs')) {
                  return const SizedBox.shrink();
                }

                return ListTile(
                  selected: _selectedIndex == index,
                  selectedTileColor: Colors.blue.withOpacity(0.1),
                  leading: Icon(menu.icon),
                  title: Text(
                    menu.title,
                    style: const TextStyle(fontSize: 14),
                  ),
                  onTap: () {
                    setState(() => _selectedIndex = index);
                    
                    // Handle navigation based on menu title
                    switch (menu.title.toLowerCase()) {
                      case 'dashboard':
                        Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(builder: (context) => const MainScreen()),
                        );
                        break;
                      case 'user management':
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => const UserManagementScreen()),
                        );
                        break;
                      case 'product management':
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => const ProductFormScreen()),
                        );
                        break;
                      case 'orders':
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => const OrderScreen()),
                        );
                        break;
                      case 'sales':
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => const SalesScreen()),
                        );
                        break;
                    }
                  },
                );
              },
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.logout),
              title: const Text('Logout', style: TextStyle(fontSize: 14)),
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
      ),
    );
  }
}
