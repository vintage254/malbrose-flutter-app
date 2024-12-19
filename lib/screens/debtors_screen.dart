import 'package:flutter/material.dart';
import 'package:my_flutter_app/const/constant.dart';
import 'package:my_flutter_app/models/debtor_model.dart';
import 'package:my_flutter_app/services/database.dart';
import 'package:my_flutter_app/widgets/side_menu_widget.dart';

class DebtorsScreen extends StatefulWidget {
  const DebtorsScreen({super.key});

  @override
  State<DebtorsScreen> createState() => _DebtorsScreenState();
}

class _DebtorsScreenState extends State<DebtorsScreen> {
  List<Debtor> _debtors = [];
  bool _isLoading = true;
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _balanceController = TextEditingController();
  final _detailsController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadDebtors();
  }

  Future<void> _loadDebtors() async {
    try {
      final debtorsData = await DatabaseService.instance.getDebtors();
      if (mounted) {
        setState(() {
          _debtors = debtorsData.map((map) => Debtor.fromMap(map)).toList();
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading debtors: $e')),
        );
      }
    }
  }

  Future<void> _addDebtor() async {
    if (_formKey.currentState!.validate()) {
      try {
        final exists = await DatabaseService.instance.checkDebtorExists(
          _nameController.text.trim(),
        );

        if (exists) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('A debtor with this name already exists'),
              backgroundColor: Colors.red,
            ),
          );
          return;
        }

        final debtor = {
          'name': _nameController.text.trim(),
          'balance': double.parse(_balanceController.text),
          'details': _detailsController.text.trim(),
          'status': 'PENDING',
          'created_at': DateTime.now().toIso8601String(),
        };

        await DatabaseService.instance.addDebtor(debtor);
        _nameController.clear();
        _balanceController.clear();
        _detailsController.clear();
        await _loadDebtors();

        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Debtor added successfully'),
            backgroundColor: Colors.green,
          ),
        );
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error adding debtor: $e')),
        );
      }
    }
  }

  Future<void> _updateDebtorBalance(Debtor debtor) async {
    final newBalanceController = TextEditingController(
      text: debtor.balance.toString(),
    );
    final newDetailsController = TextEditingController(
      text: debtor.details,
    );

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Update Balance for ${debtor.name}'),
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
                
                await DatabaseService.instance.updateDebtorBalanceAndStatus(
                  debtor.id!,
                  newBalance,
                  newDetailsController.text.trim(),
                  status,
                );
                
                if (!mounted) return;
                Navigator.pop(context);
                await _loadDebtors();
                
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
                    'Debtors Management',
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
                                  labelText: 'Debtor Name',
                                ),
                                validator: (value) {
                                  if (value == null || value.isEmpty) {
                                    return 'Please enter debtor name';
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
                                  labelText: 'Details',
                                ),
                                maxLines: 3,
                                validator: (value) {
                                  if (value == null || value.isEmpty) {
                                    return 'Please enter details';
                                  }
                                  return null;
                                },
                              ),
                            ),
                            const SizedBox(width: defaultPadding),
                            ElevatedButton.icon(
                              onPressed: _addDebtor,
                              icon: const Icon(Icons.add),
                              label: const Text('Add Debtor'),
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
                  Expanded(
                    child: _isLoading
                        ? const Center(child: CircularProgressIndicator())
                        : Card(
                            child: ListView.builder(
                              itemCount: _debtors.length,
                              itemBuilder: (context, index) {
                                final debtor = _debtors[index];
                                return ListTile(
                                  title: Text(debtor.name),
                                  subtitle: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text('Balance: KSH ${debtor.balance.toStringAsFixed(2)}'),
                                      Text('Details: ${debtor.details}'),
                                      Text('Status: ${debtor.status}'),
                                    ],
                                  ),
                                  trailing: SizedBox(
                                    width: 120,
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        IconButton(
                                          icon: const Icon(Icons.edit),
                                          onPressed: () => _updateDebtorBalance(debtor),
                                        ),
                                        Expanded(
                                          child: Chip(
                                            label: Text(
                                              debtor.status,
                                              style: const TextStyle(fontSize: 12),
                                            ),
                                            backgroundColor: debtor.status == 'COMPLETED'
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
    super.dispose();
  }
} 