import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:my_flutter_app/services/backup_service.dart';
import 'package:file_picker/file_picker.dart';
import 'package:my_flutter_app/services/database.dart';
import 'package:my_flutter_app/services/machine_config_service.dart';
import 'package:my_flutter_app/models/sync_log_model.dart';

class BackupScreen extends StatefulWidget {
  const BackupScreen({super.key});

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
    return Scaffold(
      appBar: AppBar(
        title: const Text('Database & Machine Management'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () async {
              await _loadBackups();
              await _loadTables();
              await _loadMachineConfig();
            },
            tooltip: 'Refresh',
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(Icons.backup), text: 'Backups'),
            Tab(icon: Icon(Icons.sync), text: 'Multi-Machine'),
            Tab(icon: Icon(Icons.business), text: 'Company Profile'),
          ],
        ),
      ),
      body: SafeArea(
        child: TabBarView(
          controller: _tabController,
          children: [
            _buildBackupTab(),
            _buildMachineConfigTab(),
            _buildCompanyProfileTab(),
          ],
        ),
      ),
    );
  }
  
  Widget _buildBackupTab() {
    return Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Wrap(
              spacing: 16.0,
              runSpacing: 12.0,
              alignment: WrapAlignment.center,
              children: [
                ElevatedButton.icon(
                  onPressed: _isLoading ? null : _createBackup,
                  icon: const Icon(Icons.backup),
                  label: const Text('Full Backup'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: _isLoading ? null : _backupSelectedTables,
                  icon: const Icon(Icons.checklist),
                  label: const Text('Selective Backup'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.purple,
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: _isLoading ? null : _createEmptyDatabase,
                  icon: const Icon(Icons.create_new_folder),
                  label: const Text('Create Empty DB'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.teal,
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: _isLoading ? null : _exportBackup,
                  icon: const Icon(Icons.file_download),
                  label: const Text('Export Backup'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: _isLoading ? null : _importBackup,
                  icon: const Icon(Icons.file_upload),
                  label: const Text('Import Backup'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange,
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: _isLoading ? null : _exportOrdersCSV,
                  icon: const Icon(Icons.request_page),
                  label: const Text('Export Orders CSV'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.deepPurple,
                    foregroundColor: Colors.white,
                  ),
                ),
                ElevatedButton(
                  onPressed: () => _showResetDatabaseConfirmation(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Reset Database'),
                ),
              ],
            ),
            ),
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
          const Divider(),
          Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              // On very small screens, stack the panels vertically
              if (constraints.maxWidth < 600) {
                return _buildSmallScreenBackupTab();
              } else {
                // Default layout for larger screens
                return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Table selection panel
                    if (_allTables.isNotEmpty)
                  Expanded(
                    flex: 1,
                    child: Card(
                      margin: const EdgeInsets.all(8.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text(
                                  'Tables for Selective Backup',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                                Row(
                                      mainAxisSize: MainAxisSize.min,
                                  children: [
                                    TextButton(
                                      onPressed: () {
                                        setState(() {
                                              _selectedTables = List.from(_allTables);
                                        });
                                      },
                                          style: TextButton.styleFrom(
                                            padding: const EdgeInsets.symmetric(horizontal: 8),
                                          ),
                                      child: const Text('Select All'),
                                    ),
                                        const SizedBox(width: 4),
                                    TextButton(
                                      onPressed: () {
                                        setState(() {
                                              _selectedTables.clear();
                                        });
                                      },
                                          style: TextButton.styleFrom(
                                            padding: const EdgeInsets.symmetric(horizontal: 8),
                                          ),
                                          child: const Text('Deselect'),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          const Divider(height: 1),
                          Expanded(
                            child: ListView.builder(
                                  itemCount: _allTables.length,
                              itemBuilder: (context, index) {
                                    final table = _allTables[index];
                                    final isSelected = _selectedTables.contains(table);
                                final rowCount = _tableRowCounts[table] ?? 0;
                                
                                return CheckboxListTile(
                                  title: Text(table),
                                  subtitle: Text('Rows: $rowCount'),
                                  value: isSelected,
                                  onChanged: (value) {
                                    setState(() {
                                          if (value == true) {
                                            _selectedTables.add(table);
                                          } else {
                                            _selectedTables.remove(table);
                                          }
                                    });
                                  },
                                  dense: true,
                                );
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                // Backups list
                Expanded(
                  flex: 2,
                  child: Card(
                    margin: const EdgeInsets.all(8.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Padding(
                          padding: EdgeInsets.all(8.0),
                          child: Text(
                            'Available Backups',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8.0),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                                  if (_isInBatchDeleteMode && _backups.isNotEmpty)
                                    Expanded(
                                      child: SingleChildScrollView(
                                        scrollDirection: Axis.horizontal,
                                        child: Row(
                                  children: [
                                    TextButton.icon(
                                      icon: const Icon(Icons.select_all),
                                      label: const Text('Select All'),
                                      onPressed: () => _selectAllBackups(true),
                                    ),
                                    TextButton.icon(
                                      icon: const Icon(Icons.deselect),
                                      label: const Text('Deselect All'),
                                      onPressed: () => _selectAllBackups(false),
                                    ),
                                    const SizedBox(width: 8),
                                    ElevatedButton.icon(
                                      icon: const Icon(Icons.delete_forever),
                                      label: const Text('Delete Selected'),
                                      onPressed: _deleteSelectedBackups,
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.red,
                                      ),
                                    ),
                                  ],
                                        ),
                                      ),
                                ),
                              TextButton.icon(
                                    icon: Icon(_isInBatchDeleteMode ? Icons.close : Icons.delete),
                                    label: Text(_isInBatchDeleteMode ? 'Cancel' : 'Batch Delete'),
                                onPressed: _backups.isEmpty ? null : _toggleBatchDeleteMode,
                                style: TextButton.styleFrom(
                                      foregroundColor: _isInBatchDeleteMode ? Colors.blue : Colors.red,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Divider(height: 1),
                        Expanded(
                          child: _backups.isEmpty
                              ? const Center(
                                  child: Text(
                                    'No backups found. Create a backup to get started.',
                                    style: TextStyle(fontSize: 16),
                                  ),
                                )
                              : ListView.builder(
                                  itemCount: _backups.length,
                                  itemBuilder: (context, index) {
                                    final backup = _backups[index];
                                    final fileName = basename(backup.path);
                                    final fileSize = (backup as File).lengthSync();
                                    final fileSizeFormatted = _formatFileSize(fileSize);
                                    final modifiedDate = backup.statSync().modified;
                                    
                                    return ListTile(
                                          leading: _isInBatchDeleteMode
                                        ? Checkbox(
                                                value: _batchSelectedBackups.contains(backup.path),
                                            onChanged: (value) {
                                              setState(() {
                                                    if (value == true) {
                                                      _batchSelectedBackups.add(backup.path);
                                                    } else {
                                                      _batchSelectedBackups.remove(backup.path);
                                                    }
                                              });
                                            },
                                          )
                                        : const Icon(Icons.backup, color: Colors.blue),
                                      title: Text(fileName),
                                      subtitle: Text(
                                        'Size: $fileSizeFormatted\nCreated: ${DateFormat('yyyy-MM-dd HH:mm:ss').format(modifiedDate)}',
                                      ),
                                          trailing: _isInBatchDeleteMode 
                                            ? null
                                            : Wrap(
                                              alignment: WrapAlignment.end,
                                              spacing: 8,
                                              children: [
                                                IconButton(
                                                  icon: const Icon(Icons.restore, color: Colors.green),
                                                  onPressed: () => _restoreBackup(backup.path),
                                                  tooltip: 'Restore',
                                                  constraints: const BoxConstraints(),
                                                  padding: const EdgeInsets.all(8),
                                                ),
                                                IconButton(
                                                  icon: const Icon(Icons.delete, color: Colors.red),
                                                  onPressed: () => _deleteBackup(backup.path),
                                                  tooltip: 'Delete',
                                                  constraints: const BoxConstraints(),
                                                  padding: const EdgeInsets.all(8),
                                                ),
                                              ],
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
                );
              }
            }
          ),
        ),
      ],
    );
  }
  
  Widget _buildSmallScreenBackupTab() {
    return Column(
      children: [
        if (_allTables.isNotEmpty)
          // Tables section (collapsible)
          ExpansionTile(
            title: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Tables for Selective Backup',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  '${_selectedTables.length} selected',
                  style: const TextStyle(
                    fontSize: 12,
                    color: Colors.grey,
                  ),
                ),
              ],
            ),
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
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
                        _selectedTables.clear();
                      });
                    },
                    child: const Text('Deselect All'),
                  ),
                ],
              ),
              SizedBox(
                height: 200, // Fixed height
                child: ListView.builder(
                  itemCount: _allTables.length,
                  itemBuilder: (context, index) {
                    final table = _allTables[index];
                    final isSelected = _selectedTables.contains(table);
                    final rowCount = _tableRowCounts[table] ?? 0;
                    
                    return CheckboxListTile(
                      title: Text(table),
                      subtitle: Text('Rows: $rowCount'),
                      value: isSelected,
                      onChanged: (value) {
                        setState(() {
                          if (value == true) {
                            _selectedTables.add(table);
                          } else {
                            _selectedTables.remove(table);
                          }
                        });
                      },
                      dense: true,
                    );
                  },
                ),
              ),
            ],
          ),
        
        // Backups list (takes remaining space)
        Expanded(
          child: Card(
            margin: const EdgeInsets.all(8.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Available Backups',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      TextButton.icon(
                        icon: Icon(_isInBatchDeleteMode ? Icons.close : Icons.delete),
                        label: Text(_isInBatchDeleteMode ? 'Cancel' : 'Batch'),
                        onPressed: _backups.isEmpty ? null : _toggleBatchDeleteMode,
                        style: TextButton.styleFrom(
                          foregroundColor: _isInBatchDeleteMode ? Colors.blue : Colors.red,
                        ),
                      ),
                    ],
                  ),
                ),
                if (_isInBatchDeleteMode && _backups.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8.0),
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          TextButton(
                            onPressed: () => _selectAllBackups(true),
                            child: const Text('Select All'),
                          ),
                          TextButton(
                            onPressed: () => _selectAllBackups(false),
                            child: const Text('Deselect All'),
                          ),
                          ElevatedButton(
                            onPressed: _deleteSelectedBackups,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.red,
                            ),
                            child: const Text('Delete Selected'),
                          ),
                        ],
                      ),
                    ),
                  ),
                const Divider(height: 1),
                Expanded(
                  child: _backups.isEmpty
                      ? const Center(
                          child: Text(
                            'No backups found. Create a backup to get started.',
                            style: TextStyle(fontSize: 16),
                          ),
                        )
                      : ListView.builder(
                          itemCount: _backups.length,
                          itemBuilder: (context, index) {
                            final backup = _backups[index];
                            final fileName = basename(backup.path);
                            final fileSize = (backup as File).lengthSync();
                            final fileSizeFormatted = _formatFileSize(fileSize);
                            final modifiedDate = backup.statSync().modified;
                            
                            return ListTile(
                              leading: _isInBatchDeleteMode
                                ? Checkbox(
                                    value: _batchSelectedBackups.contains(backup.path),
                                    onChanged: (value) {
                                      setState(() {
                                        if (value == true) {
                                          _batchSelectedBackups.add(backup.path);
                                        } else {
                                          _batchSelectedBackups.remove(backup.path);
                                        }
                                      });
                                    },
                                  )
                                : const Icon(Icons.backup, color: Colors.blue),
                              title: Text(fileName),
                              subtitle: Text(
                                'Size: $fileSizeFormatted\nCreated: ${DateFormat('yyyy-MM-dd HH:mm:ss').format(modifiedDate)}',
                              ),
                              trailing: _isInBatchDeleteMode 
                                        ? null
                                        : Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            IconButton(
                                              icon: const Icon(Icons.restore, color: Colors.green),
                                              onPressed: () => _restoreBackup(backup.path),
                                              tooltip: 'Restore',
                                        constraints: const BoxConstraints(),
                                        padding: const EdgeInsets.all(8),
                                            ),
                                            IconButton(
                                              icon: const Icon(Icons.delete, color: Colors.red),
                                              onPressed: () => _deleteBackup(backup.path),
                                              tooltip: 'Delete',
                                        constraints: const BoxConstraints(),
                                        padding: const EdgeInsets.all(8),
                                            ),
                                          ],
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
    );
  }
  
  Widget _buildMachineConfigTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Card(
            elevation: 2,
            margin: const EdgeInsets.only(bottom: 16),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Machine Role Configuration',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  
                  // Current company indicator
                  if (_currentCompany != null)
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade100,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.business, color: Colors.blue),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Current Company: ${_currentCompany!['name']}',
                                  style: const TextStyle(fontWeight: FontWeight.bold),
                                ),
                                Text(
                                  'Database: ${_currentCompany!['database']}',
                                  style: const TextStyle(fontSize: 12),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  
                  const SizedBox(height: 16),
                  
                  const Text('Select Machine Role:'),
                  const SizedBox(height: 8),
                  
                  // Fix for render flex issue - use a container with constraints
                  SizedBox(
                    width: double.infinity,
                    child: DropdownButtonFormField<MachineRole>(
                      value: _machineRole,
                      isExpanded: true, // Ensure the dropdown uses available space
                      iconSize: 24,
                      menuMaxHeight: 200, // Set max height for dropdown menu
                      isDense: false, // Explicitly set this to false to give more room
                      onChanged: (value) {
                        if (value != null && value != _machineRole) {
                          _saveMachineRole(value);
                        }
                      },
                      items: MachineRole.values.map((role) {
                        final roleName = role.toString().split('.').last;
                        String displayName;
                        String description;
                        
                        switch (role) {
                          case MachineRole.single:
                            displayName = 'Single Machine';
                            description = 'Operates independently without syncing';
                            break;
                          case MachineRole.master:
                            displayName = 'Master';
                            description = 'Central database for other machines';
                            break;
                          case MachineRole.servant:
                            displayName = 'Servant';
                            description = 'Syncs with a master machine';
                            break;
                        }
                        
                        // Use a single-line layout with no vertical stacking
                        return DropdownMenuItem<MachineRole>(
                          value: role,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4.0),
                            child: Text(
                              displayName,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        );
                      }).toList(),
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 20),
                  
                  // Master Machine Settings
                  if (_machineRole == MachineRole.master) ...[
                    const Text(
                      'Master Settings',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    
                    const SizedBox(height: 8),
                    
                    // Use a responsive layout based on available width
                    LayoutBuilder(
                      builder: (context, constraints) {
                        // On small screens, stack the widgets vertically
                        if (constraints.maxWidth < 500) {
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Conflict resolution dropdown
                              SizedBox(
                                width: double.infinity,
                                child: DropdownButtonFormField<String>(
                                  value: _conflictResolution,
                                  isExpanded: true,
                                  onChanged: (value) {
                                    if (value != null) {
                                      _saveConflictResolution(value);
                                    }
                                  },
                                  items: const [
                                    DropdownMenuItem(
                                      value: 'last_write_wins',
                                      child: Text('Last Write Wins', overflow: TextOverflow.ellipsis),
                                    ),
                                    DropdownMenuItem(
                                      value: 'manual_merge',
                                      child: Text('Manual Merge', overflow: TextOverflow.ellipsis),
                                    ),
                                  ],
                                  decoration: const InputDecoration(
                                    labelText: 'Conflict Resolution',
                                    border: OutlineInputBorder(),
                                  ),
                                ),
                              ),
                              
                              const SizedBox(height: 16),
                              
                              // Create new company button
                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton.icon(
                                  onPressed: _isSyncing ? null : () => _showCreateNewCompanyDialog(),
                                  icon: const Icon(Icons.add_business),
                                  label: const Text('Create New Company Database'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.blue,
                                  ),
                                ),
                              ),
                            ],
                          );
                        } else {
                          // On larger screens, use the original row layout
                          return Row(
                            children: [
                              Expanded(
                                child: SizedBox(
                                  width: double.infinity,
                                  child: DropdownButtonFormField<String>(
                                    value: _conflictResolution,
                                    isExpanded: true,
                                    onChanged: (value) {
                                      if (value != null) {
                                        _saveConflictResolution(value);
                                      }
                                    },
                                    items: const [
                                      DropdownMenuItem(
                                        value: 'last_write_wins',
                                        child: Text('Last Write Wins', overflow: TextOverflow.ellipsis),
                                      ),
                                      DropdownMenuItem(
                                        value: 'manual_merge',
                                        child: Text('Manual Merge', overflow: TextOverflow.ellipsis),
                                      ),
                                    ],
                                    decoration: const InputDecoration(
                                      labelText: 'Conflict Resolution',
                                      border: OutlineInputBorder(),
                                    ),
                                  ),
                                ),
                              ),
                              
                              const SizedBox(width: 16),
                              
                              ElevatedButton.icon(
                                onPressed: _isSyncing ? null : () => _showCreateNewCompanyDialog(),
                                icon: const Icon(Icons.add_business),
                                label: const Text('Create New Company Database'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.blue,
                                ),
                              ),
                            ],
                          );
                        }
                      },
                    ),
                  ],
                  
                  // Servant Machine Settings
                  if (_machineRole == MachineRole.servant) ...[
                    const Text(
                      'Servant Settings',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    
                    const SizedBox(height: 8),
                    
                    // Use a responsive layout for servant settings
                    LayoutBuilder(
                      builder: (context, constraints) {
                        // On small screens, stack the widgets vertically
                        if (constraints.maxWidth < 600) {
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Master address input
                              TextFormField(
                                controller: _masterAddressController,
                                decoration: const InputDecoration(
                                  labelText: 'Master Address/IP',
                                  hintText: 'Enter IP address or hostname',
                                  border: OutlineInputBorder(),
                                ),
                              ),
                              
                              const SizedBox(height: 8),
                              
                              // Action buttons
                              Row(
                                children: [
                                  Expanded(
                                    child: ElevatedButton(
                                      onPressed: _isSyncing ? null : _saveMasterAddress,
                                      child: const Text('Save'),
                                    ),
                                  ),
                                  
                                  const SizedBox(width: 8),
                                  
                                  Expanded(
                                    child: ElevatedButton.icon(
                                      onPressed: _isSyncing ? null : _testMasterConnection,
                                      icon: const Icon(Icons.network_check),
                                      label: const Text('Test Connection'),
                                    ),
                                  ),
                                ],
                              ),
                              
                              const SizedBox(height: 16),
                              
                              // Sync frequency dropdown
                              SizedBox(
                                width: double.infinity,
                                child: DropdownButtonFormField<SyncFrequency>(
                                  value: _syncFrequency,
                                  isExpanded: true,
                                  onChanged: (value) {
                                    if (value != null) {
                                      _saveSyncFrequency(value);
                                    }
                                  },
                                  items: SyncFrequency.values.map((frequency) {
                                    String displayName;
                                    
                                    switch (frequency) {
                                      case SyncFrequency.manual:
                                        displayName = 'Manual Sync Only';
                                        break;
                                      case SyncFrequency.realTime:
                                        displayName = 'Real-Time';
                                        break;
                                      case SyncFrequency.fiveMinutes:
                                        displayName = 'Every 5 Minutes';
                                        break;
                                      case SyncFrequency.fifteenMinutes:
                                        displayName = 'Every 15 Minutes';
                                        break;
                                      case SyncFrequency.hourly:
                                        displayName = 'Hourly';
                                        break;
                                      case SyncFrequency.daily:
                                        displayName = 'Daily';
                                        break;
                                    }
                                    
                                    return DropdownMenuItem<SyncFrequency>(
                                      value: frequency,
                                      child: Text(
                                        displayName,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    );
                                  }).toList(),
                                  decoration: const InputDecoration(
                                    labelText: 'Sync Frequency',
                                    border: OutlineInputBorder(),
                                  ),
                                ),
                              ),
                              
                              const SizedBox(height: 16),
                              
                              // Sync now button
                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton.icon(
                                  onPressed: _isSyncing ? null : _syncWithMaster,
                                  icon: _isSyncing 
                                    ? const SizedBox(
                                        width: 20,
                                        height: 20,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Colors.white,
                                        ),
                                      )
                                    : const Icon(Icons.sync),
                                  label: const Text('Sync Now'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.green,
                                    foregroundColor: Colors.white,
                                  ),
                                ),
                              ),
                            ],
                          );
                        } else {
                          // On larger screens, use the original layout
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: TextFormField(
                                      controller: _masterAddressController,
                                      decoration: const InputDecoration(
                                        labelText: 'Master Address/IP',
                                        hintText: 'Enter IP address or hostname',
                                        border: OutlineInputBorder(),
                                      ),
                                    ),
                                  ),
                                  
                                  const SizedBox(width: 8),
                                  
                                  ElevatedButton(
                                    onPressed: _isSyncing ? null : _saveMasterAddress,
                                    child: const Text('Save'),
                                  ),
                                  
                                  const SizedBox(width: 8),
                                  
                                  ElevatedButton.icon(
                                    onPressed: _isSyncing ? null : _testMasterConnection,
                                    icon: const Icon(Icons.network_check),
                                    label: const Text('Test Connection'),
                                  ),
                                ],
                              ),
                              
                              const SizedBox(height: 16),
                              
                              Row(
                                children: [
                                  Expanded(
                                    child: SizedBox(
                                      width: double.infinity,
                                      child: DropdownButtonFormField<SyncFrequency>(
                                        value: _syncFrequency,
                                        isExpanded: true,
                                        onChanged: (value) {
                                          if (value != null) {
                                            _saveSyncFrequency(value);
                                          }
                                        },
                                        items: SyncFrequency.values.map((frequency) {
                                          String displayName;
                                          
                                          switch (frequency) {
                                            case SyncFrequency.manual:
                                              displayName = 'Manual Sync Only';
                                              break;
                                            case SyncFrequency.realTime:
                                              displayName = 'Real-Time';
                                              break;
                                            case SyncFrequency.fiveMinutes:
                                              displayName = 'Every 5 Minutes';
                                              break;
                                            case SyncFrequency.fifteenMinutes:
                                              displayName = 'Every 15 Minutes';
                                              break;
                                            case SyncFrequency.hourly:
                                              displayName = 'Hourly';
                                              break;
                                            case SyncFrequency.daily:
                                              displayName = 'Daily';
                                              break;
                                          }
                                          
                                          return DropdownMenuItem<SyncFrequency>(
                                            value: frequency,
                                            child: Text(
                                              displayName,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          );
                                        }).toList(),
                                        decoration: const InputDecoration(
                                          labelText: 'Sync Frequency',
                                          border: OutlineInputBorder(),
                                        ),
                                      ),
                                    ),
                                  ),
                                  
                                  const SizedBox(width: 16),
                                  
                                  ElevatedButton.icon(
                                    onPressed: _isSyncing ? null : _syncWithMaster,
                                    icon: _isSyncing 
                                      ? const SizedBox(
                                          width: 20,
                                          height: 20,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: Colors.white,
                                          ),
                                        )
                                      : const Icon(Icons.sync),
                                    label: const Text('Sync Now'),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.green,
                                      foregroundColor: Colors.white,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          );
                        }
                      },
                    ),
                  ],
                ],
              ),
            ),
          ),
          
          // Advanced Backup Options
          Card(
            elevation: 2,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Advanced Backup Options',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  
                  SwitchListTile(
                    title: const Text('Schedule Automatic Backups'),
                    subtitle: const Text('Create backups automatically on a schedule'),
                    value: _autoBackupEnabled,
                    onChanged: (value) {
                      setState(() {
                        _autoBackupEnabled = value;
                      });
                    },
                  ),
                  
                  if (_autoBackupEnabled)
                    Padding(
                      padding: const EdgeInsets.only(left: 16, right: 16, bottom: 8),
                      child: SizedBox(
                        width: double.infinity,
                        child: DropdownButtonFormField<String>(
                          value: _autoBackupInterval,
                          isExpanded: true,
                          onChanged: (value) {
                            if (value != null) {
                              setState(() {
                                _autoBackupInterval = value;
                              });
                            }
                          },
                          items: const [
                            DropdownMenuItem(
                              value: 'daily', 
                              child: Text('Daily', overflow: TextOverflow.ellipsis),
                            ),
                            DropdownMenuItem(
                              value: 'weekly', 
                              child: Text('Weekly', overflow: TextOverflow.ellipsis),
                            ),
                            DropdownMenuItem(
                              value: 'biweekly', 
                              child: Text('Bi-Weekly', overflow: TextOverflow.ellipsis),
                            ),
                            DropdownMenuItem(
                              value: 'monthly', 
                              child: Text('Monthly', overflow: TextOverflow.ellipsis),
                            ),
                          ],
                          decoration: const InputDecoration(
                            labelText: 'Backup Interval',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                    ),
                  
                  SwitchListTile(
                    title: const Text('Encrypt Backups'),
                    subtitle: const Text('Add password protection to backups'),
                    value: _encryptBackups,
                    onChanged: (value) {
                      setState(() {
                        _encryptBackups = value;
                      });
                    },
                  ),
                  
                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        ElevatedButton(
                          onPressed: _saveBackupSettings,
                          child: const Text('Save Backup Settings'),
                        ),
                      ],
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
  
  Widget _buildCompanyProfileTab() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              const Text(
                'Company Profiles',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              ElevatedButton.icon(
                onPressed: () => _showCreateNewCompanyDialog(),
                icon: const Icon(Icons.add),
                label: const Text('Create New Company'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                ),
              ),
            ],
          ),
        ),
        const Divider(),
        Expanded(
          child: ListView.builder(
            itemCount: _companyProfiles.length,
            itemBuilder: (context, index) {
              final profile = _companyProfiles[index];
              final isCurrentCompany = _currentCompany != null && 
                                      _currentCompany!['name'] == profile['name'];
              
              return ListTile(
                leading: Icon(
                  Icons.business,
                  color: isCurrentCompany ? Colors.green : Colors.grey,
                ),
                title: Text(
                  profile['name'],
                  style: TextStyle(
                    fontWeight: isCurrentCompany ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Database: ${profile['database']}'),
                    Text('Created: ${DateFormat('yyyy-MM-dd').format(DateTime.parse(profile['created']))}'),
                  ],
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (isCurrentCompany)
                      const Chip(
                        label: Text('Current'),
                        backgroundColor: Colors.green,
                        labelStyle: TextStyle(color: Colors.white),
                      )
                    else
                      ElevatedButton(
                        onPressed: () => _switchCompany(profile['name']),
                        child: const Text('Switch'),
                      ),
                    if (!isCurrentCompany)
                      IconButton(
                        icon: const Icon(Icons.delete, color: Colors.red),
                        onPressed: () => _deleteCompany(profile['name']),
                        tooltip: 'Delete Company',
                      ),
                  ],
                ),
                isThreeLine: true,
              );
            },
          ),
        ),
      ],
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
}