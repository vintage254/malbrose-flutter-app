import 'package:flutter/material.dart';
import 'package:my_flutter_app/const/constant.dart';
import 'package:my_flutter_app/models/invoice_model.dart';
import 'package:my_flutter_app/models/customer_model.dart';
import 'package:intl/intl.dart';

class InvoicePreviewWidget extends StatelessWidget {
  final Invoice invoice;
  final Customer customer;

  const InvoicePreviewWidget({
    super.key,
    required this.invoice,
    required this.customer,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.all(defaultPadding),
      child: Padding(
        padding: const EdgeInsets.all(defaultPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Invoice Preview',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const Divider(),
            _buildInfoRow('Invoice Number:', invoice.invoiceNumber),
            _buildInfoRow('Customer:', customer.name),
            _buildInfoRow('Date:', DateFormat('MMM dd, yyyy').format(invoice.createdAt)),
            if (invoice.dueDate != null)
              _buildInfoRow('Due Date:', DateFormat('MMM dd, yyyy').format(invoice.dueDate!)),
            _buildInfoRow('Status:', invoice.status),
            _buildInfoRow('Total Amount:', 'KSH ${invoice.totalAmount.toStringAsFixed(2)}'),
            const SizedBox(height: defaultPadding),
            if (invoice.items != null) ...[
              const Text('Items:', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: defaultPadding / 2),
              ListView.builder(
                shrinkWrap: true,
                itemCount: invoice.items!.length,
                itemBuilder: (context, index) {
                  final item = invoice.items![index];
                  return ListTile(
                    title: Text('Order #${item.orderId}'),
                    trailing: Text('KSH ${item.total.toStringAsFixed(2)}'),
                  );
                },
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Flexible(
            flex: 2,
            child: Text(
              label, 
              style: const TextStyle(fontWeight: FontWeight.bold)
            ),
          ),
          const SizedBox(width: 8),
          Flexible(
            flex: 3,
            child: Text(
              value,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
} 