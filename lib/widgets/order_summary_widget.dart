import 'package:flutter/material.dart';
import 'package:my_flutter_app/const/constant.dart';
import 'package:my_flutter_app/services/order_service.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:my_flutter_app/models/order_model.dart';

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
      padding: const EdgeInsets.all(defaultPadding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Today\'s Orders',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: defaultPadding),
          Expanded(
            child: Consumer<OrderService>(
              builder: (context, orderService, child) {
                if (orderService.recentOrders.isEmpty) {
                  return const Center(
                    child: Text(
                      'No orders today',
                      style: TextStyle(color: Colors.white),
                    ),
                  );
                }
                return ListView.builder(
                  controller: _scrollController,
                  itemCount: orderService.recentOrders.length,
                  itemBuilder: (context, index) {
                    final orderData = orderService.recentOrders[index];
                    
                    // Safely handle order items
                    final orderItems = (orderData['items'] as List?)?.map((item) => OrderItem(
                      orderId: orderData['id'],
                      productId: item['product_id'],
                      quantity: item['quantity'],
                      unitPrice: (item['unit_price'] as num).toDouble(),
                      sellingPrice: (item['selling_price'] as num).toDouble(),
                      totalAmount: (item['total_amount'] as num).toDouble(),
                      productName: item['product_name'],
                    )).toList() ?? [];

                    final order = Order.fromMap(orderData, orderItems);

                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        leading: Icon(
                          Icons.receipt_long,
                          color: order.orderStatus == 'COMPLETED'
                              ? Colors.green
                              : Colors.orange,
                        ),
                        title: Row(
                          children: [
                            Text('Order #${order.orderNumber}'),
                            const Spacer(),
                            Text(
                              DateFormat('HH:mm').format(order.createdAt),
                              style: const TextStyle(
                                fontSize: 12,
                                color: Colors.grey,
                              ),
                            ),
                          ],
                        ),
                        subtitle: Text(
                          'Customer: ${order.customerName ?? "N/A"}\n'
                          'Status: ${order.orderStatus}',
                        ),
                        trailing: Text(
                          'KSH ${order.totalAmount.toStringAsFixed(2)}',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        isThreeLine: true,
                      ),
                    );
                  },
                );
              },
            ),
          ),
          const Divider(color: Colors.white60),
          const Text(
            'Today\'s Summary',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: defaultPadding),
          Consumer<OrderService>(
            builder: (context, orderService, _) => Column(
              children: [
                _buildSummaryItem(
                  'Total Orders',
                  orderService.totalOrders.toString(),
                ),
                _buildSummaryItem(
                  'Total Sales',
                  'KSH ${NumberFormat('#,##0.00').format(orderService.totalSales)}',
                ),
                _buildSummaryItem(
                  'Pending Orders',
                  orderService.pendingOrdersCount.toString(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Widget _buildSummaryItem(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(color: Colors.white),
          ),
          Text(
            value,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
} 