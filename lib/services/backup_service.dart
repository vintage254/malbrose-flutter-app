import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'package:sqflite/sqflite.dart';
import 'package:intl/intl.dart';
import 'package:my_flutter_app/services/database.dart';
import 'package:my_flutter_app/services/config_service.dart';

class BackupService {
  static final BackupService instance = BackupService._init();
  BackupService._init();
  
  // Maximum number of backups to keep
  final int _maxBackups = 30;
  
  // Get the backup directory
  Future<Directory> _getBackupDirectory() async {
    final appDir = await getApplicationDocumentsDirectory();
    final backupDir = Directory('${appDir.path}/backups');
    
    if (!await backupDir.exists()) {
      await backupDir.create(recursive: true);
    }
    
    return backupDir;
  }
  
  // Get the database path
  Future<String> _getDatabasePath() async {
    final databasesPath = await getDatabasesPath();
    return path.join(databasesPath, 'malbrose_db.db');
  }
  
  // Create a backup of the database
  Future<String> createBackup() async {
    try {
      final backupDir = await _getBackupDirectory();
      final timestamp = DateFormat('yyyy-MM-dd_HH-mm-ss').format(DateTime.now());
      final backupFile = File('${backupDir.path}/malbrose_backup_$timestamp.db');
      
      // Get the database path
      final dbPath = await _getDatabasePath();
      final dbFile = File(dbPath);
      
      if (await dbFile.exists()) {
        // Copy the database file to the backup location
        await dbFile.copy(backupFile.path);
        
        // Clean up old backups
        await _cleanupOldBackups();
        
        debugPrint('Backup created successfully: ${backupFile.path}');
        return backupFile.path;
      } else {
        throw Exception('Database file not found at $dbPath');
      }
    } catch (e) {
      debugPrint('Error creating backup: $e');
      rethrow;
    }
  }
  
  // Restore from a backup file
  Future<bool> restoreBackup(String backupPath) async {
    try {
      final backupFile = File(backupPath);
      
      if (!await backupFile.exists()) {
        throw Exception('Backup file not found at $backupPath');
      }
      
      // Close the current database connection
      await _closeDatabase();
      
      // Get the database path
      final dbPath = await _getDatabasePath();
      final dbFile = File(dbPath);
      
      // Create a backup of the current database before restoring
      if (await dbFile.exists()) {
        final timestamp = DateFormat('yyyy-MM-dd_HH-mm-ss').format(DateTime.now());
        final preRestoreBackup = File('${dbPath}_pre_restore_$timestamp');
        await dbFile.copy(preRestoreBackup.path);
      }
      
      // Copy the backup file to the database location
      await backupFile.copy(dbPath);
      
      // Reopen the database
      await _initDatabase();
      
      debugPrint('Backup restored successfully from $backupPath');
      return true;
    } catch (e) {
      debugPrint('Error restoring backup: $e');
      return false;
    }
  }
  
  // Close the database connection
  Future<void> _closeDatabase() async {
    try {
      // Get the database instance and close it
      final db = await DatabaseService.instance.database;
      await db.close();
      debugPrint('Database closed for backup operation');
    } catch (e) {
      debugPrint('Error closing database: $e');
    }
  }
  
  // Initialize the database after restore
  Future<void> _initDatabase() async {
    try {
      // Force the database service to reinitialize
      await DatabaseService.instance.database;
      debugPrint('Database reinitialized after restore');
    } catch (e) {
      debugPrint('Error reinitializing database: $e');
      rethrow;
    }
  }
  
  // Clean up old backups, keeping only the most recent ones
  Future<void> _cleanupOldBackups() async {
    try {
      final backupDir = await _getBackupDirectory();
      final backupFiles = await backupDir.list().where((entity) => 
        entity is File && entity.path.contains('malbrose_backup_')
      ).toList();
      
      // Sort files by last modified time (newest first)
      backupFiles.sort((a, b) => 
        b.statSync().modified.compareTo(a.statSync().modified)
      );
      
      // Keep only the 10 most recent backups
      const maxBackups = 10;
      if (backupFiles.length > maxBackups) {
        for (var i = maxBackups; i < backupFiles.length; i++) {
          await backupFiles[i].delete();
          debugPrint('Deleted old backup: ${backupFiles[i].path}');
        }
      }
    } catch (e) {
      debugPrint('Error cleaning up old backups: $e');
    }
  }
  
  // List all available backups
  Future<List<FileSystemEntity>> listBackups() async {
    try {
      final backupDir = await _getBackupDirectory();
      final backupFiles = await backupDir.list().where((entity) => 
        entity is File && entity.path.contains('malbrose_backup_')
      ).toList();
      
      // Sort files by last modified time (newest first)
      backupFiles.sort((a, b) => 
        b.statSync().modified.compareTo(a.statSync().modified)
      );
      
      return backupFiles;
    } catch (e) {
      debugPrint('Error listing backups: $e');
      return [];
    }
  }
  
  // Delete a specific backup
  Future<bool> deleteBackup(String backupPath) async {
    try {
      final backupFile = File(backupPath);
      
      if (await backupFile.exists()) {
        await backupFile.delete();
        debugPrint('Backup deleted: $backupPath');
        return true;
      } else {
        debugPrint('Backup file not found: $backupPath');
        return false;
      }
    } catch (e) {
      debugPrint('Error deleting backup: $e');
      return false;
    }
  }
  
  // Schedule automatic backups
  Future<void> scheduleAutomaticBackups() async {
    // This is a placeholder for scheduling automatic backups
    // In a real implementation, you would use a background task or a timer
    // to schedule regular backups
    
    // For now, we'll just create a backup when this method is called
    await createBackup();
  }
  
  // Export backup to external storage
  Future<String> exportBackup() async {
    try {
      // Create a new backup
      final backupPath = await createBackup();
      final backupFile = File(backupPath);
      
      // Get the downloads directory
      final downloadsDir = await getDownloadsDirectory();
      if (downloadsDir == null) {
        throw Exception('Downloads directory not found');
      }
      
      // Create a copy in the downloads directory
      final timestamp = DateFormat('yyyy-MM-dd_HH-mm-ss').format(DateTime.now());
      final exportPath = '${downloadsDir.path}/malbrose_backup_$timestamp.db';
      await backupFile.copy(exportPath);
      
      debugPrint('Backup exported to: $exportPath');
      return exportPath;
    } catch (e) {
      debugPrint('Error exporting backup: $e');
      rethrow;
    }
  }
  
  // Import backup from external storage
  Future<bool> importBackup(String filePath) async {
    try {
      final importFile = File(filePath);
      
      if (!await importFile.exists()) {
        throw Exception('Import file not found at $filePath');
      }
      
      // Copy the import file to the backups directory
      final backupDir = await _getBackupDirectory();
      final timestamp = DateFormat('yyyy-MM-dd_HH-mm-ss').format(DateTime.now());
      final backupPath = '${backupDir.path}/malbrose_imported_$timestamp.db';
      await importFile.copy(backupPath);
      
      // Restore from the imported backup
      final success = await restoreBackup(backupPath);
      
      debugPrint('Backup imported from: $filePath');
      return success;
    } catch (e) {
      debugPrint('Error importing backup: $e');
      return false;
    }
  }
} 