import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:my_flutter_app/services/backup_service.dart';
import 'package:file_picker/file_picker.dart';
import 'package:my_flutter_app/services/database.dart';
import 'package:my_flutter_app/services/machine_config_service.dart';
import 'package:my_flutter_app/models/sync_log_model.dart';
import 'package:provider/provider.dart';
import '../services/master_discovery_service.dart';
import 'master_discovery_screen.dart';
import 'package:my_flutter_app/widgets/app_scaffold.dart';

class BackupScreen extends StatefulWidget {
  static const String routeName = '/backup';
  
  const BackupScreen({Key? key}) : super(key: key);

  @override
  State<BackupScreen> createState() => _BackupScreenState();
}

class _BackupScreenState extends State<BackupScreen> with SingleTickerProviderStateMixin {
  final DatabaseService _databaseService = DatabaseService.instance;
  final MachineConfigService _machineConfigService = MachineConfigService.instance;
  final BackupService _backupService = BackupService.instance;
  
  // Backup state
  List<FileSystemEntity> _backups = [];
  List<String> _allTables = [];
  List<String> _selectedTables = [];
  List<String> _batchSelectedBackups = [];
  bool _isLoading = false;
  String _statusMessage = '';
  bool _isInBatchDeleteMode = false;
  Map<String, int> _tableRowCounts = {};
  
  // Machine configuration state
  MachineRole _machineRole = MachineRole.single;
  String _masterAddress = '';
  SyncFrequency _syncFrequency = SyncFrequency.manual;
  String _conflictResolution = 'last_write_wins';
  bool _isSyncing = false;
  String _syncStatus = '';
  DateTime? _lastSyncTime;
  
  // Company profile state
  List<Map<String, dynamic>> _companyProfiles = [];
  Map<String, dynamic>? _currentCompany;
  
  // Advanced backup settings
  bool _autoBackupEnabled = false;
  String _autoBackupInterval = 'daily';
  bool _encryptBackups = false;
  
  // Controllers
  late TabController _tabController;
  final TextEditingController _masterAddressController = TextEditingController();
  final TextEditingController _backupNameController = TextEditingController();
  
  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadBackups();
    _loadTables();
    _loadMachineConfig();
  }
  
  @override
  void dispose() {
    _tabController.dispose();
    _masterAddressController.dispose();
    _backupNameController.dispose();
    super.dispose();
  }
  
  Future<void> _loadMachineConfig() async {
    setState(() {
      _isLoading = true;
      _statusMessage = 'Loading machine configuration...';
    });
    
    try {
      _machineRole = await _machineConfigService.getMachineRole();
      _masterAddress = await _machineConfigService.getMasterAddress();
      _syncFrequency = await _machineConfigService.getSyncFrequency();
      _conflictResolution = await _machineConfigService.getConflictResolution();
      _lastSyncTime = await _machineConfigService.getLastSyncTime();
      _companyProfiles = await _machineConfigService.getCompanyProfiles();
      _currentCompany = await _machineConfigService.getCurrentCompany();
      
      _masterAddressController.text = _masterAddress;
      
      setState(() {
        _isLoading = false;
        _statusMessage = '';
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _statusMessage = 'Error loading machine configuration: $e';
      });
    }
  }
  
  void _saveMachineRole(MachineRole role) async {
    setState(() {
      _isLoading = true;
      _statusMessage = 'Saving machine role...';
    });
    
    try {
      // If switching to servant mode, scan for master devices first
      if (role == MachineRole.servant) {
      setState(() {
          _statusMessage = 'Scanning network for master devices...';
        });
        
        // Scan for master devices on the network
        final masterAddresses = await _machineConfigService.scanForMasters();
        
        if (masterAddresses.isEmpty) {
          // No master found - prevent switch
      setState(() {
            _isLoading = false;
            _statusMessage = 'No master device found on the network. Please ensure the master device is active and try again.';
      });
          return;
        } else if (masterAddresses.length > 1) {
          // Multiple masters found - prevent switch
      setState(() {
        _isLoading = false;
            _statusMessage = 'Multiple master devices detected (${masterAddresses.join(", ")}). Please resolve the conflict and try again.';
          });
          return;
        } else {
          // Single master found - connect to it
          final masterAddress = masterAddresses.first;
          _masterAddressController.text = masterAddress;
          await _machineConfigService.setMasterAddress(masterAddress);
          setState(() {
            _masterAddress = masterAddress;
            _statusMessage = 'Found and connected to master at $masterAddress';
      });
    }
  }
  
      // Save the machine role
      await _machineConfigService.setMachineRole(role);
      setState(() {
        _machineRole = role;
        _isLoading = false;
        _statusMessage = role == MachineRole.servant 
            ? 'Machine role set to servant, connected to master at $_masterAddress' 
            : 'Machine role set to ${role.toString().split('.').last}';
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _statusMessage = 'Error changing machine role: $e';
      });
    }
  }

  void _saveMasterAddress() async {
    if (_masterAddressController.text.isEmpty) {
        setState(() {
        _statusMessage = 'Master address cannot be empty';
        });
        return;
      }
      
      setState(() {
        _isLoading = true;
      _statusMessage = 'Saving master address...';
      });
      
    try {
      await _machineConfigService.setMasterAddress(_masterAddressController.text);
      setState(() {
        _masterAddress = _masterAddressController.text;
        _isLoading = false;
        _statusMessage = 'Master address saved';
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _statusMessage = 'Error saving master address: $e';
      });
    }
  }

  void _saveSyncFrequency(SyncFrequency frequency) async {
      setState(() {
        _isLoading = true;
      _statusMessage = 'Saving sync frequency...';
      });
      
    try {
      await _machineConfigService.setSyncFrequency(frequency);
      setState(() {
        _syncFrequency = frequency;
        _isLoading = false;
        _statusMessage = 'Sync frequency saved';
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _statusMessage = 'Error saving sync frequency: $e';
      });
    }
  }

  void _saveConflictResolution(String resolution) async {
      setState(() {
        _isLoading = true;
      _statusMessage = 'Saving conflict resolution strategy...';
    });
    
    try {
      await _machineConfigService.setConflictResolution(resolution);
      setState(() {
        _conflictResolution = resolution;
        _isLoading = false;
        _statusMessage = 'Conflict resolution strategy saved';
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _statusMessage = 'Error saving conflict resolution strategy: $e';
      });
    }
  }

  void _testMasterConnection() async {
    if (_masterAddressController.text.isEmpty) {
      setState(() {
        _statusMessage = 'Master address cannot be empty';
      });
      return;
    }
    
    setState(() {
      _isSyncing = true;
      _syncStatus = 'Testing connection...';
    });
    
    try {
      final success = await _machineConfigService.testConnection(_masterAddressController.text);
      setState(() {
        _isSyncing = false;
        _syncStatus = success 
            ? 'Connection successful!' 
            : 'Connection failed. Please check the address and try again.';
      });
    } catch (e) {
      setState(() {
        _isSyncing = false;
        _syncStatus = 'Error testing connection: $e';
      });
    }
  }
  
  void _syncWithMaster() async {
    if (_masterAddress.isEmpty) {
      setState(() {
        _syncStatus = 'Master address is not set';
      });
      return;
    }
    
    setState(() {
      _isSyncing = true;
      _syncStatus = 'Syncing with master...';
    });
    
    try {
      final result = await _machineConfigService.syncWithMaster();
      final now = DateTime.now();
      await _machineConfigService.setLastSyncTime(now);
      
      setState(() {
        _isSyncing = false;
        _lastSyncTime = now;
        _syncStatus = result['success'] 
            ? 'Sync completed successfully' 
            : 'Sync failed: ${result['message']}';
      });
      
      // Refresh backups after sync
      await _loadBackups();
    } catch (e) {
      setState(() {
        _isSyncing = false;
        _syncStatus = 'Error during sync: $e';
      });
    }
  }
  
  void _saveBackupSettings() async {
    setState(() {
      _isLoading = true;
      _statusMessage = 'Saving backup settings...';
    });
    
    try {
      await _machineConfigService.saveBackupSettings(
        autoBackupEnabled: _autoBackupEnabled,
        autoBackupInterval: _autoBackupInterval,
        encryptBackups: _encryptBackups,
      );
      
    setState(() {
        _isLoading = false;
        _statusMessage = 'Backup settings saved successfully';
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _statusMessage = 'Error saving backup settings: $e';
      });
    }
  }
  
  void _showCreateNewCompanyDialog() {
    final nameController = TextEditingController();
    final dbNameController = TextEditingController();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Create New Company'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: nameController,
              decoration: const InputDecoration(
                labelText: 'Company Name',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: dbNameController,
              decoration: const InputDecoration(
                labelText: 'Database Name',
                border: OutlineInputBorder(),
                hintText: 'e.g., company_name_db',
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
            onPressed: () {
              if (nameController.text.isEmpty || dbNameController.text.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Both fields are required')),
                );
                return;
              }
              
              Navigator.pop(context);
              _createNewCompany(nameController.text, dbNameController.text);
            },
            child: const Text('Create'),
          ),
        ],
      ),
    );
    }
    
  void _createNewCompany(String name, String dbName) async {
    setState(() {
      _isLoading = true;
      _statusMessage = 'Creating new company...';
    });
    
    try {
      final newProfile = await _machineConfigService.createCompanyProfile(
        name: name,
        database: dbName,
      );
      
      setState(() {
        _companyProfiles.add(newProfile);
        _isLoading = false;
        _statusMessage = 'New company created successfully';
      });
      
      // Switch to the new company
      _switchCompany(name);
    } catch (e) {
      setState(() {
        _isLoading = false;
        _statusMessage = 'Error creating new company: $e';
      });
    }
  }
  
  void _switchCompany(String companyName) async {
    final company = _companyProfiles.firstWhere(
      (profile) => profile['name'] == companyName,
      orElse: () => <String, dynamic>{},
    );
    
    if (company.isEmpty) {
        setState(() {
        _statusMessage = 'Company not found';
        });
        return;
      }
      
      setState(() {
        _isLoading = true;
      _statusMessage = 'Switching to company: $companyName';
      });
      
    try {
      await _databaseService.switchDatabase(company['database']);
      await _machineConfigService.setCurrentCompany(company);
      
      setState(() {
        _currentCompany = company;
        _isLoading = false;
        _statusMessage = 'Switched to company: $companyName';
      });
      
      // Reload backups and tables for the new database
      await _loadBackups();
      await _loadTables();
    } catch (e) {
      setState(() {
        _isLoading = false;
        _statusMessage = 'Error switching company: $e';
      });
    }
  }
  
  Future<void> _loadTables() async {
    try {
      final tables = await BackupService.instance.getTableNames();
      
      final rowCounts = <String, int>{};
      for (final table in tables) {
        rowCounts[table] = await BackupService.instance.getTableRowCount(table);
      }
      
      setState(() {
        _allTables = tables;
        _selectedTables = tables;
        _tableRowCounts = rowCounts;
      });
    } catch (e) {
      setState(() {
        _statusMessage = 'Error loading tables: $e';
      });
    }
  }
  
  Future<void> _loadBackups() async {
    setState(() {
      _isLoading = true;
      _statusMessage = '';
    });
    
    try {
      final backups = await BackupService.instance.listBackups();
      setState(() {
        _backups = backups;
      });
    } catch (e) {
      setState(() {
        _statusMessage = 'Error loading backups: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'Backup',
      body: Column(
        children: [
          Expanded(
            child: _buildMainContent(),
          ),
          ],
      ),
    );
  }
  
  Widget _buildMainContent() {
    // Check if this machine is configured as a master or single instance
    if (_machineRole == MachineRole.master || _machineRole == MachineRole.single) {
      // This device is a master, show backup form directly
      return _buildBackupFormForMaster();
    }
    
    // For servants, handle master discovery more gracefully
    if (_machineRole == MachineRole.servant) {
      return _buildServantDiscoveryUI();
    }
    
    // Fallback for unconfigured devices
    return _buildRoleSelectionUI();
  }
  
  Widget _buildConnectionPrompt() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.link_off,
            size: 72,
            color: Colors.grey.shade300,
                  ),
          const SizedBox(height: 16),
          Text(
            'Connect to a Master',
                style: TextStyle(
              fontSize: 24,
                  fontWeight: FontWeight.bold,
              color: Colors.grey.shade800,
            ),
          ),
          const SizedBox(height: 8),
                          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
                          child: Text(
              'You need to connect to a master device before you can perform a backup.',
              textAlign: TextAlign.center,
                            style: TextStyle(
                color: Colors.grey.shade600,
                            ),
                          ),
                        ),
          const SizedBox(height: 32),
                                    ElevatedButton.icon(
            icon: const Icon(Icons.search),
            label: const Text('Find Master'),
                                      style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(
                horizontal: 24,
                vertical: 12,
                  ),
                ),
                    onPressed: () {
              Navigator.of(context).pushNamed(MasterDiscoveryScreen.routeName);
                    },
                  ),
          const SizedBox(height: 16),
                  TextButton(
            child: const Text('Learn More'),
                    onPressed: () {
              // Show help dialog or navigate to help page
                    },
                  ),
                ],
              ),
    );
  }
  
  Widget _buildBackupForm() {
    MasterDiscoveryService? discoveryService;
    
    try {
      discoveryService = Provider.of<MasterDiscoveryService>(context, listen: false);
    } catch (e) {
      // If provider is not available, fallback to a default UI
      return Center(
        child: Text('Could not connect to the master service. Please restart the app.'),
      );
    }
    
    final master = discoveryService.selectedMaster;
    if (master == null) {
      return _buildConnectionPrompt();
    }
    
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Master information card
          Card(
            margin: const EdgeInsets.only(bottom: 24),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                    Container(
                    width: 48,
                    height: 48,
                      decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(24),
                                    ),
                    child: Center(
                      child: Icon(
                        Icons.computer,
                        color: Theme.of(context).colorScheme.primary,
                                    ),
                                  ),
                                ),
                              const SizedBox(width: 16),
                                  Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                        Text(
                          'Connected to Master',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                            color: Colors.grey.shade600,
                            fontSize: 14,
                          ),
                  ),
                        const SizedBox(height: 4),
                        Text(
                          master.deviceName ?? master.ip,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                          ),
                            ),
                      ],
                    ),
                  ),
                  TextButton.icon(
                    icon: const Icon(Icons.edit, size: 16),
                    label: const Text('Change'),
                    onPressed: () {
                      Navigator.of(context).pushNamed(MasterDiscoveryScreen.routeName);
                    },
                        ),
                      ],
                    ),
                  ),
          ),
          
          // Backup options and form
          // ... existing backup form code ...
        ],
                      ),
    );
  }
  
  Widget _buildBackupFormForMaster() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Master status card
          Card(
            margin: const EdgeInsets.only(bottom: 24),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: Colors.green.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: const Center(
                      child: Icon(
                        Icons.computer,
                        color: Colors.green,
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Master Device',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.grey.shade600,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'This device is configured as a master',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                          ),
                        ),
                      ],
                    ),
                  ),
                  TextButton.icon(
                    icon: const Icon(Icons.settings, size: 16),
                    label: const Text('Settings'),
                    onPressed: () {
                      // Show settings dialog for master configuration
                      _showMasterSettingsDialog();
                    },
                  ),
                ],
              ),
            ),
          ),
          
          // Backup operations section
          const Text(
            'Backup Operations',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          
          // Backup buttons
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildOperationButton(
                icon: Icons.backup,
                label: 'Create Backup',
                onPressed: _createBackup,
              ),
              _buildOperationButton(
                icon: Icons.restore,
                label: 'Import Backup',
                onPressed: _importBackup,
              ),
              _buildOperationButton(
                icon: Icons.download,
                label: 'Export Backup',
                onPressed: _exportBackup,
              ),
            ],
          ),
          
          const SizedBox(height: 24),
          
          // CSV Export Section
          const Text(
            'CSV Export',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Export database tables as CSV files for use in Excel or other applications',
            style: TextStyle(
              color: Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 16),
          
          // CSV Export options
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildOperationButton(
                icon: Icons.table_chart,
                label: 'Export Tables as CSV',
                onPressed: _showExportTablesDialog,
              ),
              _buildOperationButton(
                icon: Icons.receipt_long,
                label: 'Export Orders as CSV',
                onPressed: _exportOrdersCSV,
              ),
            ],
          ),
          
          const SizedBox(height: 24),
          
          // Status message
          if (_statusMessage.isNotEmpty)
            Container(
              padding: const EdgeInsets.all(8),
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: _statusMessage.contains('Error')
                    ? Colors.red.withOpacity(0.1)
                    : Colors.green.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                _statusMessage,
                style: TextStyle(
                  color: _statusMessage.contains('Error')
                      ? Colors.red
                      : Colors.green.shade800,
                ),
              ),
            ),
          
          // Available backups list
          const Text(
            'Available Backups',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          
          // Show backups list or empty state
          _backups.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32.0),
                    child: Column(
                      children: [
                        Icon(
                          Icons.backup_outlined,
                          size: 64,
                          color: Colors.grey.shade400,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No backups available',
                          style: TextStyle(
                            color: Colors.grey.shade600,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 8),
                        ElevatedButton(
                          onPressed: _createBackup,
                          child: const Text('Create First Backup'),
                        ),
                      ],
                    ),
                  ),
                )
              : ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _backups.length,
                  itemBuilder: (context, index) {
                    final backup = _backups[index];
                    final fileName = basename(backup.path);
                    final modifiedDate = backup.statSync().modified;
                    final fileSize = backup.statSync().size;
                    final fileSizeFormatted = _formatFileSize(fileSize);
                    
                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        leading: const Icon(Icons.backup, color: Colors.blue),
                        title: Text(fileName),
                        subtitle: Text(
                          'Size: $fileSizeFormatted\nCreated: ${DateFormat('yyyy-MM-dd HH:mm:ss').format(modifiedDate)}',
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.restore),
                              tooltip: 'Restore',
                              onPressed: () => _restoreBackup(backup.path),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete),
                              tooltip: 'Delete',
                              onPressed: () => _deleteBackup(backup.path),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ],
      ),
    );
  }
  
  Widget _buildOperationButton({
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
  }) {
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon),
          const SizedBox(height: 8),
          Text(label),
        ],
      ),
    );
  }
  
  void _showMasterSettingsDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Master Device Settings'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Configure your master device settings:'),
            const SizedBox(height: 16),
            
            // Machine role selection
            const Text('Machine Role:', style: TextStyle(fontWeight: FontWeight.bold)),
            DropdownButton<MachineRole>(
              value: _machineRole,
              isExpanded: true,
              onChanged: (value) {
                if (value != null) {
                  Navigator.pop(context);
                  _saveMachineRole(value);
                }
              },
              items: const [
                DropdownMenuItem(
                  value: MachineRole.master,
                  child: Text('Master - Main device that others sync with'),
                ),
                DropdownMenuItem(
                  value: MachineRole.single,
                  child: Text('Single - Standalone device (no sync)'),
                ),
                DropdownMenuItem(
                  value: MachineRole.servant,
                  child: Text('Servant - Syncs with a master device'),
                ),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
                      ),
    );
  }
  
  String _formatFileSize(int size) {
    const suffixes = ['B', 'KB', 'MB', 'GB', 'TB'];
    var i = 0;
    double formattedSize = size.toDouble();
    
    while (formattedSize > 1024 && i < suffixes.length - 1) {
      formattedSize /= 1024;
      i++;
    }
    
    return '${formattedSize.toStringAsFixed(2)} ${suffixes[i]}';
  }
  
  String basename(String path) {
    return path.split('/').last;
  }

  Future<void> _createBackup() async {
    setState(() {
      _isLoading = true;
      _statusMessage = 'Creating backup...';
    });
    
    try {
      final backupPath = await _backupService.createBackup();
      setState(() {
        _statusMessage = 'Backup created successfully';
      });
      await _loadBackups(); // Refresh backup list
    } catch (e) {
      setState(() {
        _statusMessage = 'Error creating backup: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }
  
  Future<void> _backupSelectedTables() async {
    if (_selectedTables.isEmpty) {
      setState(() {
        _statusMessage = 'Please select at least one table to backup';
      });
      return;
    }
    
    // Show dialog to get backup name
    _backupNameController.text = 'selective_backup_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}';
    
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Name Your Backup'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Enter a name for your selective backup:'),
            const SizedBox(height: 8),
            TextFormField(
              controller: _backupNameController,
              decoration: const InputDecoration(
                labelText: 'Backup Name',
                border: OutlineInputBorder(),
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
            onPressed: () => Navigator.pop(context, _backupNameController.text),
            child: const Text('Create Backup'),
          ),
        ],
      ),
    );
    
    if (result == null || result.isEmpty) {
      return; // User cancelled
    }
    
    setState(() {
      _isLoading = true;
      _statusMessage = 'Creating selective backup...';
    });
    
    try {
      final backupPath = await _backupService.backupSelectedTables(
        dbName: result,
        selectedTables: _selectedTables,
      );
      
      setState(() {
        _statusMessage = 'Selective backup created successfully';
      });
      
      await _loadBackups(); // Refresh backup list
    } catch (e) {
      setState(() {
        _statusMessage = 'Error creating selective backup: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }
  
  Future<void> _createEmptyDatabase() async {
    // Show dialog to get database name
    _backupNameController.text = 'empty_db_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}';
    
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Create Empty Database'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Enter a name for your empty database:'),
            const SizedBox(height: 8),
            TextFormField(
              controller: _backupNameController,
              decoration: const InputDecoration(
                labelText: 'Database Name',
                border: OutlineInputBorder(),
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
            onPressed: () => Navigator.pop(context, _backupNameController.text),
            child: const Text('Create'),
          ),
        ],
      ),
    );
    
    if (result == null || result.isEmpty) {
      return; // User cancelled
    }
    
    setState(() {
      _isLoading = true;
      _statusMessage = 'Creating empty database...';
    });
    
    try {
      final dbPath = await _backupService.createEmptyDatabase(result);
      
      setState(() {
        _statusMessage = 'Empty database created successfully';
      });
      
      await _loadBackups(); // Refresh backup list
    } catch (e) {
      setState(() {
        _statusMessage = 'Error creating empty database: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }
  
  Future<void> _exportBackup() async {
    // If no backups, create one first
    if (_backups.isEmpty) {
      setState(() {
        _statusMessage = 'Creating backup for export...';
        _isLoading = true;
      });
      
      try {
        await _backupService.createBackup();
        await _loadBackups();
      } catch (e) {
        setState(() {
          _statusMessage = 'Error creating backup for export: $e';
          _isLoading = false;
        });
        return;
      }
    }
    
    // If still no backups after creation attempt, there's an issue
    if (_backups.isEmpty) {
      setState(() {
        _statusMessage = 'No backups available to export';
      });
      return;
    }
    
    // Show dialog to select which backup to export
    final selectedBackup = await showDialog<FileSystemEntity>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Select Backup to Export'),
        content: Container(
          width: double.maxFinite,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Choose a backup to export:'),
              const SizedBox(height: 16),
              Container(
                height: 300,
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: _backups.length,
                  itemBuilder: (context, index) {
                    final backup = _backups[index];
                    final fileName = basename(backup.path);
                    final modifiedDate = backup.statSync().modified;
                    final fileSize = backup.statSync().size;
                    final fileSizeFormatted = _formatFileSize(fileSize);
                    
                    return ListTile(
                      leading: const Icon(Icons.backup, color: Colors.blue),
                      title: Text(fileName),
                      subtitle: Text(
                        'Size: $fileSizeFormatted\nCreated: ${DateFormat('yyyy-MM-dd HH:mm:ss').format(modifiedDate)}',
                      ),
                      onTap: () => Navigator.pop(context, backup),
                    );
                  },
                ),
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
            onPressed: () {
              // Create new backup and return it
              Navigator.pop(context, null);
            },
            child: const Text('Create New Backup'),
          ),
        ],
      ),
    );
    
    if (selectedBackup == null) {
      // User might have clicked Cancel or Create New Backup
      final wasCancel = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Export Backup'),
          content: const Text('Do you want to create a new backup for export or cancel the operation?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, true), // true means cancel
              child: const Text('Cancel Export'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, false), // false means create new
              child: const Text('Create New Backup'),
            ),
          ],
        ),
      ) ?? true; // Default to cancel if dialog is dismissed
      
      if (wasCancel) {
        if (mounted) {
          setState(() {
            _statusMessage = 'Backup export cancelled';
            _isLoading = false;
          });
        }
        return;
      }
      
      // User wants to create a new backup
      if (mounted) {
        setState(() {
          _statusMessage = 'Creating new backup for export...';
          _isLoading = true;
        });
      }
      
      try {
        // Create a new backup
        final exportPath = await _backupService.exportBackup();
        
        if (mounted) {
          setState(() {
            _statusMessage = 'Backup exported successfully to: $exportPath';
          });
        }
      } catch (e) {
        if (mounted) {
          setState(() {
            _statusMessage = 'Error exporting backup: $e';
          });
        }
      } finally {
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
      }
      return;
    }
    
    // User selected an existing backup
    if (mounted) {
      setState(() {
        _isLoading = true;
        _statusMessage = 'Exporting selected backup...';
      });
    }
    
    try {
      final exportPath = await _backupService.exportExistingBackup(selectedBackup.path);
      
      if (mounted) {
        setState(() {
          _statusMessage = 'Backup exported successfully to: $exportPath';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _statusMessage = 'Error exporting backup: $e';
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }
  
  Future<void> _importBackup() async {
    setState(() {
      _isLoading = true;
      _statusMessage = 'Selecting backup file to import...';
    });
    
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['db'],
        dialogTitle: 'Select a backup file to import',
      );
      
      if (result == null || result.files.isEmpty) {
        setState(() {
          _statusMessage = 'Import cancelled';
          _isLoading = false;
        });
        return;
      }
      
      final file = result.files.first;
      final path = file.path;
      
      if (path == null) {
        setState(() {
          _statusMessage = 'Invalid file selected';
          _isLoading = false;
        });
        return;
      }
      
      // Confirm import
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Confirm Import'),
          content: const Text(
            'Importing a backup will replace your current database. This action cannot be undone. Do you want to continue?'
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
              ),
              child: const Text('Import'),
            ),
          ],
        ),
      ) ?? false;
      
      if (!confirmed) {
        setState(() {
          _statusMessage = 'Import cancelled';
          _isLoading = false;
        });
        return;
      }
      
      setState(() {
        _statusMessage = 'Importing backup...';
      });
      
      final success = await _backupService.importBackup(path);
      
      setState(() {
        _statusMessage = success 
          ? 'Backup imported successfully' 
          : 'Error importing backup';
      });
      
      if (success) {
        await _loadBackups();
        await _loadTables();
      }
    } catch (e) {
      setState(() {
        _statusMessage = 'Error importing backup: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }
  
  Future<void> _restoreBackup(String backupPath) async {
    // Confirm restore
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Restore'),
        content: const Text(
          'Restoring a backup will replace your current database. This action cannot be undone. Do you want to continue?'
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            child: const Text('Restore'),
          ),
        ],
      ),
    ) ?? false;
    
    if (!confirmed) {
      return;
    }
    
    setState(() {
      _isLoading = true;
      _statusMessage = 'Restoring backup...';
    });
    
    try {
      final success = await _backupService.restoreBackup(backupPath);
      
      setState(() {
        _statusMessage = success 
          ? 'Backup restored successfully' 
          : 'Error restoring backup';
      });
      
      if (success) {
        await _loadTables();
      }
    } catch (e) {
      setState(() {
        _statusMessage = 'Error restoring backup: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }
  
  Future<void> _deleteBackup(String backupPath) async {
    // Confirm delete
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Delete'),
        content: const Text(
          'Are you sure you want to delete this backup? This action cannot be undone.'
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    ) ?? false;
    
    if (!confirmed) {
      return;
    }
    
    setState(() {
      _isLoading = true;
      _statusMessage = 'Deleting backup...';
    });
    
    try {
      final success = await _backupService.deleteBackup(backupPath);
      
      setState(() {
        _statusMessage = success 
          ? 'Backup deleted successfully' 
          : 'Error deleting backup';
      });
      
      if (success) {
        await _loadBackups();
      }
    } catch (e) {
      setState(() {
        _statusMessage = 'Error deleting backup: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }
  
  void _toggleBatchDeleteMode() {
    setState(() {
      _isInBatchDeleteMode = !_isInBatchDeleteMode;
      _batchSelectedBackups.clear();
    });
  }
  
  void _selectAllBackups(bool select) {
    setState(() {
      _batchSelectedBackups.clear();
      
      if (select) {
        for (final backup in _backups) {
          _batchSelectedBackups.add(backup.path);
        }
      }
    });
  }
  
  Future<void> _deleteSelectedBackups() async {
    if (_batchSelectedBackups.isEmpty) {
      setState(() {
        _statusMessage = 'No backups selected for deletion';
      });
      return;
    }
    
    // Confirm multiple delete
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Multiple Delete'),
        content: Text(
          'Are you sure you want to delete ${_batchSelectedBackups.length} backup(s)? This action cannot be undone.'
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    ) ?? false;
    
    if (!confirmed) {
      return;
    }
    
    setState(() {
      _isLoading = true;
      _statusMessage = 'Deleting multiple backups...';
    });
    
    try {
      int successCount = 0;
      int failCount = 0;
      
      for (final path in _batchSelectedBackups) {
        final success = await _backupService.deleteBackup(path);
        if (success) {
          successCount++;
        } else {
          failCount++;
        }
      }
      
      setState(() {
        if (failCount > 0) {
          _statusMessage = 'Deleted $successCount backup(s), failed to delete $failCount';
        } else {
          _statusMessage = 'Successfully deleted $successCount backup(s)';
        }
        _isInBatchDeleteMode = false;
        _batchSelectedBackups.clear();
      });
      
      await _loadBackups();
    } catch (e) {
      setState(() {
        _statusMessage = 'Error deleting backups: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }
  
  void _showResetDatabaseConfirmation(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reset Database'),
        content: const Text(
          'This will delete all data in the current database and reset it to an empty state. This action cannot be undone. Are you sure you want to continue?',
          style: TextStyle(color: Colors.red),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _resetDatabase();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Reset Database'),
          ),
        ],
      ),
    );
  }
  
  Future<void> _resetDatabase() async {
    setState(() {
      _isLoading = true;
      _statusMessage = 'Resetting database...';
    });
    
    try {
      // Create empty database with same schema
      final emptyDbPath = await _backupService.createEmptyDatabase('temp_empty_db');
      
      // Restore from empty database
      final success = await _backupService.restoreBackup(emptyDbPath);
      
      // Delete the temporary empty database
      await _backupService.deleteBackup(emptyDbPath);
      
      setState(() {
        _statusMessage = success 
          ? 'Database reset successfully' 
          : 'Error resetting database';
      });
      
      if (success) {
        await _loadTables();
      }
    } catch (e) {
      setState(() {
        _statusMessage = 'Error resetting database: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _deleteCompany(String companyName) async {
    // Confirm deletion
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Company'),
        content: Text(
          'Are you sure you want to delete "$companyName"? This will permanently delete the company profile and its database. This action cannot be undone.',
          style: const TextStyle(color: Colors.red),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    ) ?? false;
    
    if (!confirmed) {
      return;
    }
    
    setState(() {
      _isLoading = true;
      _statusMessage = 'Deleting company...';
    });
    
    try {
      await _machineConfigService.deleteCompanyProfile(companyName);
      
      setState(() {
        _statusMessage = 'Company deleted successfully';
        // Update company profiles list
        _companyProfiles.removeWhere((company) => company['name'] == companyName);
      });
    } catch (e) {
      setState(() {
        _statusMessage = 'Error deleting company: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _exportOrdersCSV() async {
    // Show date picker dialog
    final dateRange = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDateRange: DateTimeRange(
        start: DateTime.now().subtract(const Duration(days: 30)),
        end: DateTime.now(),
      ),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: Colors.deepPurple,
              onPrimary: Colors.white,
              onSurface: Colors.black,
            ),
          ),
          child: child!,
        );
      },
    );

    // If user cancelled the date picker
    if (dateRange == null) {
      setState(() {
        _statusMessage = 'CSV export cancelled';
      });
      return;
    }

    setState(() {
      _statusMessage = 'Exporting orders as CSV...';
      _isLoading = true;
    });
    
    try {
      // Call the service with selected date range
      final exportPath = await _backupService.exportOrdersAsCSV(
        startDate: dateRange.start,
        endDate: dateRange.end,
      );
      
      setState(() {
        _statusMessage = 'Orders exported successfully to: $exportPath';
      });
    } catch (e) {
      setState(() {
        _statusMessage = 'Error exporting orders: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  // UI for servant mode - shows the process of searching for masters
  Widget _buildServantDiscoveryUI() {
    // State variables to track discovery process
    bool isSearching = false;
    List<dynamic> foundMasters = [];
    
    // Try to check for existing connection first
    MasterDiscoveryService? discoveryService;
    try {
      discoveryService = Provider.of<MasterDiscoveryService>(context, listen: false);
      if (discoveryService.selectedMaster != null) {
        // Already connected to a master
        return _buildBackupForm();
      }
      
      // We don't have access to the specific methods, so let's use what we know works
      foundMasters = discoveryService.selectedMaster != null ? [discoveryService.selectedMaster] : [];
      
    } catch (e) {
      // Provider not available
      setState(() {
        _statusMessage = "Master discovery service not available";
      });
    }

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Servant status card
          Card(
            margin: const EdgeInsets.all(16),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  const Text(
                    'Servant Device',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'This device is configured as a servant and needs to connect to a master',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey.shade700),
                  ),
                  const SizedBox(height: 16),
                  // Settings button
                  OutlinedButton.icon(
                    icon: const Icon(Icons.settings),
                    label: const Text('Change Mode'),
                    onPressed: () => _showMasterSettingsDialog(),
                  ),
                ],
              ),
            ),
          ),
          
          const SizedBox(height: 24),
          
          // Search status and animation
          if (_isLoading) 
            const CircularProgressIndicator(),
          const SizedBox(height: 16),
          Text(
            _statusMessage.isNotEmpty ? _statusMessage : 'Looking for master devices...',
            style: const TextStyle(fontSize: 16),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          
          // No masters found message when not loading and no masters
          if (!_isLoading && foundMasters.isEmpty)
            Column(
              children: [
                Icon(
                  Icons.signal_wifi_off,
                  size: 64,
                  color: Colors.grey,
                ),
                const SizedBox(height: 16),
                const Text(
                  'No master devices found',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Make sure your master device is on and connected to the network',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey.shade700),
                ),
                const SizedBox(height: 24),
                ElevatedButton.icon(
                  icon: const Icon(Icons.refresh),
                  label: const Text('Scan for Masters'),
                  onPressed: () {
                    // Use the MachineConfigService to scan instead
                    _scanForMastersManually();
                  },
                ),
              ],
            ),
          
          // Manual connection button always shown
          ElevatedButton.icon(
            icon: const Icon(Icons.add),
            label: const Text('Connect Manually'),
            onPressed: () {
              _showManualConnectionDialog();
            },
          ),
          
          const SizedBox(height: 16),
          // Navigation button
          TextButton.icon(
            icon: const Icon(Icons.search),
            label: const Text('Find Masters'),
            onPressed: () {
              // Navigate to the master discovery screen
              Navigator.of(context).pushNamed(MasterDiscoveryScreen.routeName);
            },
          ),
        ],
      ),
    );
  }
  
  // Manual method to scan for masters using the MachineConfigService
  void _scanForMastersManually() {
    setState(() {
      _isLoading = true;
      _statusMessage = 'Scanning network for master devices...';
    });
    
    // Use the MachineConfigService to scan for masters
    _machineConfigService.scanForMasters().then((masterAddresses) {
      setState(() {
        if (masterAddresses.isEmpty) {
          _statusMessage = 'No master devices found on the network';
        } else if (masterAddresses.length == 1) {
          _statusMessage = 'Found a master device at ${masterAddresses.first}';
          _masterAddressController.text = masterAddresses.first;
        } else {
          _statusMessage = 'Found ${masterAddresses.length} master devices';
          _masterAddressController.text = masterAddresses.first;
        }
        _isLoading = false;
      });
    }).catchError((error) {
      setState(() {
        _statusMessage = 'Error scanning for masters: $error';
        _isLoading = false;
      });
    });
  }
  
  void _showManualConnectionDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Connect to Master'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Enter the IP address of your master device:'),
            SizedBox(height: 16),
            TextField(
              controller: _masterAddressController,
              decoration: InputDecoration(
                labelText: 'Master IP Address',
                hintText: 'e.g., 192.168.1.100',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
            },
            child: Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _saveMasterAddress();
              _testMasterConnection();
            },
            child: Text('Connect'),
          ),
        ],
      ),
    );
  }

  // UI for devices without a role configured
  Widget _buildRoleSelectionUI() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.settings,
            size: 72,
            color: Colors.grey.shade300,
          ),
          const SizedBox(height: 16),
          Text(
            'Setup Device Role',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.grey.shade800,
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              'Choose how this device will operate with other devices in your network.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.grey.shade600,
              ),
            ),
          ),
          const SizedBox(height: 32),
          
          // Role selection cards
          Container(
            width: 400,
            child: Column(
              children: [
                _buildRoleCard(
                  icon: Icons.dns,
                  title: 'Master',
                  description: 'This is the main device that stores the primary database and receives updates from other devices.',
                  onTap: () => _saveMachineRole(MachineRole.master),
                ),
                const SizedBox(height: 16),
                _buildRoleCard(
                  icon: Icons.device_hub,
                  title: 'Servant',
                  description: 'This device will sync with a master device on your network.',
                  onTap: () => _saveMachineRole(MachineRole.servant),
                ),
                const SizedBox(height: 16),
                _buildRoleCard(
                  icon: Icons.devices,
                  title: 'Single',
                  description: 'This device operates independently and does not sync with other devices.',
                  onTap: () => _saveMachineRole(MachineRole.single),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildRoleCard({
    required IconData icon,
    required String title,
    required String description,
    required VoidCallback onTap,
  }) {
    return Card(
      elevation: 2,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: Theme.of(context).primaryColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Icon(
                  icon,
                  color: Theme.of(context).primaryColor,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      description,
                      style: TextStyle(
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.arrow_forward_ios, size: 16),
            ],
          ),
        ),
      ),
    );
  }

  // Show dialog to select tables for CSV export
  Future<void> _showExportTablesDialog() async {
    // Reset the selection to all tables initially
    setState(() {
      _selectedTables = List.from(_allTables);
    });
    
    // Show dialog to select tables
    await showDialog<void>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Export Tables as CSV'),
          content: SizedBox(
            width: double.maxFinite,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('${_selectedTables.length} of ${_allTables.length} tables selected'),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        TextButton(
                          onPressed: () {
                            setState(() {
                              _selectedTables = List.from(_allTables);
                            });
                          },
                          child: const Text('Select All'),
                        ),
                        TextButton(
                          onPressed: () {
                            setState(() {
                              _selectedTables = [];
                            });
                          },
                          child: const Text('Deselect All'),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: _allTables.length,
                    itemBuilder: (context, index) {
                      final table = _allTables[index];
                      final isSelected = _selectedTables.contains(table);
                      final rowCount = _tableRowCounts[table] ?? 0;
                      
                      return CheckboxListTile(
                        title: Text(table),
                        subtitle: Text('$rowCount rows'),
                        value: isSelected,
                        onChanged: (value) {
                          setState(() {
                            if (value == true && !_selectedTables.contains(table)) {
                              _selectedTables.add(table);
                            } else if (value == false && _selectedTables.contains(table)) {
                              _selectedTables.remove(table);
                            }
                          });
                        },
                      );
                    },
                  ),
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
              onPressed: () {
                Navigator.pop(context);
                _exportSelectedTablesAsCSV();
              },
              child: const Text('Export Selected'),
            ),
          ],
        ),
      ),
    );
  }
  
  // Export selected tables as CSV files
  Future<void> _exportSelectedTablesAsCSV() async {
    if (_selectedTables.isEmpty) {
      setState(() {
        _statusMessage = 'Please select at least one table to export';
      });
      return;
    }
    
    setState(() {
      _isLoading = true;
      _statusMessage = 'Exporting ${_selectedTables.length} tables as CSV...';
    });
    
    try {
      // Create a folder to store CSV files
      final exportPath = await _backupService.exportTablesAsCSV(_selectedTables);
      
      setState(() {
        _statusMessage = 'Tables exported successfully to: $exportPath';
      });
    } catch (e) {
      setState(() {
        _statusMessage = 'Error exporting tables: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }
}