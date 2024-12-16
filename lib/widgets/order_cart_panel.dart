import 'package:flutter/material.dart';
import 'package:my_flutter_app/models/cart_item_model.dart';
import 'package:my_flutter_app/const/constant.dart';
import 'package:my_flutter_app/services/auth_service.dart';

class OrderCartPanel extends StatefulWidget {
  final List<CartItem> items;
  final Function(int) onRemoveItem;
  final VoidCallback onPlaceOrder;
  final VoidCallback onClearCart;
  
  const OrderCartPanel({
    super.key,
    required this.items,
    required this.onRemoveItem,
    required this.onPlaceOrder,
    required this.onClearCart,
  });

  @override
  State<OrderCartPanel> createState() => _OrderCartPanelState();
}

class _OrderCartPanelState extends State<OrderCartPanel> {
  final _customerNameController = TextEditingController();
  
  double get _total => widget.items.fold(
    0, (sum, item) => sum + item.total
  );

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
              itemCount: widget.items.length,
              itemBuilder: (context, index) {
                final item = widget.items[index];
                return Card(
                  child: ListTile(
                    title: Text(item.product.productName),
                    subtitle: Text('Quantity: ${item.quantity}'),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '\$${item.total.toStringAsFixed(2)}',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete),
                          onPressed: () => widget.onRemoveItem(index),
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
                  onPressed: widget.items.isEmpty ? null : widget.onPlaceOrder,
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
                  onPressed: widget.items.isEmpty ? null : widget.onClearCart,
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