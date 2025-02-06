import 'package:flutter/material.dart';
import 'package:my_flutter_app/models/cart_item_model.dart';
import 'package:my_flutter_app/const/constant.dart';
import 'package:my_flutter_app/services/auth_service.dart';
import 'package:my_flutter_app/services/database.dart';
import 'package:my_flutter_app/services/order_service.dart';

class OrderCartPanel extends StatefulWidget {
  final List<CartItem>? initialItems;
  final String? customerName;
  final int? orderId;
  final bool isEditing;
  final Function(int)? onRemoveItem;
  final VoidCallback? onPlaceOrder;
  final VoidCallback? onClearCart;

  const OrderCartPanel({
    super.key,
    this.initialItems,
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
  List<CartItem> _items = [];

  @override
  void initState() {
    super.initState();
    _customerNameController = TextEditingController(text: widget.customerName);
    if (widget.initialItems != null) {
      _items = List.from(widget.initialItems!);
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
        for (var item in _items) {
          await txn.insert(DatabaseService.tableOrderItems, {
            'order_id': widget.orderId,
            'product_id': item.product.id,
            'quantity': item.quantity,
            'unit_price': item.unitPrice,
            'selling_price': item.sellingPrice,
            'total_amount': item.total,
            'is_sub_unit': item.isSubUnit ? 1 : 0,
            'sub_unit_name': item.subUnitName,
            'sub_unit_quantity': item.subUnitQuantity,
          });
        }

        // Log the activity
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

  double get _total => _items.fold(
    0, (sum, item) => sum + item.total
  );

  void _removeItem(int index) {
    if (widget.onRemoveItem != null) {
      widget.onRemoveItem!(index);
      setState(() {
        _items.removeAt(index);
      });
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
            'Current Order',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: defaultPadding),
          TextField(
            controller: _customerNameController,
            decoration: const InputDecoration(
              labelText: 'Customer Name (Optional)',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: defaultPadding),
          Text(
            'Order #${DateTime.now().millisecondsSinceEpoch}',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          Text(
            'Created by: ${AuthService.instance.currentUser?.username ?? "Unknown"}',
          ),
          const SizedBox(height: defaultPadding),
          Expanded(
            child: ListView.builder(
              itemCount: _items.length,
              itemBuilder: (context, index) {
                final item = _items[index];
                return Card(
                  child: ListTile(
                    title: Text(item.product.productName),
                    subtitle: Text(
                      'Quantity: ${item.quantity}${item.isSubUnit ? ' ${item.subUnitName ?? 'pieces'}' : ''}',
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '\$${item.total.toStringAsFixed(2)}',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete),
                          onPressed: widget.onRemoveItem != null 
                            ? () => widget.onRemoveItem!(index)
                            : null,
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          const Divider(),
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
                '\$${_total.toStringAsFixed(2)}',
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
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _items.isEmpty ? null : widget.onPlaceOrder,
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
                  onPressed: _items.isEmpty ? null : widget.onClearCart,
                  icon: const Icon(Icons.clear_all),
                  label: const Text('Clear'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _customerNameController.dispose();
    super.dispose();
  }
} 