import 'package:flutter/material.dart';
import 'package:my_flutter_app/const/constant.dart';
import 'package:my_flutter_app/models/order_model.dart';
import 'package:my_flutter_app/services/database.dart';
import 'package:my_flutter_app/widgets/side_menu_widget.dart';
import 'package:my_flutter_app/widgets/receipt_panel.dart';
import 'package:my_flutter_app/services/order_service.dart';

class SalesScreen extends StatefulWidget {
  const SalesScreen({super.key});

  @override
  State<SalesScreen> createState() => _SalesScreenState();
}

class _SalesScreenState extends State<SalesScreen> {
  List<Order> _pendingOrders = [];
  Order? _selectedOrder;
  bool _isLoading = true;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadPendingOrders();
  }

  Future<void> _loadPendingOrders() async {
    try {
      final orders = await DatabaseService.instance.getOrdersByStatus('PENDING');
      if (mounted) {
        // Group orders by order number
        final Map<String, List<Order>> groupedOrders = {};
        final List<Order> ordersList = orders.map((o) => Order.fromMap(o)).toList();
        
        for (final order in ordersList) {
          final orderNumber = order.orderNumber ?? '';
          if (!groupedOrders.containsKey(orderNumber)) {
            groupedOrders[orderNumber] = [];
          }
          groupedOrders[orderNumber]!.add(order);
        }
        
        // Create combined orders
        final List<Order> combinedOrders = groupedOrders.entries.map((entry) {
          final orders = entry.value;
          final firstOrder = orders.first;
          return Order(
            id: firstOrder.id,
            orderNumber: firstOrder.orderNumber,
            productId: firstOrder.productId,
            quantity: firstOrder.quantity,
            sellingPrice: firstOrder.sellingPrice,
            buyingPrice: firstOrder.buyingPrice,
            totalAmount: orders.fold(0.0, (sum, order) => sum + order.totalAmount),
            customerName: firstOrder.customerName,
            orderStatus: firstOrder.orderStatus,
            createdBy: firstOrder.createdBy,
            orderDate: firstOrder.orderDate,
            items: orders,
          );
        }).toList();

        setState(() {
          _pendingOrders = combinedOrders;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading orders: $e')),
        );
      }
    }
  }

  List<Order> get _filteredOrders {
    if (_searchQuery.isEmpty) return _pendingOrders;
    return _pendingOrders.where((order) {
      final search = _searchQuery.toLowerCase();
      return 
        (order.customerName?.toLowerCase().contains(search) ?? false) ||
        order.id.toString().contains(search);
    }).toList();
  }

  Future<void> _processSale(Order order) async {
    try {
      // Update all items in the order at once using the order number
      await DatabaseService.instance.updateOrderStatus(order.orderNumber!, 'COMPLETED');
      
      // Update product quantities for all items in the order
      for (final item in order.items ?? []) {
        await DatabaseService.instance.updateProductQuantity(
          item.productId,
          item.quantity,
          subtract: true, // subtract the quantity
        );
      }
      
      // Notify OrderService about the update
      OrderService.instance.notifyOrderUpdate();
      
      // Refresh the orders list
      await _loadPendingOrders();
      setState(() {
        _selectedOrder = null;
      });
      
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Sale processed successfully'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error processing sale: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Widget _buildOrderListItem(Order order) {
    return Card(
      margin: const EdgeInsets.symmetric(
        horizontal: defaultPadding,
        vertical: defaultPadding / 2,
      ),
      child: ListTile(
        leading: const Icon(Icons.receipt),
        title: Text('Order #${order.orderNumber}'),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Customer: ${order.customerName ?? "N/A"}'),
            Text('Items: ${order.items?.length ?? 1}'),
          ],
        ),
        trailing: Text(
          'KSH ${order.totalAmount.toStringAsFixed(2)}',
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
        onTap: () => setState(() => _selectedOrder = order),
        selected: _selectedOrder?.orderNumber == order.orderNumber,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Row(
        children: [
          const Expanded(flex: 1, child: SideMenuWidget()),
          Expanded(
            flex: 2,
            child: Container(
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
                    child: Row(
                      children: [
                        const Text(
                          'Pending Orders', 
                          style: TextStyle(
                            fontSize: 24, 
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        const Spacer(),
                        SizedBox(
                          width: 200,
                          child: TextField(
                            controller: _searchController,
                            decoration: InputDecoration(
                              hintText: 'Search orders...',
                              prefixIcon: const Icon(Icons.search),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                              filled: true,
                              fillColor: Colors.white,
                            ),
                            onChanged: (value) {
                              setState(() {
                                _searchQuery = value;
                              });
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: _isLoading
                        ? const Center(child: CircularProgressIndicator())
                        : _filteredOrders.isEmpty
                            ? const Center(
                                child: Text(
                                  'No pending orders found',
                                  style: TextStyle(
                                    fontSize: 18,
                                    color: Colors.white,
                                  ),
                                ),
                              )
                            : ListView.builder(
                                itemCount: _filteredOrders.length,
                                itemBuilder: (context, index) {
                                  final order = _filteredOrders[index];
                                  return _buildOrderListItem(order);
                                },
                              ),
                  ),
                ],
              ),
            ),
          ),
          if (_selectedOrder != null)
            Expanded(
              flex: 2,
              child: ReceiptPanel(
                order: _selectedOrder!,
                onProcessSale: _processSale,
              ),
            ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }
} 