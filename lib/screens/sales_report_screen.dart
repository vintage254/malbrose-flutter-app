import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:my_flutter_app/const/constant.dart';
import 'package:my_flutter_app/services/database.dart';
import 'package:my_flutter_app/widgets/side_menu_widget.dart';

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
          rows: _salesData.map(_buildSaleRow).toList(),
        ),
      ),
    );
  }

  DataRow _buildSaleRow(Map<String, dynamic> sale) {
    final isSubUnit = sale['is_sub_unit'] == 1;
    final subUnitQuantity = (sale['sub_unit_quantity'] as num?)?.toDouble();
    final effectivePrice = (sale['effective_price'] as num).toDouble();
    final baseBuyingPrice = (sale['base_buying_price'] as num).toDouble();
    final quantity = (sale['quantity'] as num).toInt();

    final buyingPrice = isSubUnit && subUnitQuantity != null ? 
        baseBuyingPrice / subUnitQuantity : 
        baseBuyingPrice;

    final total = effectivePrice * quantity;
    final profit = (effectivePrice - buyingPrice) * quantity;
    final marginPercentage = buyingPrice > 0 ? 
        ((effectivePrice - buyingPrice) / buyingPrice * 100) : 
        0.0;

    return DataRow(
      cells: [
        DataCell(Text(DateFormat('MMM dd, yyyy').format(
          DateTime.parse(sale['created_at'] as String)))),
        DataCell(Text(sale['order_number']?.toString() ?? '-')),
        DataCell(Text(sale['customer_name']?.toString() ?? '-')),
        DataCell(Text('${sale['product_name']}${isSubUnit ? 
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
        DataCell(Text('${marginPercentage.toStringAsFixed(1)}%',
          style: TextStyle(
            color: marginPercentage >= 20 ? Colors.green : 
                   marginPercentage >= 10 ? Colors.orange : Colors.red
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
} 