import 'dart:io';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:path/path.dart' show join;

// Database constants
const String dbName = 'malbrose_db.db';
const String tableCreditors = 'creditors';

void main() async {
  print('Starting database fix utility...');
  
  // Initialize sqflite_ffi
  print('Initializing SQLite FFI...');
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;
  
  try {
    await fixDatabase();
    print('Database fix completed successfully.');
    exitCode = 0;
  } catch (e) {
    print('Error fixing database: $e');
    exitCode = 1;
  }
}

Future<void> fixDatabase() async {
  print('Getting database path...');
  String dbPath = '';
  
  try {
    dbPath = await getDatabasesPath();
    if (dbPath.isEmpty) {
      print('Error: Database path is empty.');
      return;
    }
  } catch (e) {
    print('Error getting database path: $e');
    
    // Try to get a reasonable path as fallback
    try {
      final dir = Directory.current;
      dbPath = dir.path;
      print('Using fallback database path: $dbPath');
    } catch (e) {
      print('Error getting fallback path: $e');
      return;
    }
  }
  
  final fullPath = join(dbPath, dbName);
  print('Database path: $fullPath');
  
  // Check if database file exists
  final dbFile = File(fullPath);
  if (!await dbFile.exists()) {
    print('Database file does not exist. Nothing to fix.');
    return;
  }
  
  print('Database file exists. Attempting to fix...');
  
  // Make sure the database file is writable
  try {
    final file = File(fullPath);
    if (await file.exists()) {
      final stat = await file.stat();
      print('Database file permissions: ${stat.mode}');
      
      // Try to make the file writable
      if (Platform.isWindows) {
        try {
          await Process.run('attrib', ['-R', fullPath]);
          print('Removed read-only attribute from database file');
        } catch (e) {
          print('Warning: Failed to remove read-only attribute: $e');
        }
      } else if (Platform.isLinux || Platform.isMacOS) {
        try {
          await Process.run('chmod', ['666', fullPath]);
          print('Changed file permissions to 666');
        } catch (e) {
          print('Warning: Failed to change file permissions: $e');
        }
      }
    }
  } catch (e) {
    print('Error checking file permissions: $e');
  }
  
  // Close any existing database connections
  print('Closing existing database connections...');
  try {
    await databaseFactory.deleteDatabase(fullPath);
  } catch (e) {
    print('Warning: Could not close connections: $e');
  }
  
  try {
    // Open database manually with explicit readOnly: false
    final db = await openDatabase(
      fullPath,
      readOnly: false,
      singleInstance: true,
    );
    
    // Check if creditors table exists
    final tableExists = await db.rawQuery(
      "SELECT name FROM sqlite_master WHERE type='table' AND name='$tableCreditors'"
    );
    
    if (tableExists.isNotEmpty) {
      print('Found creditors table, checking for data...');
      
      // Backup existing data if possible
      List<Map<String, dynamic>> existingData = [];
      try {
        existingData = await db.query(tableCreditors);
        print('Backed up ${existingData.length} creditor records');
      } catch (e) {
        print('Could not backup existing data: $e');
      }
      
      // Get table schema to check for UNIQUE constraint
      final tableSchema = await db.rawQuery(
        "SELECT sql FROM sqlite_master WHERE type='table' AND name='$tableCreditors'"
      );
      
      if (tableSchema.isNotEmpty) {
        final createSql = tableSchema[0]['sql'].toString().toUpperCase();
        final hasUniqueConstraint = createSql.contains('UNIQUE') && createSql.contains('NAME');
        
        if (hasUniqueConstraint) {
          print('Found UNIQUE constraint on creditors.name, will remove it.');
          
          // Drop the table
          await db.execute('DROP TABLE IF EXISTS $tableCreditors');
          print('Dropped creditors table');
          
          // Recreate table without UNIQUE constraint
          await db.execute('''
            CREATE TABLE $tableCreditors (
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
          print('Recreated creditors table without UNIQUE constraint');
          
          // Restore data if any
          if (existingData.isNotEmpty) {
            int restored = 0;
            for (var record in existingData) {
              // Remove id to let it auto-increment
              record.remove('id');
              try {
                await db.insert(tableCreditors, record);
                restored++;
              } catch (e) {
                print('Error restoring record: $e');
              }
            }
            print('Restored $restored/${existingData.length} creditor records');
          }
        } else {
          print('No UNIQUE constraint found on creditors.name, no need to fix.');
        }
      }
    } else {
      // Create creditors table if it doesn't exist
      await db.execute('''
        CREATE TABLE $tableCreditors (
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
      print('Created new creditors table (it did not exist before)');
    }
    
    // Close the database
    await db.close();
    print('Database fix completed successfully');
    
  } catch (e) {
    print('Error fixing database: $e');
    rethrow;
  }
} 