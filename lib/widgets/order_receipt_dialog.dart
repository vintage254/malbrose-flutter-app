import 'package:flutter/material.dart';
import 'package:my_flutter_app/models/product_model.dart';
import 'package:my_flutter_app/const/constant.dart';

class OrderReceiptDialog extends StatelessWidget {
  final Product product;
  final int quantity;

  const OrderReceiptDialog({
    super.key,
    required this.product,
    required this.quantity,
  });

  @override
  Widget build(BuildContext context) {
    final totalAmount = quantity * product.sellingPrice;
    
    return AlertDialog(
      title: const Text('Order Receipt'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Malbrose Hardware Store',
              style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: defaultPadding),
          Text('Date: ${DateTime.now().toString()}'),
          Text('Product: ${product.productName}'),
          Text('Quantity: $quantity'),
          Text('Price per unit: \$${product.sellingPrice}'),
          Text('Total Amount: \$${totalAmount.toStringAsFixed(2)}',
              style: const TextStyle(fontWeight: FontWeight.bold)),
        ],
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