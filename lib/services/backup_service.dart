import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'package:sqflite/sqflite.dart';
import 'package:intl/intl.dart';
import 'package:my_flutter_app/services/database.dart';
import 'package:file_picker/file_picker.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

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
    try {
      // First try to get the current database path from the DatabaseService
      final db = await DatabaseService.instance.database;
      final dbPath = db.path;
      
      // If we have a valid path, use it
      if (dbPath.isNotEmpty) {
        debugPrint('Using current database path: $dbPath');
        return dbPath;
      }
      
      // Fallback to the standard location
      final databasesPath = await getDatabasesPath();
      final standardPath = path.join(databasesPath, 'malbrose_db.db');
      
      // Check if file exists at standard path
      if (await File(standardPath).exists()) {
        debugPrint('Found database at standard path: $standardPath');
        return standardPath;
      }
      
      // Final fallback - check in .dart_tool directory
      final toolPath = path.join(
        Directory.current.path, 
        '.dart_tool', 
        'sqflite_common_ffi', 
        'databases', 
        'malbrose_db.db'
      );
      
      if (await File(toolPath).exists()) {
        debugPrint('Found database at .dart_tool path: $toolPath');
        return toolPath;
      }
      
      // If no database file found, throw exception with helpful details
      String errorMsg = 'Cannot locate database file. Checked paths:\n';
      errorMsg += '- $dbPath (current db path)\n';
      errorMsg += '- $standardPath (standard path)\n';
      errorMsg += '- $toolPath (.dart_tool path)';
      throw Exception(errorMsg);
    } catch (e) {
      debugPrint('Error in _getDatabasePath: $e');
      rethrow;
    }
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
      
      // Generate a default filename with timestamp
      final timestamp = DateFormat('yyyy-MM-dd_HH-mm-ss').format(DateTime.now());
      final defaultFilename = 'malbrose_backup_$timestamp.db';
      
      // Ask user for save location
      String? outputPath = await FilePicker.platform.saveFile(
        dialogTitle: 'Choose where to save the database backup',
        fileName: defaultFilename,
        allowedExtensions: ['db'],
        type: FileType.custom,
      );
      
      if (outputPath == null) {
        // User cancelled the picker
        throw Exception('Backup export cancelled by user');
      }
      
      // Ensure .db extension
      if (!outputPath.toLowerCase().endsWith('.db')) {
        outputPath = '$outputPath.db';
      }
      
      // Copy the backup to the selected location
      await backupFile.copy(outputPath);
      
      debugPrint('Backup exported to: $outputPath');
      return outputPath;
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
  
  // Get all table names from the database
  Future<List<String>> getTableNames() async {
    try {
      // Get the database instance
      final db = await DatabaseService.instance.database;
      
      // Query for all tables
      final result = await db.rawQuery("SELECT name FROM sqlite_master WHERE type='table' AND name NOT LIKE 'sqlite_%' AND name NOT LIKE 'android_%'");
      
      // Extract table names
      final tableNames = result.map<String>((row) => row['name'] as String).toList();
      
      debugPrint('Found ${tableNames.length} tables: ${tableNames.join(', ')}');
      return tableNames;
    } catch (e) {
      debugPrint('Error getting table names: $e');
      return [];
    }
  }
  
  // Get table schema
  Future<String?> getTableSchema(String tableName) async {
    try {
      // Get the database instance
      final db = await DatabaseService.instance.database;
      
      // Query for table schema
      final result = await db.rawQuery("SELECT sql FROM sqlite_master WHERE type='table' AND name=?", [tableName]);
      
      if (result.isEmpty) {
        return null;
      }
      
      return result.first['sql'] as String;
    } catch (e) {
      debugPrint('Error getting schema for table $tableName: $e');
      return null;
    }
  }
  
  // Get approximate table size
  Future<int> getTableRowCount(String tableName) async {
    try {
      // Get the database instance
      final db = await DatabaseService.instance.database;
      
      // Get row count
      final result = await db.rawQuery('SELECT COUNT(*) as count FROM $tableName');
      
      return result.first['count'] as int;
    } catch (e) {
      debugPrint('Error getting row count for table $tableName: $e');
      return 0;
    }
  }
  
  // Create a new empty database with schema but no data
  Future<String> createEmptyDatabase(String dbName) async {
    try {
      // Ensure valid filename
      if (!dbName.toLowerCase().endsWith('.db')) {
        dbName = '$dbName.db';
      }
      
      // Sanitize filename - remove any invalid characters
      dbName = dbName.replaceAll(RegExp(r'[<>:"/\\|?*]'), '_');
      
      // Get the backup directory
      final backupDir = await _getBackupDirectory();
      final newDbPath = '${backupDir.path}/$dbName';
      
      // Check if the file already exists
      final newDbFile = File(newDbPath);
      if (await newDbFile.exists()) {
        throw Exception('A database with this name already exists');
      }
      
      // Get the database schema from the current database
      final tableNames = await getTableNames();
      final schemas = <String>[];
      
      for (final tableName in tableNames) {
        final schema = await getTableSchema(tableName);
        if (schema != null) {
          schemas.add(schema);
        }
      }
      
      // Create a new database with the schema
      final factory = databaseFactory;
      final newDb = await factory.openDatabase(
        newDbPath,
        options: OpenDatabaseOptions(
          version: 1,
          onCreate: (db, version) async {
            for (final schema in schemas) {
              await db.execute(schema);
            }
          }
        )
      );
      
      // Close the database properly
      await newDb.close();
      
      debugPrint('Created new empty database at: $newDbPath');
      return newDbPath;
    } catch (e) {
      debugPrint('Error creating empty database: $e');
      rethrow;
    }
  }
  
  // Backup selected tables to a new database
  Future<String> backupSelectedTables({
    required String dbName,
    required List<String> selectedTables,
  }) async {
    try {
      // Ensure valid filename
      if (!dbName.toLowerCase().endsWith('.db')) {
        dbName = '$dbName.db';
      }
      
      // Sanitize filename - remove any invalid characters
      dbName = dbName.replaceAll(RegExp(r'[<>:"/\\|?*]'), '_');
      
      // Get the backup directory
      final backupDir = await _getBackupDirectory();
      final newDbPath = '${backupDir.path}/$dbName';
      
      // Check if the file already exists
      final newDbFile = File(newDbPath);
      if (await newDbFile.exists()) {
        throw Exception('A database with this name already exists');
      }
      
      // Get the database instance
      final sourceDb = await DatabaseService.instance.database;
      
      // Create a new database
      final factory = databaseFactory;
      final newDb = await factory.openDatabase(
        newDbPath,
        options: OpenDatabaseOptions(
          version: 1,
        )
      );
      
      // Copy schemas and data for selected tables
      for (final tableName in selectedTables) {
        try {
          // Get schema
          final schemaResult = await sourceDb.rawQuery(
            "SELECT sql FROM sqlite_master WHERE type='table' AND name=?", 
            [tableName]
          );
          
          if (schemaResult.isEmpty) {
            debugPrint('Warning: Schema not found for table $tableName, skipping...');
            continue;
          }
          
          final schema = schemaResult.first['sql'] as String;
          
          // Create table in new database
          await newDb.execute(schema);
          
          // Copy data
          final data = await sourceDb.query(tableName);
          
          // Use transaction for faster insertion
          await newDb.transaction((txn) async {
            for (final row in data) {
              await txn.insert(tableName, row);
            }
          });
          
          debugPrint('Copied table $tableName with ${data.length} rows');
        } catch (e) {
          debugPrint('Error copying table $tableName: $e');
          // Continue with other tables even if one fails
        }
      }
      
      // Close the new database properly
      await newDb.close();
      
      debugPrint('Created backup with selected tables at: $newDbPath');
      return newDbPath;
    } catch (e) {
      debugPrint('Error creating selective backup: $e');
      rethrow;
    }
  }
  
  // Custom named backup of the entire database
  Future<String> createNamedBackup(String dbName) async {
    try {
      // Ensure valid filename
      if (!dbName.toLowerCase().endsWith('.db')) {
        dbName = '$dbName.db';
      }
      
      // Sanitize filename - remove any invalid characters
      dbName = dbName.replaceAll(RegExp(r'[<>:"/\\|?*]'), '_');
      
      // Get the backup directory
      final backupDir = await _getBackupDirectory();
      final backupPath = '${backupDir.path}/$dbName';
      
      // Check if the file already exists
      final backupFile = File(backupPath);
      if (await backupFile.exists()) {
        throw Exception('A backup with this name already exists');
      }
      
      // Get the database path
      final dbPath = await _getDatabasePath();
      final dbFile = File(dbPath);
      
      if (await dbFile.exists()) {
        // Copy the database file to the backup location
        await dbFile.copy(backupPath);
        
        // Clean up old backups
        await _cleanupOldBackups();
        
        debugPrint('Named backup created at: $backupPath');
        return backupPath;
      } else {
        throw Exception('Database file not found at $dbPath');
      }
    } catch (e) {
      debugPrint('Error creating named backup: $e');
      rethrow;
    }
  }
}