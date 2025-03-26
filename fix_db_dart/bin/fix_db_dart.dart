import 'dart:io';
import 'package:path/path.dart' as path;
import 'package:sqflite_common/sqlite_api.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main(List<String> arguments) async {
  print('Malbrose Database Fix Utility v1.0.0');
  print('-------------------------------------');

  // Initialize SQLite FFI
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  // Search for the database in potential locations
  final dbPaths = [
    path.join('.dart_tool', 'sqflite_common_ffi', 'databases', 'malbrose_db.db'),
    path.join('..', '.dart_tool', 'sqflite_common_ffi', 'databases', 'malbrose_db.db'),
    path.join(Platform.environment['APPDATA'] ?? '', 'com.example.myflutterapp', 'databases', 'malbrose_db.db'),
    'malbrose_db.db',
  ];

  String? dbPath;
  for (final testPath in dbPaths) {
    if (await File(testPath).exists()) {
      dbPath = testPath;
      print('Found database at: $dbPath');
      break;
    }
  }

  if (dbPath == null) {
    print('Error: Could not find the database file');
    print('Searched in:');
    for (final p in dbPaths) {
      print('  - ${path.absolute(p)}');
    }
    exit(1);
  }

  // Check if the file is read-only
  try {
    final file = File(dbPath);
    final stat = await file.stat();
    print('File permissions: ${stat.modeString()}');

    // Try to make the file writable
    if (Platform.isWindows) {
      print('Attempting to make file writable (Windows)...');
      try {
        final result = await Process.run('attrib', ['-r', dbPath]);
        if (result.exitCode == 0) {
          print('Successfully removed read-only attribute');
        } else {
          print('Warning: Failed to remove read-only attribute');
          print(result.stderr);
        }
      } catch (e) {
        print('Warning: Failed to execute attrib command: $e');
      }
    } else {
      print('Attempting to make file writable (Unix)...');
      try {
        final result = await Process.run('chmod', ['666', dbPath]);
        if (result.exitCode == 0) {
          print('Successfully changed file permissions');
        } else {
          print('Warning: Failed to change file permissions');
          print(result.stderr);
        }
      } catch (e) {
        print('Warning: Failed to execute chmod command: $e');
      }
    }

    // Create a backup file
    final backupPath = '$dbPath.bak';
    try {
      await file.copy(backupPath);
      print('Created backup at: $backupPath');
    } catch (e) {
      print('Warning: Failed to create backup: $e');
    }

    // Fix the database
    await fixDatabase(dbPath);
  } catch (e) {
    print('Error: $e');
    exit(1);
  }
}

Future<void> fixDatabase(String dbPath) async {
  try {
    print('Opening database...');
    Database? db;
    try {
      db = await databaseFactory.openDatabase(
        dbPath,
        options: OpenDatabaseOptions(
          readOnly: false,
          singleInstance: true,
        ),
      );
    } catch (e) {
      print('Error opening database: $e');
      print('Trying to close existing connections and retry...');
      await databaseFactory.deleteDatabase(dbPath);
      db = await databaseFactory.openDatabase(
        dbPath,
        options: OpenDatabaseOptions(
          readOnly: false,
          singleInstance: true,
        ),
      );
    }

    // Check if creditors table exists
    final tables = await db.query('sqlite_master', 
      columns: ['name'], 
      where: 'type = ? AND name = ?', 
      whereArgs: ['table', 'creditors']);
    
    if (tables.isEmpty) {
      print('Creditors table not found. No fix needed.');
      await db.close();
      print('Database check completed. No issues found.');
      return;
    }
    
    print('Creditors table found. Checking schema...');

    // Get the current schema
    final schema = await db.query('sqlite_master',
      columns: ['sql'],
      where: 'type = ? AND name = ?',
      whereArgs: ['table', 'creditors']);

    final tableSql = schema.first['sql'] as String;
    print('Current table schema:');
    print(tableSql);

    // Check if UNIQUE constraint exists
    if (!tableSql.toUpperCase().contains('UNIQUE')) {
      print('No UNIQUE constraint found. No fix needed.');
      await db.close();
      print('Database check completed. No issues found.');
      return;
    }

    print('UNIQUE constraint found. Proceeding with fix...');

    // Backup data
    final creditors = await db.query('creditors');
    print('Backed up ${creditors.length} creditor records in memory');

    // Drop the table
    print('Dropping creditors table...');
    await db.execute('DROP TABLE IF EXISTS creditors');

    // Create the table without UNIQUE constraint
    print('Recreating creditors table without UNIQUE constraint...');
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
    print('Restoring data...');
    for (final creditor in creditors) {
      // Remove the id to let it auto-increment
      final data = Map<String, dynamic>.from(creditor);
      data.remove('id');
      await db.insert('creditors', data);
    }

    // Verify the fix
    final newSchema = await db.query('sqlite_master',
      columns: ['sql'],
      where: 'type = ? AND name = ?',
      whereArgs: ['table', 'creditors']);

    print('New table schema:');
    print(newSchema.first['sql']);

    final countResult = await db.rawQuery('SELECT COUNT(*) FROM creditors');
    final count = countResult.first.values.first as int;
    print('Restored $count creditor records');

    await db.close();
    print('Database fix completed successfully.');
  } catch (e) {
    print('Error fixing database: $e');
    exit(1);
  }
}
