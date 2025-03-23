import 'package:flutter/material.dart';
import 'package:my_flutter_app/const/constant.dart';
import 'package:my_flutter_app/models/creditor_model.dart';
import 'package:my_flutter_app/services/database.dart';
import 'package:my_flutter_app/widgets/side_menu_widget.dart';

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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading creditors: $e')),
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
        final exists = await DatabaseService.instance.checkCreditorExists(
          _nameController.text.trim(),
        );

        if (exists) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('A creditor with this name already exists'),
              backgroundColor: Colors.red,
            ),
          );
          return;
        }

        final creditor = {
          'name': _nameController.text.trim(),
          'balance': double.parse(_balanceController.text),
          'details': _detailsController.text.trim(),
          'status': 'PENDING',
          'created_at': DateTime.now().toIso8601String(),
        };

        await DatabaseService.instance.addCreditor(creditor);
        _nameController.clear();
        _balanceController.clear();
        _detailsController.clear();
        await _loadCreditors();

        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Creditor added successfully'),
            backgroundColor: Colors.green,
          ),
        );
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error adding creditor: $e')),
        );
      }
    }
  }

  Future<void> _updateCreditorBalance(Creditor creditor) async {
    final newBalanceController = TextEditingController(
      text: creditor.balance.toString(),
    );
    final newDetailsController = TextEditingController(
      text: creditor.details,
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
                final newBalance = double.parse(newBalanceController.text);
                final status = newBalance <= 0 ? 'COMPLETED' : 'PENDING';
                
                await DatabaseService.instance.updateCreditorBalanceAndStatus(
                  creditor.id!,
                  newBalance,
                  newDetailsController.text.trim(),
                  status,
                );
                
                if (!mounted) return;
                Navigator.pop(context);
                await _loadCreditors();
                
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Balance updated successfully'),
                    backgroundColor: Colors.green,
                  ),
                );
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Error updating balance: $e')),
                );
              }
            },
            child: const Text('Update'),
          ),
        ],
      ),
    );
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
                  const Text(
                    'Creditors Management',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
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
                  // Search bar
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
                                return ListTile(
                                  title: Text(creditor.name),
                                  subtitle: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text('Balance: KSH ${creditor.balance.toStringAsFixed(2)}'),
                                      Text('Details: ${creditor.details}'),
                                      Text('Status: ${creditor.status}'),
                                    ],
                                  ),
                                  trailing: SizedBox(
                                    width: 120,
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        IconButton(
                                          icon: const Icon(Icons.edit),
                                          onPressed: () => _updateCreditorBalance(creditor),
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