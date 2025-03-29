import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:my_flutter_app/services/backup_service.dart';
import 'package:file_picker/file_picker.dart';
import 'package:my_flutter_app/services/database.dart';

class BackupScreen extends StatefulWidget {
  const BackupScreen({super.key});

  @override
  State<BackupScreen> createState() => _BackupScreenState();
}

class _BackupScreenState extends State<BackupScreen> {
  bool _isLoading = false;
  String _statusMessage = '';
  List<FileSystemEntity> _backups = [];
  List<String> _availableTables = [];
  Map<String, bool> _selectedTables = {};
  Map<String, int> _tableRowCounts = {};
  final TextEditingController _backupNameController = TextEditingController();
  Map<String, bool> _selectedBackups = {};
  bool _batchDeleteMode = false;
  
  @override
  void initState() {
    super.initState();
    _loadBackups();
    _loadTables();
  }
  
  @override
  void dispose() {
    _backupNameController.dispose();
    super.dispose();
  }
  
  Future<void> _loadTables() async {
    try {
      final tables = await BackupService.instance.getTableNames();
      
      final rowCounts = <String, int>{};
      for (final table in tables) {
        rowCounts[table] = await BackupService.instance.getTableRowCount(table);
      }
      
      setState(() {
        _availableTables = tables;
        _tableRowCounts = rowCounts;
        // Initialize all tables as selected
        _selectedTables = {for (var table in tables) table: true};
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
  
  Future<void> _createBackup() async {
    try {
      setState(() {
        _isLoading = true;
        _statusMessage = 'Creating backup...';
      });
      
      final backupPath = await BackupService.instance.createBackup();
      
      setState(() {
        _statusMessage = 'Backup created: ${basename(backupPath)}';
        _isLoading = false;
      });
      
      await _loadBackups();
    } catch (e) {
      setState(() {
        _statusMessage = 'Error creating backup: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _createNamedBackup() async {
    try {
      final timestamp = DateFormat('yyyy-MM-dd_HH-mm-ss').format(DateTime.now());
      final defaultName = 'malbrose_backup_$timestamp.db';
      
      final dbName = await _showBackupNameDialog(
        title: 'Create Named Backup',
        hintText: 'Enter backup name',
        defaultName: defaultName,
      );
      
      if (dbName == null || dbName.isEmpty) {
        setState(() {
          _statusMessage = 'Backup cancelled';
        });
        return;
      }
      
      setState(() {
        _isLoading = true;
        _statusMessage = 'Creating backup...';
      });
      
      final backupPath = await BackupService.instance.createNamedBackup(dbName);
      
      setState(() {
        _statusMessage = 'Backup created: ${basename(backupPath)}';
        _isLoading = false;
      });
      
      await _loadBackups();
    } catch (e) {
      setState(() {
        _statusMessage = 'Error creating named backup: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _createEmptyDatabase() async {
    try {
      final timestamp = DateFormat('yyyy-MM-dd_HH-mm-ss').format(DateTime.now());
      final defaultName = 'empty_db_$timestamp.db';
      
      final dbName = await _showBackupNameDialog(
        title: 'Create Empty Database',
        hintText: 'Enter database name',
        defaultName: defaultName,
      );
      
      if (dbName == null || dbName.isEmpty) {
        setState(() {
          _statusMessage = 'Operation cancelled';
        });
        return;
      }
      
      setState(() {
        _isLoading = true;
        _statusMessage = 'Creating empty database...';
      });
      
      final dbPath = await BackupService.instance.createEmptyDatabase(dbName);
      
      setState(() {
        _statusMessage = 'Empty database created: ${basename(dbPath)}';
        _isLoading = false;
      });
      
      await _loadBackups();
    } catch (e) {
      setState(() {
        _statusMessage = 'Error creating empty database: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _backupSelectedTables() async {
    try {
      // Get selected tables
      final selectedTables = _selectedTables.entries
          .where((entry) => entry.value)
          .map((entry) => entry.key)
          .toList();
      
      if (selectedTables.isEmpty) {
        setState(() {
          _statusMessage = 'No tables selected for backup';
        });
        return;
      }
      
      final timestamp = DateFormat('yyyy-MM-dd_HH-mm-ss').format(DateTime.now());
      final defaultName = 'selective_backup_$timestamp.db';
      
      final dbName = await _showBackupNameDialog(
        title: 'Backup Selected Tables',
        hintText: 'Enter backup name',
        defaultName: defaultName,
      );
      
      if (dbName == null || dbName.isEmpty) {
        setState(() {
          _statusMessage = 'Backup cancelled';
        });
        return;
      }
      
      setState(() {
        _isLoading = true;
        _statusMessage = 'Creating selective backup...';
      });
      
      final backupPath = await BackupService.instance.backupSelectedTables(
        dbName: dbName,
        selectedTables: selectedTables,
      );
      
      setState(() {
        _statusMessage = 'Selective backup created: ${basename(backupPath)}';
        _isLoading = false;
      });
      
      await _loadBackups();
    } catch (e) {
      setState(() {
        _statusMessage = 'Error creating selective backup: $e';
        _isLoading = false;
      });
    }
  }

  Future<String?> _showBackupNameDialog({
    required String title,
    required String hintText,
    required String defaultName,
  }) async {
    _backupNameController.text = defaultName;
    
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: _backupNameController,
          autofocus: true,
          decoration: InputDecoration(
            hintText: hintText,
            labelText: 'Name',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, _backupNameController.text),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }
  
  Future<void> _deleteBackup(String backupPath) async {
    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Backup'),
        content: const Text(
          'Are you sure you want to delete this backup? '
          'This action cannot be undone.',
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
    );
    
    if (confirmed != true) {
      return;
    }
    
    setState(() {
      _isLoading = true;
      _statusMessage = 'Deleting backup...';
    });
    
    try {
      final file = File(backupPath);
      await file.delete();
      setState(() {
        _statusMessage = 'Backup deleted successfully';
      });
      await _loadBackups();
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
  
  Future<void> _deleteSelectedBackups() async {
    // Get selected backups
    final selectedPaths = _selectedBackups.entries
        .where((entry) => entry.value)
        .map((entry) => entry.key)
        .toList();
    
    if (selectedPaths.isEmpty) {
      setState(() {
        _statusMessage = 'No backups selected for deletion';
      });
      return;
    }
    
    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Selected Backups'),
        content: Text(
          'Are you sure you want to delete ${selectedPaths.length} selected backup(s)? '
          'This action cannot be undone.',
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
    );
    
    if (confirmed != true) {
      return;
    }
    
    setState(() {
      _isLoading = true;
      _statusMessage = 'Deleting selected backups...';
    });
    
    try {
      int successCount = 0;
      List<String> failures = [];
      
      for (final path in selectedPaths) {
        try {
          final file = File(path);
          await file.delete();
          successCount++;
        } catch (e) {
          failures.add(basename(path));
          print('Error deleting backup $path: $e');
        }
      }
      
      setState(() {
        if (failures.isEmpty) {
          _statusMessage = 'Successfully deleted $successCount backups';
          _batchDeleteMode = false;
          _selectedBackups.clear();
        } else {
          _statusMessage = 'Deleted $successCount backups, but failed to delete ${failures.length} backups: ${failures.join(", ")}';
        }
      });
      
      await _loadBackups();
    } catch (e) {
      setState(() {
        _statusMessage = 'Error during batch deletion: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }
  
  void _toggleBatchDeleteMode() {
    setState(() {
      _batchDeleteMode = !_batchDeleteMode;
      if (!_batchDeleteMode) {
        _selectedBackups.clear();
      } else {
        // Initialize all backups as unselected
        for (final backup in _backups) {
          _selectedBackups[backup.path] = false;
        }
      }
    });
  }
  
  void _selectAllBackups(bool value) {
    setState(() {
      for (final backup in _backups) {
        _selectedBackups[backup.path] = value;
      }
    });
  }
  
  Future<void> _restoreBackup(String backupPath) async {
    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Restore Backup'),
        content: const Text(
          'Are you sure you want to restore this backup? '
          'This will replace your current database and cannot be undone.',
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
    );
    
    if (confirmed != true) {
      return;
    }
    
    setState(() {
      _isLoading = true;
      _statusMessage = 'Restoring backup...';
    });
    
    try {
      final success = await BackupService.instance.restoreBackup(backupPath);
      setState(() {
        _statusMessage = success
            ? 'Backup restored successfully'
            : 'Failed to restore backup';
      });
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
  
  Future<void> _exportBackup() async {
    setState(() {
      _isLoading = true;
      _statusMessage = 'Exporting backup...';
    });
    
    try {
      final exportPath = await BackupService.instance.exportBackup();
      setState(() {
        _statusMessage = 'Backup exported successfully to $exportPath';
      });
    } catch (e) {
      setState(() {
        _statusMessage = 'Error exporting backup: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }
  
  Future<void> _importBackup() async {
    try {
      // Pick a file
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['db'],
      );
      
      if (result == null || result.files.isEmpty) {
        return;
      }
      
      final filePath = result.files.first.path;
      if (filePath == null) {
        setState(() {
          _statusMessage = 'Error: No file selected';
        });
        return;
      }
      
      // Show confirmation dialog
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Import Backup'),
          content: const Text(
            'Are you sure you want to import this backup? '
            'This will replace your current database and cannot be undone.',
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
      );
      
      if (confirmed != true) {
        return;
      }
      
      setState(() {
        _isLoading = true;
        _statusMessage = 'Importing backup...';
      });
      
      final success = await BackupService.instance.importBackup(filePath);
      setState(() {
        _statusMessage = success
            ? 'Backup imported successfully'
            : 'Failed to import backup';
      });
      
      await _loadBackups();
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
  
  void _showResetDatabaseConfirmation(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reset Database'),
        content: const Text(
          'WARNING: This will completely reset your database and delete all data. '
          'This action cannot be undone.\n\n'
          'Are you sure you want to continue?'
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _resetDatabase(context);
            },
            child: const Text('Reset Database', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
  
  Future<void> _resetDatabase(BuildContext context) async {
    setState(() {
      _isLoading = true;
      _statusMessage = 'Resetting database...';
    });
    
    try {
      await DatabaseService.instance.resetAndRecreateDatabase();
      
      setState(() {
        _isLoading = false;
        _statusMessage = 'Database reset successfully';
      });
      
      // Show success message
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Database has been reset successfully'),
          backgroundColor: Colors.green,
        ),
      );
      
      // Navigate back to home after a short delay
      Future.delayed(const Duration(seconds: 2), () {
        Navigator.pushNamedAndRemoveUntil(context, '/setup', (route) => false);
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _statusMessage = 'Error resetting database: $e';
      });
      
      // Show error message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to reset database: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Database Backup & Restore'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadBackups,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
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
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Table selection panel
                if (_availableTables.isNotEmpty)
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
                                  children: [
                                    TextButton(
                                      onPressed: () {
                                        setState(() {
                                          for (var table in _availableTables) {
                                            _selectedTables[table] = true;
                                          }
                                        });
                                      },
                                      child: const Text('Select All'),
                                    ),
                                    TextButton(
                                      onPressed: () {
                                        setState(() {
                                          for (var table in _availableTables) {
                                            _selectedTables[table] = false;
                                          }
                                        });
                                      },
                                      child: const Text('Deselect All'),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          const Divider(height: 1),
                          Expanded(
                            child: ListView.builder(
                              itemCount: _availableTables.length,
                              itemBuilder: (context, index) {
                                final table = _availableTables[index];
                                final isSelected = _selectedTables[table] ?? false;
                                final rowCount = _tableRowCounts[table] ?? 0;
                                
                                return CheckboxListTile(
                                  title: Text(table),
                                  subtitle: Text('Rows: $rowCount'),
                                  value: isSelected,
                                  onChanged: (value) {
                                    setState(() {
                                      _selectedTables[table] = value ?? false;
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
                              if (_batchDeleteMode && _backups.isNotEmpty)
                                Row(
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
                              TextButton.icon(
                                icon: Icon(_batchDeleteMode ? Icons.close : Icons.delete),
                                label: Text(_batchDeleteMode ? 'Cancel' : 'Batch Delete'),
                                onPressed: _backups.isEmpty ? null : _toggleBatchDeleteMode,
                                style: TextButton.styleFrom(
                                  foregroundColor: _batchDeleteMode ? Colors.blue : Colors.red,
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
                                      leading: _batchDeleteMode
                                        ? Checkbox(
                                            value: _selectedBackups[backup.path] ?? false,
                                            onChanged: (value) {
                                              setState(() {
                                                _selectedBackups[backup.path] = value ?? false;
                                              });
                                            },
                                          )
                                        : const Icon(Icons.backup, color: Colors.blue),
                                      title: Text(fileName),
                                      subtitle: Text(
                                        'Size: $fileSizeFormatted\nCreated: ${DateFormat('yyyy-MM-dd HH:mm:ss').format(modifiedDate)}',
                                      ),
                                      trailing: _batchDeleteMode 
                                        ? null
                                        : Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            IconButton(
                                              icon: const Icon(Icons.restore, color: Colors.green),
                                              onPressed: () => _restoreBackup(backup.path),
                                              tooltip: 'Restore',
                                            ),
                                            IconButton(
                                              icon: const Icon(Icons.delete, color: Colors.red),
                                              onPressed: () => _deleteBackup(backup.path),
                                              tooltip: 'Delete',
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
            ),
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
}