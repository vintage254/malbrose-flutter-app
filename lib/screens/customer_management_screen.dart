import 'package:flutter/material.dart';
import 'package:my_flutter_app/const/constant.dart';
import 'package:my_flutter_app/models/customer_model.dart';
import 'package:my_flutter_app/services/database.dart';
import 'package:my_flutter_app/widgets/side_menu_widget.dart';
import 'package:intl/intl.dart';

class CustomerManagementScreen extends StatefulWidget {
  const CustomerManagementScreen({super.key});

  @override
  State<CustomerManagementScreen> createState() => _CustomerManagementScreenState();
}

class _CustomerManagementScreenState extends State<CustomerManagementScreen> {
  List<Customer> _customers = [];
  bool _isLoading = true;
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _addressController = TextEditingController();
  final _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadCustomers();
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
          _isLoading = false;
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

  void _showAddCustomerDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add New Customer'),
        content: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: 'Name'),
                validator: (value) =>
                    value?.isEmpty ?? true ? 'Name is required' : null,
              ),
              TextFormField(
                controller: _emailController,
                decoration: const InputDecoration(labelText: 'Email'),
                keyboardType: TextInputType.emailAddress,
              ),
              TextFormField(
                controller: _phoneController,
                decoration: const InputDecoration(labelText: 'Phone'),
                keyboardType: TextInputType.phone,
              ),
              TextFormField(
                controller: _addressController,
                decoration: const InputDecoration(labelText: 'Address'),
                maxLines: 2,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: _addCustomer,
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  Future<void> _addCustomer() async {
    if (!_formKey.currentState!.validate()) return;

    try {
      final customer = Customer(
        name: _nameController.text,
        email: _emailController.text.isEmpty ? null : _emailController.text,
        phone: _phoneController.text.isEmpty ? null : _phoneController.text,
        address: _addressController.text.isEmpty ? null : _addressController.text,
        createdAt: DateTime.now(),
      );

      await DatabaseService.instance.createCustomer(customer);
      
      if (!mounted) return;
      Navigator.pop(context);
      _clearForm();
      _loadCustomers();
      
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error adding customer: $e')),
      );
    }
  }

  void _clearForm() {
    _nameController.clear();
    _emailController.clear();
    _phoneController.clear();
    _addressController.clear();
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
            flex: 5,
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
                children: [
                  Padding(
                    padding: const EdgeInsets.all(defaultPadding),
                    child: Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _searchController,
                            decoration: const InputDecoration(
                              hintText: 'Search customers...',
                              prefixIcon: Icon(Icons.search),
                              filled: true,
                              fillColor: Colors.white,
                            ),
                            onChanged: (value) {
                              setState(() {
                                _searchQuery = value;
                                _loadCustomers();
                              });
                            },
                          ),
                        ),
                        const SizedBox(width: defaultPadding),
                        ElevatedButton.icon(
                          onPressed: _showAddCustomerDialog,
                          icon: const Icon(Icons.add),
                          label: const Text('Add Customer'),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: _isLoading
                        ? const Center(child: CircularProgressIndicator())
                        : ListView.builder(
                            itemCount: _customers.length,
                            itemBuilder: (context, index) {
                              final customer = _customers[index];
                              return Card(
                                margin: const EdgeInsets.symmetric(
                                  horizontal: defaultPadding,
                                  vertical: defaultPadding / 2,
                                ),
                                child: ListTile(
                                  leading: const Icon(Icons.person),
                                  title: Text(customer.name),
                                  subtitle: Text(
                                    'Added on: ${DateFormat('MMM dd, yyyy').format(customer.createdAt)}',
                                  ),
                                  trailing: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      if (customer.phone != null)
                                        IconButton(
                                          icon: const Icon(Icons.phone),
                                          onPressed: () {
                                            // Implement phone call functionality
                                          },
                                        ),
                                      IconButton(
                                        icon: const Icon(Icons.edit),
                                        onPressed: () {
                                          // Implement edit functionality
                                        },
                                      ),
                                    ],
                                  ),
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

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _searchController.dispose();
    super.dispose();
  }
} 