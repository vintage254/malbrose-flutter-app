import 'package:flutter/material.dart';
import 'package:my_flutter_app/models/cart_item_model.dart';
import 'package:my_flutter_app/const/constant.dart';
import 'package:my_flutter_app/services/auth_service.dart';
import 'package:my_flutter_app/services/database.dart';
import 'package:my_flutter_app/services/order_service.dart';

class OrderCartPanel extends StatefulWidget {
  final List<CartItem> initialItems;
  final String? customerName;
  final int? orderId;
  final bool isEditing;
  final Function(int)? onRemoveItem;
  final VoidCallback? onPlaceOrder;
  final VoidCallback? onClearCart;

  const OrderCartPanel({
    super.key,
    required this.initialItems,
    this.customerName,
    this.orderId,
    this.isEditing = false,
    this.onRemoveItem,
    this.onPlaceOrder,
    this.onClearCart,
  });

  @override
  State<OrderCartPanel> createState() => _OrderCartPanelState();
}

class _OrderCartPanelState extends State<OrderCartPanel> {
  late final TextEditingController _customerNameController;

  @override
  void initState() {
    super.initState();
    _customerNameController = TextEditingController(text: widget.customerName);
  }

  @override
  void didUpdateWidget(OrderCartPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.customerName != oldWidget.customerName) {
      _customerNameController.text = widget.customerName ?? '';
    }
  }

  Future<void> _updateOrder() async {
    try {
      await DatabaseService.instance.withTransaction((txn) async {
        // Update order details
        await txn.update(
          DatabaseService.tableOrders,
          {
            'customer_name': _customerNameController.text,
            'total_amount': _total,
            'updated_at': DateTime.now().toIso8601String(),
          },
          where: 'id = ?',
          whereArgs: [widget.orderId],
        );

        // Delete existing order items
        await txn.delete(
          DatabaseService.tableOrderItems,
          where: 'order_id = ?',
          whereArgs: [widget.orderId],
        );

        // Insert updated order items
        for (var item in widget.initialItems) {
          await txn.insert(DatabaseService.tableOrderItems, {
            'order_id': widget.orderId,
            'product_id': item.product.id,
            'quantity': item.quantity,
            'unit_price': item.product.buyingPrice,
            'selling_price': item.product.sellingPrice,
            'total_amount': item.total,
            'is_sub_unit': item.isSubUnit ? 1 : 0,
            'sub_unit_name': item.subUnitName,
          });
        }

        // Log the activity within the same transaction
        await txn.insert(
          DatabaseService.tableActivityLogs,
          {
            'user_id': AuthService.instance.currentUser!.id!,
            'username': AuthService.instance.currentUser!.username,
            'action': 'update_order',
            'details': 'Updated order #${widget.orderId}',
            'timestamp': DateTime.now().toIso8601String(),
          },
        );
      });

      // Notify order service to refresh stats
      OrderService.instance.notifyOrderUpdate();

      if (mounted) {
        Navigator.pop(context);
      }
    } catch (e) {
      print('Error updating order: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error updating order: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  double get _total => widget.initialItems.fold(
    0, (sum, item) => sum + item.total
  );

  void _removeItem(int index) {
    if (widget.onRemoveItem != null) {
      widget.onRemoveItem!(index);
      setState(() {
        // Remove the item from the list
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      type: MaterialType.transparency,
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
        padding: const EdgeInsets.all(defaultPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.isEditing ? 'Edit Order' : 'Current Order',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: Colors.white,
              ),
            ),
            const SizedBox(height: defaultPadding),
            TextField(
              controller: _customerNameController,
              decoration: const InputDecoration(
                labelText: 'Customer Name (Optional)',
                border: OutlineInputBorder(),
                filled: true,
                fillColor: Colors.white,
              ),
            ),
            const SizedBox(height: defaultPadding),
            Text(
              'Order #${widget.orderId ?? DateTime.now().millisecondsSinceEpoch}',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            Text(
              'Created by: ${AuthService.instance.currentUser?.username ?? "Unknown"}',
              style: const TextStyle(color: Colors.white70),
            ),
            const SizedBox(height: defaultPadding),
            Expanded(
              child: Card(
                child: ListView.builder(
                  itemCount: widget.initialItems.length,
                  itemBuilder: (context, index) {
                    final item = widget.initialItems[index];
                    return ListTile(
                      title: Text(item.product.productName),
                      subtitle: Text(
                        'Quantity: ${item.quantity}${item.isSubUnit ? ' ${item.subUnitName ?? 'pieces'}' : ''}',
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'KSH ${item.total.toStringAsFixed(2)}',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          if (widget.onRemoveItem != null)
                            IconButton(
                              icon: const Icon(Icons.delete),
                              onPressed: () => widget.onRemoveItem!(index),
                            ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(defaultPadding),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Total:',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          'KSH ${_total.toStringAsFixed(2)}',
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: defaultPadding),
                    Row(
                      children: [
                        if (widget.isEditing)
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: _updateOrder,
                              icon: const Icon(Icons.save),
                              label: const Text('Save Changes'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.blue,
                              ),
                            ),
                          )
                        else ...[
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: widget.initialItems.isEmpty ? null : widget.onPlaceOrder,
                              icon: const Icon(Icons.receipt_long),
                              label: const Text('Place Order'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.green,
                              ),
                            ),
                          ),
                          const SizedBox(width: defaultPadding),
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: widget.initialItems.isEmpty ? null : widget.onClearCart,
                              icon: const Icon(Icons.clear_all),
                              label: const Text('Clear'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.red,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _customerNameController.dispose();
    super.dispose();
  }
} 