import 'package:flutter/material.dart';
import 'package:my_flutter_app/const/constant.dart';
import 'package:my_flutter_app/services/order_service.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:my_flutter_app/models/order_model.dart';
import 'package:my_flutter_app/widgets/order_cart_panel.dart';

class OrderSummaryWidget extends StatefulWidget {
  const OrderSummaryWidget({super.key});

  @override
  State<OrderSummaryWidget> createState() => _OrderSummaryWidgetState();
}

class _OrderSummaryWidgetState extends State<OrderSummaryWidget> {
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  void _onScroll() {
    if (_scrollController.position.pixels == _scrollController.position.maxScrollExtent) {
      // Load more orders if needed
      // Currently showing all for the day, so no need to load more
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<OrderService>(
      builder: (context, orderService, child) {
        final recentOrders = orderService.recentOrders;

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
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text(
                  'Today\'s Orders',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
              Expanded(
                child: ListView.builder(
                  controller: _scrollController,
                  itemCount: recentOrders.length,
                  itemBuilder: (context, index) {
                    final order = recentOrders[index];
                    final status = order['status'] as String;
                    final createdAt = DateTime.parse(order['created_at'] as String);
                    
                    return Card(
                      margin: const EdgeInsets.symmetric(
                        horizontal: 16.0,
                        vertical: 8.0,
                      ),
                      color: _getStatusColor(status),
                      child: InkWell(
                        onTap: () => _handleOrderTap(context, order),
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    'Order #${order['order_number']}',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                  ),
                                  Text(
                                    DateFormat('HH:mm').format(createdAt),
                                    style: const TextStyle(color: Colors.white70),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Customer: ${order['customer_name'] ?? 'Walk-in'}',
                                style: const TextStyle(color: Colors.white),
                              ),
                              Text(
                                'Total: KSH ${NumberFormat('#,##0.00').format(order['total_amount'])}',
                                style: const TextStyle(color: Colors.white),
                              ),
                              Text(
                                'Status: $status',
                                style: const TextStyle(color: Colors.white70),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Color _getStatusColor(String status) {
    switch (status.toUpperCase()) {
      case 'COMPLETED':
        return Colors.green.withOpacity(0.7);
      case 'PENDING':
        return Colors.orange.withOpacity(0.7);
      default:
        return Colors.grey.withOpacity(0.7);
    }
  }

  void _handleOrderTap(BuildContext context, Map<String, dynamic> order) {
    if (order['status'] == 'PENDING') {
      // Navigate to OrderCartPanel for editing
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => OrderCartPanel(
            orderId: order['id'] as int,
            isEditing: true,
          ),
        ),
      );
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }
} 