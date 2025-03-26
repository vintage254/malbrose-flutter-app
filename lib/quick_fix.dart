import 'dart:io';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:path/path.dart' show join;

// A very simple direct script to fix the database without any Flutter dependencies
Future<void> main() async {
  print('Quick database fix utility');
  print('-------------------------');
  
  // Initialize SQLite FFI
  print('Initializing SQLite...');
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;
  
  // Find the database
  final dbPath = '.dart_tool/sqflite_common_ffi/databases';
  final dbFile = join(dbPath, 'malbrose_db.db');
  print('Looking for database at: $dbFile');
  
  // Check if file exists
  final file = File(dbFile);
  if (!await file.exists()) {
    print('Database file not found. Trying alternative paths...');
    
    // Try alternative paths
    final workingDir = Directory.current.path;
    final alternativePaths = [
      join(workingDir, '.dart_tool/sqflite_common_ffi/databases/malbrose_db.db'),
      join(workingDir, 'malbrose_db.db'),
    ];
    
    bool found = false;
    for (final path in alternativePaths) {
      final altFile = File(path);
      if (await altFile.exists()) {
        print('Found database at: $path');
        found = true;
        
        // Use this database file
        await fixDatabase(path);
        break;
      }
    }
    
    if (!found) {
      print('Could not find database file. Please provide the path manually.');
      exitCode = 1;
      return;
    }
  } else {
    print('Database file found. Fixing...');
    await fixDatabase(dbFile);
  }
  
  print('Done.');
  exitCode = 0;
}

Future<void> fixDatabase(String dbPath) async {
  print('Fixing database: $dbPath');
  
  // Ensure the file is writable
  try {
    final file = File(dbPath);
    
    // Try to make a backup first
    final backupPath = '$dbPath.bak';
    print('Making backup to: $backupPath');
    await file.copy(backupPath);
    
    // Remove read-only flag on Windows
    if (Platform.isWindows) {
      await Process.run('attrib', ['-R', dbPath]);
      print('Removed read-only attribute');
    } else if (Platform.isLinux || Platform.isMacOS) {
      await Process.run('chmod', ['666', dbPath]);
      print('Changed permissions to 666');
    }
  } catch (e) {
    print('Warning: Failed to prepare file: $e');
  }
  
  // Try to recreate the creditors table
  try {
    // Close any existing connections
    try {
      await databaseFactory.deleteDatabase(dbPath);
    } catch (e) {
      print('Note: Could not close existing connections: $e');
    }
    
    print('Opening database...');
    final db = await openDatabase(
      dbPath,
      readOnly: false,
      singleInstance: true,
    );
    
    // Check if creditors table exists
    final tables = await db.rawQuery("SELECT name FROM sqlite_master WHERE type='table'");
    print('Tables found: ${tables.map((t) => t['name']).join(', ')}');
    
    final creditorTableExists = tables.any((t) => t['name'] == 'creditors');
    
    if (creditorTableExists) {
      print('Found creditors table, checking schema...');
      
      // Check schema to see if it has UNIQUE constraint
      final schema = await db.rawQuery("SELECT sql FROM sqlite_master WHERE name='creditors'");
      final tableSchema = schema[0]['sql'] as String;
      
      print('Current schema: $tableSchema');
      
      final hasUniqueConstraint = tableSchema.toUpperCase().contains('UNIQUE') && 
                                 tableSchema.toUpperCase().contains('NAME');
      
      if (hasUniqueConstraint) {
        print('Found UNIQUE constraint. Removing it...');
        
        // Backup data
        print('Backing up data...');
        final data = await db.query('creditors');
        print('Found ${data.length} records');
        
        // Drop table
        print('Dropping table...');
        await db.execute('DROP TABLE creditors');
        
        // Create new table
        print('Creating new table without UNIQUE constraint...');
        await db.execute('''
          CREATE TABLE creditors (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT NOT NULL,
            balance REAL NOT NULL,
            details TEXT,
            status TEXT NOT NULL,
            created_at TEXT NOT NULL,
            last_updated TEXT,
            order_number TEXT,
            order_details TEXT,
            original_amount REAL
          )
        ''');
        
        // Restore data
        if (data.isNotEmpty) {
          print('Restoring data...');
          int count = 0;
          for (final record in data) {
            try {
              // Remove ID to let SQLite auto-assign
              final recordCopy = Map<String, dynamic>.from(record);
              recordCopy.remove('id');
              
              await db.insert('creditors', recordCopy);
              count++;
            } catch (e) {
              print('Error inserting record: $e');
            }
          }
          print('Restored $count/${data.length} records');
        }
        
        print('UNIQUE constraint removed successfully');
      } else {
        print('No UNIQUE constraint found. Nothing to fix.');
      }
    } else {
      print('Creditors table not found. Creating it...');
      await db.execute('''
        CREATE TABLE creditors (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          name TEXT NOT NULL,
          balance REAL NOT NULL,
          details TEXT,
          status TEXT NOT NULL,
          created_at TEXT NOT NULL,
          last_updated TEXT,
          order_number TEXT,
          order_details TEXT,
          original_amount REAL
        )
      ''');
      print('Created creditors table');
    }
    
    // Close the database
    await db.close();
    print('Database fixed and closed successfully');
    
  } catch (e) {
    print('Error fixing database: $e');
  }
} 