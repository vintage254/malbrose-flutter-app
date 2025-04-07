import 'package:flutter/material.dart';
import 'package:my_flutter_app/models/creditor_model.dart';
import 'package:my_flutter_app/services/database.dart';
import 'package:my_flutter_app/services/order_service.dart';

class CreditOrdersDialog extends StatefulWidget {
  final String customerName;

  const CreditOrdersDialog({
    super.key,
    required this.customerName,
  });

  @override
  State<CreditOrdersDialog> createState() => _CreditOrdersDialogState();
}

class _CreditOrdersDialogState extends State<CreditOrdersDialog> {
  final TextEditingController _paymentAmountController = TextEditingController();
  final TextEditingController _paymentDetailsController = TextEditingController();
  
  List<Creditor> _creditOrders = [];
  bool _isLoading = true;
  double _totalCreditBalance = 0;
  String _selectedPaymentMethod = 'Cash';
  final OrderService _orderService = OrderService.instance;
  
  final List<String> _paymentMethods = ['Cash', 'Bank Transfer', 'Mobile Money'];

  @override
  void initState() {
    super.initState();
    _loadCreditOrders();
  }

  @override
  void dispose() {
    _paymentAmountController.dispose();
    _paymentDetailsController.dispose();
    super.dispose();
  }

  Future<void> _loadCreditOrders() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final creditOrdersData = await DatabaseService.instance.getCreditOrdersByCustomer(widget.customerName);
      
      setState(() {
        _creditOrders = creditOrdersData.map((data) => Creditor.fromMap(data)).toList();
        _totalCreditBalance = _creditOrders.fold(0, (sum, order) => sum + order.balance);
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading credit orders: $e');
      
      if (mounted) {
        setState(() {
          _isLoading = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading credit orders: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _submitPayment() async {
    if (_paymentAmountController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a payment amount'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    double paymentAmount;
    try {
      paymentAmount = double.parse(_paymentAmountController.text);
      if (paymentAmount <= 0) {
        throw Exception('Payment amount must be greater than zero');
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a valid payment amount'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Show loading dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return const AlertDialog(
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Processing payment...'),
            ],
          ),
        );
      },
    );

    try {
      // Apply payment to credits using OrderService instead of directly calling DatabaseService
      final success = await _orderService.applyPaymentToCredits(
        widget.customerName,
        paymentAmount,
        _selectedPaymentMethod,
        _paymentDetailsController.text,
      );
      
      // Close loading dialog
      if (mounted) {
        Navigator.of(context, rootNavigator: true).pop();
      }
      
      if (!success) {
        throw Exception('Failed to apply payment');
      }
      
      // Reload credit orders to show updated balances
      await _loadCreditOrders();
      
      // Clear input fields
      _paymentAmountController.clear();
      _paymentDetailsController.clear();
      
      // Show success message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Payment applied successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      // Close loading dialog
      if (mounted) {
        Navigator.of(context, rootNavigator: true).pop();
      }
      
      // Show error message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error applying payment: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Container(
        width: MediaQuery.of(context).size.width * 0.8,
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${widget.customerName}\'s Credit Orders',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const Divider(),
            _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _creditOrders.isEmpty
                    ? const Center(
                        child: Padding(
                          padding: EdgeInsets.all(16.0),
                          child: Text(
                            'No pending credit orders found for this customer',
                            style: TextStyle(fontSize: 16),
                          ),
                        ),
                      )
                    : Flexible(
                        child: SingleChildScrollView(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Padding(
                                padding: EdgeInsets.symmetric(vertical: 8.0),
                                child: Text(
                                  'Outstanding Credit Orders:',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                              ),
                              ListView.builder(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                itemCount: _creditOrders.length,
                                itemBuilder: (context, index) {
                                  final order = _creditOrders[index];
                                  return Card(
                                    margin: const EdgeInsets.symmetric(vertical: 4),
                                    child: ListTile(
                                      title: Text(
                                        'Order #${order.orderNumber ?? 'Unknown'}',
                                        style: const TextStyle(fontWeight: FontWeight.bold),
                                      ),
                                      subtitle: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'Date: ${order.createdAt?.toString().substring(0, 10) ?? 'Unknown'}',
                                          ),
                                          Text(
                                            'Original Amount: ${order.originalAmount?.toStringAsFixed(2) ?? 'Unknown'}',
                                          ),
                                          Text(
                                            'Remaining Balance: ${order.balance.toStringAsFixed(2)}',
                                            style: const TextStyle(fontWeight: FontWeight.bold),
                                          ),
                                        ],
                                      ),
                                      isThreeLine: true,
                                    ),
                                  );
                                },
                              ),
                              Padding(
                                padding: const EdgeInsets.symmetric(vertical: 8.0),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    const Text(
                                      'Total Credit Balance:',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                      ),
                                    ),
                                    Text(
                                      _totalCreditBalance.toStringAsFixed(2),
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const Divider(),
                              const Padding(
                                padding: EdgeInsets.symmetric(vertical: 8.0),
                                child: Text(
                                  'Payment Details:',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                              ),
                              Row(
                                children: [
                                  Expanded(
                                    child: TextFormField(
                                      controller: _paymentAmountController,
                                      decoration: const InputDecoration(
                                        labelText: 'Payment Amount',
                                        border: OutlineInputBorder(),
                                      ),
                                      keyboardType: TextInputType.number,
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: DropdownButtonFormField<String>(
                                      value: _selectedPaymentMethod,
                                      decoration: const InputDecoration(
                                        labelText: 'Payment Method',
                                        border: OutlineInputBorder(),
                                      ),
                                      items: _paymentMethods.map((method) {
                                        return DropdownMenuItem<String>(
                                          value: method,
                                          child: Text(method),
                                        );
                                      }).toList(),
                                      onChanged: (value) {
                                        if (value != null) {
                                          setState(() {
                                            _selectedPaymentMethod = value;
                                          });
                                        }
                                      },
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),
                              TextFormField(
                                controller: _paymentDetailsController,
                                decoration: const InputDecoration(
                                  labelText: 'Payment Notes (optional)',
                                  border: OutlineInputBorder(),
                                ),
                                maxLines: 2,
                              ),
                              const SizedBox(height: 16),
                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton(
                                  onPressed: _creditOrders.isEmpty ? null : _submitPayment,
                                  style: ElevatedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(vertical: 16),
                                  ),
                                  child: const Text('Submit Payment'),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
          ],
        ),
      ),
    );
  }
}
