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
import 'dart:typed_data';
import 'package:flutter/services.dart';
import 'package:my_flutter_app/services/config_service.dart';

class DynamicCustomerReportWidget extends StatelessWidget {
  final Customer customer;
  final List<Map<String, dynamic>> orders;
  final List<Map<String, dynamic>> orderItems;
  final List<Map<String, dynamic>> creditRecords;
  final DateTime? startDate;
  final DateTime? endDate;
  final double completedAmount;
  final double pendingAmount;
  final double totalAmount;
  final double outstandingCreditAmount;

  const DynamicCustomerReportWidget({
    Key? key,
    required this.customer,
    required this.orders,
    required this.orderItems,
    required this.creditRecords,
    this.startDate,
    this.endDate,
    required this.completedAmount,
    required this.pendingAmount,
    required this.totalAmount,
    required this.outstandingCreditAmount,
  }) : super(key: key);

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
      child: Padding(
        padding: const EdgeInsets.all(defaultPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with title and action buttons
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Customer Report',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
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
            
            // Orders and items in expandable panels
            Expanded(
              child: ListView(
                children: [
                  ...orders.map((order) {
                    // Extract values with null safety
                    final orderId = order['id'] as int?;
                    if (orderId == null) {
                      return const SizedBox.shrink(); // Skip orders with null ID
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
                    
                    // Use order_status with fallback to status for consistent behavior
                    final status = order['order_status'] as String? ?? 
                                order['status'] as String? ?? 
                                'UNKNOWN';
                    
                    final totalAmount = (order['total_amount'] as num?)?.toDouble() ?? 0.0;
                    
                    return Card(
                      margin: const EdgeInsets.only(bottom: 16),
                      elevation: 2,
                      color: status == 'COMPLETED' ? Colors.green.shade50 : Colors.orange.shade50,
                      child: ExpansionTile(
                        initiallyExpanded: true, // Show order details by default
                        title: Text('Order #$orderNumber - ${DateFormat('MMM dd, yyyy').format(orderDate)}'),
                        subtitle: Row(
                          children: [
                            Text('Total: KSH ${totalAmount.toStringAsFixed(2)}'),
                            const SizedBox(width: 16),
                            _buildStatusChip(status),
                          ],
                        ),
                        children: [
                          Container(
                            width: double.infinity,
                            constraints: BoxConstraints(
                              minWidth: MediaQuery.of(context).size.width * 0.9,
                            ),
                            child: SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              physics: const AlwaysScrollableScrollPhysics(),
                              child: DataTable(
                                columnSpacing: 24,
                                horizontalMargin: 12,
                                columns: const [
                                  DataColumn(label: Text('Product')),
                                  DataColumn(label: Text('Quantity')),
                                  DataColumn(label: Text('Unit Price')),
                                  DataColumn(label: Text('Total')),
                                ],
                                rows: orderItems.map((item) {
                                  final isSubUnit = (item['is_sub_unit'] as int?) == 1;
                                  final subUnitName = item['sub_unit_name'] as String?;
                                  
                                  return DataRow(
                                    cells: [
                                      DataCell(Text(item['product_name'] as String? ?? 'Unknown')),
                                      DataCell(Text(
                                        '${item['quantity']?.toString() ?? '0'}${isSubUnit ? " ${subUnitName ?? 'pcs'}" : ""}'
                                      )),
                                      DataCell(Text('KSH ${((item['selling_price'] as num?)?.toDouble() ?? 0.0).toStringAsFixed(2)}')),
                                      DataCell(Text('KSH ${((item['total_amount'] as num?)?.toDouble() ?? 0.0).toStringAsFixed(2)}')),
                                    ],
                                  );
                                }).toList(),
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                  
                  // Summary section
                  Container(
                    padding: const EdgeInsets.all(16),
                    margin: const EdgeInsets.only(top: 16),
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
                        Text(
                          'Outstanding Credit: KSH ${outstandingCreditAmount.toStringAsFixed(2)}',
                          style: const TextStyle(
                            fontWeight: FontWeight.normal,
                            fontSize: 14,
                            color: Colors.red,
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
                  
                  // Credit Records Section
                  if (creditRecords.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.all(16),
                      margin: const EdgeInsets.only(top: 16),
                      decoration: BoxDecoration(
                        color: Colors.red.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.red.shade200),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Credit Records',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const SizedBox(height: 12),
                          SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            physics: const AlwaysScrollableScrollPhysics(),
                            child: DataTable(
                              columnSpacing: 24,
                              horizontalMargin: 12,
                              columns: const [
                                DataColumn(label: Text('Date')),
                                DataColumn(label: Text('Order #')),
                                DataColumn(label: Text('Amount')),
                                DataColumn(label: Text('Status')),
                                DataColumn(label: Text('Notes')),
                              ],
                              rows: creditRecords.map((record) {
                                final amount = (record['amount'] as num?)?.toDouble() ?? 0.0;
                                final date = record['created_at'] != null 
                                    ? DateFormat('MMM dd, yyyy').format(DateTime.parse(record['created_at'] as String))
                                    : 'Unknown';
                                final status = record['status'] as String? ?? 'PENDING';
                                
                                return DataRow(
                                  cells: [
                                    DataCell(Text(date)),
                                    DataCell(Text(record['order_number'] as String? ?? '${record['id'] ?? "Unknown"}')),
                                    DataCell(Text('KSH ${amount.toStringAsFixed(2)}')),
                                    DataCell(
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: status == 'PAID' ? Colors.green.shade100 : Colors.red.shade100,
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        child: Text(
                                          status,
                                          style: TextStyle(
                                            color: status == 'PAID' ? Colors.green.shade800 : Colors.red.shade800,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      )
                                    ),
                                    DataCell(Text(record['notes'] as String? ?? '')),
                                  ],
                                );
                              }).toList(),
                            ),
                          ),
                          const SizedBox(height: 8),
                          const Divider(),
                          Align(
                            alignment: Alignment.centerRight,
                            child: Text(
                              'Total Outstanding Credit: KSH ${outstandingCreditAmount.toStringAsFixed(2)}',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                                color: Colors.red,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
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
      padding: const EdgeInsets.all(4),
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
    final config = ConfigService.instance;
    
    // Group order items by order ID
    final Map<int, List<Map<String, dynamic>>> itemsByOrder = {};
    for (final item in orderItems) {
      final orderId = item['order_id'] as int?;
      if (orderId == null) continue;
      
      if (!itemsByOrder.containsKey(orderId)) {
        itemsByOrder[orderId] = [];
      }
      itemsByOrder[orderId]!.add(item);
    }
    
    // Completed and pending orders - prioritize order_status over status (deprecated)
    final completedOrders = orders.where((order) {
      final status = order['order_status'] as String? ?? 
                    order['status'] as String? ?? 
                    'UNKNOWN';
      return status == 'COMPLETED';
    }).toList();
    
    final pendingOrders = orders.where((order) {
      final status = order['order_status'] as String? ?? 
                    order['status'] as String? ?? 
                    'UNKNOWN';
      return status != 'COMPLETED';
    }).toList();
    
    // Try to load business logo if available
    pw.ImageProvider? logoImage;
    if (config.businessLogo != null && config.businessLogo.isNotEmpty) {
      try {
        final logoFile = File(config.businessLogo);
        if (await logoFile.exists()) {
          final logoBytes = await logoFile.readAsBytes();
          logoImage = pw.MemoryImage(logoBytes);
        }
      } catch (e) {
        print('Error loading logo: $e');
      }
    }
    
    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (pw.Context context) {
          return [
            // Business Header with logo
            pw.Header(
              level: 0,
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        config.businessName,
                        style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold),
                      ),
                      pw.SizedBox(height: 4),
                      pw.Text(config.businessAddress),
                      pw.Text('Tel: ${config.businessPhone}'),
                      pw.Text('Email: ${config.businessEmail}'),
                    ],
                  ),
                  if (logoImage != null)
                    pw.Container(
                      height: 60,
                      width: 60,
                      child: pw.Image(logoImage),
                    ),
                ],
              ),
            ),
            
            pw.SizedBox(height: 20),
            
            // Report Title
            pw.Center(
              child: pw.Text(
                'Customer Report',
                style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold),
              ),
            ),
            
            pw.SizedBox(height: 16),
            
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
                  final orderId = order['id'] as int?;
                  if (orderId == null) return ['', '', '', '', ''];
                  
                  final orderItems = itemsByOrder[orderId] ?? [];
                  final orderNumber = order['order_number'] as String? ?? 'Unknown';
                  final orderDate = DateTime.parse(order['created_at'] as String? ?? DateTime.now().toIso8601String());
                  final totalAmount = (order['total_amount'] as num?)?.toDouble() ?? 0.0;
                  
                  return [
                    orderNumber,
                    DateFormat('MMM dd, yyyy').format(orderDate),
                    orderItems.length.toString(),
                    'KSH ${totalAmount.toStringAsFixed(2)}',
                    'COMPLETED',
                  ];
                }).toList(),
              ),
              
              // Add detailed order items for each completed order
              for (final order in completedOrders) ...[
                pw.SizedBox(height: 8),
                _buildOrderItemsDetail(order, itemsByOrder),
                pw.SizedBox(height: 16),
              ],
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
                  final orderId = order['id'] as int?;
                  if (orderId == null) return ['', '', '', '', ''];
                  
                  final orderItems = itemsByOrder[orderId] ?? [];
                  final orderNumber = order['order_number'] as String? ?? 'Unknown';
                  final orderDate = DateTime.parse(order['created_at'] as String? ?? DateTime.now().toIso8601String());
                  final totalAmount = (order['total_amount'] as num?)?.toDouble() ?? 0.0;
                  final status = order['order_status'] as String? ?? order['status'] as String? ?? 'UNKNOWN';
                  
                  return [
                    orderNumber,
                    DateFormat('MMM dd, yyyy').format(orderDate),
                    orderItems.length.toString(),
                    'KSH ${totalAmount.toStringAsFixed(2)}',
                    status,
                  ];
                }).toList(),
              ),
              
              // Add detailed order items for each pending order
              for (final order in pendingOrders) ...[
                pw.SizedBox(height: 8),
                _buildOrderItemsDetail(order, itemsByOrder),
                pw.SizedBox(height: 16),
              ],
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
                  pw.Text('Outstanding Credit: KSH ${outstandingCreditAmount.toStringAsFixed(2)}', 
                      style: const pw.TextStyle(color: PdfColors.red)),
                  pw.SizedBox(height: 8),
                  pw.Divider(),
                  pw.Text(
                    'Total Amount: KSH ${totalAmount.toStringAsFixed(2)}',
                    style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 16),
                  ),
                ],
              ),
            ),
            
            // Credit Records Section
            if (creditRecords.isNotEmpty) ...[
              pw.SizedBox(height: 20),
              pw.Header(level: 1, text: 'Credit Records'),
              pw.Container(
                padding: const pw.EdgeInsets.all(16),
                decoration: pw.BoxDecoration(
                  color: PdfColors.red50,
                  borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
                  border: pw.Border.all(color: PdfColors.red200),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Table.fromTextArray(
                      headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                      headerDecoration: const pw.BoxDecoration(color: PdfColors.red100),
                      cellHeight: 30,
                      cellAlignments: {
                        0: pw.Alignment.centerLeft,
                        1: pw.Alignment.centerLeft,
                        2: pw.Alignment.centerRight,
                        3: pw.Alignment.center,
                        4: pw.Alignment.centerLeft,
                      },
                      headers: ['Date', 'Order #', 'Amount', 'Status', 'Notes'],
                      data: creditRecords.map((record) {
                        final amount = (record['amount'] as num?)?.toDouble() ?? 0.0;
                        final date = record['created_at'] != null 
                            ? DateFormat('MMM dd, yyyy').format(DateTime.parse(record['created_at'] as String))
                            : 'Unknown';
                        final status = record['status'] as String? ?? 'PENDING';
                        
                        return [
                          date,
                          record['order_number'] as String? ?? '${record['id'] ?? "Unknown"}',
                          'KSH ${amount.toStringAsFixed(2)}',
                          status,
                          record['notes'] as String? ?? '',
                        ];
                      }).toList(),
                    ),
                    pw.SizedBox(height: 12),
                    pw.Divider(),
                    pw.Align(
                      alignment: pw.Alignment.centerRight,
                      child: pw.Text(
                        'Total Outstanding Credit: KSH ${outstandingCreditAmount.toStringAsFixed(2)}',
                        style: pw.TextStyle(
                          fontWeight: pw.FontWeight.bold,
                          fontSize: 14,
                          color: PdfColors.red,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            
            // Footer with business info
            pw.Footer(
              title: pw.Text(
                config.receiptFooter,
                textAlign: pw.TextAlign.center,
                style: const pw.TextStyle(fontSize: 10),
              ),
            ),
          ];
        },
      ),
    );
    
    return pdf;
  }

  pw.Widget _buildOrderItemsDetail(Map<String, dynamic> order, Map<int, List<Map<String, dynamic>>> itemsByOrder) {
    final orderId = order['id'] as int?;
    if (orderId == null) return pw.Container();
    
    final orderItems = itemsByOrder[orderId] ?? [];
    if (orderItems.isEmpty) return pw.Container();
    
    final orderNumber = order['order_number'] as String? ?? 'Unknown';
    
    return pw.Container(
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey300),
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Container(
            padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: const pw.BoxDecoration(
              color: PdfColors.grey200,
              borderRadius: pw.BorderRadius.only(
                topLeft: pw.Radius.circular(4),
                topRight: pw.Radius.circular(4),
              ),
            ),
            child: pw.Text(
              'Items for Order #$orderNumber',
              style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
            ),
          ),
          pw.Table.fromTextArray(
            headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10),
            cellStyle: const pw.TextStyle(fontSize: 9),
            headerDecoration: const pw.BoxDecoration(color: PdfColors.grey100),
            cellHeight: 20,
            cellAlignments: {
              0: pw.Alignment.centerLeft,
              1: pw.Alignment.center,
              2: pw.Alignment.centerRight,
              3: pw.Alignment.centerRight,
            },
            headers: ['Product', 'Quantity', 'Unit Price', 'Total'],
            data: orderItems.map((item) {
              final isSubUnit = (item['is_sub_unit'] as int?) == 1;
              final subUnitName = item['sub_unit_name'] as String?;
              final quantity = item['quantity']?.toString() ?? '0';
              final unitDisplay = isSubUnit ? '$quantity ${subUnitName ?? "pieces"}' : quantity;
              final unitPrice = ((item['selling_price'] as num?)?.toDouble() ?? 0.0).toStringAsFixed(2);
              final totalAmount = ((item['total_amount'] as num?)?.toDouble() ?? 0.0).toStringAsFixed(2);
              
              return [
                item['product_name'] as String? ?? 'Unknown',
                unitDisplay,
                'KSH $unitPrice',
                'KSH $totalAmount',
              ];
            }).toList(),
          ),
        ],
      ),
    );
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