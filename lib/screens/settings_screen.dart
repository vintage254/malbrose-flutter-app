import 'package:flutter/material.dart';
import 'package:my_flutter_app/const/constant.dart';
import 'package:my_flutter_app/models/user_model.dart';
import 'package:my_flutter_app/services/database.dart';
import 'package:my_flutter_app/services/auth_service.dart';
import 'package:my_flutter_app/services/config_service.dart';
import 'package:my_flutter_app/services/license_service.dart';
import 'package:my_flutter_app/widgets/side_menu_widget.dart';
import 'package:my_flutter_app/widgets/side_menu.dart';
import 'package:my_flutter_app/widgets/add_user_dialog.dart';
import 'package:my_flutter_app/widgets/edit_user_dialog.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:io';
import 'package:intl/intl.dart';
import 'package:my_flutter_app/services/ssl_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> with SingleTickerProviderStateMixin {
  // User management state
  List<User> _users = [];
  bool _isLoading = true;
  final currentUser = AuthService.instance.currentUser;
  
  // Tab controller
  late TabController _tabController;
  
  // Business info state
  final _businessNameController = TextEditingController();
  final _businessAddressController = TextEditingController();
  final _businessPhoneController = TextEditingController();
  final _businessEmailController = TextEditingController();
  String? _businessLogoPath;
  
  // Tax settings state
  final _vatRateController = TextEditingController();
  bool _enableVat = true;
  bool _showVatOnReceipt = true;
  
  // Receipt settings state
  final _receiptHeaderController = TextEditingController();
  final _receiptFooterController = TextEditingController();
  bool _showBusinessLogo = true;
  bool _showCashierName = true;
  bool _showNoReturnsPolicy = true;
  final _dateTimeFormatController = TextEditingController();
  
  // License info state
  bool _isLicensed = false;
  int _daysRemaining = 0;
  String _licenseStatusMessage = '';
  final _licenseKeyController = TextEditingController();
  bool _isSubmittingLicense = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 6, vsync: this);
    _loadUsers();
    _loadSettings();
    _checkLicense();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _businessNameController.dispose();
    _businessAddressController.dispose();
    _businessPhoneController.dispose();
    _businessEmailController.dispose();
    _vatRateController.dispose();
    _receiptHeaderController.dispose();
    _receiptFooterController.dispose();
    _dateTimeFormatController.dispose();
    _licenseKeyController.dispose();
    super.dispose();
  }

  Future<void> _loadSettings() async {
    final config = ConfigService.instance;
    
    setState(() {
      // Business Info
      _businessNameController.text = config.businessName;
      _businessAddressController.text = config.businessAddress;
      _businessPhoneController.text = config.businessPhone;
      _businessEmailController.text = config.businessEmail;
      _businessLogoPath = config.businessLogo;
      
      // Tax Settings
      _vatRateController.text = config.vatRate.toString();
      _enableVat = config.enableVat;
      _showVatOnReceipt = config.showVatOnReceipt;
      
      // Receipt Settings
      _receiptHeaderController.text = config.receiptHeader;
      _receiptFooterController.text = config.receiptFooter;
      _showBusinessLogo = config.showBusinessLogo;
      _showCashierName = config.showCashierName;
      _showNoReturnsPolicy = config.showNoReturnsPolicy;
      _dateTimeFormatController.text = config.dateTimeFormat;
    });
  }

  Future<void> _checkLicense() async {
    try {
      final licenseStatus = await LicenseService.instance.getLicenseStatus();
      
      setState(() {
        _isLicensed = licenseStatus['isLicensed'] as bool;
        _daysRemaining = licenseStatus['daysRemaining'] as int;
        _licenseStatusMessage = licenseStatus['message'] as String;
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error checking license status: $e')),
      );
    }
  }

  Future<void> _loadUsers() async {
    try {
      final usersData = await DatabaseService.instance.getAllUsers();
      if (mounted) {
        setState(() {
          _users = usersData.map((map) => User.fromMap(map)).toList();
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading users: $e')),
        );
      }
    }
  }

  Future<void> _saveBusinessInfo() async {
    final config = ConfigService.instance;
    
    config.businessName = _businessNameController.text;
    config.businessAddress = _businessAddressController.text;
    config.businessPhone = _businessPhoneController.text;
    config.businessEmail = _businessEmailController.text;
    if (_businessLogoPath != null) {
      config.businessLogo = _businessLogoPath!;
    }
    
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Business information saved')),
    );
  }

  Future<void> _saveTaxSettings() async {
    final config = ConfigService.instance;
    
    // Validate VAT rate
    double? vatRate = double.tryParse(_vatRateController.text);
    if (vatRate == null || vatRate < 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid VAT rate')),
      );
      return;
    }
    
    config.vatRate = vatRate;
    config.enableVat = _enableVat;
    config.showVatOnReceipt = _showVatOnReceipt;
    
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Tax settings saved')),
    );
  }

  Future<void> _saveReceiptSettings() async {
    final config = ConfigService.instance;
    
    config.receiptHeader = _receiptHeaderController.text;
    config.receiptFooter = _receiptFooterController.text;
    config.showBusinessLogo = _showBusinessLogo;
    config.showCashierName = _showCashierName;
    config.showNoReturnsPolicy = _showNoReturnsPolicy;
    config.dateTimeFormat = _dateTimeFormatController.text;
    
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Receipt settings saved')),
    );
  }

  Future<void> _applyLicenseKey() async {
    if (_licenseKeyController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a license key')),
      );
      return;
    }
    
    setState(() => _isSubmittingLicense = true);
    
    try {
      final result = await LicenseService.instance.applyLicenseKey(_licenseKeyController.text);
      
      if (result['success'] as bool) {
        // Refresh license status
        await _checkLicense();
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(result['message'] as String)),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(result['message'] as String)),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error applying license key: $e')),
      );
    } finally {
      setState(() => _isSubmittingLicense = false);
    }
  }

  Future<void> _pickBusinessLogo() async {
    try {
      final picker = ImagePicker();
      final pickedFile = await picker.pickImage(source: ImageSource.gallery);
      
      if (pickedFile != null) {
        setState(() {
          _businessLogoPath = pickedFile.path;
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error picking logo: $e')),
      );
    }
  }

  Future<void> _handleAddUser() async {
    final result = await showDialog(
      context: context,
      builder: (context) => AddUserDialog(
        currentUserIsAdmin: currentUser?.isAdmin ?? false,
      ),
    );

    if (result == true) {
      _loadUsers();
    }
  }

  Future<void> _handleEditUser(User user) async {
    final result = await showDialog(
      context: context,
      builder: (context) => EditUserDialog(
        user: user,
        currentUserIsAdmin: currentUser?.isAdmin ?? false,
      ),
    );

    if (result == true) {
      _loadUsers();
    }
  }

  Future<void> _handleDeleteUser(User user) async {
    // Prevent deleting yourself
    if (user.id == currentUser?.id) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('You cannot delete your own account'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Delete'),
        content: Text('Are you sure you want to delete ${user.username}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await DatabaseService.instance.deleteUser(user.id!);
        _loadUsers();
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('User deleted successfully'),
            backgroundColor: Colors.green,
          ),
        );
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error deleting user: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _toggleAdminStatus(User user) async {
    try {
      // Don't allow changing your own admin status
      if (user.id == currentUser?.id) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('You cannot change your own admin status'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      // Create updated user with toggled admin status
      final updatedUser = user.copyWith(
        role: user.isAdmin ? 'USER' : DatabaseService.ROLE_ADMIN,
        permissions: user.isAdmin ? DatabaseService.PERMISSION_BASIC : DatabaseService.PERMISSION_FULL_ACCESS,
      );

      // Update the user
      await DatabaseService.instance.updateUser(updatedUser);

      // Log the action
      if (currentUser != null) {
        await DatabaseService.instance.logActivity(
          currentUser!.id!,
          currentUser!.username,
          'update_user_role',
          'Update user role',
          'Changed ${user.username} role from ${user.role} to ${updatedUser.role}'
        );
      }

      // Refresh the user list
      _loadUsers();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${user.username} is now ${updatedUser.isAdmin ? 'an admin' : 'a regular user'}'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error updating user role: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _verifyAdminPrivileges() async {
    if (currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No user is currently logged in'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    try {
      // Check if the current user is an admin
      final isAdmin = currentUser!.isAdmin;
      
      // Check if the user has admin privileges in the database
      final hasAdminPrivileges = await DatabaseService.instance.hasAdminPrivileges(currentUser!.id!);
      
      // Check if the user has specific permissions
      final hasFullAccess = await DatabaseService.instance.hasPermission(
        currentUser!.id!, 
        DatabaseService.PERMISSION_FULL_ACCESS
      );
      
      // Display the results
      if (!mounted) return;
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'User: ${currentUser!.username}\n'
            'Role: ${currentUser!.role}\n'
            'isAdmin: $isAdmin\n'
            'hasAdminPrivileges: $hasAdminPrivileges\n'
            'hasFullAccess: $hasFullAccess'
          ),
          duration: const Duration(seconds: 5),
          backgroundColor: isAdmin && hasAdminPrivileges && hasFullAccess 
              ? Colors.green 
              : Colors.orange,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error verifying privileges: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        backgroundColor: Colors.blue.shade700,
        foregroundColor: Colors.white,
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabs: const [
            Tab(text: 'Business Info'),
            Tab(text: 'Users'),
            Tab(text: 'Tax Settings'),
            Tab(text: 'Receipt Settings'),
            Tab(text: 'Security'),
            Tab(text: 'License'),
          ],
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          indicatorColor: Colors.white,
        ),
      ),
      drawer: const SideMenu(),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildBusinessInfoTab(),
          _buildUsersTab(),
          _buildTaxSettingsTab(),
          _buildReceiptSettingsTab(),
          _buildSecurityTab(),
          _buildLicenseTab(),
        ],
      ),
    );
  }

  Widget _buildUsersTab() {
    return Padding(
      padding: const EdgeInsets.all(defaultPadding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'User Management',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Row(
                children: [
                  if (currentUser?.isAdmin ?? false)
                    Padding(
                      padding: const EdgeInsets.only(right: 8.0),
                      child: ElevatedButton.icon(
                        onPressed: _verifyAdminPrivileges,
                        icon: const Icon(Icons.security),
                        label: const Text('Verify Privileges'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue,
                        ),
                      ),
                    ),
                  if (currentUser?.isAdmin ?? false)
                    ElevatedButton.icon(
                      onPressed: _handleAddUser,
                      icon: const Icon(Icons.add),
                      label: const Text('Add User'),
                    ),
                ],
              ),
            ],
          ),
          const SizedBox(height: defaultPadding),
          Expanded(
            child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: DataTable(
                    columns: const [
                      DataColumn(label: Text('Username')),
                      DataColumn(label: Text('Full Name')),
                      DataColumn(label: Text('Email')),
                      DataColumn(label: Text('Admin')),
                      DataColumn(label: Text('Last Login')),
                      DataColumn(label: Text('Actions')),
                    ],
                    rows: _users.map((user) {
                      return DataRow(
                        cells: [
                          DataCell(Text(user.username)),
                          DataCell(Text(user.fullName)),
                          DataCell(Text(user.email)),
                          DataCell(
                            Switch(
                              value: user.isAdmin,
                              onChanged: currentUser?.isAdmin ?? false
                                ? (value) => _toggleAdminStatus(user)
                                : null,
                            ),
                          ),
                          DataCell(Text(user.lastLogin?.toString() ?? 'Never')),
                          DataCell(
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.edit),
                                  onPressed: currentUser?.isAdmin ?? false
                                    ? () => _handleEditUser(user)
                                    : null,
                                  tooltip: 'Edit User',
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete),
                                  onPressed: currentUser?.isAdmin ?? false
                                    ? () => _handleDeleteUser(user)
                                    : null,
                                  tooltip: 'Delete User',
                                ),
                              ],
                            ),
                          ),
                        ],
                      );
                    }).toList(),
                  ),
                ),
          ),
        ],
      ),
    );
  }

  Widget _buildBusinessInfoTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(defaultPadding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Business Information',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: defaultPadding),
          const Text('Enter your business details to appear on receipts and reports.'),
          const SizedBox(height: defaultPadding),
          
          // Business name
          TextField(
            controller: _businessNameController,
            decoration: const InputDecoration(
              labelText: 'Business Name',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.business),
            ),
          ),
          const SizedBox(height: defaultPadding),
          
          // Business address
          TextField(
            controller: _businessAddressController,
            maxLines: 2,
            decoration: const InputDecoration(
              labelText: 'Business Address',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.location_on),
            ),
          ),
          const SizedBox(height: defaultPadding),
          
          // Business phone
          TextField(
            controller: _businessPhoneController,
            decoration: const InputDecoration(
              labelText: 'Phone Number',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.phone),
            ),
          ),
          const SizedBox(height: defaultPadding),
          
          // Business email
          TextField(
            controller: _businessEmailController,
            decoration: const InputDecoration(
              labelText: 'Email Contact',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.email),
            ),
          ),
          const SizedBox(height: defaultPadding),
          
          // Business logo
          Row(
            children: [
              const Text('Business Logo:'),
              const SizedBox(width: defaultPadding),
              
              // Display current logo if available
              if (_businessLogoPath != null && _businessLogoPath!.isNotEmpty)
                Expanded(
                  child: Row(
                    children: [
                      Image.file(
                        File(_businessLogoPath!),
                        height: 60,
                        errorBuilder: (context, error, stackTrace) {
                          return const Text('Error loading logo');
                        },
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete),
                        onPressed: () {
                          setState(() {
                            _businessLogoPath = null;
                          });
                        },
                    ),
                  ],
                  ),
                )
              else
                const Text('No logo selected'),
              
              const SizedBox(width: defaultPadding),
              ElevatedButton.icon(
                onPressed: _pickBusinessLogo,
                icon: const Icon(Icons.upload_file),
                label: const Text('Upload Logo'),
              ),
            ],
          ),
          const SizedBox(height: defaultPadding * 2),
          
          // Save button
          Center(
            child: ElevatedButton.icon(
              onPressed: _saveBusinessInfo,
              icon: const Icon(Icons.save),
              label: const Text('Save Business Information'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: defaultPadding * 2,
                  vertical: defaultPadding,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReceiptAndTaxTab() {
    return DefaultTabController(
      length: 2,
      child: Column(
        children: [
          const TabBar(
            tabs: [
              Tab(text: 'Tax Settings'),
              Tab(text: 'Receipt Settings'),
            ],
            labelColor: Colors.black87,
          ),
          Expanded(
            child: TabBarView(
              children: [
                _buildTaxSettingsTab(),
                _buildReceiptSettingsTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTaxSettingsTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(defaultPadding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Tax Settings',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: defaultPadding),
          const Text(
            'Configure VAT (Value Added Tax) settings for your business.',
            style: TextStyle(fontSize: 14),
          ),
          const SizedBox(height: defaultPadding),
          
          // Enable VAT
          SwitchListTile(
            title: const Text('Enable VAT Handling'),
            subtitle: const Text('Calculate VAT for all transactions'),
            value: _enableVat,
            onChanged: (value) {
              setState(() {
                _enableVat = value;
              });
            },
          ),
          
          // VAT Rate
          Padding(
            padding: const EdgeInsets.symmetric(vertical: defaultPadding),
            child: TextField(
              controller: _vatRateController,
              decoration: const InputDecoration(
                labelText: 'VAT Rate (%)',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.percent),
                hintText: 'Example: 16.0',
              ),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              enabled: _enableVat,
            ),
          ),
          
          // Show VAT on receipts
          SwitchListTile(
            title: const Text('Show VAT on Receipt'),
            subtitle: const Text('Display VAT breakdown on customer receipts'),
            value: _showVatOnReceipt,
            onChanged: _enableVat 
                ? (value) {
                    setState(() {
                      _showVatOnReceipt = value;
                    });
                  }
                : null,
          ),
          
          const SizedBox(height: defaultPadding),
          const Divider(),
          const SizedBox(height: defaultPadding),
          
          // Example calculation
          if (_enableVat)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(defaultPadding),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'VAT Calculation Example:',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: defaultPadding / 2),
                    
                    FutureBuilder<double>(
                      future: Future.value(double.tryParse(_vatRateController.text) ?? 16.0),
                      builder: (context, snapshot) {
                        final vatRate = snapshot.data ?? 16.0;
                        final grossAmount = 1000.0;
                        final vatAmount = grossAmount * (vatRate / (100 + vatRate));
                        final netAmount = grossAmount - vatAmount;
                        
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('For a sale of KSH ${grossAmount.toStringAsFixed(2)} (tax-inclusive):'),
                            const SizedBox(height: 4),
                            Text('• VAT ($vatRate%): KSH ${vatAmount.toStringAsFixed(2)}'),
                            Text('• Net Amount: KSH ${netAmount.toStringAsFixed(2)}'),
                          ],
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
          
          const SizedBox(height: defaultPadding * 2),
          
          // Save button
          Center(
            child: ElevatedButton.icon(
              onPressed: _saveTaxSettings,
              icon: const Icon(Icons.save),
              label: const Text('Save Tax Settings'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: defaultPadding * 2,
                  vertical: defaultPadding,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReceiptSettingsTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(defaultPadding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Receipt Settings',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: defaultPadding),
          const Text(
            'Customize how your receipts appear to customers.',
            style: TextStyle(fontSize: 14),
          ),
          const SizedBox(height: defaultPadding),
          
          // Receipt Header
          TextField(
            controller: _receiptHeaderController,
            maxLines: 2,
            decoration: const InputDecoration(
              labelText: 'Receipt Header',
              border: OutlineInputBorder(),
              hintText: 'Text to appear at the top of receipts',
            ),
          ),
          const SizedBox(height: defaultPadding),
          
          // Receipt Footer
          TextField(
            controller: _receiptFooterController,
            maxLines: 2,
            decoration: const InputDecoration(
              labelText: 'Receipt Footer',
              border: OutlineInputBorder(),
              hintText: 'Text to appear at the bottom of receipts',
            ),
          ),
          const SizedBox(height: defaultPadding),
          
          // Date & Time Format
          TextField(
            controller: _dateTimeFormatController,
            decoration: const InputDecoration(
              labelText: 'Date & Time Format',
              border: OutlineInputBorder(),
              hintText: 'Example: dd/MM/yyyy HH:mm',
              helperText: 'Format: dd=day, MM=month, yyyy=year, HH=hour, mm=minute',
            ),
          ),
          const SizedBox(height: defaultPadding),
          
          // Show business logo
          SwitchListTile(
            title: const Text('Show Business Logo'),
            subtitle: const Text('Print your business logo on receipts'),
            value: _showBusinessLogo,
            onChanged: (value) {
              setState(() {
                _showBusinessLogo = value;
              });
            },
          ),
          
          // Show cashier name
          SwitchListTile(
            title: const Text('Show Cashier Name'),
            subtitle: const Text('Print the name of the cashier on receipts'),
            value: _showCashierName,
            onChanged: (value) {
              setState(() {
                _showCashierName = value;
              });
            },
          ),
          
          // Add No Returns Policy toggle
          SwitchListTile(
            title: const Text('No Returns Policy'),
            subtitle: const Text('Include "Goods once sold are not returnable" on receipts'),
            value: _showNoReturnsPolicy,
            onChanged: (value) {
              setState(() {
                _showNoReturnsPolicy = value;
              });
            },
          ),
          
          const SizedBox(height: defaultPadding * 2),
          
          // Save button
          Center(
            child: ElevatedButton.icon(
              onPressed: _saveReceiptSettings,
              icon: const Icon(Icons.save),
              label: const Text('Save Receipt Settings'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: defaultPadding * 2,
                  vertical: defaultPadding,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLicenseTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(defaultPadding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'License Information',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: defaultPadding),
          
          // License status card
          Card(
            child: Padding(
              padding: const EdgeInsets.all(defaultPadding),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        _isLicensed ? Icons.verified_user : Icons.timer,
                        size: 48,
                        color: _isLicensed ? Colors.green : 
                               (_daysRemaining > 3 ? Colors.orange : Colors.red),
                      ),
                      const SizedBox(width: defaultPadding),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _isLicensed ? 'Licensed Version' : 'Trial Version',
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(_licenseStatusMessage),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: defaultPadding * 2),
          
          // License key entry
          if (!_isLicensed)
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Enter License Key',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: defaultPadding / 2),
                const Text(
                  'Enter your license key to activate the full version of the software.',
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
                const SizedBox(height: defaultPadding),
                Center(
                  child: ElevatedButton.icon(
                    onPressed: _isSubmittingLicense ? null : _applyLicenseKey,
                    icon: _isSubmittingLicense 
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.0,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.check_circle),
                    label: const Text('Activate License'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: defaultPadding * 2,
                        vertical: defaultPadding,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          
          if (!_isLicensed)
            Column(
              children: [
                const SizedBox(height: defaultPadding * 2),
                const Divider(),
                const SizedBox(height: defaultPadding),
                const Text(
                  'Need a license?',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: defaultPadding / 2),
                const Text(
                  'Contact our support team to purchase a license:',
                ),
                const SizedBox(height: defaultPadding / 2),
                const Text(
                  'Email: malbrosepos@gmail.com',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Phone: +254 748322954',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ],
          ),
        ],
      ),
    );
  }

  // Security tab
  Widget _buildSecurityTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Security Settings',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          
          // SSL/TLS Settings
          Card(
            elevation: 2,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'SSL/TLS Configuration',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  
                  // Import certificate option
                  ElevatedButton.icon(
                    icon: const Icon(Icons.security),
                    label: const Text('Import SSL Certificate'),
                    onPressed: _importSSLCertificate,
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // Development mode toggle for testing
                  FutureBuilder<bool?>(
                    future: ConfigService.instance.getBoolean('dev_mode'),
                    builder: (context, snapshot) {
                      final devMode = snapshot.data ?? false;
                      return SwitchListTile(
                        title: const Text('Development Mode'),
                        subtitle: const Text('Allows self-signed certificates (not secure for production)'),
                        value: devMode,
                        onChanged: (value) async {
                          await ConfigService.instance.setBoolean('dev_mode', value);
                          await _restartSSLService(value);
                          setState(() {});
                        },
                      );
                    },
                  ),
                  
                  const SizedBox(height: 8),
                  
                  // Information about the current configuration
                  FutureBuilder<bool?>(
                    future: ConfigService.instance.getBoolean('dev_mode'),
                    builder: (context, snapshot) {
                      final devMode = snapshot.data ?? false;
                      return Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: devMode ? Colors.amber.shade100 : Colors.green.shade100,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              devMode ? Icons.warning : Icons.check_circle,
                              color: devMode ? Colors.orange : Colors.green,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                devMode 
                                  ? 'Your app is in development mode with reduced security. Not recommended for production.'
                                  : 'Your app is using secure SSL/TLS configuration for network communications.',
                                style: TextStyle(
                                  color: devMode ? Colors.orange.shade800 : Colors.green.shade800,
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
          
          const SizedBox(height: 16),
          
          // Data Encryption Settings
          Card(
            elevation: 2,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Data Encryption',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  
                  // Implement encryption features later
                  const Text('Enhanced data encryption features will be available in a future update.'),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  Future<void> _importSSLCertificate() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pem', 'crt', 'cer'],
        allowMultiple: false,
      );
      
      if (result != null && result.files.isNotEmpty) {
        final file = File(result.files.first.path!);
        final certData = await file.readAsString();
        
        // Import the certificate using SSLService
        final success = await SSLService.instance.addTrustedCertificate(certData);
        
        if (success) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('SSL certificate imported successfully'),
              backgroundColor: Colors.green,
            ),
          );
        } else {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Failed to import SSL certificate'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error importing certificate: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
  
  Future<void> _restartSSLService(bool devMode) async {
    try {
      await SSLService.instance.initialize(developmentMode: devMode);
      
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('SSL service restarted in ${devMode ? "development" : "production"} mode'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error restarting SSL service: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
} 