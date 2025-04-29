import 'package:flutter/material.dart';
import 'package:my_flutter_app/const/constant.dart';
import 'package:my_flutter_app/services/license_service.dart';
import 'package:my_flutter_app/services/auth_service.dart';
import 'package:intl/intl.dart';

class LicenseCheckScreen extends StatefulWidget {
  final Widget child;

  const LicenseCheckScreen({
    super.key,
    required this.child,
  });

  @override
  State<LicenseCheckScreen> createState() => _LicenseCheckScreenState();
}

class _LicenseCheckScreenState extends State<LicenseCheckScreen> {
  bool _isLoading = true;
  bool _isLicensed = false;
  int _daysRemaining = 0;
  String _message = '';
  final _licenseKeyController = TextEditingController();
  bool _isSubmitting = false;
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
    _checkLicense();
  }

  @override
  void dispose() {
    _licenseKeyController.dispose();
    super.dispose();
  }

  Future<void> _checkLicense() async {
    setState(() => _isLoading = true);
    
    try {
      final licenseStatus = await LicenseService.instance.getLicenseStatus();
      
      setState(() {
        _isLicensed = licenseStatus['isLicensed'] as bool;
        _daysRemaining = licenseStatus['daysRemaining'] as int;
        _message = licenseStatus['message'] as String;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Error checking license: $e';
      });
    }
  }

  Future<void> _applyLicenseKey() async {
    if (_licenseKeyController.text.isEmpty) {
      setState(() => _errorMessage = 'Please enter a license key');
      return;
    }

    setState(() {
      _isSubmitting = true;
      _errorMessage = '';
    });

    try {
      final result = await LicenseService.instance.applyLicenseKey(_licenseKeyController.text);
      
      if (result['success'] as bool) {
        // License key applied successfully, refresh the license status
        await _checkLicense();
      } else {
        setState(() => _errorMessage = result['message'] as String);
      }
    } catch (e) {
      setState(() => _errorMessage = 'Error applying license key: $e');
    } finally {
      setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // If the app is licensed or still in trial period, return the child widget
    if (_isLicensed || _daysRemaining > 0) {
      // Show trial warning if days are getting low
      if (!_isLicensed && _daysRemaining <= 3) {
        // Show a snackbar for low days remaining
        WidgetsBinding.instance.addPostFrameCallback((_) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Trial period ends in $_daysRemaining days. Please enter a license key to continue using the app.'),
              backgroundColor: Colors.orange,
              duration: const Duration(seconds: 10),
              action: SnackBarAction(
                label: 'License',
                onPressed: () {
                  showDialog(
                    context: context,
                    builder: (context) => _buildLicenseDialog(),
                  );
                },
              ),
            ),
          );
        });
      }
      
      return widget.child;
    }
    
    // Otherwise, show the license screen
    if (_isLoading) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }
    
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.blue.shade700,
              Colors.blue.shade900,
            ],
          ),
        ),
        child: Center(
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(defaultPadding * 2),
              child: Card(
                elevation: 10,
                child: Padding(
                  padding: const EdgeInsets.all(defaultPadding * 2),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.lock_clock,
                        size: 80,
                        color: Colors.orange,
                      ),
                      const SizedBox(height: defaultPadding),
                      const Text(
                        'Trial Period Expired',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: defaultPadding),
                      Text(
                        _message,
                        style: const TextStyle(fontSize: 16),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: defaultPadding * 2),
                      const Text(
                        'Please enter your license key to continue using the application:',
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: defaultPadding),
                      TextField(
                        controller: _licenseKeyController,
                        decoration: const InputDecoration(
                          labelText: 'License Key',
                          hintText: 'Enter your license key',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.vpn_key),
                        ),
                      ),
                      if (_errorMessage.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: defaultPadding / 2),
                          child: Text(
                            _errorMessage,
                            style: const TextStyle(
                              color: Colors.red,
                            ),
                          ),
                        ),
                      const SizedBox(height: defaultPadding),
                      ElevatedButton(
                        onPressed: _isSubmitting ? null : _applyLicenseKey,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                            horizontal: defaultPadding * 2,
                            vertical: defaultPadding,
                          ),
                        ),
                        child: _isSubmitting
                            ? const CircularProgressIndicator()
                            : const Text('Activate License'),
                      ),
                      const SizedBox(height: defaultPadding),
                      const Text(
                        'For license inquiries, please contact:',
                        style: TextStyle(
                          fontSize: 14,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                      const SizedBox(height: 5),
                      const Text(
                        'support@example.com',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Colors.blue,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLicenseDialog() {
    return AlertDialog(
      title: const Text('Enter License Key'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Your trial period will end in $_daysRemaining days.',
            style: const TextStyle(color: Colors.orange),
          ),
          const SizedBox(height: defaultPadding),
          TextField(
            controller: _licenseKeyController,
            decoration: const InputDecoration(
              labelText: 'License Key',
              hintText: 'Enter your license key',
              border: OutlineInputBorder(),
            ),
          ),
          if (_errorMessage.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: defaultPadding / 2),
              child: Text(
                _errorMessage,
                style: const TextStyle(color: Colors.red),
              ),
            ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _isSubmitting
              ? null
              : () async {
                  await _applyLicenseKey();
                  if (_isLicensed && mounted) {
                    Navigator.pop(context);
                  }
                },
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.green,
            foregroundColor: Colors.white,
          ),
          child: _isSubmitting
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.0,
                    color: Colors.white,
                  ),
                )
              : const Text('Activate'),
        ),
      ],
    );
  }
} 