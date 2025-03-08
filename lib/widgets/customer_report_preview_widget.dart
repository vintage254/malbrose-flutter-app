import 'package:flutter/material.dart';
import 'package:my_flutter_app/const/constant.dart';
import 'package:my_flutter_app/models/customer_report_model.dart';
import 'package:my_flutter_app/models/customer_model.dart';
import 'package:intl/intl.dart';
import 'package:my_flutter_app/models/order_model.dart';
import 'package:my_flutter_app/services/customer_report_service.dart';
import 'package:pdf/pdf.dart';
import 'package:printing/printing.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';

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
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Container(
        margin: const EdgeInsets.all(defaultPadding),
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(defaultPadding),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Customer Report Preview',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    Row(
                      children: [
                        ElevatedButton.icon(
                          icon: const Icon(Icons.download),
                          label: const Text('Download PDF'),
                          onPressed: () => downloadPdf(context),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton.icon(
                          onPressed: () async {
                            try {
                              await CustomerReportService.instance.generateAndPrintCustomerReport(report, customer, context);
                            } catch (e) {
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('Error printing report: $e')),
                                );
                              }
                            }
                          },
                          icon: const Icon(Icons.print),
                          label: const Text('Print'),
                        ),
                      ],
                    ),
                  ],
                ),
                const Divider(),
                
                // Report header information
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildInfoRow('Report Number:', report.reportNumber),
                      _buildInfoRow('Customer:', customer.name),
                      _buildInfoRow('Generated On:', DateFormat('MMM dd, yyyy').format(report.createdAt)),
                      
                      // Date range information
                      Builder(
                        builder: (context) {
                          if (report.startDate != null && report.endDate != null) {
                            return _buildInfoRow('Report Period:', 
                              '${DateFormat('MMM dd, yyyy').format(report.startDate!)} to ${DateFormat('MMM dd, yyyy').format(report.endDate!)}');
                          } else if (report.startDate != null) {
                            return _buildInfoRow('From:', DateFormat('MMM dd, yyyy').format(report.startDate!));
                          } else if (report.endDate != null) {
                            return _buildInfoRow('To:', DateFormat('MMM dd, yyyy').format(report.endDate!));
                          } else {
                            return const SizedBox.shrink();
                          }
                        },
                      ),
                    ],
                  ),
                ),
                
                const SizedBox(height: defaultPadding),
                
                // Completed Orders Section
                if (report.completedItems != null && report.completedItems!.isNotEmpty)
                  _buildOrdersSection('Completed Orders', report.completedItems!, report.completedAmount, Colors.green.shade100),
                
                // Pending Orders Section
                if (report.pendingItems != null && report.pendingItems!.isNotEmpty)
                  _buildOrdersSection('Pending Orders', report.pendingItems!, report.pendingAmount, Colors.orange.shade100),
                
                const SizedBox(height: defaultPadding),
                
                // Summary section
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.blue.shade200),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        'Completed Orders: KSH ${report.completedAmount.toStringAsFixed(2)}',
                        style: const TextStyle(
                          fontWeight: FontWeight.normal,
                          fontSize: 14,
                        ),
                      ),
                      Text(
                        'Pending Orders: KSH ${report.pendingAmount.toStringAsFixed(2)}',
                        style: const TextStyle(
                          fontWeight: FontWeight.normal,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Divider(),
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

  Widget _buildOrdersSection(String title, List<OrderItem> items, double sectionTotal, Color headerColor) {
    // Group items by order number
    final Map<String, List<OrderItem>> itemsByOrder = {};
    for (final item in items) {
      final orderNumber = item.orderNumber ?? 'Unknown';
      if (!itemsByOrder.containsKey(orderNumber)) {
        itemsByOrder[orderNumber] = [];
      }
      itemsByOrder[orderNumber]!.add(item);
    }
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(8),
          color: headerColor,
          child: Text(
            title,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
        ),
        const SizedBox(height: 8),
        ...itemsByOrder.entries.map((entry) {
          final orderNumber = entry.key;
          final orderItems = entry.value;
          final orderDate = orderItems.isNotEmpty && orderItems.first.orderDate != null
              ? DateFormat('MMM dd, yyyy').format(orderItems.first.orderDate!)
              : 'Unknown date';
          
          // Calculate order total
          final orderTotal = orderItems.fold<double>(
              0, (sum, item) => sum + item.totalAmount);
              
          return Card(
            margin: const EdgeInsets.only(bottom: 16),
            elevation: 2,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  color: Colors.grey.shade200,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          'Order #$orderNumber - $orderDate',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                      Text(
                        'Total: KSH ${orderTotal.toStringAsFixed(2)}',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: DataTable(
                    columns: const [
                      DataColumn(label: Text('Product', style: TextStyle(fontWeight: FontWeight.bold))),
                      DataColumn(label: Text('Quantity', style: TextStyle(fontWeight: FontWeight.bold))),
                      DataColumn(label: Text('Price', style: TextStyle(fontWeight: FontWeight.bold))),
                      DataColumn(label: Text('Total', style: TextStyle(fontWeight: FontWeight.bold))),
                      DataColumn(label: Text('Status', style: TextStyle(fontWeight: FontWeight.bold))),
                    ],
                    rows: orderItems.map((item) => DataRow(
                      cells: [
                        DataCell(Text(item.displayName)),
                        DataCell(Text(
                          '${item.quantity}${item.isSubUnit ? " ${item.subUnitName ?? 'pieces'}" : ""}'
                        )),
                        DataCell(Text('KSH ${item.effectivePrice.toStringAsFixed(2)}')),
                        DataCell(Text('KSH ${item.totalAmount.toStringAsFixed(2)}')),
                        DataCell(_buildStatusChip(title.contains('Completed') ? 'COMPLETED' : 'PENDING')),
                      ],
                    )).toList(),
                  ),
                ),
              ],
            ),
          );
        }).toList(),
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

  // Method to download the PDF report
  Future<void> downloadPdf(BuildContext context) async {
    try {
      // Show loading indicator
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Generating PDF...')),
      );
      
      // Generate the PDF
      final pdfBytes = await CustomerReportService.generateCustomerReportPdf(report, customer);
      
      // Get the downloads directory
      final directory = await getApplicationDocumentsDirectory();
      final filePath = '${directory.path}/customer_report_${report.reportNumber}.pdf';
      
      // Write the PDF to a file
      final file = File(filePath);
      await file.writeAsBytes(pdfBytes);
      
      // Show success message with the file path
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('PDF saved to: $filePath'),
            duration: const Duration(seconds: 5),
            action: SnackBarAction(
              label: 'Open',
              onPressed: () async {
                // Open the PDF file
                await Printing.sharePdf(bytes: pdfBytes, filename: 'customer_report_${report.reportNumber}.pdf');
              },
            ),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error generating PDF: $e')),
        );
      }
    }
  }
  
  Widget _buildStatusChip(String status) {
    Color color;
    switch (status.toUpperCase()) {
      case 'COMPLETED':
        color = Colors.green;
        break;
      case 'PENDING':
        color = Colors.orange;
        break;
      case 'CANCELLED':
        color = Colors.red;
        break;
      default:
        color = Colors.grey;
    }

    return Chip(
      label: Text(status),
      backgroundColor: color.withOpacity(0.2),
      labelStyle: TextStyle(color: color),
    );
  }
} 