import 'package:flutter/material.dart';
import 'package:my_flutter_app/services/database.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'dart:io';

void main() async {
  // Ensure Flutter is initialized
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize sqflite_ffi for desktop (MUST be done before any database operations)
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;
  
  runApp(const FixDbApp());
}

class FixDbApp extends StatelessWidget {
  const FixDbApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Database Fix Utility',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        useMaterial3: true,
      ),
      home: const DatabaseFixScreen(),
    );
  }
}

class DatabaseFixScreen extends StatefulWidget {
  const DatabaseFixScreen({super.key});

  @override
  State<DatabaseFixScreen> createState() => _DatabaseFixScreenState();
}

class _DatabaseFixScreenState extends State<DatabaseFixScreen> {
  bool _isFixing = false;
  final List<String> _logs = [];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Database Fix Utility'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            const Text(
              'This utility will fix issues with your database schema, '
              'specifically the UNIQUE constraint on the creditors table.',
              style: TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _isFixing ? null : _fixDatabase,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
                minimumSize: const Size(200, 50),
              ),
              child: _isFixing
                  ? const CircularProgressIndicator(color: Colors.white)
                  : const Text('Fix Database'),
            ),
            const SizedBox(height: 24),
            const Text('Fix Log:', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: ListView.builder(
                  itemCount: _logs.length,
                  itemBuilder: (context, index) {
                    return Text(_logs[index]);
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _fixDatabase() async {
    setState(() {
      _isFixing = true;
      _logs.add('Starting database fix...');
    });

    try {
      // Make sure SQLite FFI is initialized
      _logs.add('Initializing SQLite FFI...');
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
      
      // Get database path
      _logs.add('Getting database path...');
      final dbPath = await getDatabasesPath();
      final dbFile = join(dbPath, dbName);
      _logs.add('Database path: $dbFile');
      
      // Check if database file exists
      final file = File(dbFile);
      if (!await file.exists()) {
        _logs.add('Database file does not exist. Nothing to fix.');
        return;
      }
      
      // Check if we have write permissions for the folder
      try {
        final testFile = File('${dbPath}/test_write.tmp');
        await testFile.writeAsString('test');
        await testFile.delete();
        _logs.add('Write permissions confirmed for database folder');
      } catch (e) {
        _logs.add('WARNING: No write permissions for database folder: $e');
      }
      
      // Try to fix permissions on the database file
      try {
        final attrs = await file.stat();
        _logs.add('Database file permissions: ${attrs.mode}');
        
        // Try to make the file writable if it's not
        if (Platform.isWindows) {
          try {
            await Process.run('attrib', ['-R', dbFile]);
            _logs.add('Removed read-only attribute from database file');
          } catch (e) {
            _logs.add('Failed to remove read-only attribute: $e');
          }
        } else if (Platform.isLinux || Platform.isMacOS) {
          try {
            await Process.run('chmod', ['666', dbFile]);
            _logs.add('Changed file permissions to 666');
          } catch (e) {
            _logs.add('Failed to change file permissions: $e');
          }
        }
      } catch (e) {
        _logs.add('Error checking file permissions: $e');
      }
      
      // Close any existing database connections
      _logs.add('Closing existing database connections...');
      try {
        await databaseFactory.deleteDatabase(dbFile);
      } catch (e) {
        _logs.add('Warning: Could not close connections: $e');
      }
      
      // Open database with explicit parameters
      _logs.add('Opening database in writable mode...');
      try {
        final db = await openDatabase(
          dbFile,
          readOnly: false,
          singleInstance: true,
        );
        
        // Check if creditors table exists
        _logs.add('Checking if creditors table exists...');
        final tableExists = await db.rawQuery(
          "SELECT name FROM sqlite_master WHERE type='table' AND name='creditors'"
        );
        
        if (tableExists.isNotEmpty) {
          _logs.add('Found creditors table, backing up data...');
          
          // Backup data
          List<Map<String, dynamic>> existingData = [];
          try {
            existingData = await db.query('creditors');
            _logs.add('Backed up ${existingData.length} creditor records');
          } catch (e) {
            _logs.add('Could not backup data: $e');
          }
          
          // Drop table
          _logs.add('Dropping creditors table...');
          await db.execute('DROP TABLE IF EXISTS creditors');
          
          // Recreate table
          _logs.add('Recreating creditors table without UNIQUE constraint...');
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
          if (existingData.isNotEmpty) {
            _logs.add('Restoring data...');
            int restored = 0;
            for (var record in existingData) {
              try {
                record.remove('id'); // Let SQLite assign a new ID
                await db.insert('creditors', record);
                restored++;
              } catch (e) {
                _logs.add('Error restoring record: $e');
              }
            }
            _logs.add('Restored $restored/${existingData.length} records');
          }
        } else {
          _logs.add('Creditors table not found, creating it...');
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
        }
        
        // Close the database
        await db.close();
        _logs.add('Database closed successfully');
        
        _logs.add('Database fix completed successfully!');
      } catch (e) {
        _logs.add('Error fixing database: $e');
      }
    } catch (e) {
      _logs.add('Error: $e');
    } finally {
      setState(() {
        _isFixing = false;
      });
    }
  }
} 