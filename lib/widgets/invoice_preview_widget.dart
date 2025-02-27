import 'package:flutter/material.dart';
import 'package:my_flutter_app/const/constant.dart';
import 'package:my_flutter_app/models/invoice_model.dart';
import 'package:my_flutter_app/models/customer_model.dart';
import 'package:intl/intl.dart';
import 'package:my_flutter_app/models/order_model.dart';

class InvoicePreviewWidget extends StatelessWidget {
  final Invoice invoice;
  final Customer customer;
  final VoidCallback? onPrint;
  final VoidCallback? onSave;
  final VoidCallback? onSend;

  const InvoicePreviewWidget({
    super.key,
    required this.invoice,
    required this.customer,
    this.onPrint,
    this.onSave,
    this.onSend,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.all(defaultPadding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(defaultPadding),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Invoice Preview',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.print),
                          onPressed: onPrint,
                          tooltip: 'Print Invoice',
                        ),
                        IconButton(
                          icon: const Icon(Icons.save),
                          onPressed: onSave,
                          tooltip: 'Save as PDF',
                        ),
                        IconButton(
                          icon: const Icon(Icons.send),
                          onPressed: onSend,
                          tooltip: 'Send Invoice',
                        ),
                      ],
                    ),
                  ],
                ),
                const Divider(),
                _buildInfoSection(),
                const SizedBox(height: defaultPadding),
                _buildStatusBadge(),
                const SizedBox(height: defaultPadding),
                
                if (invoice.hasCompletedItems) ...[
                  _buildSectionTitle('Completed Orders', Colors.green),
                  _buildOrdersTable(invoice.completedItems!, invoice.completedAmount),
                  const SizedBox(height: defaultPadding),
                ],
                
                if (invoice.hasPendingItems) ...[
                  _buildSectionTitle('Pending Orders', Colors.orange),
                  _buildOrdersTable(invoice.pendingItems!, invoice.pendingAmount),
                  const SizedBox(height: defaultPadding),
                ],
                
                _buildTotalSection(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoSection() {
    return Column(
      children: [
        _buildInfoRow('Report Number:', invoice.invoiceNumber),
        _buildInfoRow('Customer:', customer.name),
        _buildInfoRow('Date:', DateFormat('MMM dd, yyyy').format(invoice.createdAt)),
        if (invoice.dueDate != null)
          _buildInfoRow('Due Date:', DateFormat('MMM dd, yyyy').format(invoice.dueDate!)),
      ],
    );
  }

  Widget _buildStatusBadge() {
    final bool hasMixedStatus = invoice.hasCompletedItems && invoice.hasPendingItems;
    final Color statusColor = hasMixedStatus 
        ? Colors.blue 
        : invoice.hasCompletedItems 
            ? Colors.green 
            : Colors.orange;
    final String statusText = hasMixedStatus 
        ? 'MIXED STATUS' 
        : invoice.hasCompletedItems ? 'COMPLETED' : 'PENDING';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: statusColor.withOpacity(0.1),
        border: Border.all(color: statusColor),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(
        statusText,
        style: TextStyle(color: statusColor, fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _buildSectionTitle(String title, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: color,
        ),
      ),
    );
  }

  Widget _buildOrdersTable(List<OrderItem> items, double sectionTotal) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Table(
          columnWidths: const {
            0: FlexColumnWidth(3),
            1: FlexColumnWidth(2),
            2: FlexColumnWidth(2),
            3: FlexColumnWidth(2),
          },
          border: TableBorder.all(color: Colors.grey.shade300),
          children: [
            TableRow(
              decoration: BoxDecoration(color: Colors.grey.shade100),
              children: [
                _buildTableHeader('Product'),
                _buildTableHeader('Quantity'),
                _buildTableHeader('Unit Price'),
                _buildTableHeader('Total'),
              ],
            ),
            ...items.map((item) => _buildTableRow(item)).toList(),
          ],
        ),
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Text(
                'Subtotal: KSH ${sectionTotal.toStringAsFixed(2)}',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTableHeader(String text) {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Text(
        text,
        style: const TextStyle(fontWeight: FontWeight.bold),
      ),
    );
  }

  TableRow _buildTableRow(OrderItem item) {
    return TableRow(
      children: [
        _buildTableCell(item.displayName),
        _buildTableCell(
          '${item.quantity}${item.isSubUnit ? " ${item.subUnitName ?? 'pieces'}" : ""}'
        ),
        _buildTableCell('KSH ${item.effectivePrice.toStringAsFixed(2)}'),
        _buildTableCell('KSH ${item.totalAmount.toStringAsFixed(2)}'),
      ],
    );
  }

  Widget _buildTableCell(String text) {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Text(text),
    );
  }

  Widget _buildTotalSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (invoice.hasCompletedItems) 
            _buildTotalRow('Completed Orders Total:', invoice.completedAmount),
          if (invoice.hasPendingItems) 
            _buildTotalRow('Pending Orders Total:', invoice.pendingAmount),
          const SizedBox(height: 8),
          _buildTotalRow('Total Amount:', invoice.totalAmount, isTotal: true),
        ],
      ),
    );
  }

  Widget _buildTotalRow(String label, double amount, {bool isTotal = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Text(
            label,
            style: TextStyle(
              fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
              fontSize: isTotal ? 16 : 14,
            ),
          ),
          const SizedBox(width: 16),
          Text(
            'KSH ${amount.toStringAsFixed(2)}',
            style: TextStyle(
              fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
              fontSize: isTotal ? 16 : 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(
            child: Text(value),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusChip(Invoice invoice) {
    Color statusColor;
    String statusText = invoice.status;
    
    switch (invoice.status) {
      case 'COMPLETED':
        statusColor = Colors.green.shade700;
        break;
      case 'PARTIAL':
        statusColor = Colors.orange.shade700;
        break;
      case 'PENDING':
      default:
        statusColor = Colors.grey.shade700;
        break;
    }

    return Chip(
      label: Text(
        statusText,
        style: TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
        ),
      ),
      backgroundColor: statusColor,
    );
  }

  Widget _buildPaymentStatusChip(Invoice invoice) {
    Color statusColor;
    String statusText = invoice.paymentStatus;
    
    switch (invoice.paymentStatus) {
      case 'PAID':
        statusColor = Colors.green.shade700;
        break;
      case 'PARTIAL':
        statusColor = Colors.orange.shade700;
        break;
      case 'PENDING':
      default:
        statusColor = Colors.red.shade700;
        break;
    }

    return Chip(
      label: Text(
        statusText,
        style: TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
        ),
      ),
      backgroundColor: statusColor,
    );
  }
} 