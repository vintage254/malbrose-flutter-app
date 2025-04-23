import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:my_flutter_app/const/constant.dart';
import 'package:my_flutter_app/services/database.dart';
import 'package:my_flutter_app/widgets/side_menu_widget.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:my_flutter_app/services/printer_service.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:io';
import 'package:excel/excel.dart' as xl;
import 'package:path/path.dart' as path;

class SalesReportScreen extends StatefulWidget {
  const SalesReportScreen({super.key});

  @override
  State<SalesReportScreen> createState() => _SalesReportScreenState();
}

class _SalesReportScreenState extends State<SalesReportScreen> {
  List<Map<String, dynamic>> _salesData = [];
  Map<String, dynamic> _summary = {};
  bool _isLoading = false;
  bool _isExporting = false;
  DateTime _startDate = DateTime.now().subtract(const Duration(days: 30));
  DateTime _endDate = DateTime.now();

  @override
  void initState() {
    super.initState();
    _loadSalesReport();
  }

  Future<void> _loadSalesReport() async {
    setState(() => _isLoading = true);
    try {
      final reportData = await DatabaseService.instance.getSalesReport(
        _startDate,
        _endDate,
      );
      final summary = await DatabaseService.instance.getSalesSummary(
        _startDate,
        _endDate,
      );

      setState(() {
        _salesData = reportData;
        _summary = summary;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading sales report: $e')),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _selectDateRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDateRange: DateTimeRange(
        start: _startDate,
        end: _endDate,
      ),
    );

    if (picked != null) {
      setState(() {
        _startDate = picked.start;
        _endDate = picked.end;
      });
      await _loadSalesReport();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Row(
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              return constraints.maxWidth < 600
                ? const SizedBox.shrink() // Hide on very small screens
                : const Expanded(
                    flex: 1,
                    child: SideMenuWidget(),
                  );
            }
          ),
          Expanded(
            flex: 4,
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : SingleChildScrollView(
                    padding: const EdgeInsets.all(defaultPadding),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          physics: const AlwaysScrollableScrollPhysics(),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Sales Report',
                                style: Theme.of(context).textTheme.titleLarge,
                              ),
                              const SizedBox(width: 16),
                              Row(
                                children: [
                                  TextButton.icon(
                                    icon: const Icon(Icons.calendar_today),
                                    label: Text(
                                      '${DateFormat('MMM dd, yyyy').format(_startDate)} - ${DateFormat('MMM dd, yyyy').format(_endDate)}',
                                    ),
                                    onPressed: _selectDateRange,
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.refresh),
                                    onPressed: _loadSalesReport,
                                  ),
                                  const SizedBox(width: 8),
                                  ElevatedButton.icon(
                                    onPressed: _printSalesReport,
                                    icon: const Icon(Icons.print),
                                    label: const Text('Print Report'),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.blue,
                                      foregroundColor: Colors.white,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  ElevatedButton.icon(
                                    onPressed: _isExporting ? null : _exportToExcel,
                                    icon: _isExporting 
                                      ? const SizedBox(
                                          width: 24,
                                          height: 24,
                                          child: CircularProgressIndicator(
                                            color: Colors.white,
                                            strokeWidth: 2,
                                          ),
                                        )
                                      : const Icon(Icons.file_download),
                                    label: const Text('Export to Excel'),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.green,
                                      foregroundColor: Colors.white,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: defaultPadding),
                        _buildSummaryCards(),
                        const SizedBox(height: defaultPadding),
                        _buildSalesTable(),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCards() {
    // Safe number conversions for summary data
    final totalSales = (_summary['total_sales'] as num?)?.toDouble() ?? 0.0;
    final totalCost = (_summary['total_buying_cost'] as num?)?.toDouble() ?? 0.0;
    final totalProfit = (_summary['total_profit'] as num?)?.toDouble() ?? 0.0;
    final totalOrders = (_summary['total_orders'] as num?)?.toInt() ?? 0;
    final totalQuantity = (_summary['total_quantity'] as num?)?.toInt() ?? 0;
    final uniqueCustomers = (_summary['unique_customers'] as num?)?.toInt() ?? 0;

    // Create all the summary cards
    final summaryCards = [
      _buildSummaryCard(
        'Total Sales',
        'KSH ${totalSales.toStringAsFixed(2)}',
        Colors.blue,
        Icons.shopping_cart,
      ),
      _buildSummaryCard(
        'Total Cost',
        'KSH ${totalCost.toStringAsFixed(2)}',
        Colors.orange,
        Icons.inventory_2,
      ),
      _buildSummaryCard(
        'Total Profit',
        'KSH ${totalProfit.toStringAsFixed(2)}',
        Colors.green,
        Icons.trending_up,
      ),
      _buildSummaryCard(
        'Total Orders',
        totalOrders.toString(),
        Colors.purple,
        Icons.receipt_long,
      ),
      _buildSummaryCard(
        'Items Sold',
        '$totalQuantity units',
        Colors.indigo,
        Icons.inventory,
      ),
      _buildSummaryCard(
        'Unique Customers',
        uniqueCustomers.toString(),
        Colors.teal,
        Icons.people,
      ),
    ];

    // Use a LayoutBuilder to detect available width
    return LayoutBuilder(
      builder: (context, constraints) {
        // For very small screens, use a scrollable row
        if (constraints.maxWidth < 600) {
          return SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            physics: const AlwaysScrollableScrollPhysics(),
            child: Row(
              children: summaryCards.map((card) => 
                SizedBox(width: 200, child: card)).toList(),
            ),
          );
        }
        
        // For medium screens, use 2 columns
        else if (constraints.maxWidth < 900) {
          return GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            crossAxisSpacing: defaultPadding,
            mainAxisSpacing: defaultPadding,
            childAspectRatio: 1.8,
            physics: const NeverScrollableScrollPhysics(),
            children: summaryCards,
          );
        }
        
        // For larger screens, use 3 columns
        else {
          return GridView.count(
            crossAxisCount: 3,
            shrinkWrap: true,
            crossAxisSpacing: defaultPadding,
            mainAxisSpacing: defaultPadding,
            childAspectRatio: 2.0,
            physics: const NeverScrollableScrollPhysics(),
            children: summaryCards,
          );
        }
      },
    );
  }

  Widget _buildSalesTable() {
    // Group sales data by order number to prevent duplicates
    final Map<String, List<Map<String, dynamic>>> salesByOrder = {};
    
    for (var sale in _salesData) {
      final orderNumber = sale['order_number'] as String;
      if (!salesByOrder.containsKey(orderNumber)) {
        salesByOrder[orderNumber] = [];
      }
      salesByOrder[orderNumber]!.add(sale);
    }
    
    return Column(
      children: [
        // Add indicator text for horizontal scrolling
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: const [
            Icon(Icons.swipe, color: Colors.grey),
            SizedBox(width: 4),
            Text("Swipe to see more columns", 
                 style: TextStyle(fontSize: 12, color: Colors.grey, fontStyle: FontStyle.italic)),
          ],
        ),
        const SizedBox(height: 4),
        // Wrap in container to set border and show it's a scrollable area
        Container(
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey.shade300),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Scrollbar(
            thickness: 8,
            radius: const Radius.circular(4),
            thumbVisibility: true,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                headingRowColor: MaterialStateProperty.all(Colors.grey.shade200),
                border: TableBorder.all(color: Colors.grey.shade300, width: 0.5),
                columnSpacing: 20,
                dataRowHeight: 56,
                columns: const [
                  DataColumn(label: Text('Date', style: TextStyle(fontWeight: FontWeight.bold))),
                  DataColumn(label: Text('Order #', style: TextStyle(fontWeight: FontWeight.bold))),
                  DataColumn(label: Text('Customer', style: TextStyle(fontWeight: FontWeight.bold))),
                  DataColumn(label: Text('Product', style: TextStyle(fontWeight: FontWeight.bold))),
                  DataColumn(label: Text('Quantity', style: TextStyle(fontWeight: FontWeight.bold))),
                  DataColumn(label: Text('Buying Price', style: TextStyle(fontWeight: FontWeight.bold))),
                  DataColumn(label: Text('Selling Price', style: TextStyle(fontWeight: FontWeight.bold))),
                  DataColumn(label: Text('Total', style: TextStyle(fontWeight: FontWeight.bold))),
                  DataColumn(label: Text('Profit', style: TextStyle(fontWeight: FontWeight.bold))),
                  DataColumn(label: Text('Margin %', style: TextStyle(fontWeight: FontWeight.bold))),
                ],
                rows: salesByOrder.entries.expand((entry) {
                  final orderItems = entry.value;
                  // Use the first item for order-level information
                  final firstItem = orderItems.first;
                  
                  return orderItems.map((sale) => _buildSaleRow(sale, isFirstInOrder: sale == firstItem)).toList();
                }).toList(),
              ),
            ),
          ),
        ),
      ],
    );
  }

  DataRow _buildSaleRow(Map<String, dynamic> sale, {bool isFirstInOrder = false}) {
    final isSubUnit = sale['is_sub_unit'] == 1;
    final subUnitQuantity = (sale['sub_unit_quantity'] as num?)?.toDouble();
    // Get the total amount from the database
    final totalAmount = (sale['total_amount'] as num?)?.toDouble() ?? 0.0;
    final quantity = (sale['quantity'] as num?)?.toInt() ?? 0;
    
    // Calculate the actual effective price per unit based on the total amount
    final effectivePrice = quantity > 0 ? totalAmount / quantity : 
                          (sale['effective_price'] as num?)?.toDouble() ?? 0.0;
    
    // Use buying_price instead of base_buying_price if that's what's in your data
    final buyingPrice = (sale['buying_price'] as num?)?.toDouble() ?? 0.0;

    // Use the total_amount from the database instead of calculating it
    final total = totalAmount;
    final cost = buyingPrice * quantity;
    final profit = total - cost;
    final marginPercent = cost > 0 ? (profit / cost * 100) : 0.0;

    return DataRow(
      cells: [
        // Only show date and order number for the first item in each order
        DataCell(Text(isFirstInOrder ? DateFormat('MMM dd, yyyy').format(
          DateTime.parse(sale['created_at'] as String? ?? DateTime.now().toIso8601String())) : '')),
        DataCell(Text(isFirstInOrder ? sale['order_number']?.toString() ?? '-' : '')),
        DataCell(Text(isFirstInOrder ? sale['customer_name']?.toString() ?? '-' : '')),
        DataCell(Text('${sale['product_name'] ?? 'Unknown'}${isSubUnit ? 
          ' (${sale['sub_unit_name'] ?? 'piece'})' : ''}')),
        DataCell(Text('$quantity${isSubUnit ? 
          ' ${sale['sub_unit_name'] ?? 'pieces'}' : ''}')),
        DataCell(Text('KSH ${buyingPrice.toStringAsFixed(2)}')),
        DataCell(Text('KSH ${effectivePrice.toStringAsFixed(2)}')),
        DataCell(Text('KSH ${total.toStringAsFixed(2)}')),
        DataCell(Text('KSH ${profit.toStringAsFixed(2)}',
          style: TextStyle(
            color: profit >= 0 ? Colors.green : Colors.red,
            fontWeight: FontWeight.bold
          ))),
        DataCell(Text('${marginPercent.toStringAsFixed(1)}%',
          style: TextStyle(
            color: marginPercent >= 20 ? Colors.green : 
                   marginPercent >= 10 ? Colors.orange : Colors.red
          ))),
      ],
    );
  }

  Widget _buildSummaryCard(String title, String value, Color color, IconData icon) {
    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(defaultPadding),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 32,
              color: color,
            ),
            const SizedBox(height: 8),
            Text(
              title,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                value,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _printSalesReport() async {
    try {
      // Get the printer service
      final printerService = PrinterService.instance;
      
      final pdf = pw.Document();
      
      // Create a PDF document
      pdf.addPage(
        pw.MultiPage(
          pageFormat: printerService.getPageFormat(),
          build: (context) {
            return [
              // Header
              pw.Center(
                child: pw.Text(
                  'Sales Report',
                  style: pw.TextStyle(
                    fontSize: 24,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
              ),
              pw.SizedBox(height: 10),
              pw.Center(
                child: pw.Text(
                  '${DateFormat('MMM dd, yyyy').format(_startDate)} - ${DateFormat('MMM dd, yyyy').format(_endDate)}',
                  style: pw.TextStyle(
                    fontSize: 16,
                  ),
                ),
              ),
              pw.SizedBox(height: 20),
              
              // Summary section
              pw.Text(
                'Summary',
                style: pw.TextStyle(
                  fontSize: 18,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 10),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  _buildSummaryItem('Total Sales', 'KSH ${(_summary['total_sales'] as num?)?.toStringAsFixed(2) ?? '0.00'}'),
                  _buildSummaryItem('Total Cost', 'KSH ${(_summary['total_buying_cost'] as num?)?.toStringAsFixed(2) ?? '0.00'}'),
                  _buildSummaryItem('Total Profit', 'KSH ${(_summary['total_profit'] as num?)?.toStringAsFixed(2) ?? '0.00'}'),
                ],
              ),
              pw.SizedBox(height: 10),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  _buildSummaryItem('Total Orders', (_summary['total_orders'] as num?)?.toString() ?? '0'),
                  _buildSummaryItem('Items Sold', '${(_summary['total_quantity'] as num?)?.toString() ?? '0'} units'),
                  _buildSummaryItem('Unique Customers', (_summary['unique_customers'] as num?)?.toString() ?? '0'),
                ],
              ),
              pw.SizedBox(height: 20),
              
              // Sales table
              pw.Text(
                'Sales Details',
                style: pw.TextStyle(
                  fontSize: 18,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 10),
              pw.Table.fromTextArray(
                context: context,
                headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                headerDecoration: pw.BoxDecoration(color: PdfColors.grey300),
                cellHeight: 30,
                headers: ['Date', 'Order #', 'Customer', 'Product', 'Quantity', 'Buying Price', 'Selling Price', 'Total', 'Profit', 'Margin %'],
                data: _buildPdfSalesData(),
                cellAlignments: {
                  0: pw.Alignment.centerLeft,
                  1: pw.Alignment.centerLeft,
                  2: pw.Alignment.centerLeft,
                  3: pw.Alignment.centerLeft,
                  4: pw.Alignment.centerRight,
                  5: pw.Alignment.centerRight,
                  6: pw.Alignment.centerRight,
                  7: pw.Alignment.centerRight,
                  8: pw.Alignment.centerRight,
                  9: pw.Alignment.centerRight,
                },
              ),
              
              // Footer
              pw.SizedBox(height: 20),
              pw.Text(
                'Generated on: ${DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now())}',
                style: pw.TextStyle(
                  fontSize: 10,
                  fontStyle: pw.FontStyle.italic,
                ),
              ),
            ];
          },
        ),
      );

      // Use the printer service to print the PDF
      await printerService.printPdf(
        pdf: pdf,
        documentName: 'Sales Report - ${DateFormat('yyyy-MM-dd').format(_startDate)} to ${DateFormat('yyyy-MM-dd').format(_endDate)}',
        context: context,
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error printing sales report: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
  
  pw.Widget _buildSummaryItem(String title, String value) {
    return pw.Container(
      width: 150,
      padding: const pw.EdgeInsets.all(10),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey300),
        borderRadius: pw.BorderRadius.circular(5),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            title,
            style: pw.TextStyle(
              fontSize: 12,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
          pw.SizedBox(height: 5),
          pw.Text(
            value,
            style: const pw.TextStyle(
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  List<List<String>> _buildPdfSalesData() {
    // Group sales data by order number to prevent duplicates
    final Map<String, List<Map<String, dynamic>>> salesByOrder = {};
    
    for (var sale in _salesData) {
      final orderNumber = sale['order_number'] as String;
      if (!salesByOrder.containsKey(orderNumber)) {
        salesByOrder[orderNumber] = [];
      }
      salesByOrder[orderNumber]!.add(sale);
    }
    
    return salesByOrder.entries.expand((entry) {
      final orderItems = entry.value;
      // Use the first item for order-level information
      final firstItem = orderItems.first;
      
      return orderItems.map((sale) => _buildPdfSaleRow(sale, isFirstInOrder: sale == firstItem)).toList();
    }).toList();
  }

  List<String> _buildPdfSaleRow(Map<String, dynamic> sale, {bool isFirstInOrder = false}) {
    final isSubUnit = sale['is_sub_unit'] == 1;
    final subUnitQuantity = (sale['sub_unit_quantity'] as num?)?.toDouble();
    // Get the total amount from the database
    final totalAmount = (sale['total_amount'] as num?)?.toDouble() ?? 0.0;
    final quantity = (sale['quantity'] as num?)?.toInt() ?? 0;
    
    // Calculate the actual effective price per unit based on the total amount
    final effectivePrice = quantity > 0 ? totalAmount / quantity : 
                          (sale['effective_price'] as num?)?.toDouble() ?? 0.0;
    
    // Use buying_price instead of base_buying_price if that's what's in your data
    final buyingPrice = (sale['buying_price'] as num?)?.toDouble() ?? 0.0;

    // Use the total_amount from the database instead of calculating it
    final total = totalAmount;
    final cost = buyingPrice * quantity;
    final profit = total - cost;
    final marginPercent = cost > 0 ? (profit / cost * 100) : 0.0;

    return [
      isFirstInOrder ? DateFormat('MMM dd, yyyy').format(DateTime.parse(sale['created_at'] as String? ?? DateTime.now().toIso8601String())) : '',
      isFirstInOrder ? sale['order_number']?.toString() ?? '-' : '',
      isFirstInOrder ? sale['customer_name']?.toString() ?? '-' : '',
      '${sale['product_name'] ?? 'Unknown'}${isSubUnit ? ' (${sale['sub_unit_name'] ?? 'piece'})' : ''}',
      '$quantity${isSubUnit ? ' ${sale['sub_unit_name'] ?? 'pieces'}' : ''}',
      'KSH ${buyingPrice.toStringAsFixed(2)}',
      'KSH ${effectivePrice.toStringAsFixed(2)}',
      'KSH ${total.toStringAsFixed(2)}',
      'KSH ${profit.toStringAsFixed(2)}',
      '${marginPercent.toStringAsFixed(1)}%',
    ];
  }
  
  Future<void> _exportToExcel() async {
    try {
      setState(() => _isExporting = true);
      
      // Show progress dialog
      if (mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => const AlertDialog(
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text('Generating Excel file...'),
              ],
            ),
          ),
        );
      }
      
      // Create Excel file
      final excel = xl.Excel.createExcel();
      final sheet = excel['Sales Report'];
      
      // Add title
      sheet.merge(xl.CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 0), 
                 xl.CellIndex.indexByColumnRow(columnIndex: 9, rowIndex: 0));
      final titleCell = sheet.cell(xl.CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 0));
      titleCell.value = xl.TextCellValue('Sales Report: ${DateFormat('MMM dd, yyyy').format(_startDate)} - ${DateFormat('MMM dd, yyyy').format(_endDate)}');
      titleCell.cellStyle = xl.CellStyle(
        bold: true,
        fontSize: 14,
        horizontalAlign: xl.HorizontalAlign.Center,
      );
      
      // Add summary section
      sheet.merge(xl.CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 2), 
                 xl.CellIndex.indexByColumnRow(columnIndex: 9, rowIndex: 2));
      final summaryTitleCell = sheet.cell(xl.CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 2));
      summaryTitleCell.value = xl.TextCellValue('Summary');
      summaryTitleCell.cellStyle = xl.CellStyle(
        bold: true,
        fontSize: 12,
      );
      
      // Add summary data
      final totalSales = (_summary['total_sales'] as num?)?.toDouble() ?? 0.0;
      final totalCost = (_summary['total_buying_cost'] as num?)?.toDouble() ?? 0.0;
      final totalProfit = (_summary['total_profit'] as num?)?.toDouble() ?? 0.0;
      final totalOrders = (_summary['total_orders'] as num?)?.toInt() ?? 0;
      final totalQuantity = (_summary['total_quantity'] as num?)?.toInt() ?? 0;
      final uniqueCustomers = (_summary['unique_customers'] as num?)?.toInt() ?? 0;
      
      sheet.cell(xl.CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 3)).value = xl.TextCellValue('Total Sales:');
      sheet.cell(xl.CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: 3)).value = xl.TextCellValue('KSH ${totalSales.toStringAsFixed(2)}');
      sheet.cell(xl.CellIndex.indexByColumnRow(columnIndex: 3, rowIndex: 3)).value = xl.TextCellValue('Total Cost:');
      sheet.cell(xl.CellIndex.indexByColumnRow(columnIndex: 4, rowIndex: 3)).value = xl.TextCellValue('KSH ${totalCost.toStringAsFixed(2)}');
      sheet.cell(xl.CellIndex.indexByColumnRow(columnIndex: 6, rowIndex: 3)).value = xl.TextCellValue('Total Profit:');
      sheet.cell(xl.CellIndex.indexByColumnRow(columnIndex: 7, rowIndex: 3)).value = xl.TextCellValue('KSH ${totalProfit.toStringAsFixed(2)}');
      
      sheet.cell(xl.CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 4)).value = xl.TextCellValue('Total Orders:');
      sheet.cell(xl.CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: 4)).value = xl.IntCellValue(totalOrders);
      sheet.cell(xl.CellIndex.indexByColumnRow(columnIndex: 3, rowIndex: 4)).value = xl.TextCellValue('Items Sold:');
      sheet.cell(xl.CellIndex.indexByColumnRow(columnIndex: 4, rowIndex: 4)).value = xl.TextCellValue('$totalQuantity units');
      sheet.cell(xl.CellIndex.indexByColumnRow(columnIndex: 6, rowIndex: 4)).value = xl.TextCellValue('Unique Customers:');
      sheet.cell(xl.CellIndex.indexByColumnRow(columnIndex: 7, rowIndex: 4)).value = xl.IntCellValue(uniqueCustomers);
      
      // Add sales details title
      sheet.merge(xl.CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 6), 
                 xl.CellIndex.indexByColumnRow(columnIndex: 9, rowIndex: 6));
      final detailsTitleCell = sheet.cell(xl.CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 6));
      detailsTitleCell.value = xl.TextCellValue('Sales Details');
      detailsTitleCell.cellStyle = xl.CellStyle(
        bold: true,
        fontSize: 12,
      );
      
      // Add headers
      final headers = ['Date', 'Order #', 'Customer', 'Product', 'Quantity', 'Buying Price', 'Selling Price', 'Total', 'Profit', 'Margin %'];
      for (var i = 0; i < headers.length; i++) {
        final cell = sheet.cell(xl.CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 7));
        cell.value = xl.TextCellValue(headers[i]);
        cell.cellStyle = xl.CellStyle(
          bold: true,
        );
      }
      
      // Group sales data by order number to prevent duplicates
      final Map<String, List<Map<String, dynamic>>> salesByOrder = {};
      
      for (var sale in _salesData) {
        final orderNumber = sale['order_number'] as String;
        if (!salesByOrder.containsKey(orderNumber)) {
          salesByOrder[orderNumber] = [];
        }
        salesByOrder[orderNumber]!.add(sale);
      }
      
      // Add sales data
      var rowIndex = 8;
      for (var entry in salesByOrder.entries) {
        final orderItems = entry.value;
        final firstItem = orderItems.first;
        
        for (var sale in orderItems) {
          final isFirstInOrder = sale == firstItem;
          final isSubUnit = sale['is_sub_unit'] == 1;
          final totalAmount = (sale['total_amount'] as num?)?.toDouble() ?? 0.0;
          final quantity = (sale['quantity'] as num?)?.toInt() ?? 0;
          final effectivePrice = quantity > 0 ? totalAmount / quantity : 
                                (sale['effective_price'] as num?)?.toDouble() ?? 0.0;
          final buyingPrice = (sale['buying_price'] as num?)?.toDouble() ?? 0.0;
          final total = totalAmount;
          final cost = buyingPrice * quantity;
          final profit = total - cost;
          final marginPercent = cost > 0 ? (profit / cost * 100) : 0.0;

          // Date
          sheet.cell(xl.CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: rowIndex)).value = 
            isFirstInOrder ? xl.TextCellValue(DateFormat('MMM dd, yyyy').format(DateTime.parse(sale['created_at'] as String? ?? DateTime.now().toIso8601String()))) : xl.TextCellValue('');
          
          // Order #
          sheet.cell(xl.CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: rowIndex)).value = 
            isFirstInOrder ? xl.TextCellValue(sale['order_number']?.toString() ?? '-') : xl.TextCellValue('');
          
          // Customer
          sheet.cell(xl.CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: rowIndex)).value = 
            isFirstInOrder ? xl.TextCellValue(sale['customer_name']?.toString() ?? '-') : xl.TextCellValue('');
          
          // Product
          sheet.cell(xl.CellIndex.indexByColumnRow(columnIndex: 3, rowIndex: rowIndex)).value = 
            xl.TextCellValue('${sale['product_name'] ?? 'Unknown'}${isSubUnit ? ' (${sale['sub_unit_name'] ?? 'piece'})' : ''}');
          
          // Quantity
          sheet.cell(xl.CellIndex.indexByColumnRow(columnIndex: 4, rowIndex: rowIndex)).value = 
            xl.TextCellValue('$quantity${isSubUnit ? ' ${sale['sub_unit_name'] ?? 'pieces'}' : ''}');
          
          // Buying Price
          sheet.cell(xl.CellIndex.indexByColumnRow(columnIndex: 5, rowIndex: rowIndex)).value = 
            xl.TextCellValue('KSH ${buyingPrice.toStringAsFixed(2)}');
          
          // Selling Price
          sheet.cell(xl.CellIndex.indexByColumnRow(columnIndex: 6, rowIndex: rowIndex)).value = 
            xl.TextCellValue('KSH ${effectivePrice.toStringAsFixed(2)}');
          
          // Total
          sheet.cell(xl.CellIndex.indexByColumnRow(columnIndex: 7, rowIndex: rowIndex)).value = 
            xl.TextCellValue('KSH ${total.toStringAsFixed(2)}');
          
          // Profit
          final profitCell = sheet.cell(xl.CellIndex.indexByColumnRow(columnIndex: 8, rowIndex: rowIndex));
          profitCell.value = xl.TextCellValue('KSH ${profit.toStringAsFixed(2)}');
          profitCell.cellStyle = xl.CellStyle(
            bold: profit >= 0,
          );
          
          // Margin %
          final marginCell = sheet.cell(xl.CellIndex.indexByColumnRow(columnIndex: 9, rowIndex: rowIndex));
          marginCell.value = xl.TextCellValue('${marginPercent.toStringAsFixed(1)}%');
          marginCell.cellStyle = xl.CellStyle(
            bold: marginPercent >= 20,
          );
          
          rowIndex++;
        }
      }
      
      // Auto-fit columns
      for (var i = 0; i < headers.length; i++) {
        sheet.setColumnAutoFit(i);
      }
      
      // Create a temporary file
      final tempDir = await Directory.systemTemp.createTemp('sales_report_');
      final dateStr = DateFormat('yyyy-MM-dd').format(_startDate);
      final endDateStr = DateFormat('yyyy-MM-dd').format(_endDate);
      final tempFilePath = path.join(tempDir.path, 'sales_report_${dateStr}_to_$endDateStr.xlsx');
      
      // Save the Excel file
      final fileBytes = excel.save();
      if (fileBytes != null) {
        final file = File(tempFilePath);
        await file.writeAsBytes(fileBytes);
      }
      
      // Close progress dialog
      if (mounted) {
        Navigator.of(context, rootNavigator: true).pop();
      }
      
      // Ask user for save location
      String? outputPath = await FilePicker.platform.saveFile(
        dialogTitle: 'Save Sales Report',
        fileName: 'sales_report_${dateStr}_to_$endDateStr.xlsx',
        allowedExtensions: ['xlsx'],
        type: FileType.custom,
      );
      
      if (outputPath == null) {
        // User canceled the picker
        setState(() => _isExporting = false);
        
        // Clean up temp directory
        await tempDir.delete(recursive: true);
        return;
      }
      
      // Ensure proper extension
      if (!outputPath.toLowerCase().endsWith('.xlsx')) {
        outputPath += '.xlsx';
      }
      
      // Copy the temp file to the chosen location
      final tempFile = File(tempFilePath);
      await tempFile.copy(outputPath);
      
      // Clean up temp directory
      await tempDir.delete(recursive: true);
      
      setState(() => _isExporting = false);
      
      // Show success message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Sales report exported to: $outputPath'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      // Close progress dialog if open
      if (mounted) {
        Navigator.of(context, rootNavigator: true).popUntil((route) => route.isFirst);
      }
      
      setState(() => _isExporting = false);
      
      // Show error message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error exporting sales report: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
} 