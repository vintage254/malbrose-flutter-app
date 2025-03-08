import 'package:flutter/material.dart';
import 'package:my_flutter_app/services/config_service.dart';
import 'package:my_flutter_app/services/database.dart';
import 'package:my_flutter_app/screens/login_screen.dart';

class SetupWizardScreen extends StatefulWidget {
  const SetupWizardScreen({super.key});

  @override
  State<SetupWizardScreen> createState() => _SetupWizardScreenState();
}

class _SetupWizardScreenState extends State<SetupWizardScreen> {
  final _formKey = GlobalKey<FormState>();
  final _pageController = PageController();
  int _currentPage = 0;
  bool _isLoading = false;
  String _statusMessage = '';
  
  // Configuration options
  bool _isMaster = false;
  final _masterIpController = TextEditingController();
  final _dbPortController = TextEditingController(text: '3306');
  final _dbUsernameController = TextEditingController(text: 'root');
  final _dbPasswordController = TextEditingController();
  final _dbNameController = TextEditingController(text: 'malbrose_pos');
  
  // Business information
  final _businessNameController = TextEditingController(text: 'Malbrose Hardware Store');
  final _businessAddressController = TextEditingController(text: 'Eldoret');
  final _businessPhoneController = TextEditingController(text: '0720319340, 0721705613');
  final _businessEmailController = TextEditingController();
  
  // Admin user information
  final _adminUsernameController = TextEditingController(text: 'admin');
  final _adminPasswordController = TextEditingController();
  final _adminConfirmPasswordController = TextEditingController();
  final _adminFullNameController = TextEditingController(text: 'System Administrator');
  final _adminEmailController = TextEditingController(text: 'admin@example.com');
  
  @override
  void initState() {
    super.initState();
    _loadInitialValues();
  }
  
  @override
  void dispose() {
    _pageController.dispose();
    _masterIpController.dispose();
    _dbPortController.dispose();
    _dbUsernameController.dispose();
    _dbPasswordController.dispose();
    _dbNameController.dispose();
    _businessNameController.dispose();
    _businessAddressController.dispose();
    _businessPhoneController.dispose();
    _businessEmailController.dispose();
    _adminUsernameController.dispose();
    _adminPasswordController.dispose();
    _adminConfirmPasswordController.dispose();
    _adminFullNameController.dispose();
    _adminEmailController.dispose();
    super.dispose();
  }
  
  Future<void> _loadInitialValues() async {
    setState(() {
      _isLoading = true;
    });
    
    try {
      final configService = ConfigService.instance;
      await configService.initialize();
      
      setState(() {
        _isMaster = configService.isMaster;
        _masterIpController.text = configService.masterIp;
        _dbPortController.text = configService.dbPort.toString();
        _dbUsernameController.text = configService.dbUsername;
        _dbPasswordController.text = configService.dbPassword;
        _dbNameController.text = configService.dbName;
        _businessNameController.text = configService.businessName;
        _businessAddressController.text = configService.businessAddress;
        _businessPhoneController.text = configService.businessPhone;
        _businessEmailController.text = configService.businessEmail;
      });
      
      if (configService.setupCompleted) {
        // If setup is already completed, navigate to login screen
        if (mounted) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (context) => const LoginScreen()),
          );
        }
      }
    } catch (e) {
      setState(() {
        _statusMessage = 'Error loading configuration: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }
  
  void _nextPage() {
    if (_currentPage < 3) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }
  
  void _previousPage() {
    if (_currentPage > 0) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }
  
  Future<void> _finishSetup() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    
    setState(() {
      _isLoading = true;
      _statusMessage = 'Setting up your system...';
    });
    
    try {
      final configService = ConfigService.instance;
      
      // Save configuration
      configService.isMaster = _isMaster;
      configService.masterIp = _masterIpController.text;
      configService.dbPort = int.parse(_dbPortController.text);
      configService.dbUsername = _dbUsernameController.text;
      configService.dbPassword = _dbPasswordController.text;
      configService.dbName = _dbNameController.text;
      configService.businessName = _businessNameController.text;
      configService.businessAddress = _businessAddressController.text;
      configService.businessPhone = _businessPhoneController.text;
      configService.businessEmail = _businessEmailController.text;
      
      // Test database connection
      final isConnected = await configService.testDatabaseConnection();
      if (!isConnected) {
        setState(() {
          _isLoading = false;
          _statusMessage = 'Failed to connect to the database. Please check your settings.';
        });
        return;
      }
      
      // Initialize database
      await DatabaseService.instance.database;
      
      // Create admin user if this is a master setup
      if (_isMaster && _adminPasswordController.text.isNotEmpty) {
        await DatabaseService.instance.createAdminUser(
          _adminUsernameController.text,
          _adminPasswordController.text,
          _adminFullNameController.text,
          _adminEmailController.text,
        );
      }
      
      // Mark setup as completed
      configService.setupCompleted = true;
      
      setState(() {
        _statusMessage = 'Setup completed successfully!';
      });
      
      // Navigate to login screen
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => const LoginScreen()),
        );
      }
    } catch (e) {
      setState(() {
        _statusMessage = 'Error during setup: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }
  
  Future<void> _detectLocalIp() async {
    setState(() {
      _isLoading = true;
      _statusMessage = 'Detecting local IP address...';
    });
    
    try {
      final configService = ConfigService.instance;
      final localIp = await configService.getLocalIpAddress();
      
      setState(() {
        _masterIpController.text = localIp;
        _statusMessage = 'Local IP detected: $localIp';
      });
    } catch (e) {
      setState(() {
        _statusMessage = 'Error detecting local IP: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Malbrose POS Setup Wizard'),
        centerTitle: true,
      ),
      body: Form(
        key: _formKey,
        child: Column(
          children: [
            LinearProgressIndicator(
              value: (_currentPage + 1) / 4,
              backgroundColor: Colors.grey[300],
              valueColor: AlwaysStoppedAnimation<Color>(Theme.of(context).primaryColor),
            ),
            if (_isLoading)
              const LinearProgressIndicator(),
            if (_statusMessage.isNotEmpty)
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: Text(
                  _statusMessage,
                  style: TextStyle(
                    color: _statusMessage.contains('Error') ? Colors.red : Colors.green,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            Expanded(
              child: PageView(
                controller: _pageController,
                onPageChanged: (page) {
                  setState(() {
                    _currentPage = page;
                  });
                },
                children: [
                  _buildWelcomePage(),
                  _buildDatabaseSetupPage(),
                  _buildBusinessInfoPage(),
                  _buildAdminUserPage(),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  if (_currentPage > 0)
                    ElevatedButton(
                      onPressed: _previousPage,
                      child: const Text('Previous'),
                    )
                  else
                    const SizedBox(),
                  if (_currentPage < 3)
                    ElevatedButton(
                      onPressed: _nextPage,
                      child: const Text('Next'),
                    )
                  else
                    ElevatedButton(
                      onPressed: _isLoading ? null : _finishSetup,
                      child: const Text('Finish Setup'),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildWelcomePage() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const SizedBox(height: 20),
          const Icon(
            Icons.store,
            size: 80,
            color: Colors.blue,
          ),
          const SizedBox(height: 20),
          const Text(
            'Welcome to Malbrose POS System',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          const Text(
            'This wizard will help you set up your POS system for the first time. '
            'You will need to configure the database connection, business information, '
            'and create an admin user.',
            style: TextStyle(fontSize: 16),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 40),
          const Text(
            'Before you begin, please decide if this computer will be:',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Expanded(
                child: RadioListTile<bool>(
                  title: const Text(
                    'Server (Master)',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: const Text(
                    'This computer will host the database for all other computers',
                  ),
                  value: true,
                  groupValue: _isMaster,
                  onChanged: (value) {
                    setState(() {
                      _isMaster = value!;
                    });
                  },
                ),
              ),
              Expanded(
                child: RadioListTile<bool>(
                  title: const Text(
                    'Client (Slave)',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: const Text(
                    'This computer will connect to a server computer',
                  ),
                  value: false,
                  groupValue: _isMaster,
                  onChanged: (value) {
                    setState(() {
                      _isMaster = value!;
                    });
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
  
  Widget _buildDatabaseSetupPage() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Database Configuration',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 20),
          if (_isMaster)
            const Text(
              'This computer will host the database. Other computers will connect to this one.',
              style: TextStyle(fontSize: 16),
            )
          else
            const Text(
              'Enter the IP address of the server computer that hosts the database.',
              style: TextStyle(fontSize: 16),
            ),
          const SizedBox(height: 20),
          if (!_isMaster)
            TextFormField(
              controller: _masterIpController,
              decoration: InputDecoration(
                labelText: 'Server IP Address',
                hintText: 'e.g., 192.168.1.100',
                border: const OutlineInputBorder(),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.network_wifi),
                  onPressed: _detectLocalIp,
                  tooltip: 'Detect Local IP',
                ),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter the server IP address';
                }
                return null;
              },
            ),
          if (!_isMaster)
            const SizedBox(height: 20),
          TextFormField(
            controller: _dbPortController,
            decoration: const InputDecoration(
              labelText: 'Database Port',
              hintText: 'Default: 3306',
              border: OutlineInputBorder(),
            ),
            keyboardType: TextInputType.number,
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Please enter the database port';
              }
              if (int.tryParse(value) == null) {
                return 'Please enter a valid port number';
              }
              return null;
            },
          ),
          const SizedBox(height: 20),
          TextFormField(
            controller: _dbUsernameController,
            decoration: const InputDecoration(
              labelText: 'Database Username',
              hintText: 'Default: root',
              border: OutlineInputBorder(),
            ),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Please enter the database username';
              }
              return null;
            },
          ),
          const SizedBox(height: 20),
          TextFormField(
            controller: _dbPasswordController,
            decoration: const InputDecoration(
              labelText: 'Database Password',
              border: OutlineInputBorder(),
            ),
            obscureText: true,
          ),
          const SizedBox(height: 20),
          TextFormField(
            controller: _dbNameController,
            decoration: const InputDecoration(
              labelText: 'Database Name',
              hintText: 'Default: malbrose_pos',
              border: OutlineInputBorder(),
            ),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Please enter the database name';
              }
              return null;
            },
          ),
          const SizedBox(height: 20),
          if (_isMaster)
            const Text(
              'Note: If you are setting up as a server, make sure MySQL is installed and running on this computer.',
              style: TextStyle(
                fontSize: 14,
                fontStyle: FontStyle.italic,
                color: Colors.red,
              ),
            ),
        ],
      ),
    );
  }
  
  Widget _buildBusinessInfoPage() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
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
          const SizedBox(height: 20),
          const Text(
            'Enter your business details that will appear on receipts and reports.',
            style: TextStyle(fontSize: 16),
          ),
          const SizedBox(height: 20),
          TextFormField(
            controller: _businessNameController,
            decoration: const InputDecoration(
              labelText: 'Business Name',
              border: OutlineInputBorder(),
            ),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Please enter your business name';
              }
              return null;
            },
          ),
          const SizedBox(height: 20),
          TextFormField(
            controller: _businessAddressController,
            decoration: const InputDecoration(
              labelText: 'Business Address',
              border: OutlineInputBorder(),
            ),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Please enter your business address';
              }
              return null;
            },
          ),
          const SizedBox(height: 20),
          TextFormField(
            controller: _businessPhoneController,
            decoration: const InputDecoration(
              labelText: 'Business Phone',
              border: OutlineInputBorder(),
            ),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Please enter your business phone';
              }
              return null;
            },
          ),
          const SizedBox(height: 20),
          TextFormField(
            controller: _businessEmailController,
            decoration: const InputDecoration(
              labelText: 'Business Email (Optional)',
              border: OutlineInputBorder(),
            ),
            keyboardType: TextInputType.emailAddress,
          ),
          const SizedBox(height: 20),
          const Text(
            'Note: You can update this information later in the settings.',
            style: TextStyle(
              fontSize: 14,
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildAdminUserPage() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Admin User Setup',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 20),
          if (_isMaster)
            const Text(
              'Create an administrator account for the system.',
              style: TextStyle(fontSize: 16),
            )
          else
            const Text(
              'As a client, you will use the admin credentials created on the server.',
              style: TextStyle(fontSize: 16),
            ),
          const SizedBox(height: 20),
          if (_isMaster) ...[
            TextFormField(
              controller: _adminUsernameController,
              decoration: const InputDecoration(
                labelText: 'Admin Username',
                border: OutlineInputBorder(),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter an admin username';
                }
                return null;
              },
            ),
            const SizedBox(height: 20),
            TextFormField(
              controller: _adminPasswordController,
              decoration: const InputDecoration(
                labelText: 'Admin Password',
                border: OutlineInputBorder(),
              ),
              obscureText: true,
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter an admin password';
                }
                if (value.length < 6) {
                  return 'Password must be at least 6 characters';
                }
                return null;
              },
            ),
            const SizedBox(height: 20),
            TextFormField(
              controller: _adminConfirmPasswordController,
              decoration: const InputDecoration(
                labelText: 'Confirm Password',
                border: OutlineInputBorder(),
              ),
              obscureText: true,
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please confirm the password';
                }
                if (value != _adminPasswordController.text) {
                  return 'Passwords do not match';
                }
                return null;
              },
            ),
            const SizedBox(height: 20),
            TextFormField(
              controller: _adminFullNameController,
              decoration: const InputDecoration(
                labelText: 'Full Name',
                border: OutlineInputBorder(),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter the admin\'s full name';
                }
                return null;
              },
            ),
            const SizedBox(height: 20),
            TextFormField(
              controller: _adminEmailController,
              decoration: const InputDecoration(
                labelText: 'Email',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.emailAddress,
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter an email address';
                }
                if (!value.contains('@')) {
                  return 'Please enter a valid email address';
                }
                return null;
              },
            ),
          ] else
            const Text(
              'You will need to log in using the admin credentials created on the server computer.',
              style: TextStyle(
                fontSize: 16,
                fontStyle: FontStyle.italic,
              ),
            ),
          const SizedBox(height: 20),
          const Text(
            'Note: You can create additional users after logging in as an administrator.',
            style: TextStyle(
              fontSize: 14,
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ),
    );
  }
} 