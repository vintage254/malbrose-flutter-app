import 'package:flutter/material.dart';
import 'package:my_flutter_app/data/side_menu_data.dart';
import 'package:my_flutter_app/const/constant.dart';
import 'package:my_flutter_app/screens/product_form_screen.dart';
import 'package:my_flutter_app/screens/order_screen.dart';

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
  List<Widget> _buildMenuItems() {
    return [
      _buildPopupMenuButton(
        'Products',
        [
          const PopupMenuItem(
            value: 'add_product',
            child: Text('Add Product', style: TextStyle(fontSize: 12)),
          ),
          const PopupMenuItem(
            value: 'view_all_products',
            child: Text('View All Products', style: TextStyle(fontSize: 12)),
          ),
        ],
      ),
      _buildPopupMenuButton(
        'Orders',
        [
          const PopupMenuItem(
            value: 'place_order',
            child: Text('Place Order', style: TextStyle(fontSize: 12)),
          ),
          const PopupMenuItem(
            value: 'view_orders',
            child: Text('View Orders', style: TextStyle(fontSize: 12)),
          ),
        ],
      ),
    ];
  }

  void _handleMenuAction(String? value) async {
    if (value == null) return;

    switch (value) {
      case 'add_product':
        final result = await showDialog(
          context: context,
          builder: (context) => const ProductFormScreen(),
        );
        if (result == true) {
          widget.onProductsUpdated?.call();
        }
        break;
      case 'view_all_products':
        widget.onProductsUpdated?.call();
        break;
      case 'place_order':
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => const OrderScreen(),
          ),
        );
        break;
      case 'view_orders':
        // We'll implement this later
        break;
    }
  }

  Widget _buildPopupMenuButton(String title, List<PopupMenuItem<String>> items) {
    return PopupMenuButton<String>(
      itemBuilder: (context) => items,
      onSelected: _handleMenuAction,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(defaultPadding),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            const Color.fromARGB(255, 230, 227, 220).withAlpha(179),
            const Color.fromARGB(255, 230, 192, 80),
          ],
        ),
      ),
      child: ListView.builder(
        itemCount: SideMenuData().menu.length,
        itemBuilder: (context, index) {
          final menuItem = SideMenuData().menu[index];
          final GlobalKey menuItemKey = GlobalKey();

          return GestureDetector(
            onTap: () {
              _showPopupMenu(context, menuItem.title, menuItemKey);
            },
            child: ListTile(
              key: menuItemKey,
              leading: Icon(menuItem.icon),
              title: Text(
                menuItem.title,
                style: TextStyle(fontSize: 12),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          );
        },
      ),
    );
  }

  void _showPopupMenu(
      BuildContext context, String title, GlobalKey menuItemKey) {
    final RenderBox overlay =
        Overlay.of(context).context.findRenderObject() as RenderBox;

    final renderBox = menuItemKey.currentContext?.findRenderObject();
    if (renderBox == null) return;

    final RenderBox menuItem = renderBox as RenderBox;
    final Offset menuItemPosition = menuItem.localToGlobal(Offset.zero);
    final RelativeRect position = RelativeRect.fromLTRB(
      menuItemPosition.dx,
      menuItemPosition.dy + menuItem.size.height,
      overlay.size.width - menuItemPosition.dx,
      overlay.size.height - menuItemPosition.dy,
    );

    showMenu(
      context: context,
      position: position,
      items: _getMenuOptions(title),
    ).then(_handleMenuAction);
  }

  List<PopupMenuEntry<String>> _getMenuOptions(String title) {
    switch (title) {
      case 'user management':
        return [
          const PopupMenuItem(
              value: 'add_user',
              child: Text('Add User', style: TextStyle(fontSize: 12))),
          const PopupMenuItem(
              value: 'manage_user',
              child: Text('Manage User', style: TextStyle(fontSize: 12))),
          const PopupMenuItem(
              value: 'activity_log',
              child: Text('User Activity Log', style: TextStyle(fontSize: 12))),
        ];
      case 'product management':
        return [
          const PopupMenuItem(
              value: 'add_product',
              child: Text('Add Product', style: TextStyle(fontSize: 12))),
          const PopupMenuItem(
              value: 'view_all_products',
              child: Text('View All Products', style: TextStyle(fontSize: 12))),
        ];
      case 'orders':
        return [
          const PopupMenuItem(
              value: 'view_orders',
              child: Text('View Orders', style: TextStyle(fontSize: 12))),
        ];
      case 'Dashboard':
        return [
          const PopupMenuItem(
              value: 'dashboard_info',
              child:
                  Text('Go back to Dashboard', style: TextStyle(fontSize: 12))),
        ];
      case 'authentication':
        return [
          const PopupMenuItem(
              value: 'sign_in',
              child: Text('Sign In', style: TextStyle(fontSize: 12))),
          const PopupMenuItem(
              value: 'sign_out',
              child: Text('Sign Out', style: TextStyle(fontSize: 12))),
        ];
      default:
        return [];
    }
  }
}
