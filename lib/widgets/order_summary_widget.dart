import 'package:flutter/material.dart';
import 'package:my_flutter_app/const/constant.dart';
import 'package:my_flutter_app/services/order_service.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:my_flutter_app/models/order_model.dart';
import 'package:my_flutter_app/widgets/order_cart_panel.dart';
import 'package:my_flutter_app/models/cart_item_model.dart';
import 'package:my_flutter_app/services/database.dart';
import 'package:my_flutter_app/models/product_model.dart';

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

  Future<void> _handleOrderTap(BuildContext context, Map<String, dynamic> order) async {
    if (order['status'] == 'PENDING') {
      try {
        // Load order items
        final orderItems = await DatabaseService.instance.getOrderItems(order['id'] as int);
        
        // Convert order items to CartItems
        final cartItems = await Future.wait(orderItems.map((item) async {
          // Get the product details
          final productData = await DatabaseService.instance.getProductById(item['product_id'] as int);
          if (productData == null) return null;
          
          final product = Product.fromMap(productData);
          
          return CartItem(
            product: product,
            quantity: item['quantity'] as int,
            total: item['total_amount'] as double,
            isSubUnit: false, // Set based on your needs
            subUnitName: null,
            subUnitQuantity: null,
          );
        }));

        // Filter out any null items and navigate
        final validCartItems = cartItems.whereType<CartItem>().toList();
        
        if (mounted) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => OrderCartPanel(
                orderId: order['id'] as int,
                isEditing: true,
                initialItems: validCartItems,
                customerName: order['customer_name'] as String?,
              ),
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error loading order: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
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

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }
} 