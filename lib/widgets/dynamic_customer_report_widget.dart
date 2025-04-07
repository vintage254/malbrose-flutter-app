import 'package:flutter/material.dart';
import 'package:my_flutter_app/const/constant.dart';
import 'package:my_flutter_app/models/customer_model.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'dart:io';
import 'package:my_flutter_app/services/printer_service.dart';
import 'package:file_picker/file_picker.dart';

class DynamicCustomerReportWidget extends StatelessWidget {
  final Customer customer;
  final List<Map<String, dynamic>> orders;
  final List<Map<String, dynamic>> orderItems;
  final DateTime? startDate;
  final DateTime? endDate;
  final double completedAmount;
  final double pendingAmount;
  final double totalAmount;

  const DynamicCustomerReportWidget({
    super.key,
    required this.customer,
    required this.orders,
    required this.orderItems,
    this.startDate,
    this.endDate,
    required this.completedAmount,
    required this.pendingAmount,
    required this.totalAmount,
  });

  @override
  Widget build(BuildContext context) {
    // Group order items by order ID with null safety
    final Map<int, List<Map<String, dynamic>>> itemsByOrder = {};
    for (final item in orderItems) {
      final orderId = item['order_id'] as int?;
      if (orderId == null) continue; // Skip items with null order ID
      
      if (!itemsByOrder.containsKey(orderId)) {
        itemsByOrder[orderId] = [];
      }
      itemsByOrder[orderId]!.add(item);
    }

    return Card(
      margin: const EdgeInsets.all(defaultPadding),
      child: SingleChildScrollView(
        scrollDirection: Axis.vertical,
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Padding(
            padding: const EdgeInsets.all(defaultPadding),
            child: SizedBox(
              width: MediaQuery.of(context).size.width * 0.9,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header with title and action buttons
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Customer Report',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(width: defaultPadding),
                        Row(
                          children: [
                            ElevatedButton.icon(
                              icon: const Icon(Icons.download),
                              label: const Text('Download PDF'),
                              onPressed: () => _generateAndDownloadPdf(context),
                            ),
                            const SizedBox(width: 8),
                            ElevatedButton.icon(
                              icon: const Icon(Icons.print),
                              label: const Text('Print'),
                              onPressed: () => _printReport(context),
                            ),
                          ],
                        ),
                      ],
                    ),
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
                        _buildInfoRow('Customer:', customer.name),
                        _buildInfoRow('Generated On:', DateFormat('MMM dd, yyyy').format(DateTime.now())),
                        
                        // Date range information
                        Builder(
                          builder: (context) {
                            if (startDate != null && endDate != null) {
                              return _buildInfoRow('Report Period:', 
                                '${DateFormat('MMM dd, yyyy').format(startDate!)} to ${DateFormat('MMM dd, yyyy').format(endDate!)}');
                            } else if (startDate != null) {
                              return _buildInfoRow('From:', DateFormat('MMM dd, yyyy').format(startDate!));
                            } else if (endDate != null) {
                              return _buildInfoRow('To:', DateFormat('MMM dd, yyyy').format(endDate!));
                            } else {
                              return const SizedBox.shrink();
                            }
                          },
                        ),
                      ],
                    ),
                  ),
                  
                  const SizedBox(height: defaultPadding),
                  
                  // Orders table
                  ConstrainedBox(
                    constraints: const BoxConstraints(
                      minWidth: 500,
                      maxHeight: 400,
                    ),
                    child: SingleChildScrollView(
                      scrollDirection: Axis.vertical,
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: DataTable(
                          horizontalMargin: 20,
                          columnSpacing: 30,
                          headingRowColor: WidgetStateProperty.all(Colors.grey.shade200),
                          columns: const [
                            DataColumn(label: Text('Order #')),
                            DataColumn(label: Text('Date')),
                            DataColumn(label: Text('Items')),
                            DataColumn(label: Text('Total Amount')),
                            DataColumn(label: Text('Status')),
                          ],
                          rows: orders.map((order) {
                            // Extract values with null safety
                            final orderId = order['id'] as int?;
                            if (orderId == null) {
                              // Skip orders with null ID
                              return DataRow(cells: [
                                DataCell(Text('ERROR')),
                                DataCell(Text('')),
                                DataCell(Text('')),
                                DataCell(Text('')),
                                DataCell(Text('INVALID DATA')),
                              ]);
                            }
                            
                            final orderItems = itemsByOrder[orderId] ?? [];
                            final orderNumber = order['order_number'] as String? ?? 'Unknown';
                            
                            DateTime orderDate;
                            try {
                              orderDate = DateTime.parse(order['created_at'] as String? ?? '');
                            } catch (e) {
                              // Use current date as fallback for invalid dates
                              orderDate = DateTime.now();
                              print('Error parsing order date: $e');
                            }
                            
                            final totalAmount = (order['total_amount'] as num?)?.toDouble() ?? 0.0;
                            final status = order['status'] as String? ?? 'UNKNOWN';
                            
                            return DataRow(
                              color: WidgetStateProperty.resolveWith<Color?>((Set<WidgetState> states) {
                                return status == 'COMPLETED' ? Colors.green.shade50 : Colors.orange.shade50;
                              }),
                              cells: [
                                DataCell(Text(orderNumber)),
                                DataCell(Text(DateFormat('MMM dd, yyyy').format(orderDate))),
                                DataCell(
                                  Text(orderItems.length.toString()),
                                  onTap: () => _showOrderItemsDialog(context, order, orderItems),
                                ),
                                DataCell(Text('KSH ${totalAmount.toStringAsFixed(2)}')),
                                DataCell(
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: status == 'COMPLETED' ? Colors.green : Colors.orange,
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Text(
                                      status,
                                      style: const TextStyle(color: Colors.white),
                                    ),
                                  ),
                                ),
                              ],
                            );
                          }).toList(),
                        ),
                      ),
                    ),
                  ),
                  
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
                          'Completed Orders: KSH ${completedAmount.toStringAsFixed(2)}',
                          style: const TextStyle(
                            fontWeight: FontWeight.normal,
                            fontSize: 14,
                          ),
                        ),
                        Text(
                          'Pending Orders: KSH ${pendingAmount.toStringAsFixed(2)}',
                          style: const TextStyle(
                            fontWeight: FontWeight.normal,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Divider(),
                        Text(
                          'Total Amount: KSH ${totalAmount.toStringAsFixed(2)}',
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

  void _showOrderItemsDialog(BuildContext context, Map<String, dynamic> order, List<Map<String, dynamic>> items) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Order #${order['order_number']}'),
        content: SizedBox(
          width: 600,
          height: 400,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Date: ${DateFormat('MMM dd, yyyy').format(DateTime.parse(order['created_at'] as String))}'),
                Text('Status: ${order['status']}'),
                const SizedBox(height: 16),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: DataTable(
                    columns: const [
                      DataColumn(label: Text('Product')),
                      DataColumn(label: Text('Quantity')),
                      DataColumn(label: Text('Unit Price')),
                      DataColumn(label: Text('Total')),
                    ],
                    rows: items.map((item) {
                      return DataRow(
                        cells: [
                          DataCell(Text(item['product_name'] as String? ?? 'Unknown')),
                          DataCell(Text(item['quantity']?.toString() ?? '0')),
                          DataCell(Text('KSH ${((item['selling_price'] as num?)?.toDouble() ?? 0.0).toStringAsFixed(2)}')),
                          DataCell(Text('KSH ${((item['total_amount'] as num?)?.toDouble() ?? 0.0).toStringAsFixed(2)}')),
                        ],
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Future<void> _generateAndDownloadPdf(BuildContext context) async {
    try {
      // Show loading indicator
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Generating PDF...')),
      );
      
      final pdf = await _generatePdf();
      
      // Generate the PDF bytes
      final pdfBytes = await pdf.save();
      
      // Ask user for save location
      String? outputPath = await FilePicker.platform.saveFile(
        dialogTitle: 'Choose where to save the Customer Report PDF',
        fileName: 'customer_report_${customer.id}_${DateFormat('yyyy-MM-dd').format(DateTime.now())}.pdf',
        allowedExtensions: ['pdf'],
        type: FileType.custom,
      );
      
      if (outputPath == null) {
        // User cancelled the picker
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Download cancelled'),
              backgroundColor: Colors.orange,
            ),
          );
        }
        return;
      }
      
      // Ensure .pdf extension
      if (!outputPath.toLowerCase().endsWith('.pdf')) {
        outputPath = '$outputPath.pdf';
      }
      
      // Write the PDF to the selected location
      final file = File(outputPath);
      await file.writeAsBytes(pdfBytes);
      
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('PDF saved to: $outputPath'),
            duration: const Duration(seconds: 5),
            action: SnackBarAction(
              label: 'Open',
              onPressed: () async {
                // Open the PDF file
                final fileName = outputPath != null ? outputPath.split('/').last : 'customer_report.pdf';
                await Printing.sharePdf(bytes: pdfBytes, filename: fileName);
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

  Future<void> _printReport(BuildContext context) async {
    try {
      // Get the printer service
      final printerService = PrinterService.instance;
      
      final pdf = await _generatePdf();
      
      // Use the printer service to print the PDF
      await printerService.printPdf(
        pdf: pdf,
        documentName: 'Customer Report - ${customer.id}',
        context: context,
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error printing report: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<pw.Document> _generatePdf() async {
    final pdf = pw.Document();
    
    // Group order items by order ID
    final Map<int, List<Map<String, dynamic>>> itemsByOrder = {};
    for (final item in orderItems) {
      final orderId = item['order_id'] as int;
      if (!itemsByOrder.containsKey(orderId)) {
        itemsByOrder[orderId] = [];
      }
      itemsByOrder[orderId]!.add(item);
    }
    
    // Completed and pending orders
    final completedOrders = orders.where((order) => order['status'] == 'COMPLETED').toList();
    final pendingOrders = orders.where((order) => order['status'] != 'COMPLETED').toList();
    
    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (pw.Context context) {
          return [
            // Header
            pw.Header(
              level: 0,
              child: pw.Text('Customer Report', style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold)),
            ),
            pw.SizedBox(height: 8),
            
            // Customer info
            pw.Container(
              padding: const pw.EdgeInsets.all(16),
              decoration: pw.BoxDecoration(
                color: PdfColors.grey200,
                borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  _buildPdfInfoRow('Customer:', customer.name),
                  _buildPdfInfoRow('Generated On:', DateFormat('MMM dd, yyyy').format(DateTime.now())),
                  
                  // Date range information
                  if (startDate != null && endDate != null)
                    _buildPdfInfoRow('Report Period:', 
                      '${DateFormat('MMM dd, yyyy').format(startDate!)} to ${DateFormat('MMM dd, yyyy').format(endDate!)}')
                  else if (startDate != null)
                    _buildPdfInfoRow('From:', DateFormat('MMM dd, yyyy').format(startDate!))
                  else if (endDate != null)
                    _buildPdfInfoRow('To:', DateFormat('MMM dd, yyyy').format(endDate!)),
                ],
              ),
            ),
            pw.SizedBox(height: 16),
            
            // Completed Orders Section
            if (completedOrders.isNotEmpty) ...[
              pw.Header(level: 1, text: 'Completed Orders'),
              pw.Table.fromTextArray(
                headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                headerDecoration: const pw.BoxDecoration(color: PdfColors.grey300),
                cellHeight: 30,
                cellAlignments: {
                  0: pw.Alignment.centerLeft,
                  1: pw.Alignment.centerLeft,
                  2: pw.Alignment.center,
                  3: pw.Alignment.centerRight,
                  4: pw.Alignment.center,
                },
                headers: ['Order #', 'Date', 'Items', 'Total Amount', 'Status'],
                data: completedOrders.map((order) {
                  final orderId = order['id'] as int;
                  final orderItems = itemsByOrder[orderId] ?? [];
                  final orderNumber = order['order_number'] as String;
                  final orderDate = DateTime.parse(order['created_at'] as String);
                  final totalAmount = (order['total_amount'] as num).toDouble();
                  
                  return [
                    orderNumber,
                    DateFormat('MMM dd, yyyy').format(orderDate),
                    orderItems.length.toString(),
                    'KSH ${totalAmount.toStringAsFixed(2)}',
                    'COMPLETED',
                  ];
                }).toList(),
              ),
              pw.SizedBox(height: 16),
            ],
            
            // Pending Orders Section
            if (pendingOrders.isNotEmpty) ...[
              pw.Header(level: 1, text: 'Pending Orders'),
              pw.Table.fromTextArray(
                headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                headerDecoration: const pw.BoxDecoration(color: PdfColors.grey300),
                cellHeight: 30,
                cellAlignments: {
                  0: pw.Alignment.centerLeft,
                  1: pw.Alignment.centerLeft,
                  2: pw.Alignment.center,
                  3: pw.Alignment.centerRight,
                  4: pw.Alignment.center,
                },
                headers: ['Order #', 'Date', 'Items', 'Total Amount', 'Status'],
                data: pendingOrders.map((order) {
                  final orderId = order['id'] as int;
                  final orderItems = itemsByOrder[orderId] ?? [];
                  final orderNumber = order['order_number'] as String;
                  final orderDate = DateTime.parse(order['created_at'] as String);
                  final totalAmount = (order['total_amount'] as num).toDouble();
                  final status = order['status'] as String;
                  
                  return [
                    orderNumber,
                    DateFormat('MMM dd, yyyy').format(orderDate),
                    orderItems.length.toString(),
                    'KSH ${totalAmount.toStringAsFixed(2)}',
                    status,
                  ];
                }).toList(),
              ),
              pw.SizedBox(height: 16),
            ],
            
            // Summary
            pw.Container(
              padding: const pw.EdgeInsets.all(16),
              decoration: pw.BoxDecoration(
                color: PdfColors.blue50,
                borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
                border: pw.Border.all(color: PdfColors.blue200),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.end,
                children: [
                  pw.Text('Completed Orders: KSH ${completedAmount.toStringAsFixed(2)}'),
                  pw.Text('Pending Orders: KSH ${pendingAmount.toStringAsFixed(2)}'),
                  pw.SizedBox(height: 8),
                  pw.Divider(),
                  pw.Text(
                    'Total Amount: KSH ${totalAmount.toStringAsFixed(2)}',
                    style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 16),
                  ),
                ],
              ),
            ),
          ];
        },
      ),
    );
    
    return pdf;
  }

  pw.Widget _buildPdfInfoRow(String label, String value) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 4.0),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Expanded(
            flex: 2,
            child: pw.Text(
              label, 
              style: pw.TextStyle(fontWeight: pw.FontWeight.bold)
            ),
          ),
          pw.SizedBox(width: 8),
          pw.Expanded(
            flex: 3,
            child: pw.Text(value),
          ),
        ],
      ),
    );
  }
} 