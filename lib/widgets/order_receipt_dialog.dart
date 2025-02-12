import 'package:flutter/material.dart';
import 'package:my_flutter_app/models/product_model.dart';
import 'package:my_flutter_app/const/constant.dart';
import 'package:my_flutter_app/models/cart_item_model.dart';

class OrderReceiptDialog extends StatelessWidget {
  final List<CartItem> items;
  final String? customerName;

  const OrderReceiptDialog({
    super.key,
    required this.items,
    this.customerName,
  });

  @override
  Widget build(BuildContext context) {
    final totalAmount = items.fold<double>(
      0,
      (sum, item) => sum + item.total,
    );
    
    return AlertDialog(
      title: const Text('Order Receipt'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Malbrose Hardware Store',
                style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: defaultPadding),
            Text('Date: ${DateTime.now().toString()}'),
            if (customerName != null && customerName!.isNotEmpty)
              Text('Customer: $customerName'),
            const Divider(),
            ...items.map((item) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    flex: 2,
                    child: Text(item.product.productName),
                  ),
                  Expanded(
                    child: Text('x${item.quantity}${item.isSubUnit ? ' ${item.subUnitName ?? "pieces"}' : ''}'),
                  ),
                  Expanded(
                    child: Text('\$${item.total.toStringAsFixed(2)}'),
                  ),
                ],
              ),
            )),
            const Divider(),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Total:',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                Text(
                  '\$${totalAmount.toStringAsFixed(2)}',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Close'),
        ),
        ElevatedButton(
          onPressed: () {
            // TODO: Implement printing functionality later
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Printing will be implemented soon')),
            );
          },
          child: const Text('Print Receipt'),
        ),
      ],
    );
  }
} 