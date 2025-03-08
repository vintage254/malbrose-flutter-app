import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:my_flutter_app/const/constant.dart';
import 'package:my_flutter_app/services/database.dart';
import 'package:my_flutter_app/widgets/side_menu_widget.dart';
import 'package:printing/printing.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

class SalesReportScreen extends StatefulWidget {
  const SalesReportScreen({super.key});

  @override
  State<SalesReportScreen> createState() => _SalesReportScreenState();
}

class _SalesReportScreenState extends State<SalesReportScreen> {
  List<Map<String, dynamic>> _salesData = [];
  Map<String, dynamic> _summary = {};
  bool _isLoading = false;
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
          const Expanded(
            flex: 1,
            child: SideMenuWidget(),
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
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Sales Report',
                              style: Theme.of(context).textTheme.titleLarge,
                            ),
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
                              ],
                            ),
                          ],
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

    return GridView.count(
      crossAxisCount: 3,
      shrinkWrap: true,
      crossAxisSpacing: defaultPadding,
      mainAxisSpacing: defaultPadding,
      childAspectRatio: 2,
      physics: const NeverScrollableScrollPhysics(),
      children: [
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
      ],
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
    
    return Card(
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          columns: const [
            DataColumn(label: Text('Date')),
            DataColumn(label: Text('Order #')),
            DataColumn(label: Text('Customer')),
            DataColumn(label: Text('Product')),
            DataColumn(label: Text('Quantity')),
            DataColumn(label: Text('Buying Price')),
            DataColumn(label: Text('Selling Price')),
            DataColumn(label: Text('Total')),
            DataColumn(label: Text('Profit')),
            DataColumn(label: Text('Margin %')),
          ],
          rows: salesByOrder.entries.expand((entry) {
            final orderItems = entry.value;
            // Use the first item for order-level information
            final firstItem = orderItems.first;
            
            return orderItems.map((sale) => _buildSaleRow(sale, isFirstInOrder: sale == firstItem)).toList();
          }).toList(),
        ),
      ),
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
        DataCell(Text('${quantity}${isSubUnit ? 
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
          children: [
            Icon(
              icon,
              size: 40,
              color: color,
            ),
            const SizedBox(height: 8),
            Text(
              title,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              value,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _printSalesReport() async {
    try {
      final pdf = pw.Document();
      
      // Create a PDF document
      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
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
                  _buildSummaryItem('Total Orders', '${(_summary['total_orders'] as num?)?.toString() ?? '0'}'),
                  _buildSummaryItem('Items Sold', '${(_summary['total_quantity'] as num?)?.toString() ?? '0'} units'),
                  _buildSummaryItem('Unique Customers', '${(_summary['unique_customers'] as num?)?.toString() ?? '0'}'),
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

      // Print the document
      await Printing.layoutPdf(
        onLayout: (format) async => pdf.save(),
        name: 'Sales Report - ${DateFormat('yyyy-MM-dd').format(_startDate)} to ${DateFormat('yyyy-MM-dd').format(_endDate)}',
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
      '${quantity}${isSubUnit ? ' ${sale['sub_unit_name'] ?? 'pieces'}' : ''}',
      'KSH ${buyingPrice.toStringAsFixed(2)}',
      'KSH ${effectivePrice.toStringAsFixed(2)}',
      'KSH ${total.toStringAsFixed(2)}',
      'KSH ${profit.toStringAsFixed(2)}',
      '${marginPercent.toStringAsFixed(1)}%',
    ];
  }
} 