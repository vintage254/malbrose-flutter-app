import 'package:flutter/material.dart';
import 'package:my_flutter_app/const/constant.dart';
import 'package:my_flutter_app/models/customer_model.dart';
import 'package:my_flutter_app/models/customer_report_model.dart';
import 'package:my_flutter_app/services/database.dart';
import 'package:my_flutter_app/widgets/side_menu_widget.dart';
import 'package:my_flutter_app/services/customer_report_service.dart';
import 'package:intl/intl.dart';
import 'package:my_flutter_app/models/order_model.dart';
import 'package:my_flutter_app/widgets/customer_report_preview_widget.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
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
  List<Map<String, dynamic>> _reportData = [];
  bool _isLoading = false;
  List<Customer> _customers = [];
  List<CustomerReport> _reports = [];
  Timer? _debounceTimer;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    setState(() => _isLoading = true);
    try {
      await Future.wait([
        _loadCustomers(),
        _loadCustomerReports(),
      ]);
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _loadCustomers() async {
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
    }
  }

  Future<void> _loadCustomerReports() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    
    try {
      final List<CustomerReport> loadedCustomerReports = [];
      final reportsData = await DatabaseService.instance.getCustomerReports(
        startDate: _startDate,
        endDate: _endDate,
        searchQuery: _searchQuery,
      );

      for (var reportData in reportsData) {
        // Load order items for this report
        final completedItems = await DatabaseService.instance.getOrderItems(
          reportData['id'] as int,
          status: 'COMPLETED',
        );
        
        final pendingItems = await DatabaseService.instance.getOrderItems(
          reportData['id'] as int,
          status: 'PENDING',
        );

        // Create CustomerReport object
        final report = CustomerReport(
          id: reportData['id'] as int?,
          reportNumber: reportData['report_number'] as String,
          customerId: reportData['customer_id'] as int,
          customerName: reportData['customer_name'] as String?,
          totalAmount: (reportData['total_amount'] as num).toDouble(),
          completedAmount: (reportData['completed_amount'] as num?)?.toDouble() ?? 0.0,
          pendingAmount: (reportData['pending_amount'] as num?)?.toDouble() ?? 0.0,
          status: reportData['status'] as String,
          paymentStatus: reportData['payment_status'] as String,
          createdAt: DateTime.parse(reportData['created_at'] as String),
          dueDate: reportData['due_date'] != null 
              ? DateTime.parse(reportData['due_date'] as String)
              : null,
          completedItems: _mapOrderItems(completedItems),
          pendingItems: _mapOrderItems(pendingItems),
        );

        loadedCustomerReports.add(report);
      }

      if (mounted) {
        setState(() {
          _reports = loadedCustomerReports;
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error loading reports: $e');
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load reports: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  List<OrderItem> _mapOrderItems(List<Map<String, dynamic>> items) {
    return items.map((item) => OrderItem(
      id: item['id'] as int?,
      orderId: item['order_id'] as int,
      productId: item['product_id'] as int,
      quantity: item['quantity'] as int,
      unitPrice: (item['unit_price'] as num).toDouble(),
      sellingPrice: (item['selling_price'] as num).toDouble(),
      adjustedPrice: (item['adjusted_price'] as num?)?.toDouble() ?? 
                    (item['selling_price'] as num).toDouble(),
      totalAmount: (item['total_amount'] as num).toDouble(),
      productName: item['product_name'] as String,
      isSubUnit: (item['is_sub_unit'] as int?) == 1,
      subUnitName: item['sub_unit_name'] as String?,
    )).toList();
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
      _loadCustomerReports();
    }
  }

  Future<void> _generateCustomerReport() async {
    if (_selectedCustomer == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a customer')),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      final report = await DatabaseService.instance.withTransaction((txn) async {
        // Get orders within the same transaction
        final completedOrders = await DatabaseService.instance.getOrdersByCustomerId(
          _selectedCustomer!.id!,
          status: 'COMPLETED',
          txn: txn,
        );
        
        final pendingOrders = await DatabaseService.instance.getOrdersByCustomerId(
          _selectedCustomer!.id!,
          status: 'PENDING',
          txn: txn,
        );

        if (completedOrders.isEmpty && pendingOrders.isEmpty) {
          throw Exception('No orders found for this customer');
        }

        // Calculate totals
        final completedAmount = completedOrders.fold<double>(
          0.0,
          (sum, order) => sum + (order['total_amount'] as num).toDouble(),
        );
        
        final pendingAmount = pendingOrders.fold<double>(
          0.0,
          (sum, order) => sum + (order['total_amount'] as num).toDouble(),
        );

        final newCustomerReport = CustomerReport(
          id: null,
          reportNumber: await CustomerReportService.instance.generateCustomerReportNumber(),
          customerId: _selectedCustomer!.id!,
          customerName: _selectedCustomer!.name,
          totalAmount: completedAmount + pendingAmount,
          status: 'PENDING',
          paymentStatus: 'PENDING',
          createdAt: DateTime.now(),
          dueDate: DateTime.now().add(const Duration(days: 30)),
          orderIds: [...completedOrders.map((o) => o['id'] as int), 
                    ...pendingOrders.map((o) => o['id'] as int)],
          completedAmount: completedAmount,
          pendingAmount: pendingAmount,
        );

        // Create report within the same transaction
        return await DatabaseService.instance.createReportWithItems(newCustomerReport.toMap(), []);
      });

      // Reload reports after successful creation
      await _loadCustomerReports();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('CustomerReport generated successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      print('Error generating report: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error generating report: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
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
          const Expanded(
            flex: 1,
            child: SideMenuWidget(),
          ),
          Expanded(
            flex: 4,
            child: Padding(
              padding: const EdgeInsets.all(defaultPadding),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<Customer>(
                          value: _selectedCustomer,
                          decoration: InputDecoration(
                            labelText: 'Select Customer',
                            prefixIcon: const Icon(Icons.person),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          items: _customers.map((customer) {
                            return DropdownMenuItem(
                              value: customer,
                              child: Text(customer.name),
                            );
                          }).toList(),
                          onChanged: (Customer? customer) {
                            setState(() => _selectedCustomer = customer);
                          },
                        ),
                      ),
                      const SizedBox(width: defaultPadding),
                      ElevatedButton.icon(
                        onPressed: _isLoading ? null : _generateCustomerReport,
                        icon: _isLoading 
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.add),
                        label: const Text('New CustomerReport'),
                      ),
                    ],
                  ),
                  const SizedBox(height: defaultPadding),
                  if (_isLoading)
                    const Center(child: CircularProgressIndicator())
                  else if (_reports.isEmpty)
                    Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.receipt_long_outlined,
                            size: 64,
                            color: Colors.grey,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            _selectedCustomer != null
                              ? 'No reports found for ${_selectedCustomer!.name}'
                              : 'Select a customer to view reports',
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              color: Colors.grey,
                            ),
                          ),
                        ],
                      ),
                    )
                  else
                    Expanded(
                      child: ListView.builder(
                        itemCount: _reports.length,
                        itemBuilder: (context, index) {
                          final report = _reports[index];
                          return CustomerReportPreviewWidget(
                            report: report,
                            customer: _customers.firstWhere(
                              (c) => c.id == report.customerId,
                            ),
                          );
                        },
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

  Color _getStatusColor(String status) {
    switch (status.toUpperCase()) {
      case 'PAID':
        return Colors.green;
      case 'PENDING':
        return Colors.orange;
      case 'OVERDUE':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  Future<void> _printCustomerReport(CustomerReport report, Customer customer) async {
    try {
      await CustomerReportService.instance.printCustomerReport(report, customer);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error printing report: $e')),
        );
      }
    }
  }

  void _showCustomerReportDetails(CustomerReport report, Customer customer) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('CustomerReport #${report.reportNumber}'),
        content: SizedBox(
          width: 600,
          child: CustomerReportPreviewWidget(
            report: report,
            customer: customer,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
          ElevatedButton.icon(
            onPressed: () => _printCustomerReport(report, customer),
            icon: const Icon(Icons.print),
            label: const Text('Print'),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    _debounceTimer?.cancel();
    super.dispose();
  }
} 