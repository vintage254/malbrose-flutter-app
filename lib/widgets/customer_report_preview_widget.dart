import 'package:flutter/material.dart';
import 'package:my_flutter_app/const/constant.dart';
import 'package:my_flutter_app/models/customer_report_model.dart';
import 'package:my_flutter_app/models/customer_model.dart';
import 'package:intl/intl.dart';
import 'package:my_flutter_app/models/order_model.dart';

class CustomerReportPreviewWidget extends StatelessWidget {
  final CustomerReport report;
  final Customer customer;

  const CustomerReportPreviewWidget({
    super.key,
    required this.report,
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
                'Customer Report Preview',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const Divider(),
              _buildInfoRow('Report Number:', report.reportNumber),
              _buildInfoRow('Customer:', customer.name),
              _buildInfoRow('Date:', DateFormat('MMM dd, yyyy').format(report.createdAt)),
              if (report.dueDate != null)
                _buildInfoRow('Due Date:', DateFormat('MMM dd, yyyy').format(report.dueDate!)),
              _buildInfoRow('Status:', report.status),
              _buildInfoRow('Payment Status:', report.paymentStatus ?? 'N/A'),
              const SizedBox(height: defaultPadding),
              
              // Completed Orders Section
              if (report.completedItems != null && report.completedItems!.isNotEmpty)
                _buildOrdersSection('Completed Orders', report.completedItems!, report.completedAmount),
              
              // Pending Orders Section
              if (report.pendingItems != null && report.pendingItems!.isNotEmpty)
                _buildOrdersSection('Pending Orders', report.pendingItems!, report.pendingAmount),
              
              const SizedBox(height: defaultPadding),
              Align(
                alignment: Alignment.centerRight,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      'Total Amount: KSH ${report.totalAmount.toStringAsFixed(2)}',
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
                  child: Text(item.productName),
                )),
                TableCell(child: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Text('${item.quantity} ${item.isSubUnit ? item.subUnitName ?? "pieces" : "units"}'),
                )),
                TableCell(child: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Text('KSH ${item.adjustedPrice.toStringAsFixed(2)}'),
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
} 