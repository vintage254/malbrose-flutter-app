import 'package:flutter/material.dart';
import 'package:my_flutter_app/const/constant.dart';
import 'package:my_flutter_app/services/order_service.dart';
import 'package:my_flutter_app/services/auth_service.dart';
import 'package:my_flutter_app/screens/order_screen.dart';
import 'package:my_flutter_app/screens/activity_log_screen.dart';
import 'package:my_flutter_app/screens/creditors_screen.dart';
import 'package:my_flutter_app/screens/debtors_screen.dart';
import 'package:my_flutter_app/screens/sales_report_screen.dart';
import 'package:my_flutter_app/screens/product_management_screen.dart';
import 'package:my_flutter_app/screens/settings_screen.dart';
import 'package:my_flutter_app/screens/sales_screen.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

class DashboardWidget extends StatefulWidget {
  const DashboardWidget({super.key});

  @override
  State<DashboardWidget> createState() => DashboardWidgetState();
}

class DashboardWidgetState extends State<DashboardWidget> {
  void refreshProducts() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = AuthService.instance.currentUser;
    final isAdmin = currentUser?.isAdmin ?? false;
    final screenWidth = MediaQuery.of(context).size.width;

    // Determine number of cards per row based on screen width
    final cardsPerRow = screenWidth < 600 ? 2 : 3;
    
    // Calculate card width and spacing
    final totalSpacing = defaultPadding * (cardsPerRow + 1);
    final cardWidth = (screenWidth - totalSpacing) / cardsPerRow;
    
    return Container(
      width: double.infinity,
      height: double.infinity,
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
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(defaultPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Stats Section
            Consumer<OrderService>(
              builder: (context, orderService, child) => Wrap(
                spacing: defaultPadding,
                runSpacing: defaultPadding,
                children: [
                  SizedBox(
                    width: cardWidth,
                    child: _StatCard(
                      title: 'Today\'s Completed Orders',
                      value: orderService.todayOrders.toString(),
                      icon: Icons.shopping_cart,
                      color: Colors.blue,
                    ),
                  ),
                  SizedBox(
                    width: cardWidth,
                    child: _StatCard(
                      title: 'Today\'s Sales',
                      value: 'KSH ${NumberFormat('#,##0.00').format(orderService.todaySales)}',
                      icon: Icons.payments,
                      color: Colors.green,
                    ),
                  ),
                  SizedBox(
                    width: cardWidth,
                    child: _StatCard(
                      title: 'Pending Orders',
                      value: orderService.pendingOrdersCount.toString(),
                      icon: Icons.pending_actions,
                      color: Colors.orange,
                    ),
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: defaultPadding * 2),
            
            // Action Cards - Reorganized to match workflow
            Wrap(
              spacing: defaultPadding,
              runSpacing: defaultPadding,
              children: [
                // Order workflow
                SizedBox(
                  width: cardWidth,
                  child: _ActionCard(
                    title: 'Create Order',
                    icon: Icons.add_shopping_cart,
                    color: Colors.blue,
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const OrderScreen()),
                    ),
                  ),
                ),
                SizedBox(
                  width: cardWidth,
                  child: _ActionCard(
                    title: 'Held Orders',
                    icon: Icons.pause_circle_filled,
                    color: Colors.orange,
                    onPressed: () => Navigator.pushNamed(context, '/held-orders'),
                  ),
                ),
                SizedBox(
                  width: cardWidth,
                  child: _ActionCard(
                    title: 'Make Sale',
                    icon: Icons.point_of_sale,
                    color: Colors.purple,
                    onPressed: () => Navigator.pushNamed(context, '/sales'),
                  ),
                ),
                
                // Product & Finance Management
                SizedBox(
                  width: cardWidth,
                  child: _ActionCard(
                    title: 'Product Management',
                    icon: Icons.inventory,
                    color: Colors.teal,
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const ProductManagementScreen()),
                    ),
                  ),
                ),
                SizedBox(
                  width: cardWidth,
                  child: _ActionCard(
                    title: 'Creditors',
                    icon: Icons.account_balance_wallet,
                    color: Colors.green,
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const CreditorsScreen()),
                    ),
                  ),
                ),
                SizedBox(
                  width: cardWidth,
                  child: _ActionCard(
                    title: 'Debtors',
                    icon: Icons.person_add,
                    color: Colors.orange,
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const DebtorsScreen()),
                    ),
                  ),
                ),
                
                // Reports
                SizedBox(
                  width: cardWidth,
                  child: _ActionCard(
                    title: 'Customer Reports',
                    icon: Icons.receipt_long,
                    color: Colors.purple,
                    onPressed: () => Navigator.pushNamed(context, '/customer-reports'),
                  ),
                ),
              ],
            ),
            
            if (isAdmin) ...[
              const SizedBox(height: defaultPadding * 2),
              const Divider(color: Colors.white54),
              const Text(
                'Admin Actions',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: defaultPadding),
              
              // Admin Action Cards - Reorganized to match workflow
              Wrap(
                spacing: defaultPadding,
                runSpacing: defaultPadding,
                children: [
                  // Order History (admin only)
                  SizedBox(
                    width: cardWidth,
                    child: _ActionCard(
                      title: 'Order History',
                      icon: Icons.history,
                      color: Colors.teal,
                      onPressed: () => Navigator.pushNamed(context, '/order-history'),
                    ),
                  ),
                  
                  // Reports (admin only)
                  SizedBox(
                    width: cardWidth,
                    child: _ActionCard(
                      title: 'Sales Reports',
                      icon: Icons.bar_chart,
                      color: Colors.blue,
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const SalesReportScreen()),
                      ),
                    ),
                  ),
                  
                  // Settings & System (admin only)
                  SizedBox(
                    width: cardWidth,
                    child: _ActionCard(
                      title: 'Settings',
                      icon: Icons.settings,
                      color: Colors.indigo,
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const SettingsScreen()),
                      ),
                    ),
                  ),
                  SizedBox(
                    width: cardWidth,
                    child: _ActionCard(
                      title: 'Printer Settings',
                      icon: Icons.print,
                      color: Colors.indigo,
                      onPressed: () => Navigator.pushNamed(context, '/printer-settings'),
                    ),
                  ),
                  SizedBox(
                    width: cardWidth,
                    child: _ActionCard(
                      title: 'Backup & Restore',
                      icon: Icons.backup,
                      color: Colors.indigo,
                      onPressed: () => Navigator.pushNamed(context, '/backup'),
                    ),
                  ),
                  SizedBox(
                    width: cardWidth,
                    child: _ActionCard(
                      title: 'Activity Logs',
                      icon: Icons.history,
                      color: Colors.teal,
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const ActivityLogScreen()),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;

  const _StatCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(defaultPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: color, size: 30),
                const SizedBox(width: defaultPadding),
                Flexible(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: defaultPadding),
            Text(
              value,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ActionCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color color;
  final VoidCallback onPressed;

  const _ActionCard({
    required this.title,
    required this.icon,
    required this.color,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        onTap: onPressed,
        child: Padding(
          padding: const EdgeInsets.all(defaultPadding),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: color, size: 24),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}