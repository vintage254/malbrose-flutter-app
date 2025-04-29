import 'package:flutter/material.dart';
import 'package:my_flutter_app/const/constant.dart';
import 'package:my_flutter_app/models/customer_model.dart';
import 'package:my_flutter_app/services/database.dart';
import 'package:my_flutter_app/widgets/side_menu_widget.dart';
import 'package:intl/intl.dart';
import 'package:my_flutter_app/widgets/dynamic_customer_report_widget.dart';
import 'dart:async';

class CustomerReportsScreen extends StatefulWidget {
  const CustomerReportsScreen({super.key});

  @override
  State<CustomerReportsScreen> createState() => _CustomerReportsScreenState();
}

class _CustomerReportsScreenState extends State<CustomerReportsScreen> {
  final TextEditingController _searchController = TextEditingController();
  DateTime? _startDate;
  DateTime? _endDate;
  Customer? _selectedCustomer;
  bool _isLoading = false;
  List<Customer> _customers = [];
  List<Map<String, dynamic>> _orders = [];
  List<Map<String, dynamic>> _orderItems = [];
  List<Map<String, dynamic>> _creditRecords = [];
  Timer? _debounceTimer;
  String _searchQuery = '';
  bool _reportGenerated = false;
  double _completedAmount = 0.0;
  double _pendingAmount = 0.0;
  double _totalAmount = 0.0;
  double _outstandingCreditAmount = 0.0;

  @override
  void initState() {
    super.initState();
    _loadCustomers();
    
    // Set default date range to last 30 days
    _endDate = DateTime.now();
    _startDate = _endDate!.subtract(const Duration(days: 30));
  }

  @override
  void dispose() {
    _searchController.dispose();
    _debounceTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadCustomers() async {
    setState(() => _isLoading = true);
    try {
      final customersWithOrdersData = await DatabaseService.instance.getCustomersWithOrderCounts();
      
      if (mounted) {
        setState(() {
          _customers = customersWithOrdersData
              .map((map) => Customer.fromMap(map))
              .where((customer) => customer.name
                  .toLowerCase()
                  .contains(_searchQuery.toLowerCase()))
              .toList();
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading customers with order counts: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _loadCustomerOrders() async {
    if (_selectedCustomer == null || _selectedCustomer?.id == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a valid customer first')),
      );
      return;
    }
    
    setState(() {
      _isLoading = true;
      _reportGenerated = false;
      _orders = [];
      _orderItems = [];
      _creditRecords = [];
      _outstandingCreditAmount = 0.0;
    });
    
    try {
      // Format date strings for SQL query if dates are selected
      String? startDateStr, endDateStr;
      if (_startDate != null) {
        startDateStr = DateFormat('yyyy-MM-dd').format(_startDate!);
      }
      if (_endDate != null) {
        // Add one day to include the end date fully
        final nextDay = _endDate!.add(const Duration(days: 1));
        endDateStr = DateFormat('yyyy-MM-dd').format(nextDay);
      }
      
      // Get orders AND their items in a single optimized query
      final result = await DatabaseService.instance.getCustomerOrdersWithItems(
        _selectedCustomer!.id!,
        startDate: startDateStr,
        endDate: endDateStr,
      );
      
      final orders = result['orders'] as List<Map<String, dynamic>>;
      final orderItems = result['orderItems'] as List<Map<String, dynamic>>;
      
      // Get customer's credit information
      final outstandingCredit = await DatabaseService.instance.getCustomerTotalOutstandingBalance(_selectedCustomer!.id!);
      
      // Get detailed credit records
      final creditRecords = await DatabaseService.instance.getCreditOrdersByCustomer(_selectedCustomer!.name);
      
      double completedAmount = 0.0;
      double pendingAmount = 0.0;
      
      // Process orders with the correct status field
      for (final order in orders) {
        // Use order_status with fallback to status for consistent behavior
        final orderStatus = order['order_status'] as String? ?? 
                          order['status'] as String? ?? 
                          'UNKNOWN';
        
        // Calculate totals based on the consistent status
        final orderTotal = ((order['total_amount'] as num?) ?? 0).toDouble();
        if (orderStatus == 'COMPLETED') {
          completedAmount += orderTotal;
        } else {
          pendingAmount += orderTotal;
        }
      }
      
      if (mounted) {
        setState(() {
          _orders = orders;
          _orderItems = orderItems;
          _creditRecords = creditRecords;
          _completedAmount = completedAmount;
          _pendingAmount = pendingAmount;
          _totalAmount = completedAmount + pendingAmount;
          _outstandingCreditAmount = outstandingCredit;
          _reportGenerated = true;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading customer orders: $e')),
        );
        setState(() => _isLoading = false);
      }
    }
  }

  void _onSearchChanged(String query) {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 500), () {
      setState(() {
        _searchQuery = query;
        _loadCustomers();
      });
    });
  }

  Future<void> _selectDateRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDateRange: _startDate != null && _endDate != null
          ? DateTimeRange(start: _startDate!, end: _endDate!)
          : null,
    );
    
    if (picked != null && mounted) {
      setState(() {
        _startDate = picked.start;
        _endDate = picked.end;
      });
      
      // If a customer is already selected, reload the orders with the new date range
      if (_selectedCustomer != null) {
        _loadCustomerOrders();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SideMenuWidget(),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(defaultPadding),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Customer Reports',
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  const SizedBox(height: defaultPadding),
                  // Wrap the row in a SingleChildScrollView to prevent overflow
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        SizedBox(
                          width: 300,
                          child: TextField(
                            controller: _searchController,
                            decoration: const InputDecoration(
                              labelText: 'Search Customers',
                              prefixIcon: Icon(Icons.search),
                              border: OutlineInputBorder(),
                            ),
                            onChanged: _onSearchChanged,
                          ),
                        ),
                        const SizedBox(width: defaultPadding),
                        ElevatedButton.icon(
                          onPressed: _selectDateRange,
                          icon: const Icon(Icons.date_range),
                          label: Text(_startDate != null && _endDate != null
                              ? '${DateFormat('MMM d, y').format(_startDate!)} - ${DateFormat('MMM d, y').format(_endDate!)}'
                              : 'Select Date Range'),
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                              horizontal: defaultPadding,
                              vertical: defaultPadding / 2,
                            ),
                          ),
                        ),
                        const SizedBox(width: defaultPadding),
                        ElevatedButton.icon(
                          onPressed: _selectedCustomer != null
                              ? _loadCustomerOrders
                              : null,
                          icon: const Icon(Icons.refresh),
                          label: const Text('Generate Report'),
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                              horizontal: defaultPadding,
                              vertical: defaultPadding / 2,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: defaultPadding),
                  Expanded(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Customer selection panel
                        SizedBox(
                          width: 300,
                          child: Card(
                            child: Padding(
                              padding: const EdgeInsets.all(defaultPadding),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Select Customer',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                  ),
                                  const SizedBox(height: defaultPadding / 2),
                                  _isLoading
                                      ? const Center(
                                          child: CircularProgressIndicator(),
                                        )
                                      : Expanded(
                                          child: ListView.builder(
                                            itemCount: _customers.length,
                                            itemBuilder: (context, index) {
                                              final customer = _customers[index];
                                              return ListTile(
                                                title: Text(customer.name),
                                                subtitle: Text(
                                                    'Orders: ${customer.totalOrders}'),
                                                selected: _selectedCustomer?.id ==
                                                    customer.id,
                                                onTap: () {
                                                  setState(() {
                                                    _selectedCustomer = customer;
                                                  });
                                                },
                                              );
                                            },
                                          ),
                                        ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: defaultPadding),
                        // Report display area
                        Expanded(
                          child: _isLoading
                              ? const Center(child: CircularProgressIndicator())
                              : !_reportGenerated
                                  ? const Center(
                                      child: Text(
                                        'Select a customer and date range, then click "Generate Report"',
                                        style: TextStyle(fontSize: 16),
                                      ),
                                    )
                                  : _orders.isEmpty
                                      ? const Center(
                                          child: Text(
                                            'No orders found for the selected customer and date range',
                                            style: TextStyle(fontSize: 16),
                                          ),
                                        )
                                      : _selectedCustomer == null
                                          ? const Center(
                                              child: Text(
                                                'Please select a customer first',
                                                style: TextStyle(fontSize: 16),
                                              ),
                                            )
                                          : DynamicCustomerReportWidget(
                                              customer: _selectedCustomer!,
                                              orders: _orders,
                                              orderItems: _orderItems,
                                              creditRecords: _creditRecords,
                                              startDate: _startDate,
                                              endDate: _endDate,
                                              completedAmount: _completedAmount,
                                              pendingAmount: _pendingAmount,
                                              totalAmount: _totalAmount,
                                              outstandingCreditAmount: _outstandingCreditAmount,
                                            ),
                        ),
                      ],
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
} 