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
  DateTime _startDate = DateTime.now().subtract(const Duration(days: 30));
  DateTime _endDate = DateTime.now();
  String _groupBy = 'day'; // 'day', 'month', 'year'
  bool _isLoading = false;
  List<Map<String, dynamic>> _reportData = [];
  Map<String, dynamic> _summary = {};

  @override
  void initState() {
    super.initState();
    _loadReport();
  }

  Future<void> _loadReport() async {
    setState(() => _isLoading = true);
    
    try {
      final reportData = await DatabaseService.instance.getSalesReport(
        startDate: _startDate,
        endDate: _endDate,
        groupBy: _groupBy,
      );
      
      final summary = await DatabaseService.instance.getSalesSummary(
        _startDate,
        _endDate,
      );

      if (mounted) {
        setState(() {
          _reportData = reportData;
          _summary = summary;
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error loading report: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Row(
        children: [
          const Expanded(flex: 1, child: SideMenuWidget()),
          Expanded(
            flex: 4,
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.amber.withOpacity(0.7),
                    Colors.orange.shade900,
                  ],
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.all(defaultPadding),
                    child: Row(
                      children: [
                        const Text(
                          'Sales Report',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        const Spacer(),
                        // Date Range Picker
                        TextButton.icon(
                          icon: const Icon(Icons.calendar_today, color: Colors.white),
                          label: Text(
                            '${DateFormat('MMM d, y').format(_startDate)} - ${DateFormat('MMM d, y').format(_endDate)}',
                            style: const TextStyle(color: Colors.white),
                          ),
                          onPressed: () async {
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
                              _loadReport();
                            }
                          },
                        ),
                        const SizedBox(width: defaultPadding),
                        // Group By Dropdown
                        DropdownButton<String>(
                          value: _groupBy,
                          dropdownColor: Colors.amber,
                          style: const TextStyle(color: Colors.white),
                          items: const [
                            DropdownMenuItem(value: 'day', child: Text('Daily')),
                            DropdownMenuItem(value: 'month', child: Text('Monthly')),
                            DropdownMenuItem(value: 'year', child: Text('Yearly')),
                          ],
                          onChanged: (value) {
                            if (value != null) {
                              setState(() => _groupBy = value);
                              _loadReport();
                            }
                          },
                        ),
                      ],
                    ),
                  ),
                  // Summary Cards
                  Padding(
                    padding: const EdgeInsets.all(defaultPadding),
                    child: Row(
                      children: [
                        _buildSummaryCard(
                          'Total Orders',
                          _summary['total_orders']?.toString() ?? '0',
                          Icons.shopping_cart,
                          Colors.blue,
                        ),
                        _buildSummaryCard(
                          'Total Buying Price',
                          'KSH ${NumberFormat('#,##0.00').format(_summary['total_cost'] ?? 0)}',
                          Icons.money,
                          Colors.orange,
                        ),
                        _buildSummaryCard(
                          'Total Selling Price',
                          'KSH ${NumberFormat('#,##0.00').format(_summary['total_sales'] ?? 0)}',
                          Icons.payments,
                          Colors.green,
                        ),
                        _buildSummaryCard(
                          'Total Profit',
                          'KSH ${NumberFormat('#,##0.00').format(_summary['total_profit'] ?? 0)}',
                          Icons.trending_up,
                          Colors.purple,
                        ),
                      ],
                    ),
                  ),
                  // Report Table
                  Expanded(
                    child: _isLoading
                        ? const Center(child: CircularProgressIndicator())
                        : SingleChildScrollView(
                            padding: const EdgeInsets.all(defaultPadding),
                            child: DataTable(
                              columns: const [
                                DataColumn(label: Text('Date')),
                                DataColumn(label: Text('Product')),
                                DataColumn(label: Text('Quantity')),
                                DataColumn(label: Text('Buying Price')),
                                DataColumn(label: Text('Selling Price')),
                                DataColumn(label: Text('Total Sales')),
                                DataColumn(label: Text('Total Cost')),
                                DataColumn(label: Text('Profit')),
                              ],
                              rows: _reportData.map((item) {
                                return DataRow(
                                  cells: [
                                    DataCell(Text(item['date'])),
                                    DataCell(Text(item['product_name'])),
                                    DataCell(Text('${item['total_quantity']} ${item['is_sub_unit'] == 1 ? (item['sub_unit_name'] ?? 'pieces') : 'units'}')),
                                    DataCell(Text('KSH ${NumberFormat('#,##0.00').format(item['buying_price'])}')),
                                    DataCell(Text('KSH ${NumberFormat('#,##0.00').format(item['selling_price'])}')),
                                    DataCell(Text('KSH ${NumberFormat('#,##0.00').format(item['total_sales'])}')),
                                    DataCell(Text('KSH ${NumberFormat('#,##0.00').format(item['total_cost'])}')),
                                    DataCell(Text('KSH ${NumberFormat('#,##0.00').format(item['profit'])}')),
                                  ],
                                );
                              }).toList(),
                            ),
                          ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCard(String title, String value, IconData icon, Color color) {
    return Expanded(
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(defaultPadding),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(icon, color: color),
                  const SizedBox(width: 8),
                  Text(title),
                ],
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
      ),
    );
  }
} 