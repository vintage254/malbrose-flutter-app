import 'package:flutter/material.dart';
import 'package:my_flutter_app/const/constant.dart';
import 'package:my_flutter_app/models/invoice_model.dart';
import 'package:my_flutter_app/models/customer_model.dart';
import 'package:intl/intl.dart';
import 'package:my_flutter_app/models/order_model.dart';

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
              
              // Completed Orders Section
              if (invoice.completedItems != null && invoice.completedItems!.isNotEmpty)
                _buildOrdersSection('Completed Orders', invoice.completedItems!, invoice.completedAmount),
              
              // Pending Orders Section
              if (invoice.pendingItems != null && invoice.pendingItems!.isNotEmpty)
                _buildOrdersSection('Pending Orders', invoice.pendingItems!, invoice.pendingAmount),
              
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

  Widget _buildOrdersSection(String title, List<OrderItem> items, double sectionTotal) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
        const SizedBox(height: 8),
        Table(
          columnWidths: const {
            0: FlexColumnWidth(2),
            1: FlexColumnWidth(1),
            2: FlexColumnWidth(1),
            3: FlexColumnWidth(1),
          },
          border: TableBorder.all(color: Colors.grey.shade300),
          children: [
            const TableRow(
              decoration: BoxDecoration(color: Colors.grey),
              children: [
                TableCell(child: Padding(
                  padding: EdgeInsets.all(8.0),
                  child: Text('Product', style: TextStyle(fontWeight: FontWeight.bold)),
                )),
                TableCell(child: Padding(
                  padding: EdgeInsets.all(8.0),
                  child: Text('Quantity', style: TextStyle(fontWeight: FontWeight.bold)),
                )),
                TableCell(child: Padding(
                  padding: EdgeInsets.all(8.0),
                  child: Text('Price', style: TextStyle(fontWeight: FontWeight.bold)),
                )),
                TableCell(child: Padding(
                  padding: EdgeInsets.all(8.0),
                  child: Text('Total', style: TextStyle(fontWeight: FontWeight.bold)),
                )),
              ],
            ),
            ...items.map((item) => TableRow(
              children: [
                TableCell(child: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Text(item.displayName),
                )),
                TableCell(child: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Text(
                    '${item.quantity}${item.isSubUnit ? " ${item.subUnitName ?? 'pieces'}" : ""}'
                  ),
                )),
                TableCell(child: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Text('KSH ${item.effectivePrice.toStringAsFixed(2)}'),
                )),
                TableCell(child: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Text('KSH ${item.totalAmount.toStringAsFixed(2)}'),
                )),
              ],
            )).toList(),
          ],
        ),
        Align(
          alignment: Alignment.centerRight,
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: Text(
              'Subtotal: KSH ${sectionTotal.toStringAsFixed(2)}',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildItemRow(OrderItem item) {
    return ListTile(
      title: Text(item.displayName),
      subtitle: Text(
        '${item.quantity}${item.isSubUnit ? " ${item.subUnitName ?? 'pieces'}" : ""}'
      ),
      trailing: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text('KSH ${item.effectivePrice.toStringAsFixed(2)}'),
          Text('KSH ${item.totalAmount.toStringAsFixed(2)}'),
        ],
      ),
    );
  }
} 