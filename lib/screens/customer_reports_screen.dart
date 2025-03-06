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
  List<CustomerReport> _reportData = [];
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
        _loadReports(),
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

  Future<void> _loadReports() async {
    if (_selectedCustomer == null) return;
    
    setState(() => _isLoading = true);
    try {
      await DatabaseService.instance.withTransaction((txn) async {
        final reports = await CustomerReportService.instance.getCustomerReports(
          _selectedCustomer!.id!,
          txn: txn
        );
        if (mounted) {
          setState(() => _reports = reports);
        }
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading reports: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
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
      _loadReports();
    }
  }

  Future<void> _generateCustomerReport() async {
    if (_selectedCustomer == null) return;

    setState(() => _isLoading = true);
    try {
      await DatabaseService.instance.withTransaction((txn) async {
        final report = await CustomerReportService.instance.generateCustomerReport(
          _selectedCustomer!.id!,
          txn: txn
        );
        
        await CustomerReportService.instance.createCustomerReportWithItems(
          report, 
          txn: txn
        );
      });

      await _loadReports();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Customer report generated successfully')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error generating customer report: $e')),
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
                            _loadReports();
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
                        label: const Text('New Customer Report'),
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
                              ? 'No customer reports found for ${_selectedCustomer!.name}'
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
      await CustomerReportService.instance.generateAndPrintCustomerReport(report, customer);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error printing customer report: $e')),
        );
      }
    }
  }

  void _showReportDetails(CustomerReport report, Customer customer) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Customer Report #${report.reportNumber}'),
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