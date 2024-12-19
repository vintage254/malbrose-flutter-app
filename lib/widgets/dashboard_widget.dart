import 'package:flutter/material.dart';
import 'package:my_flutter_app/const/constant.dart';
import 'package:my_flutter_app/services/order_service.dart';
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
      child: Padding(
        padding: const EdgeInsets.all(defaultPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Consumer<OrderService>(
              builder: (context, orderService, child) => Text(
                orderService.currentDate,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
            const SizedBox(height: defaultPadding),
            Consumer<OrderService>(
              builder: (context, orderService, child) => Row(
                children: [
                  _StatCard(
                    title: 'Total Orders',
                    value: orderService.totalOrders.toString(),
                    icon: Icons.shopping_cart,
                    color: Colors.blue,
                  ),
                  const SizedBox(width: defaultPadding),
                  _StatCard(
                    title: 'Total Sales',
                    value: 'KSH ${NumberFormat('#,##0.00').format(orderService.totalSales)}',
                    icon: Icons.payments,
                    color: Colors.green,
                  ),
                  const SizedBox(width: defaultPadding),
                  _StatCard(
                    title: 'Pending Orders',
                    value: orderService.pendingOrders.toString(),
                    icon: Icons.pending_actions,
                    color: Colors.orange,
                  ),
                ],
              ),
            ),
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
    return Expanded(
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(defaultPadding),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(icon, color: color, size: 30),
                  const SizedBox(width: defaultPadding),
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
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
      ),
    );
  }
}
