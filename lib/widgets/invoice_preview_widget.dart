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
      child: SingleChildScrollView(
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
              const SizedBox(height: defaultPadding),
              if (invoice.items != null && invoice.items!.isNotEmpty) ...[
                const Text('Items:', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: defaultPadding / 2),
                Table(
                  columnWidths: const {
                    0: FlexColumnWidth(2),  // Product
                    1: FlexColumnWidth(1),  // Quantity
                    2: FlexColumnWidth(1),  // Price
                    3: FlexColumnWidth(1),  // Total
                  },
                  border: TableBorder.all(color: Colors.grey.shade300),
                  children: [
                    const TableRow(
                      decoration: BoxDecoration(
                        color: Colors.grey,
                      ),
                      children: [
                        TableCell(
                          child: Padding(
                            padding: EdgeInsets.all(8.0),
                            child: Text('Product', style: TextStyle(fontWeight: FontWeight.bold)),
                          ),
                        ),
                        TableCell(
                          child: Padding(
                            padding: EdgeInsets.all(8.0),
                            child: Text('Quantity', style: TextStyle(fontWeight: FontWeight.bold)),
                          ),
                        ),
                        TableCell(
                          child: Padding(
                            padding: EdgeInsets.all(8.0),
                            child: Text('Price', style: TextStyle(fontWeight: FontWeight.bold)),
                          ),
                        ),
                        TableCell(
                          child: Padding(
                            padding: EdgeInsets.all(8.0),
                            child: Text('Total', style: TextStyle(fontWeight: FontWeight.bold)),
                          ),
                        ),
                      ],
                    ),
                    ...invoice.items!.map((item) => TableRow(
                      children: [
                        TableCell(
                          child: Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: Text(item.productName),
                          ),
                        ),
                        TableCell(
                          child: Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: Text(
                              '${item.quantity} ${item.isSubUnit ? (item.subUnitName ?? "pieces") : "units"}'
                            ),
                          ),
                        ),
                        TableCell(
                          child: Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: Text('KSH ${item.adjustedPrice.toStringAsFixed(2)}'),
                          ),
                        ),
                        TableCell(
                          child: Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: Text('KSH ${item.totalAmount.toStringAsFixed(2)}'),
                          ),
                        ),
                      ],
                    )).toList(),
                  ],
                ),
              ],
              const SizedBox(height: defaultPadding),
              Align(
                alignment: Alignment.centerRight,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      'Total Amount: KSH ${invoice.totalAmount.toStringAsFixed(2)}',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
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