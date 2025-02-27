import 'package:flutter/material.dart';
import 'package:my_flutter_app/const/constant.dart';
import 'package:my_flutter_app/models/customer_model.dart';
import 'package:my_flutter_app/models/invoice_model.dart';
import 'package:my_flutter_app/services/database.dart';
import 'package:my_flutter_app/widgets/side_menu_widget.dart';
import 'package:my_flutter_app/services/invoice_service.dart';
import 'package:intl/intl.dart';
import 'package:my_flutter_app/models/order_model.dart';
import 'package:my_flutter_app/widgets/invoice_preview_widget.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'dart:async';
import 'package:path_provider/path_provider.dart';
import 'package:open_file/open_file.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:io';

class InvoicesScreen extends StatefulWidget {
  const InvoicesScreen({super.key});

  @override
  State<InvoicesScreen> createState() => _InvoicesScreenState();
}

class _InvoicesScreenState extends State<InvoicesScreen> {
  final TextEditingController _searchController = TextEditingController();
  DateTime? _startDate;
  DateTime? _endDate;
  Customer? _selectedCustomer;
  List<Invoice> _invoiceData = [];
  bool _isLoading = false;
  List<Customer> _customers = [];
  List<Invoice> _invoices = [];
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
        _loadInvoices(),
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

  Future<void> _loadInvoices() async {
    if (_selectedCustomer == null) return;
    
    setState(() => _isLoading = true);
    try {
      await DatabaseService.instance.withTransaction((txn) async {
        final invoices = await DatabaseService.instance.getInvoices(
          startDate: _startDate,
          endDate: _endDate,
          searchQuery: _searchQuery,
          executor: txn,
        );
        
        final List<Invoice> processedInvoices = [];
        for (final map in invoices) {
          final invoice = Invoice.fromMap(map);
          final items = await InvoiceService.instance.getInvoiceItems(invoice.id!, txn: txn);
          processedInvoices.add(invoice.copyWith(
            completedItems: items.where((item) => item['status'] == 'COMPLETED').map((item) => 
              OrderItem.fromMap(item)).toList(),
            pendingItems: items.where((item) => item['status'] == 'PENDING').map((item) => 
              OrderItem.fromMap(item)).toList(),
          ));
        }
        
        if (mounted) {
          setState(() {
            _invoices = processedInvoices
                .where((invoice) => invoice.customerId == _selectedCustomer!.id)
                .toList();
          });
        }
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading invoices: $e')),
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
      _loadInvoices();
    }
  }

  Future<void> _generateInvoice() async {
    if (_selectedCustomer == null) return;

    setState(() => _isLoading = true);
    try {
      await DatabaseService.instance.withTransaction((txn) async {
        final invoice = await InvoiceService.instance.generateInvoice(
          _selectedCustomer!.id!,
          startDate: _startDate,
          endDate: _endDate,
          txn: txn
        );
        
        await InvoiceService.instance.createInvoiceWithItems(
          invoice, 
          txn: txn
        );
      });

      await _loadInvoices();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Invoice generated successfully')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error generating invoice: $e')),
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
                            _loadInvoices();
                          },
                        ),
                      ),
                      const SizedBox(width: defaultPadding),
                      OutlinedButton.icon(
                        onPressed: _selectDateRange,
                        icon: const Icon(Icons.date_range),
                        label: Text(
                          _startDate != null && _endDate != null
                              ? '${DateFormat('MMM d').format(_startDate!)} - ${DateFormat('MMM d').format(_endDate!)}'
                              : 'Select Date Range',
                        ),
                      ),
                      const SizedBox(width: defaultPadding),
                      ElevatedButton.icon(
                        onPressed: _isLoading ? null : _generateInvoice,
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
                        label: const Text('New Invoice'),
                      ),
                    ],
                  ),
                  const SizedBox(height: defaultPadding),
                  if (_isLoading)
                    const Center(child: CircularProgressIndicator())
                  else if (_invoices.isEmpty)
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
                              ? 'No invoices found for ${_selectedCustomer!.name}'
                              : 'Select a customer to view invoices',
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
                        itemCount: _invoices.length,
                        itemBuilder: (context, index) {
                          final invoice = _invoices[index];
                          final customer = _customers.firstWhere(
                            (c) => c.id == invoice.customerId,
                          );
                          return InvoicePreviewWidget(
                            invoice: invoice,
                            customer: customer,
                            onPrint: () => _printInvoice(invoice, customer),
                            onSave: () => _saveInvoice(invoice, customer),
                            onSend: () => _sendInvoice(invoice, customer),
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

  Future<void> _printInvoice(Invoice invoice, Customer customer) async {
    try {
      setState(() => _isLoading = true);
      await InvoiceService.instance.generateAndPrintInvoice(invoice, customer);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Invoice printed successfully')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error printing invoice: $e')),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _saveInvoice(Invoice invoice, Customer customer) async {
    try {
      setState(() => _isLoading = true);
      final pdf = await InvoiceService.generateInvoicePdf(invoice, customer);
      
      // Save PDF to downloads directory
      final downloadsPath = await getDownloadsDirectory();
      if (downloadsPath == null) throw Exception('Downloads directory not found');
      
      final fileName = '${invoice.invoiceNumber.replaceAll('/', '_')}.pdf';
      final file = File('${downloadsPath.path}/$fileName');
      await file.writeAsBytes(pdf);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('PDF saved to ${file.path}'),
            action: SnackBarAction(
              label: 'Open',
              onPressed: () => OpenFile.open(file.path),
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving invoice: $e')),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _sendInvoice(Invoice invoice, Customer customer) async {
    try {
      setState(() => _isLoading = true);
      
      if (customer.email == null) {
        throw Exception('Customer email not available');
      }
      
      // First save the PDF
      final pdf = await InvoiceService.generateInvoicePdf(invoice, customer);
      final tempDir = await getTemporaryDirectory();
      final fileName = '${invoice.invoiceNumber.replaceAll('/', '_')}.pdf';
      final file = File('${tempDir.path}/$fileName');
      await file.writeAsBytes(pdf);
      
      // Prepare email content
      final emailSubject = 'Invoice ${invoice.invoiceNumber}';
      final emailBody = '''
Dear ${customer.name},

Please find attached your invoice ${invoice.invoiceNumber}.

Total Amount: KSH ${invoice.totalAmount.toStringAsFixed(2)}
Due Date: ${invoice.dueDate != null ? DateFormat('MMM dd, yyyy').format(invoice.dueDate!) : 'N/A'}

Thank you for your business!

Best regards,
Your Company Name''';

      // Create mailto URL
      final mailtoUri = Uri(
        scheme: 'mailto',
        path: customer.email,
        query: encodeQueryParameters({
          'subject': emailSubject,
          'body': emailBody,
          'attachment': file.path,
        }),
      );

      // Launch email client
      if (await canLaunchUrl(mailtoUri)) {
        await launchUrl(mailtoUri);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Email client opened successfully')),
          );
        }
      } else {
        throw Exception('Could not launch email client');
      }
      
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error sending invoice: $e')),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  String encodeQueryParameters(Map<String, String> params) {
    return params.entries
        .map((e) => '${Uri.encodeComponent(e.key)}=${Uri.encodeComponent(e.value)}')
        .join('&');
  }

  @override
  void dispose() {
    _searchController.dispose();
    _debounceTimer?.cancel();
    super.dispose();
  }
} 