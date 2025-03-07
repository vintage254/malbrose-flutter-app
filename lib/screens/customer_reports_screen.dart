import 'package:flutter/material.dart';
import 'package:my_flutter_app/const/constant.dart';
import 'package:my_flutter_app/models/customer_model.dart';
import 'package:my_flutter_app/models/order_model.dart';
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
  Timer? _debounceTimer;
  String _searchQuery = '';
  bool _reportGenerated = false;
  double _completedAmount = 0.0;
  double _pendingAmount = 0.0;
  double _totalAmount = 0.0;

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
      final customersData = await DatabaseService.instance.getAllCustomers();
      if (mounted) {
        setState(() {
          _customers = customersData
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
          SnackBar(content: Text('Error loading customers: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _loadCustomerOrders() async {
    if (_selectedCustomer == null) return;
    
    setState(() {
      _isLoading = true;
      _reportGenerated = false;
      _orders = [];
      _orderItems = [];
    });
    
    try {
      // Get all orders for the selected customer
      final orders = await DatabaseService.instance.getCustomerOrders(_selectedCustomer!.id!);
      
      // Filter orders by date range if specified
      final filteredOrders = orders.where((order) {
        if (_startDate == null && _endDate == null) return true;
        
        final orderDate = DateTime.parse(order['created_at'] as String);
        
        if (_startDate != null && _endDate != null) {
          return orderDate.isAfter(_startDate!) && 
                 orderDate.isBefore(_endDate!.add(const Duration(days: 1)));
        } else if (_startDate != null) {
          return orderDate.isAfter(_startDate!);
        } else if (_endDate != null) {
          return orderDate.isBefore(_endDate!.add(const Duration(days: 1)));
        }
        
        return true;
      }).toList();
      
      // Get order items for each order
      List<Map<String, dynamic>> allOrderItems = [];
      double completedAmount = 0.0;
      double pendingAmount = 0.0;
      
      for (final order in filteredOrders) {
        final items = await DatabaseService.instance.getOrderItems(order['id'] as int);
        allOrderItems.addAll(items);
        
        // Calculate totals based on order status
        final orderTotal = (order['total_amount'] as num).toDouble();
        if (order['status'] == 'COMPLETED') {
          completedAmount += orderTotal;
        } else {
          pendingAmount += orderTotal;
        }
      }
      
      if (mounted) {
        setState(() {
          _orders = filteredOrders;
          _orderItems = allOrderItems;
          _completedAmount = completedAmount;
          _pendingAmount = pendingAmount;
          _totalAmount = completedAmount + pendingAmount;
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
                                      : DynamicCustomerReportWidget(
                                          customer: _selectedCustomer!,
                                          orders: _orders,
                                          orderItems: _orderItems,
                                          startDate: _startDate,
                                          endDate: _endDate,
                                          completedAmount: _completedAmount,
                                          pendingAmount: _pendingAmount,
                                          totalAmount: _totalAmount,
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