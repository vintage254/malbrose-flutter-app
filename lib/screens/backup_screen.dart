import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:my_flutter_app/services/backup_service.dart';
import 'package:file_picker/file_picker.dart';

class BackupScreen extends StatefulWidget {
  const BackupScreen({super.key});

  @override
  State<BackupScreen> createState() => _BackupScreenState();
}

class _BackupScreenState extends State<BackupScreen> {
  bool _isLoading = false;
  String _statusMessage = '';
  List<FileSystemEntity> _backups = [];
  
  @override
  void initState() {
    super.initState();
    _loadBackups();
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
    setState(() {
      _isLoading = true;
      _statusMessage = 'Creating backup...';
    });
    
    try {
      final backupPath = await BackupService.instance.createBackup();
      setState(() {
        _statusMessage = 'Backup created successfully at $backupPath';
      });
      await _loadBackups();
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
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton.icon(
                  onPressed: _isLoading ? null : _createBackup,
                  icon: const Icon(Icons.backup),
                  label: const Text('Create Backup'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
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
                        leading: const Icon(Icons.backup, color: Colors.blue),
                        title: Text(fileName),
                        subtitle: Text(
                          'Size: $fileSizeFormatted\nCreated: ${DateFormat('yyyy-MM-dd HH:mm:ss').format(modifiedDate)}',
                        ),
                        trailing: Row(
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
                        isThreeLine: true,
                      );
                    },
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