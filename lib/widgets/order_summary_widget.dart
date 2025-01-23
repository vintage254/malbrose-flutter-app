import 'package:flutter/material.dart';
import 'package:my_flutter_app/const/constant.dart';
import 'package:my_flutter_app/services/order_service.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:my_flutter_app/models/order_model.dart';

class OrderSummaryWidget extends StatelessWidget {
  const OrderSummaryWidget({super.key});

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
            'Recent Orders',
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
                      'No recent orders',
                      style: TextStyle(color: Colors.white),
                    ),
                  );
                }
                return ListView.builder(
                  itemCount: orderService.recentOrders.length,
                  itemBuilder: (context, index) {
                    final orderData = orderService.recentOrders[index];
                    // Convert Map to Order object using fromMap
                    final orderItems = orderData['items']?.map<OrderItem>((item) => OrderItem(
                      orderId: orderData['id'],
                      productId: item['product_id'],
                      quantity: item['quantity'],
                      unitPrice: (item['unit_price'] as num).toDouble(),
                      sellingPrice: (item['selling_price'] as num).toDouble(),
                      totalAmount: (item['total_amount'] as num).toDouble(),
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
                        title: Text('Order #${order.orderNumber}'),
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
                  orderService.pendingOrders.toString(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
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