import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:my_flutter_app/const/constant.dart';
import 'package:my_flutter_app/models/creditor_model.dart';
import 'package:my_flutter_app/services/database.dart';
import 'package:my_flutter_app/widgets/side_menu_widget.dart';
import 'package:my_flutter_app/utils/ui_helpers.dart';
import 'package:my_flutter_app/services/auth_service.dart';
import 'package:my_flutter_app/utils/receipt_number_generator.dart';

class CreditorsScreen extends StatefulWidget {
  const CreditorsScreen({super.key});

  @override
  State<CreditorsScreen> createState() => _CreditorsScreenState();
}

class _CreditorsScreenState extends State<CreditorsScreen> {
  List<Creditor> _creditors = [];
  List<Creditor> _filteredCreditors = [];
  bool _isLoading = true;
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _balanceController = TextEditingController();
  final _detailsController = TextEditingController();
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadCreditors();
  }

  Future<void> _loadCreditors() async {
    try {
      final creditorsData = await DatabaseService.instance.getCreditors();
      if (mounted) {
        setState(() {
          _creditors = creditorsData.map((map) => Creditor.fromMap(map)).toList();
          _filteredCreditors = List.from(_creditors);
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        UIHelpers.showSnackBarWithContext(
          context,
          'Error loading creditors: $e',
          isError: true,
        );
      }
    }
  }

  void _filterCreditors(String query) {
    if (query.isEmpty) {
      setState(() {
        _filteredCreditors = List.from(_creditors);
      });
    } else {
      setState(() {
        _filteredCreditors = _creditors
            .where((creditor) => creditor.name.toLowerCase().contains(query.toLowerCase()))
            .toList();
      });
    }
  }

  Future<void> _addCreditor() async {
    if (_formKey.currentState!.validate()) {
      try {
        // Get current date and time
        final now = DateTime.now();
        
        // Auto-generate a credit receipt number for manually added creditors
        final creditReceiptNumber = ReceiptNumberGenerator.generateCreditReceiptNumber();
        
        // Create a complete creditor record with all the necessary fields
        final creditor = {
          'name': _nameController.text.trim(),
          'balance': double.parse(_balanceController.text),
          'details': _detailsController.text.trim(),
          'status': 'PENDING',
          'created_at': now.toIso8601String(),
          'updated_at': now.toIso8601String(),
          'original_amount': double.parse(_balanceController.text),
          
          // Add fields that would normally be populated through payment method
          'receipt_number': creditReceiptNumber,
          'order_number': 'MANUAL-${now.millisecondsSinceEpoch}', // Unique identifier for manual entries
          'order_details': 'Manually added credit entry',
          'customer_name': _nameController.text.trim(), // Ensure customer name is also set
        };

        final creditorId = await DatabaseService.instance.addCreditor(creditor);
        
        // Additionally log this manual creation in the activity log
        final currentUser = AuthService.instance.currentUser;
        if (currentUser != null) {
          await DatabaseService.instance.logActivity(
            currentUser.id,
            currentUser.username,
            'create_credit_manual',
            'Manual Credit Creation',
            'Manually created credit of KSH ${double.parse(_balanceController.text).toStringAsFixed(2)} for ${_nameController.text.trim()} (Receipt #$creditReceiptNumber)',
          );
        }
        
        _nameController.clear();
        _balanceController.clear();
        _detailsController.clear();
        await _loadCreditors();

        if (!mounted) return;
        UIHelpers.showSnackBarWithContext(
          context,
          'Creditor added successfully',
          isError: false,
        );
      } catch (e) {
        if (!mounted) return;
        UIHelpers.showSnackBarWithContext(
          context,
          'Error adding creditor: $e',
          isError: true,
        );
      }
    }
  }

  Future<void> _updateCreditorBalance(Creditor creditor) async {
    if (creditor.id == null) {
      UIHelpers.showSnackBarWithContext(
        context,
        'Cannot update creditor: ID is missing',
        isError: true,
      );
      return;
    }
  
    final newBalanceController = TextEditingController(
      text: creditor.balance.toString(),
    );
    final newDetailsController = TextEditingController(
      text: creditor.details,
    );
    final orderNumberController = TextEditingController(
      text: creditor.orderNumber ?? '',
    );

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Update Balance for ${creditor.name}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: newBalanceController,
              decoration: const InputDecoration(labelText: 'New Balance'),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: defaultPadding),
            TextField(
              controller: orderNumberController,
              decoration: const InputDecoration(labelText: 'Order Number'),
            ),
            const SizedBox(height: defaultPadding),
            TextField(
              controller: newDetailsController,
              decoration: const InputDecoration(labelText: 'Details'),
              maxLines: 3,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              try {
                final newBalanceText = newBalanceController.text.trim();
                if (newBalanceText.isEmpty) {
                  throw Exception('Please enter a valid balance');
                }
                
                final newBalance = double.parse(newBalanceText);
                final status = newBalance <= 0 ? 'COMPLETED' : 'PENDING';
                
                await Future.delayed(const Duration(milliseconds: 100));
                
                await DatabaseService.instance.updateCreditorBalanceAndStatus(
                  creditor.id!,
                  newBalance,
                  newDetailsController.text.trim(),
                  status,
                  orderNumber: orderNumberController.text.trim(),
                );
                
                if (!mounted) return;
                Navigator.pop(context);
                await _loadCreditors();
                
                UIHelpers.showSnackBarWithContext(
                  context,
                  'Balance updated successfully',
                  isError: false,
                );
              } catch (e) {
                UIHelpers.showSnackBarWithContext(
                  context,
                  'Error updating balance: $e',
                  isError: true,
                );
              }
            },
            child: const Text('Update'),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteCreditor(Creditor creditor) async {
    if (creditor.id == null) {
      UIHelpers.showSnackBarWithContext(
        context,
        'Cannot delete creditor: ID is missing',
        isError: true,
      );
      return;
    }
    
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Creditor'),
        content: Text('Are you sure you want to delete this credit record for ${creditor.name}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await Future.delayed(const Duration(milliseconds: 100));
        await DatabaseService.instance.deleteCreditor(creditor.id!);
        await _loadCreditors();
        if (mounted) {
          UIHelpers.showSnackBarWithContext(
            context,
            'Credit record deleted successfully',
            isError: false,
          );
        }
      } catch (e) {
        if (mounted) {
          UIHelpers.showSnackBarWithContext(
            context,
            'Error deleting credit record: $e',
            isError: true,
          );
        }
      }
    }
  }

  Future<void> _fixDatabase() async {
    try {
      // Show loading dialog
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: CircularProgressIndicator(),
        ),
      );
      
      await DatabaseService.instance.fixUniqueConstraint();
      
      if (!mounted) return;
      
      // Close loading dialog
      Navigator.pop(context);
      
      // Reload data
      await _loadCreditors();
      
      // Show success message
      UIHelpers.showSnackBarWithContext(
        context,
        'Database schema fixed successfully. UNIQUE constraint removed.',
        isError: false,
      );
    } catch (e) {
      if (!mounted) return;
      
      // Close loading dialog
      Navigator.pop(context);
      
      // Show error message
      UIHelpers.showSnackBarWithContext(
        context,
        'Error fixing database schema: $e',
        isError: true,
      );
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
              padding: const EdgeInsets.all(defaultPadding),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Creditors Management',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      ElevatedButton.icon(
                        onPressed: _fixDatabase,
                        icon: const Icon(Icons.build_circle),
                        label: const Text('Fix DB Schema'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.purple,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: defaultPadding),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(defaultPadding),
                      child: Form(
                        key: _formKey,
                        child: Row(
                          children: [
                            Expanded(
                              child: TextFormField(
                                controller: _nameController,
                                decoration: const InputDecoration(
                                  labelText: 'Creditor Name',
                                ),
                                validator: (value) {
                                  if (value == null || value.isEmpty) {
                                    return 'Please enter creditor name';
                                  }
                                  return null;
                                },
                              ),
                            ),
                            const SizedBox(width: defaultPadding),
                            Expanded(
                              child: TextFormField(
                                controller: _balanceController,
                                decoration: const InputDecoration(
                                  labelText: 'Initial Balance',
                                ),
                                keyboardType: TextInputType.number,
                                validator: (value) {
                                  if (value == null || value.isEmpty) {
                                    return 'Please enter initial balance';
                                  }
                                  if (double.tryParse(value) == null) {
                                    return 'Please enter a valid number';
                                  }
                                  return null;
                                },
                              ),
                            ),
                            const SizedBox(width: defaultPadding),
                            Expanded(
                              child: TextFormField(
                                controller: _detailsController,
                                decoration: const InputDecoration(
                                  labelText: 'Credit Details',
                                  hintText: 'Enter product names or credit details',
                                ),
                                maxLines: 3,
                                validator: (value) {
                                  if (value == null || value.isEmpty) {
                                    return 'Please enter credit details';
                                  }
                                  return null;
                                },
                              ),
                            ),
                            const SizedBox(width: defaultPadding),
                            ElevatedButton.icon(
                              onPressed: _addCreditor,
                              icon: const Icon(Icons.add),
                              label: const Text('Add Creditor'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.green,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: defaultPadding),
                  TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: 'Search creditors by name...',
                      prefixIcon: const Icon(Icons.search),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      filled: true,
                      fillColor: Colors.white,
                    ),
                    onChanged: _filterCreditors,
                  ),
                  const SizedBox(height: defaultPadding),
                  Expanded(
                    child: _isLoading
                        ? const Center(child: CircularProgressIndicator())
                        : Card(
                            child: ListView.builder(
                              itemCount: _filteredCreditors.length,
                              itemBuilder: (context, index) {
                                final creditor = _filteredCreditors[index];
                                return ExpansionTile(
                                  title: Text(creditor.name),
                                  subtitle: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text('Balance: KSH ${creditor.balance.toStringAsFixed(2)}'),
                                      if (creditor.orderNumber != null && creditor.orderNumber!.isNotEmpty)
                                        Text('Order: ${creditor.orderNumber}'),
                                      Text('Status: ${creditor.status}'),
                                    ],
                                  ),
                                  trailing: SizedBox(
                                    width: 160,
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        IconButton(
                                          icon: const Icon(Icons.edit),
                                          onPressed: () => _updateCreditorBalance(creditor),
                                        ),
                                        IconButton(
                                          icon: const Icon(Icons.delete, color: Colors.red),
                                          onPressed: () => _deleteCreditor(creditor),
                                        ),
                                        Expanded(
                                          child: Chip(
                                            label: Text(
                                              creditor.status,
                                              style: const TextStyle(fontSize: 12),
                                            ),
                                            backgroundColor: creditor.status == 'COMPLETED'
                                                ? Colors.green
                                                : Colors.orange,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  children: [
                                    Padding(
                                      padding: const EdgeInsets.all(defaultPadding),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text('Details: ${creditor.details}'),
                                          if (creditor.originalAmount != null)
                                            Text('Original Amount: KSH ${creditor.originalAmount!.toStringAsFixed(2)}'),
                                          Text('Created: ${creditor.createdAt != null ? DateFormat('MMM dd, yyyy HH:mm').format(creditor.createdAt!) : 'N/A'}'),
                                          if (creditor.lastUpdated != null)
                                            Text('Last Updated: ${DateFormat('MMM dd, yyyy HH:mm').format(creditor.lastUpdated!)}'),
                                        ],
                                      ),
                                    ),
                                  ],
                                );
                              },
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

  @override
  void dispose() {
    _nameController.dispose();
    _balanceController.dispose();
    _detailsController.dispose();
    _searchController.dispose();
    super.dispose();
  }
} 