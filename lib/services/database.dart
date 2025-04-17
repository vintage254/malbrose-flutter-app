import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as p;
import 'package:my_flutter_app/models/order_model.dart';
import 'package:my_flutter_app/models/user_model.dart';
import 'package:my_flutter_app/services/auth_service.dart';
import 'package:crypto/crypto.dart';
import 'dart:convert';
import 'package:synchronized/synchronized.dart';
import '../models/customer_model.dart';
import 'dart:io';
import 'dart:math';
import 'dart:async';
import 'package:my_flutter_app/models/product_model.dart';
import 'package:excel/excel.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:bcrypt/bcrypt.dart';

class DatabaseService {
  static final DatabaseService instance = DatabaseService._init();
  static Database? _database;
  final _lock = Lock();
  bool _initialized = false;

  // Database constants
  static const String dbName = 'malbrose_db.db';
  static const int dbVersion = 1;
  
  // Add this property to fix missing databaseVersion error
  final int databaseVersion = 1;
  
  // Table names
  static const String tableUsers = 'users';
  static const String tableCreditors = 'creditors';
  static const String tableDebtors = 'debtors';
  static const String tableProducts = 'products';
  static const String tableOrders = 'orders';
  static const String tableOrderItems = 'order_items';
  static const String tableActivityLogs = 'activity_logs';
  static const String tableCustomers = 'customers';
  static const String tableCustomerReports = 'customer_reports';
  static const String tableReportItems = 'report_items';
  static const String tableCreditTransactions = 'credit_transactions';

  // Action constants
  static const String actionCreateOrder = 'create_order';
  static const String actionUpdateOrder = 'update_order';
  static const String actionCompleteSale = 'complete_sale';
  static const String actionRevertReceipt = 'revert_receipt';
  static const String actionCreateProduct = 'create_product';
  static const String actionUpdateProduct = 'update_product';
  static const String actionCreateCreditor = 'create_creditor';
  static const String actionUpdateCreditor = 'update_creditor';
  static const String actionDeleteCreditor = 'delete_creditor';
  static const String actionCreateDebtor = 'create_debtor';
  static const String actionUpdateDebtor = 'update_debtor';
  static const String actionLogin = 'login';
  static const String actionLogout = 'logout';
  static const String actionCreateCustomerReport = 'create_customer_report';
  static const String actionUpdateCustomerReport = 'update_customer_report';
  static const String actionPrintCustomerReport = 'print_customer_report';
  static const String actionCreateCustomer = 'create_customer';

  // Role and permission constants
  static const String ROLE_ADMIN = 'ADMIN';
  static const String PERMISSION_FULL_ACCESS = 'FULL_ACCESS';
  static const String PERMISSION_BASIC = 'BASIC';

  DatabaseService._init();

  // Completely rewritten database getter to be more reliable
  Future<Database> get database async {
    try {
      if (_database != null) return _database!;

      // Use a lock to prevent multiple initializations at the same time
      return await _lock.synchronized(() async {
        if (_database != null) return _database!;
        
        // Initialize the database with retry 
        _database = await _initDB();
        _initialized = true;
        
        // Add admin user if not exists
        await _ensureAdminUserExists();
        
        return _database!;
      });
    } catch (e) {
      print('Critical error getting database: $e');
      
      // Last resort emergency fallback - create in-memory database
      try {
        if (_database == null) {
          print('Creating emergency in-memory database');
          _database = await openDatabase(
            ':memory:',
            version: databaseVersion,
            onCreate: _createTables,
          );
        }
        return _database!;
      } catch (fallbackError) {
        print('Fatal error creating fallback database: $fallbackError');
        rethrow;
      }
    }
  }

  // Add a method to explicitly close the database
  Future<void> _closeDatabase() async {
    if (_database != null) {
      try {
        await _database!.close();
        print('Database closed successfully');
      } catch (e) {
        print('Error closing database: $e');
      }
      _database = null;
      _initialized = false;
    }
  }
  
  // Add a method to force unlock the database
  Future<void> _forceUnlockDatabase() async {
    try {
      final databasePath = await getDatabasesPath();
      final dbPath = p.join(databasePath, 'malbrose_db.db');
      
      // Check if the database file exists
      final dbFile = File(dbPath);
      if (await dbFile.exists()) {
        // Check for lock files and delete them
        final lockFile = File('$dbPath-shm');
        if (await lockFile.exists()) {
          try {
            await lockFile.delete();
            print('Deleted database lock file: $dbPath-shm');
          } catch (e) {
            print('Warning: Could not delete lock file: $dbPath-shm - $e');
            // Continue even if we can't delete the file
          }
        }
        
        final journalFile = File('$dbPath-wal');
        if (await journalFile.exists()) {
          try {
            await journalFile.delete();
            print('Deleted database journal file: $dbPath-wal');
          } catch (e) {
            print('Warning: Could not delete journal file: $dbPath-wal - $e');
            // Continue even if we can't delete the file
          }
        }
        
        final journalFile2 = File('$dbPath-journal');
        if (await journalFile2.exists()) {
          try {
            await journalFile2.delete();
            print('Deleted database journal file: $dbPath-journal');
          } catch (e) {
            print('Warning: Could not delete journal file: $dbPath-journal - $e');
            // Continue even if we can't delete the file
          }
        }
      }
    } catch (e) {
      print('Warning: Error forcing database unlock: $e');
      // Don't throw the error to avoid crashing the app
    }
  }

  // Completely rewritten transaction method to be more aggressive with retries and timeouts
  Future<T> withTransaction<T>(Future<T> Function(Transaction txn) action) async {
      int retryCount = 0;
    const maxRetries = 2;
      
      while (true) {
      Database db;
      try {
        // Get a fresh database connection for each retry
        if (retryCount > 0) {
          await _closeDatabase();
          _database = null;
          _initialized = false;
        }
        
        db = await database;
        
        // Use a simple transaction with minimal timeout
        return await db.transaction(action, exclusive: true);
        } catch (e) {
        final errorMsg = e.toString().toLowerCase();
        final isLockError = errorMsg.contains('locked') || 
                            errorMsg.contains('busy') || 
                            errorMsg.contains('timeout');
        
          print('Transaction error (attempt ${retryCount + 1}): $e');
          
          // If we've reached max retries or it's not a locking error, rethrow
        if (retryCount >= maxRetries || !isLockError) {
          // Close and reopen database on serious errors
          await _closeDatabase();
          _database = null;
          _initialized = false;
            rethrow;
          }
          
        // Aggressive exponential backoff for retries
        final delay = 500 * (1 << retryCount);
          print('Retrying transaction in $delay ms...');
          await Future.delayed(Duration(milliseconds: delay));
          retryCount++;
        }
      }
  }

  // Completely rewritten _initDatabase method
  Future<Database> _initDB() async {
    try {
      final databasePath = await getDatabasesPath();
      final dbPath = p.join(databasePath, dbName);
      
      // Ensure the directory exists
      final dbDir = Directory(p.dirname(dbPath));
      if (!await dbDir.exists()) {
        await dbDir.create(recursive: true);
      }
      
      // Open database with proper configuration
      return await databaseFactoryFfi.openDatabase(
        dbPath,
        options: OpenDatabaseOptions(
          version: dbVersion,
          onCreate: _createTables,
          // We'll avoid automatically running migrations on each start since we have
          // a comprehensive schema creation in _createTables
          onUpgrade: null, // Remove onUpgrade to avoid unnecessary schema changes
          onOpen: (db) async {
            // Ensure all tables exist when opening
            await _ensureTablesExist(db);
            
            // Enable foreign keys
            await db.execute('PRAGMA foreign_keys = ON');
            
            // Set journal mode to WAL for better performance
            await db.execute('PRAGMA journal_mode = WAL');
            
            // Set synchronous to NORMAL for better performance while maintaining safety
            await db.execute('PRAGMA synchronous = NORMAL');
            
            print('Database opened with pragmas set');
          }
        )
      );
    } catch (e) {
      print('Error initializing database: $e');
      rethrow;
    }
  }
  
  // New method to ensure all tables exist
  Future<void> _ensureTablesExist(Database db) async {
    try {
      await _createTables(db, dbVersion);
      await _ensureCreditorsTableColumns(db); // Add this line
    } catch (e) {
      print('Error ensuring tables exist: $e');
    }
  }

  // Migration to add department column to products table if it doesn't exist
  Future<void> _migrateDatabase(Database db) async {
    try {
      // First check if the products table exists
      final tables = await db.rawQuery("SELECT name FROM sqlite_master WHERE type='table' AND name='$tableProducts'");
      if (tables.isEmpty) {
        print('Products table does not exist yet, skipping migration');
        return;
      }
      
      // Now check if department column exists in products table
      final result = await db.rawQuery('PRAGMA table_info($tableProducts)');
      final hasColumn = result.any((column) => column['name'] == 'department');
      
      if (!hasColumn) {
        await _addDepartmentColumn(db);
      }
    } catch (e) {
      print('Error during database migration: $e');
    }
  }

  // Add department column to products table
  Future<void> _addDepartmentColumn(Database db) async {
    try {
      await db.execute(
        'ALTER TABLE $tableProducts ADD COLUMN department TEXT DEFAULT "${Product.deptLubricants}"'
      );
      print('Added department column to products table');
    } catch (e) {
      print('Error adding department column: $e');
      // If the column already exists, SQLite will throw an error
      // We can safely ignore it
    }
  }

  // Add a method to force a clean database
  Future<void> _forceCleanDatabase(String dbPath) async {
    try {
      // Check if the database file exists
      final dbFile = File(dbPath);
      if (await dbFile.exists()) {
        // Delete the database file
        await dbFile.delete();
        print('Deleted existing database file for clean start');
      }
      
      // Also check for journal and shm files
      final walFile = File('$dbPath-wal');
      if (await walFile.exists()) {
        await walFile.delete();
      }
      
      final shmFile = File('$dbPath-shm');
      if (await shmFile.exists()) {
        await shmFile.delete();
      }
      
      final journalFile = File('$dbPath-journal');
      if (await journalFile.exists()) {
        await journalFile.delete();
      }
      
      print('Forced clean database state');
    } catch (e) {
      print('Error forcing clean database: $e');
    }
  }

  Future<void> _setPragmas(Database db) async {
    try {
        // Enable foreign keys
        await db.execute('PRAGMA foreign_keys=ON');
      
      // Set busy timeout to 3 seconds - even shorter timeout to fail faster
      await db.execute('PRAGMA busy_timeout=3000');
      
      // Performance settings
      await db.execute('PRAGMA cache_size=2000');
      await db.execute('PRAGMA temp_store=MEMORY');
      
      // These settings should be set last
      await db.execute('PRAGMA journal_mode=WAL');
      await db.execute('PRAGMA synchronous=NORMAL');
        await db.execute('PRAGMA locking_mode=NORMAL');
    } catch (e) {
      print('Error setting database pragmas: $e');
    }
  }

  // Create tables
  Future<void> _createTables(Database db, int version) async {
    try {
      print('Creating database tables (version $version)');
      
      // Get existing tables
      final result = await db.query('sqlite_master', 
        where: 'type = ?', 
        whereArgs: ['table'],
        columns: ['name']
      );
      
      final tableNames = result.map((table) => table['name'] as String).toList();
      
      // Create users table if it doesn't exist
      if (!tableNames.contains(tableUsers)) {
        await db.execute('''
          CREATE TABLE IF NOT EXISTS $tableUsers (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            username TEXT NOT NULL UNIQUE,
            password TEXT NOT NULL,
            full_name TEXT NOT NULL,
            email TEXT NOT NULL,
            role TEXT NOT NULL DEFAULT 'USER',
            permissions TEXT NOT NULL DEFAULT 'BASIC',
            created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
            last_login TEXT
          )
        ''');
        print('Users table created or already exists');
      }
      // Create creditors table if it doesn't exist
      if (!tableNames.contains(tableCreditors)) {
        await db.execute('''
          CREATE TABLE IF NOT EXISTS $tableCreditors (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT NOT NULL,
            balance REAL NOT NULL,
            details TEXT,
            status TEXT NOT NULL DEFAULT 'PENDING',
            created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
            last_updated TEXT,
            order_number TEXT,
            order_details TEXT,
            original_amount REAL,
            customer_id INTEGER
          )
        ''');
        print('Creditors table created or already exists');
      }
      
      // Create debtors table if it doesn't exist
      if (!tableNames.contains(tableDebtors)) {
        await db.execute('''
          CREATE TABLE IF NOT EXISTS $tableDebtors (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT NOT NULL,
            balance REAL NOT NULL,
            details TEXT NOT NULL,
            status TEXT NOT NULL,
            created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
            last_updated TEXT,
            contact TEXT,
            id_number TEXT,
            order_number TEXT,
            order_details TEXT,
            original_amount REAL
          )
        ''');
        print('Debtors table created or already exists');
      }
      // Create activity_logs table if it doesn't exist
      if (!tableNames.contains(tableActivityLogs)) {
        await db.execute('''
          CREATE TABLE IF NOT EXISTS $tableActivityLogs (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            user_id INTEGER NOT NULL,
            username TEXT NOT NULL,
            action TEXT NOT NULL,
            action_type TEXT,
            details TEXT NOT NULL,
            timestamp TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
          )
        ''');
        print('Activity logs table created or already exists');
      }
      
      // Create customers table if it doesn't exist
      if (!tableNames.contains(tableCustomers)) {
        await db.execute('''
          CREATE TABLE IF NOT EXISTS $tableCustomers (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT NOT NULL,
            total_orders INTEGER NOT NULL DEFAULT 0,
            total_amount REAL NOT NULL DEFAULT 0.0,
            last_order_date TEXT,
            created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
            updated_at TEXT,
            total_purchases REAL DEFAULT 0.0,
            last_purchase_date TEXT
          )
        ''');
        print('Customers table created or already exists');
      }
      
      // Create customer_reports table if it doesn't exist
      if (!tableNames.contains(tableCustomerReports)) {
        await db.execute('''
          CREATE TABLE IF NOT EXISTS $tableCustomerReports (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            report_number TEXT NOT NULL UNIQUE,
            customer_id INTEGER NOT NULL,
            customer_name TEXT NOT NULL,
            total_amount REAL NOT NULL,
            completed_amount REAL NOT NULL DEFAULT 0.0,
            pending_amount REAL NOT NULL DEFAULT 0.0,
            created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
            start_date TEXT,
            end_date TEXT,
            payment_status TEXT,
            FOREIGN KEY (customer_id) REFERENCES $tableCustomers (id) ON DELETE CASCADE
          )
        ''');
        print('Customer reports table created or already exists');
      }
      
      // Create report_items table if it doesn't exist
      if (!tableNames.contains(tableReportItems)) {
        await db.execute('''
          CREATE TABLE IF NOT EXISTS $tableReportItems (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            report_id INTEGER NOT NULL,
            order_id INTEGER,
            product_id INTEGER,
            product_name TEXT NOT NULL,
            quantity INTEGER NOT NULL,
            unit_price REAL NOT NULL,
            selling_price REAL NOT NULL,
            total_amount REAL NOT NULL,
            status TEXT NOT NULL DEFAULT 'PENDING',
            is_sub_unit INTEGER NOT NULL DEFAULT 0,
            sub_unit_name TEXT,
            created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
            FOREIGN KEY (report_id) REFERENCES $tableCustomerReports (id) ON DELETE CASCADE,
            FOREIGN KEY (product_id) REFERENCES $tableProducts (id) ON DELETE SET NULL
          )
        ''');
        print('Report items table created or already exists');
      }
      
      // Create products table if it doesn't exist
      if (!tableNames.contains(tableProducts)) {
        await db.execute('''
          CREATE TABLE IF NOT EXISTS $tableProducts (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            image TEXT,
            supplier TEXT NOT NULL,
            received_date TEXT NOT NULL,
            product_name TEXT NOT NULL,
            buying_price REAL NOT NULL,
            selling_price REAL NOT NULL,
            quantity INTEGER NOT NULL DEFAULT 0,
            description TEXT,
            has_sub_units INTEGER NOT NULL DEFAULT 0,
            sub_unit_quantity INTEGER,
            sub_unit_price REAL,
            sub_unit_buying_price REAL,
            sub_unit_name TEXT,
            created_by INTEGER,
            updated_by INTEGER,
            number_of_sub_units INTEGER,
            price_per_sub_unit REAL,
            department TEXT NOT NULL DEFAULT 'Lubricants & others',
            created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
            updated_at TEXT
          )
        ''');
        print('Products table created or already exists');
      }
      
      // Create orders table if it doesn't exist
      if (!tableNames.contains(tableOrders)) {
        await db.execute('''
          CREATE TABLE IF NOT EXISTS $tableOrders (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            order_number TEXT NOT NULL UNIQUE,
            sales_receipt_number TEXT,
            held_receipt_number TEXT,
            customer_id INTEGER,
            customer_name TEXT NOT NULL,
            total_amount REAL NOT NULL DEFAULT 0.0,
            order_status TEXT NOT NULL DEFAULT 'PENDING',
            payment_status TEXT NOT NULL DEFAULT 'PENDING',
            payment_method TEXT,
            created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
            updated_at TEXT,
            order_date TEXT NOT NULL,
            created_by INTEGER NOT NULL,
            adjusted_price REAL,
            status TEXT,
            FOREIGN KEY (customer_id) REFERENCES $tableCustomers (id) ON DELETE SET NULL
          )
        ''');
        print('Orders table created or already exists');
      }
      
      // Create order_items table if it doesn't exist
      if (!tableNames.contains(tableOrderItems)) {
        await db.execute('''
          CREATE TABLE IF NOT EXISTS $tableOrderItems (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            order_id INTEGER NOT NULL,
            product_id INTEGER NOT NULL,
            product_name TEXT NOT NULL,
            quantity INTEGER NOT NULL,
            unit_price REAL NOT NULL,
            selling_price REAL NOT NULL,
            adjusted_price REAL,
            total_amount REAL NOT NULL,
            is_sub_unit INTEGER NOT NULL DEFAULT 0,
            sub_unit_name TEXT,
            sub_unit_quantity REAL,
            order_number TEXT,
            order_date TEXT,
            status TEXT,
            created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
            FOREIGN KEY (order_id) REFERENCES $tableOrders (id) ON DELETE CASCADE,
            FOREIGN KEY (product_id) REFERENCES $tableProducts (id) ON DELETE SET NULL
          )
        ''');
        print('Order items table created or already exists');
      }
      
      // Add other table checks as needed
    } catch (e) {
      print('Error creating tables: $e');
      rethrow;
    }
  }
  
  // Add missing columns to tables
  Future<void> _addMissingColumnsToTables(Database db) async {
    try {
      // First, let's add the last_updated alias to products table as a safety measure
      // This will make both 'updated_at' and 'last_updated' work in queries
      try {
        var tableInfo = await db.rawQuery('PRAGMA table_info($tableProducts)');
        List<String> columnNames = tableInfo.map((col) => col['name'].toString()).toList();
        
        // If the table doesn't have last_updated but has updated_at, add last_updated as an alias
        if (!columnNames.contains('last_updated') && columnNames.contains('updated_at')) {
          print('Adding last_updated alias to products table for backwards compatibility');
          await db.execute('ALTER TABLE $tableProducts ADD COLUMN last_updated TEXT');
          
          // Copy all values from updated_at to last_updated
          await db.execute('UPDATE $tableProducts SET last_updated = updated_at');
        }
      } catch (e) {
        print('Warning: Could not add last_updated alias column: $e');
      }
      
      // Check if creditors table has all required columns
      var tableInfo = await db.rawQuery('PRAGMA table_info($tableCreditors)');
      List<String> columnNames = tableInfo.map((col) => col['name'].toString()).toList();
      
      if (!columnNames.contains('order_number')) {
        await db.execute('ALTER TABLE $tableCreditors ADD COLUMN order_number TEXT');
      }
      if (!columnNames.contains('order_details')) {
        await db.execute('ALTER TABLE $tableCreditors ADD COLUMN order_details TEXT');
      }
      if (!columnNames.contains('original_amount')) {
        await db.execute('ALTER TABLE $tableCreditors ADD COLUMN original_amount REAL');
      }
      if (!columnNames.contains('customer_id')) {
        await db.execute('ALTER TABLE $tableCreditors ADD COLUMN customer_id INTEGER');
        print('Added customer_id column to creditors table');
      }
      if (!columnNames.contains('receipt_number')) {
        await db.execute('ALTER TABLE $tableCreditors ADD COLUMN receipt_number TEXT');
        print('Added receipt_number column to creditors table');
      }
      
      // Also call the dedicated method to ensure all creditor columns
      await _ensureCreditorsTableColumns(db);
      
      // Check if order_items table has all required columns
      tableInfo = await db.rawQuery('PRAGMA table_info($tableOrderItems)');
      columnNames = tableInfo.map((col) => col['name'].toString()).toList();
      
      if (!columnNames.contains('selling_price')) {
        await db.execute('ALTER TABLE $tableOrderItems ADD COLUMN selling_price REAL NOT NULL DEFAULT 0');
        print('Added selling_price column to order_items table');
      }
      if (!columnNames.contains('total_amount')) {
        await db.execute('ALTER TABLE $tableOrderItems ADD COLUMN total_amount REAL NOT NULL DEFAULT 0');
        print('Added total_amount column to order_items table');
      }
      if (!columnNames.contains('adjusted_price')) {
        await db.execute('ALTER TABLE $tableOrderItems ADD COLUMN adjusted_price REAL');
        print('Added adjusted_price column to order_items table');
      }
      if (!columnNames.contains('status')) {
        await db.execute('ALTER TABLE $tableOrderItems ADD COLUMN status TEXT');
        print('Added status column to order_items table');
      }
      
      // Check if products table has all required columns
      tableInfo = await db.rawQuery('PRAGMA table_info($tableProducts)');
      columnNames = tableInfo.map((col) => col['name'].toString()).toList();
      
      if (!columnNames.contains('product_name')) {
        // Add product_name column and copy values from name column
        await db.execute('ALTER TABLE $tableProducts ADD COLUMN product_name TEXT');
        
        // Only try to update if the name column exists
        if (columnNames.contains('name')) {
          try {
            await db.execute('UPDATE $tableProducts SET product_name = name');
            print('Added product_name column to products table and copied values from name column');
          } catch (e) {
            print('Error updating product_name from name: $e');
          }
        }
      }
      
      if (!columnNames.contains('supplier')) {
        await db.execute('ALTER TABLE $tableProducts ADD COLUMN supplier TEXT DEFAULT "Unknown"');
        print('Added supplier column to products table');
      }
      
      if (!columnNames.contains('received_date')) {
        await db.execute('ALTER TABLE $tableProducts ADD COLUMN received_date TEXT DEFAULT "${DateTime.now().toIso8601String()}"');
        print('Added received_date column to products table');
      }
      
      if (!columnNames.contains('has_sub_units')) {
        await db.execute('ALTER TABLE $tableProducts ADD COLUMN has_sub_units INTEGER DEFAULT 0');
        print('Added has_sub_units column to products table');
      }
      
      if (!columnNames.contains('number_of_sub_units')) {
        await db.execute('ALTER TABLE $tableProducts ADD COLUMN number_of_sub_units INTEGER');
        print('Added number_of_sub_units column to products table');
      }
      
      if (!columnNames.contains('price_per_sub_unit')) {
        await db.execute('ALTER TABLE $tableProducts ADD COLUMN price_per_sub_unit REAL');
        print('Added price_per_sub_unit column to products table');
      }
      
      if (!columnNames.contains('created_by')) {
        await db.execute('ALTER TABLE $tableProducts ADD COLUMN created_by INTEGER');
        print('Added created_by column to products table');
      }
      
      if (!columnNames.contains('updated_by')) {
        await db.execute('ALTER TABLE $tableProducts ADD COLUMN updated_by INTEGER');
        print('Added updated_by column to products table');
      }
      
      // Check if orders table has all required columns
      tableInfo = await db.rawQuery('PRAGMA table_info($tableOrders)');
      columnNames = tableInfo.map((col) => col['name'].toString()).toList();
      
      if (!columnNames.contains('payment_status')) {
        await db.execute('ALTER TABLE $tableOrders ADD COLUMN payment_status TEXT NOT NULL DEFAULT "PENDING"');
        print('Added payment_status column to orders table');
      }
      
      if (!columnNames.contains('order_date')) {
        await db.execute('ALTER TABLE $tableOrders ADD COLUMN order_date TEXT NOT NULL DEFAULT "${DateTime.now().toIso8601String()}"');
        print('Added order_date column to orders table');
      }
      
      if (!columnNames.contains('updated_at')) {
        await db.execute('ALTER TABLE $tableOrders ADD COLUMN updated_at TEXT');
        print('Added updated_at column to orders table');
      }
      
      // Add checks for other tables as needed
    } catch (e) {
      print('Error adding missing columns: $e');
      // Don't rethrow as this might not be critical
    }
  }

  // Create admin user with specified details
  Future<int> createAdminUser(
    String username,
    String password,
    String fullName,
    String email,
  ) async {
    try {
      final db = await database;
      
      // Hash the password
      final hashedPassword = _hashPassword(password);
      
      // Check if admin user already exists
      final existingAdmin = await db.query(
        tableUsers,
        where: 'username = ?',
        whereArgs: [username],
      );
      
      if (existingAdmin.isNotEmpty) {
        // Update existing admin user
        await db.update(
          tableUsers,
          {
            'password': hashedPassword,
            'full_name': fullName,
            'email': email,
            'role': 'ADMIN',
            'permissions': 'FULL_ACCESS',
            'last_login': DateTime.now().toIso8601String(),
          },
          where: 'username = ?',
          whereArgs: [username],
        );
        
        return existingAdmin.first['id'] as int;
      } else {
        // Create new admin user
        return await db.insert(
          tableUsers,
          {
            'username': username,
            'password': hashedPassword,
            'full_name': fullName,
            'email': email,
            'role': 'ADMIN',
            'permissions': 'FULL_ACCESS',
            'created_at': DateTime.now().toIso8601String(),
            'last_login': DateTime.now().toIso8601String(),
          },
        );
      }
    } catch (e) {
      print('Error creating admin user: $e');
      rethrow;
    }
  }

  // Add a method to revert a completed order
  Future<void> revertCompletedOrder(Order order) async {
    int retryCount = 0;
    const maxRetries = 3;
    const baseDelay = 200; // milliseconds
    
    while (true) {
      try {
        final db = await database;
        await db.transaction((txn) async {
          // Verify the order is completed
          final orderData = await txn.query(
            tableOrders,
            where: 'id = ? AND status = ?',
            whereArgs: [order.id, 'COMPLETED'],
            limit: 1,
          );
          
          if (orderData.isEmpty) {
            throw Exception('Order not found or not in COMPLETED status');
          }
          
          // Get order items with complete information
          final orderItems = await txn.rawQuery('''
            SELECT oi.*, p.id as product_id, p.quantity as current_quantity, p.sub_unit_quantity
            FROM $tableOrderItems oi
            JOIN $tableProducts p ON oi.product_id = p.id
            WHERE oi.order_id = ?
          ''', [order.id]);

          // Update product quantities
          for (var item in orderItems) {
            final productId = item['product_id'] as int;
            final quantity = (item['quantity'] as num).toInt();
            final isSubUnit = (item['is_sub_unit'] as num?) == 1;
            final subUnitQuantity = (item['sub_unit_quantity'] as num?)?.toDouble();
            final currentQuantity = (item['current_quantity'] as num).toDouble();
            
            // Calculate quantity to add back
            double quantityToAdd;
            if (isSubUnit && subUnitQuantity != null && subUnitQuantity > 0) {
              quantityToAdd = quantity / subUnitQuantity;
            } else {
              quantityToAdd = quantity.toDouble();
            }
            
            final newQuantity = currentQuantity + quantityToAdd;
            
            await txn.update(
              tableProducts,
              {'quantity': newQuantity},
              where: 'id = ?',
              whereArgs: [productId],
            );
          }
          
          // Update customer statistics if customer_id exists
          if (order.customerId != null) {
            final customerStats = await txn.query(
              tableCustomers,
              columns: ['total_orders', 'total_amount'],
              where: 'id = ?',
              whereArgs: [order.customerId],
              limit: 1,
            );
            
            if (customerStats.isNotEmpty) {
              final currentTotalOrders = (customerStats.first['total_orders'] as int?) ?? 0;
              final currentTotalAmount = (customerStats.first['total_amount'] as num?)?.toDouble() ?? 0.0;
              
              // Only update if totals would remain non-negative
              if (currentTotalOrders > 0) {
                final newTotalOrders = currentTotalOrders - 1;
                final newTotalAmount = (currentTotalAmount - order.totalAmount).clamp(0.0, double.infinity);
                
                await txn.update(
                  tableCustomers,
                  {
                    'total_orders': newTotalOrders,
                    'total_amount': newTotalAmount,
                    'updated_at': DateTime.now().toIso8601String(),
                  },
                  where: 'id = ?',
                  whereArgs: [order.customerId],
                );
              }
            }
          }
          
          // Update order status to REVERTED
          await txn.update(
            tableOrders,
            {
              'status': 'REVERTED',
              'payment_status': 'REVERTED',
              'updated_at': DateTime.now().toIso8601String(),
            },
            where: 'id = ?',
            whereArgs: [order.id],
          );
          
          // Log the activity
          final currentUser = AuthService.instance.currentUser;
          if (currentUser != null) {
            await txn.insert(tableActivityLogs, {
              'user_id': currentUser.id ?? 0,
              'username': currentUser.username,
              'action': actionRevertReceipt,
              'action_type': 'Revert Receipt',
              'details': 'Reverted receipt for order #${order.orderNumber}, customer: ${order.customerName}, amount: ${order.totalAmount}',
              'timestamp': DateTime.now().toIso8601String(),
            });
          }
        });
        
        // If the transaction was successful, return
        return;
      } catch (e) {
        print('Error reverting order (attempt ${retryCount + 1}): $e');
        
        if (e is DatabaseException && 
            (e.toString().contains('database is locked') || 
             e.toString().contains('database locked')) && 
            retryCount < maxRetries) {
          retryCount++;
          // Exponential backoff with jitter
          final delay = baseDelay * (1 << retryCount) + (Random().nextInt(100));
          print('Database locked. Retrying in $delay ms...');
          await Future.delayed(Duration(milliseconds: delay));
          continue;
        }
        
        // If we've reached max retries or it's not a locking issue, rethrow
        rethrow;
      }
    }
  }

  Future<Customer?> getCustomerById(int id) async {
    try {
      final db = await database;
      final results = await db.query(
        tableCustomers,
        where: 'id = ?',
        whereArgs: [id],
        limit: 1,
      );
      
      return results.isNotEmpty ? Customer.fromMap(results.first) : null;
    } catch (e) {
      print('Error fetching customer by ID: $e');
      return null;
    }
  }

  /// Exports all products to an Excel file
  Future<String> exportProductsToExcel() async {
    try {
      // 1. Get all products from database
      final productsData = await getAllProducts();
      final products = productsData.map((map) => Product.fromMap(map)).toList();
      
      // 2. Create a new Excel workbook
      final excel = Excel.createExcel();
      
      // 3. Get the default sheet (usually "Sheet1")
      String defaultSheet = excel.sheets.keys.first;
      final sheet = excel[defaultSheet];
      
      // 4. Get the headers from Product model
      final headersList = Product.getExcelHeaders();
      
      // 5. Create and append headers as the first row (as TextCellValue objects)
      final headersRow = headersList.map((header) => TextCellValue(header)).toList();
      sheet.appendRow(headersRow);
      
      // 6. Convert each product to row data and append
      for (var product in products) {
        final excelMap = product.toExcelMap();
        
        // Map each header to its corresponding value, converting to appropriate CellValue types
        final rowData = headersList.map((header) {
          final value = excelMap[header];
          if (value == null) return null;
          
          if (value is int) return IntCellValue(value);
          if (value is double) return DoubleCellValue(value);
          return TextCellValue(value.toString());
        }).toList();
        
        // Append row to the sheet
        sheet.appendRow(rowData);
      }
      
      // 7. Get app's documents directory for saving the file
      final directory = await getApplicationDocumentsDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final filePath = '${directory.path}/products_export_$timestamp.xlsx';
      
      // 8. Save Excel to bytes
      var fileBytes = excel.save();
      if (fileBytes == null) {
        throw Exception("Failed to generate Excel file");
      }
      
      // 9. Write bytes to file
      final file = File(filePath);
      await file.writeAsBytes(fileBytes);
      
      print('✅ Excel file saved successfully at: $filePath');
      return filePath;
      
    } catch (e) {
      print('❌ Error exporting products to Excel: $e');
      rethrow;
    }
  }

  /// Creates a new product
  Future<int> createProduct(Map<String, dynamic> productData) async {
    try {
      final db = await database;
      
      // Make sure the current timestamp is set for created_at
      if (!productData.containsKey('created_at')) {
        productData['created_at'] = DateTime.now().toIso8601String();
      }
      
      // Make sure updated_at is also set
      if (!productData.containsKey('updated_at')) {
        productData['updated_at'] = DateTime.now().toIso8601String();
      }
      
      // Check if product with same name exists (using product_name)
      final productName = productData['product_name'];
      if (productName == null || productName.toString().trim().isEmpty) {
        throw Exception('Product name is required');
      }
      
      final existingProducts = await db.query(
        tableProducts,
        where: 'product_name = ?',
        whereArgs: [productName],
        limit: 1,
      );
      
      if (existingProducts.isNotEmpty) {
        // Update existing product
        final productId = existingProducts.first['id'] as int;
        await db.update(
          tableProducts,
          productData,
          where: 'id = ?',
          whereArgs: [productId],
        );
        return productId;
      } else {
        // Insert new product
        return await db.insert(tableProducts, productData);
      }
    } catch (e) {
      print('Error creating product: $e');
      return -1;
    }
  }

  // Helper method to parse double values from Excel cells
  double? _parseDouble(dynamic value) {
    if (value == null) return null;
    
    try {
      if (value is double) return value;
      if (value is int) return value.toDouble();
      
      // Check if the value is a product name or description that was inadvertently mapped to a numeric field
      String stringValue = value.toString().trim();
      // If the string contains mostly text, it's likely not a number at all
      if (stringValue.length > 10 && !stringValue.contains(RegExp(r'[\d]'))) {
        print('Detected non-numeric value in numeric field: $stringValue');
        return null;
      }
      
      // Extract only digits, decimal point, and negative sign
      final numericChars = RegExp(r'[-\d.]+');
      final match = numericChars.firstMatch(stringValue);
      if (match != null) {
        final numericString = match.group(0);
        if (numericString != null) {
          return double.tryParse(numericString);
        }
      }
      
      return null;
    } catch (e) {
      print('Error parsing double: $e');
      return null;
    }
  }
  
  // Helper method to parse integer values from Excel cells
  int? _parseInt(dynamic value) {
    if (value == null) return null;
    
    try {
      if (value is int) return value;
      if (value is double) return value.toInt();
      
      // Check if the value is a product name or description that was inadvertently mapped to a numeric field
      String stringValue = value.toString().trim();
      // If the string contains mostly text, it's likely not a number at all
      if (stringValue.length > 10 && !stringValue.contains(RegExp(r'[\d]'))) {
        print('Detected non-numeric value in numeric field: $stringValue');
        return null;
      }
      
      // Extract only digits and negative sign
      final numericChars = RegExp(r'[-\d]+');
      final match = numericChars.firstMatch(stringValue);
      if (match != null) {
        final numericString = match.group(0);
        if (numericString != null) {
          return int.tryParse(numericString);
        }
      }
      
      return null;
    } catch (e) {
      print('Error parsing int: $e');
      return null;
    }
  }

  // Helper method to set a cell to bold
  void setBold(Sheet sheet, int row, int col) {
    final cell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: col, rowIndex: row));
    // Apply bold style directly to cell
    // Note: CellStyle might not be available in this version of the package
    try {
      cell.cellStyle = CellStyle(
        bold: true,
        horizontalAlign: HorizontalAlign.Center,
      );
    } catch (e) {
      // If CellStyle is not available, just continue with plain text
      print('Warning: Could not apply cell styling: $e');
    }
  }

  /// Imports products from an Excel file
  Future<Map<String, dynamic>> importProductsFromExcel(String filePath) async {
    final errors = <String>[];
    int imported = 0;
    int failed = 0;
    
    try {
      print('Starting Excel import from file: $filePath');
      final bytes = await File(filePath).readAsBytes();
      final excel = Excel.decodeBytes(bytes);
      
      if (excel.tables.isEmpty) {
        return {
          'success': false,
          'message': 'No data found in Excel file',
          'imported': 0,
          'failed': 0,
          'errors': errors,
        };
      }
      
      final sheet = excel.tables.entries.first.value;
      
      // Get headers from first row
      final headers = <String>[];
      for (var cell in sheet.rows.first) {
        if (cell?.value != null) {
          headers.add(cell!.value.toString().trim());
        }
      }
      
      print('Found headers in Excel file: ${headers.join(', ')}');
      
      // Map headers to database fields
      final headerMap = <String, String>{};
      
      // First, analyze the data to determine which columns contain which type of data
      final columnTypes = _analyzeColumnTypes(sheet, headers);
      print('Column type analysis: $columnTypes');
      
      // Then use direct mapping based on column positions and column types
      bool useDirectMapping = true;
      if (useDirectMapping) {
        // Find the likely product name column (usually first text column)
        int productNameIndex = -1;
        int descriptionIndex = -1;
        int buyingPriceIndex = -1;
        int sellingPriceIndex = -1;
        int quantityIndex = -1;
        int supplierIndex = -1;
        int departmentIndex = -1;
        
        // Identify column types and positions
        for (int i = 0; i < headers.length; i++) {
          String type = columnTypes[i] ?? 'unknown';
          String header = headers[i].toLowerCase();
          
          // Check for department column
          if (header.contains('department') || header.contains('dept') || header.contains('category')) {
            departmentIndex = i;
            continue;
          }
          
          // Direct match for product_name (case insensitive)
          if (header == 'product_name' || header == 'product name' || header == 'productname') {
            productNameIndex = i;
            continue; // Skip other checks for this column
          }
          
          if (type == 'text') {
            // Try to identify text columns
            if ((header.contains('name') || header.contains('product') || header.contains('item')) && 
                !header.contains('department') && !header.contains('sub') && 
                productNameIndex == -1) {
              productNameIndex = i;
            } else if (header.contains('desc') || header.contains('detail') || 
                       descriptionIndex == -1) {
              descriptionIndex = i;
            } else if (header.contains('supp') || header.contains('vendor') || 
                       header.contains('dist') || supplierIndex == -1) {
              supplierIndex = i;
            }
          } else if (type == 'numeric') {
            // Try to identify numeric columns
            if (header.contains('buy') || header.contains('cost') || header.contains('purchase') || 
                header.contains('bp') || buyingPriceIndex == -1) {
              buyingPriceIndex = i;
            } else if (header.contains('sell') || header.contains('price') || 
                       header.contains('sp') || header.contains('retail') || 
                       sellingPriceIndex == -1) {
              sellingPriceIndex = i;
            } else if (header.contains('qty') || header.contains('quant') || 
                       header.contains('stock') || quantityIndex == -1) {
              quantityIndex = i;
            }
          }
        }
        
        // Debug print all headers for examination
        for (int i = 0; i < headers.length; i++) {
          print('Header $i: "${headers[i]}" - Type: ${columnTypes[i]}');
        }
        
        // Ensure product_name is always mapped - by default use index 1 if all else fails
        // This is based on your Excel which has product_name in column 1
        if (productNameIndex == -1 && headers.length > 1) {
          print('No product name column detected - defaulting to column index 1');
          productNameIndex = 1;
        }
        
        // If department wasn't found but first column might be department
        if (departmentIndex == -1 && headers.isNotEmpty && 
            headers[0].toLowerCase().contains('department')) {
          departmentIndex = 0;
        }
        
        // If we didn't find specific columns, use positional defaults based on the Excel screenshot
        if (descriptionIndex == -1 && headers.length > 2) descriptionIndex = 2;
        if (buyingPriceIndex == -1 && headers.length > 3) buyingPriceIndex = 3;
        if (sellingPriceIndex == -1 && headers.length > 4) sellingPriceIndex = 4;
        if (supplierIndex == -1 && headers.length > 5) supplierIndex = 5;
        if (quantityIndex == -1 && headers.length > 6) quantityIndex = 6;
        
        // Map the identified indices to field names
        if (productNameIndex >= 0) headerMap[productNameIndex.toString()] = 'product_name';
        if (descriptionIndex >= 0) headerMap[descriptionIndex.toString()] = 'description';
        if (buyingPriceIndex >= 0) headerMap[buyingPriceIndex.toString()] = 'buying_price';
        if (sellingPriceIndex >= 0) headerMap[sellingPriceIndex.toString()] = 'selling_price';
        if (supplierIndex >= 0) headerMap[supplierIndex.toString()] = 'supplier';
        if (quantityIndex >= 0) headerMap[quantityIndex.toString()] = 'quantity';
        if (departmentIndex >= 0) headerMap[departmentIndex.toString()] = 'department';
        
        // Add any additional mappings for sub-units if needed
        int subUnitIndex = -1;
        for (int i = 0; i < headers.length; i++) {
          if (headers[i].toLowerCase().contains('sub') || headers[i].toLowerCase().contains('unit')) {
            subUnitIndex = i;
            break;
          }
        }
        if (subUnitIndex >= 0) headerMap[subUnitIndex.toString()] = 'sub_unit_name';
        
        // Find column for number_of_sub_units if exists
        for (int i = 0; i < headers.length; i++) {
          if (headers[i].toLowerCase().contains('no') && headers[i].toLowerCase().contains('sub')) {
            headerMap[i.toString()] = 'number_of_sub_units';
            break;
          }
        }
        
        print('Using intelligent column mapping based on content analysis');
        print('Mapped headers: $headerMap');
      } else {
        // Original header mapping logic as fallback
        final standardHeaderMap = Product.getHeaderMappings();
        final alternateHeaderMap = Product.getAlternateHeaderMappings();
        
        // First try exact matches with standard headers
        for (var i = 0; i < headers.length; i++) {
          final header = headers[i];
          final headerLower = header.toLowerCase();
          
          // Check standard mapping (case insensitive)
          bool matched = false;
          standardHeaderMap.forEach((key, value) {
            if (key.toLowerCase() == headerLower) {
              headerMap[i.toString()] = value;
              matched = true;
            }
          });
          
          // If not matched, check alternate mappings
          if (!matched) {
            alternateHeaderMap.forEach((key, value) {
              if (key.toLowerCase() == headerLower) {
                headerMap[i.toString()] = value;
                matched = true;
              }
            });
          }
          
          // Special cases for common variations
          if (!matched) {
            // These are the critical fields that are most commonly having issues
            if (headerLower.contains('buy') || headerLower.contains('cost') || headerLower == 'bp') {
              headerMap[i.toString()] = 'buying_price';
            } else if (headerLower.contains('sell') || headerLower.contains('sale') || headerLower.contains('retail') || headerLower == 'sp') {
              headerMap[i.toString()] = 'selling_price';
            } else if (headerLower.contains('qty') || headerLower.contains('quant') || headerLower.contains('stock')) {
              headerMap[i.toString()] = 'quantity';
            } else if (headerLower.contains('supp') || headerLower.contains('vend') || headerLower.contains('dist')) {
              headerMap[i.toString()] = 'supplier';
            } else if (headerLower.contains('name') || headerLower.contains('prod') || headerLower.contains('item')) {
              headerMap[i.toString()] = 'product_name';
            } else if (headerLower.contains('desc')) {
              headerMap[i.toString()] = 'description';
            } else if (headerLower.contains('dept') || headerLower.contains('cat')) {
              headerMap[i.toString()] = 'department';
            }
          }
        }
      }
      
      print('Mapped headers: $headerMap');
      
      // Check for required fields
      final requiredFields = ['product_name', 'buying_price', 'selling_price', 'quantity', 'supplier'];
      final missingFields = requiredFields.where((field) => !headerMap.values.contains(field)).toList();
      
      if (missingFields.isNotEmpty) {
        return {
          'success': false,
          'message': 'Missing required fields: ${missingFields.join(', ')}',
          'imported': 0,
          'failed': 0,
          'errors': errors,
        };
      }
      
      // Process data rows
      for (var i = 1; i < sheet.rows.length; i++) {
        try {
          final row = sheet.rows[i];
          
          // Skip empty rows
          if (row.isEmpty || row.every((cell) => cell?.value == null)) {
            continue;
          }
          
          final productData = <String, dynamic>{};
          
          // Map cell values to product fields
          for (var j = 0; j < row.length; j++) {
            final cell = row[j];
            if (cell?.value != null && headerMap.containsKey(j.toString())) {
              final fieldName = headerMap[j.toString()]!;
              
              // Process based on field type
              if (['buying_price', 'selling_price', 'sub_unit_price', 'price_per_sub_unit', 'sub_unit_buying_price'].contains(fieldName)) {
                // Convert to double
                final numValue = _parseDouble(cell!.value);
                if (numValue != null) {
                  productData[fieldName] = numValue;
                } else {
                  print('Warning: Could not parse "${cell.value}" as double for field $fieldName');
                  // Set a default value to prevent errors
                  productData[fieldName] = 0.0;
                }
              } else if (['quantity', 'sub_unit_quantity', 'number_of_sub_units'].contains(fieldName)) {
                // Convert to int
                final numValue = _parseInt(cell!.value);
                if (numValue != null) {
                  productData[fieldName] = numValue;
                } else {
                  print('Warning: Could not parse "${cell.value}" as int for field $fieldName. Using default 0.');
                  // Set a safe default for quantity
                  productData[fieldName] = 0;
                }
              } else if (fieldName == 'has_sub_units') {
                // Convert Yes/No to 1/0
                final strValue = cell!.value.toString().trim().toLowerCase();
                productData[fieldName] = (strValue == 'yes' || strValue == 'true' || strValue == '1') ? 1 : 0;
              } else if (fieldName == 'received_date') {
                // Parse date
                try {
                  final dateStr = cell!.value.toString().trim();
                  DateTime dateValue;
                  
                  if (dateStr.contains('T')) {
                    // ISO format
                    dateValue = DateTime.parse(dateStr);
                  } else {
                    // Attempt to parse MM/DD/YYYY or similar formats
                    final parts = dateStr.split(RegExp(r'[/\-]'));
                    if (parts.length == 3) {
                      // Assume month/day/year format
                      dateValue = DateTime(int.parse(parts[2]), int.parse(parts[0]), int.parse(parts[1]));
                    } else {
                      // Default to current date if format is unrecognized
                      dateValue = DateTime.now();
                    }
                  }
                  
                  productData[fieldName] = dateValue.toIso8601String();
                } catch (e) {
                  // Default to current date if parsing fails
                  productData[fieldName] = DateTime.now().toIso8601String();
                }
              } else if (fieldName == 'department') {
                // Use the department value from the Excel or default if empty
                String departmentValue = cell!.value.toString().trim();
                if (departmentValue.isEmpty) {
                  productData[fieldName] = Product.deptLubricants;
                } else {
                  productData[fieldName] = Product.normalizeDepartment(departmentValue);
                }
              } else if (fieldName == 'supplier') {
                // Use "System" as default for empty supplier
                String supplierValue = cell!.value.toString().trim();
                productData[fieldName] = supplierValue.isEmpty ? "System" : supplierValue;
              } else {
                // String fields
                productData[fieldName] = cell!.value.toString().trim();
              }
            }
          }
          
          // Check if product_name exists, if not generate a placeholder
          if (!productData.containsKey('product_name')) {
            // Generate placeholder for product_name
            productData['product_name'] = 'Product_${DateTime.now().millisecondsSinceEpoch}';
            print('Warning: Generated placeholder name for product at row ${i+1}');
          }
          
          // Set defaults for missing fields
          if (!productData.containsKey('received_date') || productData['received_date'] == null) {
            productData['received_date'] = DateTime.now().toIso8601String();
          }
          
          if (!productData.containsKey('description')) {
            productData['description'] = '';
          }
          // Set default supplier if not provided
          if (!productData.containsKey('supplier') || productData['supplier'] == null || productData['supplier'].toString().isEmpty) {
            productData['supplier'] = 'System';
          }
          
          // Set default department if not provided
          if (!productData.containsKey('department') || productData['department'] == null) {
            productData['department'] = Product.deptLubricants;
          }
          
          // Set has_sub_units based on whether sub_unit fields are provided
          if (productData.containsKey('sub_unit_name') && productData['sub_unit_name'] != null && productData['sub_unit_name'].toString().isNotEmpty) {
            productData['has_sub_units'] = 1;
          } else {
            productData['has_sub_units'] = 0;
          }
          
          // Fill in default values for required numeric fields
          if (productData['buying_price'] == null) productData['buying_price'] = 0.0;
          if (productData['selling_price'] == null) productData['selling_price'] = 0.0;
          if (productData['quantity'] == null) productData['quantity'] = 0;
          
          // Make sure product_name is not empty
          if (!productData.containsKey('product_name') || productData['product_name'] == null || 
              productData['product_name'].toString().trim().isEmpty) {
            // For product name, we need some value - use a generated name
            productData['product_name'] = 'Product_${DateTime.now().millisecondsSinceEpoch}';
            print('Warning: Generated placeholder name for product at row ${i+1}');
          }
          
          // Ensure supplier has a value
          if (!productData.containsKey('supplier') || productData['supplier'] == null || 
              productData['supplier'].toString().trim().isEmpty) {
            productData['supplier'] = 'Unknown Supplier';
          }
          
          // Print product data for debugging
          print('Row ${i+1} data: ${productData.toString()}');
          
          // Check if product with same name exists
          final result = await createProduct(productData);
          if (result > 0) {
            imported++;
          } else {
            failed++;
            errors.add('Row ${i+1}: Failed to import product "${productData['product_name']}"');
          }
        } catch (e) {
          errors.add('Row ${i+1}: Error processing row: $e');
          failed++;
        }
      }
      
      // Return results
      return {
        'success': true,
        'message': 'Imported $imported products successfully. Failed: $failed',
        'imported': imported,
        'failed': failed,
        'errors': errors,
      };
    } catch (e) {
      print('❌ Error importing products from Excel: $e');
      return {
        'success': false,
        'message': 'Error importing products: $e',
        'imported': imported,
        'failed': failed,
        'errors': errors,
      };
    }
  }
  
  // Analyze column types based on sample data
  Map<int, String> _analyzeColumnTypes(Sheet sheet, List<String> headers) {
    Map<int, String> columnTypes = {};
    
    // Use first few data rows to determine column types
    final sampleSize = min(5, sheet.rows.length - 1);
    
    for (int colIndex = 0; colIndex < headers.length; colIndex++) {
      int numericCount = 0;
      int dateCount = 0;
      int textCount = 0;
      
      for (int rowIndex = 1; rowIndex <= sampleSize; rowIndex++) {
        if (rowIndex < sheet.rows.length && 
            colIndex < sheet.rows[rowIndex].length && 
            sheet.rows[rowIndex][colIndex]?.value != null) {
          final value = sheet.rows[rowIndex][colIndex]!.value;
          
          if (value is double || value is int) {
            numericCount++;
          } else {
            final stringValue = value.toString().trim();
            if (stringValue.isEmpty) continue;
            
            // Check if it's a numeric string
            if (double.tryParse(stringValue) != null) {
              numericCount++;
            }
            // Check if it's a date string
            else if (RegExp(r'^\d{1,2}[/\-]\d{1,2}[/\-]\d{2,4}$').hasMatch(stringValue) ||
                    DateTime.tryParse(stringValue) != null) {
              dateCount++;
            }
            // Otherwise it's text
            else {
              textCount++;
            }
          }
        }
      }
      
      // Determine most common type for this column
      if (numericCount > textCount && numericCount > dateCount) {
        columnTypes[colIndex] = 'numeric';
      } else if (dateCount > numericCount && dateCount > textCount) {
        columnTypes[colIndex] = 'date';
      } else {
        columnTypes[colIndex] = 'text';
      }
    }
    
    return columnTypes;
  }

  /// Delete all products from the database
  Future<int> deleteAllProducts() async {
    final db = await database;
    print('Deleting all products from the database...');
    return await db.delete(tableProducts);
  }

  // Get all orders
  Future<List<Map<String, dynamic>>> getAllOrders() async {
    final db = await database;
    return await db.query(tableOrders, orderBy: 'created_at DESC');
  }

  // Delete order
  Future<int> deleteOrder(int id) async {
    final db = await database;
    try {
      return await withTransaction((txn) async {
        // First delete all order items
        await txn.delete(
          tableOrderItems,
          where: 'order_id = ?',
          whereArgs: [id],
        );
        
        // Then delete the order
        return await txn.delete(
          tableOrders,
          where: 'id = ?',
          whereArgs: [id],
        );
      });
    } catch (e) {
      print('Error deleting order: $e');
      // Try using the more resilient method with retries
      await deleteOrderTransaction(id);
      return 1; // Return 1 to indicate success
    }
  }

  // Get customer by name or ID
  Future<Map<String, dynamic>?> getCustomerByNameOrId(dynamic identifier) async {
    final db = await database;
    List<Map<String, dynamic>> results;
    
    if (identifier is int) {
      // Search by ID
      results = await db.query(
        tableCustomers,
        where: 'id = ?',
        whereArgs: [identifier],
        limit: 1,
      );
    } else if (identifier is String) {
      // Search by name
      results = await db.query(
        tableCustomers,
        where: 'name = ?',
        whereArgs: [identifier],
        limit: 1,
      );
    } else {
      throw ArgumentError('identifier must be int (ID) or String (name)');
    }
    
    return results.isNotEmpty ? results.first : null;
  }
  
  // Check if an order number already exists in the database
  Future<bool> orderNumberExists(String orderNumber) async {
    final db = await database;
    final results = await db.query(
      tableOrders,
      where: 'order_number = ?',
      whereArgs: [orderNumber],
      limit: 1,
    );
    
    return results.isNotEmpty;
  }
  
  // Generate a unique order number by checking if it exists in the database
  Future<String> generateUniqueOrderNumber(String prefix) async {
    final now = DateTime.now();
    final dateStr = DateFormat('yyyyMMdd').format(now);
    final timeStr = DateFormat('HHmmss').format(now);
    
    // First try with regular format
    String orderNumber = '$prefix-$dateStr-$timeStr';
    
    // If it already exists (rare but possible), append a random number
    if (await orderNumberExists(orderNumber)) {
      final random = (1000 + DateTime.now().millisecond).toString();
      orderNumber = '$prefix-$dateStr-$timeStr$random';
    }
    
    return orderNumber;
  }

  // Add delete methods for creditors and debtors
  Future<void> deleteCreditor(int id) async {
    try {
      final db = await database;
      
      // Get creditor details for logging
      final creditor = await db.query(
        tableCreditors,
        columns: ['name'],
        where: 'id = ?',
        whereArgs: [id],
        limit: 1,
      );
      
      await db.delete(
        tableCreditors,
        where: 'id = ?',
        whereArgs: [id],
      );
      
      // Log the activity
      final currentUser = AuthService.instance.currentUser;
      if (currentUser != null && creditor.isNotEmpty) {
        await logActivity(
          currentUser.id ?? 0,
          currentUser.username,
          'delete_creditor',
          'Delete creditor',
          'Deleted credit record for: ${creditor.first['name']}'
        );
      }
    } catch (e) {
      print('Error deleting creditor: $e');
      rethrow;
    }
  }

  Future<void> deleteDebtor(int id) async {
    try {
      final db = await database;
      
      // Get debtor details for logging
      final debtor = await db.query(
        tableDebtors,
        columns: ['name'],
        where: 'id = ?',
        whereArgs: [id],
        limit: 1,
      );
      
      await db.delete(
        tableDebtors,
        where: 'id = ?',
        whereArgs: [id],
      );
      
      // Log the activity
      final currentUser = AuthService.instance.currentUser;
      if (currentUser != null && debtor.isNotEmpty) {
        await logActivity(
          currentUser.id ?? 0,
          currentUser.username,
          'delete_debtor',
          'Delete debtor',
          'Deleted debit record for: ${debtor.first['name']}'
        );
      }
    } catch (e) {
      print('Error deleting debtor: $e');
      rethrow;
    }
  }

  // Initialize the database (backward compatibility method name)
  Future<Database> _initDatabase() => _initDB();

  // Force recreate creditors table to remove UNIQUE constraint - improved version
  Future<void> fixUniqueConstraint() async {
    // Make sure database is initialized with FFI
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    
    print('Manually recreating creditors table to remove UNIQUE constraint');
    
    // Get database path but don't use the getter that might trigger initialization logic
    final dbPath = await getDatabasesPath();
    final dbFile = p.join(dbPath, dbName);
    print('Database path: $dbFile');
    
    try {
      // Open database manually with explicit readOnly: false
      final db = await openDatabase(
        dbFile,
        readOnly: false,
        singleInstance: true,
      );
      
      // Check if creditors table exists
      final tableExists = await db.rawQuery("SELECT name FROM sqlite_master WHERE type='table' AND name='$tableCreditors'");
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
            original_amount REAL,
            customer_id INTEGER
          )
        ''');
        print('Recreated creditors table without UNIQUE constraint');
        
        // Restore data if any
        if (existingData.isNotEmpty) {
          for (var record in existingData) {
            // Remove id to let it auto-increment
            record.remove('id');
            try {
              await db.insert(tableCreditors, record);
            } catch (e) {
              print('Error restoring record: $e');
            }
          }
          print('Restored ${existingData.length} creditor records');
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
            original_amount REAL,
            customer_id INTEGER
          )
        ''');
        print('Created new creditors table without UNIQUE constraint');
      }
      
      // Check and create activity_logs table if it doesn't exist
      final activityLogsExists = await db.rawQuery("SELECT sql FROM sqlite_master WHERE type='table' AND name='$tableActivityLogs'");
      if (activityLogsExists.isEmpty) {
        await db.execute('''
          CREATE TABLE IF NOT EXISTS $tableActivityLogs (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            user_id INTEGER NOT NULL,
            username TEXT,
            action TEXT NOT NULL,
            action_type TEXT,
            details TEXT,
            timestamp TEXT NOT NULL
          )
        ''');
        print('Created activity_logs table');
      }
      
      print('Fixed database successfully');
    } catch (e) {
      print('Error fixing UNIQUE constraint: $e');
      rethrow;
    }
  }

  // Get all credit orders for a specific customer
  Future<List<Map<String, dynamic>>> getCreditOrdersByCustomer(String customerName) async {
    try {
      final db = await database;
      
      return await db.query(
        tableCreditors,
        where: 'name = ? AND status = ? AND balance > 0',
        whereArgs: [customerName, 'PENDING'],
        orderBy: 'created_at ASC', // Order by oldest first (FIFO)
      );
    } catch (e) {
      print('Error getting credit orders by customer: $e');
      return [];
    }
  }

  // Apply payment to customer's credit orders in FIFO order
  Future<void> applyPaymentToCredits(
    String customerName, 
    double paymentAmount, 
    String paymentMethod,
    String paymentDetails
  ) async {
    int retryCount = 0;
    const maxRetries = 3;
    const baseDelay = 200; // milliseconds
    
    while (true) {
      try {
        await withTransaction((txn) async {
          // Get all pending credit orders for this customer
          final creditOrders = await txn.query(
            tableCreditors,
            where: 'name = ? AND status = ? AND balance > 0',
            whereArgs: [customerName, 'PENDING'],
            orderBy: 'created_at ASC', // Order by oldest first (FIFO)
          );
          
          if (creditOrders.isEmpty) {
            return; // No credit orders found
          }
          
          double remainingPayment = paymentAmount;
          final currentUser = AuthService.instance.currentUser;
          final timestamp = DateTime.now().toIso8601String();
          final List<Map<String, dynamic>> updatedCreditors = [];
          
          // Apply payment to each credit order in FIFO order
          for (final order in creditOrders) {
            if (remainingPayment <= 0) break;
            
            final int id = order['id'] as int;
            final double balance = order['balance'] as double;
            final String orderNumber = order['order_number'] as String? ?? 'Unknown';
            
            // Calculate how much to apply to this credit order
            final double amountToApply = remainingPayment >= balance ? balance : remainingPayment;
            final double newBalance = balance - amountToApply;
            final String status = newBalance <= 0 ? 'PAID' : 'PENDING';
            
            // Update the creditor record
            await txn.update(
              tableCreditors,
              {
                'balance': newBalance,
                'status': status,
                'last_updated': timestamp,
                'details': 'Payment of $amountToApply applied via $paymentMethod. $paymentDetails',
              },
              where: 'id = ?',
              whereArgs: [id],
            );
            
            // Also update the order status if fully paid
            if (status == 'PAID') {
              await txn.update(
                tableOrders,
                {
                  'payment_status': 'PAID',
                  'last_updated': timestamp,
                },
                where: 'order_number = ?',
                whereArgs: [orderNumber],
              );
            }
            
            updatedCreditors.add({
              'id': id,
              'order_number': orderNumber,
              'amount_applied': amountToApply,
              'new_balance': newBalance,
              'status': status,
            });
            
            // Reduce the remaining payment
            remainingPayment -= amountToApply;
          }
          
          // Log the activity within the same transaction
          if (currentUser != null) {
            final updatedOrders = updatedCreditors.map((c) => 
              '${c['order_number']}: ${c['amount_applied'].toStringAsFixed(2)} applied (Balance: ${c['new_balance'].toStringAsFixed(2)})'
            ).join(', ');
            
            await txn.insert(
              tableActivityLogs,
              {
                'user_id': currentUser.id ?? 0,
                'username': currentUser.username,
                'action': 'credit_payment',
                'action_type': 'Credit payment',
                'details': 'Applied payment of $paymentAmount to customer $customerName via $paymentMethod. Orders updated: $updatedOrders',
                'timestamp': timestamp,
              },
            );
          }
        });
        
        // If we get here, the transaction was successful
        break;
        
      } catch (e) {
        retryCount++;
        if (retryCount >= maxRetries) {
          print('Error applying payment after $maxRetries attempts: $e');
          rethrow;
        }
        
        // Exponential backoff for retries
        final delay = baseDelay * (1 << retryCount);
        print('Retrying payment application in $delay ms...');
        await Future.delayed(Duration(milliseconds: delay));
      }
    }
  }

  Future<void> fixDatabaseSchema() async {
    try {
      final db = await database;
      
      // Get all table names in the database
      final tables = await db.rawQuery("SELECT name FROM sqlite_master WHERE type='table'");
      final List<String> tableNames = tables.map((t) => t['name'].toString()).toList();
      
      // Check if the customers table exists
      if (tableNames.contains(tableCustomers)) {
        // Get the current columns in the customers table
        final tableInfo = await db.rawQuery('PRAGMA table_info($tableCustomers)');
        final List<String> columnNames = tableInfo.map((col) => col['name'].toString()).toList();
        
        // Check if we have the minimal required columns for the Customer model
        if (!columnNames.contains('name')) {
          await db.execute('ALTER TABLE $tableCustomers ADD COLUMN name TEXT NOT NULL DEFAULT "Unknown"');
        }
        if (!columnNames.contains('total_purchases')) {
          await db.execute('ALTER TABLE $tableCustomers ADD COLUMN total_purchases REAL DEFAULT 0');
        }
        if (!columnNames.contains('last_purchase_date')) {
          await db.execute('ALTER TABLE $tableCustomers ADD COLUMN last_purchase_date TEXT');
        }
        
        print('Updated customers table schema to match model requirements');
      }
    } catch (e) {
      print('Error fixing database schema: $e');
    }
  }

  Future<Database> initDatabase() async {
    try {
      print('Initializing database service...');
      final db = await database;
      
      // Check if database upgrade is required
      await _checkAndUpgradeDatabase(db);
      
      // Migrate any unhashed passwords or activity logs if necessary
      await _migrateUnhashedPasswords();
      await _migrateActivityLogs();
      
      print('Database initialization complete');
      return db; // This return value now matches the Future<Database> type
    } catch (e) {
      print('Error initializing database: $e');
      rethrow;
    }
  }

  // Add a method to completely reset and recreate the database
  Future<void> resetAndRecreateDatabase() async {
    try {
      print('Attempting to reset and recreate database...');
      
      // First, close the database if it's open
      await _closeDatabase();
      
      // Get the database path
      final databasePath = await getDatabasesPath();
      final dbPath = p.join(databasePath, dbName);
      
      // Force clean (delete the database files)
      await _forceCleanDatabase(dbPath);
      
      // Force unlock the database
      await _forceUnlockDatabase();
      
      // Reopen the database (this will trigger table creation)
      _database = null;
      final db = await database;
      
      // Set pragmas and check for upgrades
      await _setPragmas(db);
      await _checkAndUpgradeDatabase(db);
      
      print('Database has been reset and recreated successfully');
    } catch (e) {
      print('Error resetting database: $e');
      rethrow;
    }
  }
  
  // Add a method to reset the admin password
  Future<bool> resetAdminPassword() async {
    try {
      final db = await database;
      
      // Set a known password for the admin user
      final knownPassword = 'admin123';
      final hashedPassword = _hashPassword(knownPassword);
      
      print('Resetting admin password to: $knownPassword');
      print('Hashed password: $hashedPassword');
      
      await db.update(
        tableUsers,
        {'password': hashedPassword},
        where: 'username = ?',
        whereArgs: ['admin']
      );
      
      print('Admin password reset successful');
      return true;
    } catch (e) {
      print('Error resetting admin password: $e');
      return false;
    }
  }

  // Check if database exists and is valid
  Future<bool> checkDatabaseExists() async {
    try {
      // Get database path
      final databasesPath = await getApplicationDocumentsDirectory();
      final dbPath = p.join(databasesPath.path, '..', '.dart_tool', 'sqflite_common_ffi', 'databases', dbName);
      
      // Check if file exists
      final file = File(dbPath);
      final exists = await file.exists();
      
      if (!exists) {
        print('Database file does not exist at: $dbPath');
        return false;
      }
      
      // Try to open the database and check for key tables
      final db = await databaseFactoryFfi.openDatabase(
        dbPath,
        options: OpenDatabaseOptions(readOnly: true)
      );
      
      try {
        // Check for critical tables
        final tables = [tableUsers, tableCreditors, tableProducts, tableOrders];
        for (final table in tables) {
          // Try to query table info
          final result = await db.rawQuery('PRAGMA table_info($table)');
          if (result.isEmpty) {
            print('Table $table does not exist or has no columns');
            await db.close();
            return false;
          }
        }
        
        // Check for admin user
        final adminUser = await db.query(
          tableUsers,
          where: 'username = ?',
          whereArgs: ['admin'],
          limit: 1
        );
        
        if (adminUser.isEmpty) {
          print('Admin user not found in database');
          await db.close();
          return false;
        }
        
        // Close database
        await db.close();
        return true;
      } catch (e) {
        print('Error checking database tables: $e');
        await db.close();
        return false;
      }
    } catch (e) {
      print('Error checking database: $e');
      return false;
    }
  }

  // Update the completeSale method to log properly
  Future<void> completeSale(Order order, {String paymentMethod = 'Cash'}) async {
    int retryCount = 0;
    const maxRetries = 3;
    const baseDelay = 200; // milliseconds
    
    while (true) {
      try {
        final db = await database;
        await db.transaction((txn) async {
          // First verify the order exists and is in a valid state
          final orderData = await txn.query(
            tableOrders,
            where: 'order_number = ? AND order_status != ?',
            whereArgs: [order.orderNumber, 'COMPLETED'],
            limit: 1,
          );
          
          if (orderData.isEmpty) {
            throw Exception('Order not found or already completed');
          }
          
          // Get order items with complete information
          final orderItems = await txn.rawQuery('''
            SELECT oi.*, p.sub_unit_quantity, p.quantity as current_quantity
            FROM $tableOrderItems oi
            JOIN $tableProducts p ON oi.product_id = p.id
            WHERE oi.order_id = ?
          ''', [order.id]);
          
          if (orderItems.isEmpty) {
            throw Exception('No items found for order');
          }
          
          // Update order status using order_status field
          await txn.update(
            tableOrders,
            {
              'order_status': 'COMPLETED',
              'payment_status': paymentMethod == 'Credit' ? 'PENDING' : 'PAID',
              'payment_method': paymentMethod,
              'updated_at': DateTime.now().toIso8601String(),
            },
            where: 'order_number = ?',
            whereArgs: [order.orderNumber],
          );
          
          // Update product quantities
          for (var item in orderItems) {
            final productId = item['product_id'] as int;
            final quantity = item['quantity'] as int;
            final isSubUnit = item['is_sub_unit'] == 1;
            final subUnitQuantity = item['sub_unit_quantity'] as double?;
            
            if (productId <= 0) {
              print('Warning: Invalid product ID found: $productId');
              continue;
            }
            
            // Calculate the actual quantity to deduct
            final actualQuantity = isSubUnit && subUnitQuantity != null
                ? quantity / subUnitQuantity
                : quantity.toDouble();
            
            // Update product quantity
            await txn.rawUpdate('''
              UPDATE $tableProducts 
              SET quantity = quantity - ?,
                  updated_at = CURRENT_TIMESTAMP
              WHERE id = ?
            ''', [actualQuantity, productId]);
          }
          
          // Log the activity
          final currentUser = AuthService.instance.currentUser;
          if (currentUser != null) {
            await txn.insert(
              tableActivityLogs,
              {
                'user_id': currentUser.id ?? 0,
                'username': currentUser.username,
                'action': actionCompleteSale,
                'details': 'Completed sale #${order.orderNumber}, amount: ${order.totalAmount}, method: $paymentMethod',
                'timestamp': DateTime.now().toIso8601String(),
              },
            );
          }
        });
        
        // If we get here, the transaction was successful
        break;
        
      } catch (e) {
        retryCount++;
        if (retryCount >= maxRetries) {
          print('Error completing sale after $maxRetries attempts: $e');
          rethrow;
        }
        
        // Exponential backoff
        final delay = baseDelay * (1 << (retryCount - 1));
        print('Retrying sale completion after $delay ms (attempt $retryCount)');
        await Future.delayed(Duration(milliseconds: delay));
      }
    }
  }

  // Get all debtors
  Future<List<Map<String, dynamic>>> getDebtors() async {
    try {
      final db = await database;
      final debtors = await db.query(
        tableDebtors,
        orderBy: 'created_at DESC',
      );
      return debtors;
    } catch (e) {
      print('Error getting debtors: $e');
      rethrow;
    }
  }

  // Add a new debtor
  Future<int> addDebtor(Map<String, dynamic> debtor) async {
    try {
      final db = await database;
      final id = await db.insert(
        tableDebtors,
        debtor,
      );
      
      // Log the activity
      final currentUser = AuthService.instance.currentUser;
      if (currentUser != null) {
        await logActivity(
          currentUser.id ?? 0,
          currentUser.username,
          actionCreateDebtor,
          'Create debtor',
          'Added debit record for: ${debtor['name']}'
        );
      }
      
      return id;
    } catch (e) {
      print('Error adding debtor: $e');
      rethrow;
    }
  }

  // Update debtor balance and status
  Future<void> updateDebtorBalanceAndStatus(int id, double balance, String details, String status) async {
    try {
      final db = await database;
      
      // Get current debtor details for logging
      final currentDebtor = await db.query(
        tableDebtors,
        columns: ['name', 'balance'],
        where: 'id = ?',
        whereArgs: [id],
        limit: 1,
      );
      
      if (currentDebtor.isEmpty) {
        throw Exception('Debtor not found');
      }
      
      await db.update(
        tableDebtors,
        {
          'balance': balance,
          'details': details,
          'status': status,
          'last_updated': DateTime.now().toIso8601String(),
        },
        where: 'id = ?',
        whereArgs: [id],
      );
      
      // Log the activity
      final currentUser = AuthService.instance.currentUser;
      if (currentUser != null) {
        final oldBalance = currentDebtor.first['balance'] as double;
        await logActivity(
          currentUser.id ?? 0,
          currentUser.username,
          actionUpdateDebtor,
          'Update debtor',
          'Updated balance for ${currentDebtor.first['name']} from $oldBalance to $balance, status: $status'
        );
      }
    } catch (e) {
      print('Error updating debtor: $e');
      rethrow;
    }
  }

  // Get user by ID - used for session restoration
  Future<Map<String, dynamic>?> getUserById(int id) async {
    try {
      final db = await database;
      final result = await db.query(
        tableUsers,
        where: 'id = ?',
        whereArgs: [id],
        limit: 1,
      );
      
      return result.isNotEmpty ? result.first : null;
    } catch (e) {
      print('Error getting user by ID: $e');
      return null;
    }
  }

  // Update user information
  Future<int> updateUser(User user) async {
    try {
      final db = await database;
      return await db.update(
        tableUsers,
        user.toMap(),
        where: 'id = ?',
        whereArgs: [user.id],
      );
    } catch (e) {
      print('Error updating user: $e');
      rethrow;
    }
  }

  // Get all creditors
  Future<List<Map<String, dynamic>>> getCreditors() async {
    try {
      final db = await database;
      final creditors = await db.query(
        tableCreditors,
        orderBy: 'created_at DESC',
      );
      return creditors;
    } catch (e) {
      print('Error getting creditors: $e');
      rethrow;
    }
  }

  // Add a new creditor
  Future<int> addCreditor(Map<String, dynamic> creditor) async {
    try {
      final db = await database;
      
      // Check for existing creditor with same order number if order_number is provided
      if (creditor.containsKey('order_number') && creditor['order_number'] != null) {
        final existingCreditors = await db.query(
          tableCreditors,
          where: 'order_number = ?',
          whereArgs: [creditor['order_number']],
          limit: 1
        );
        
        if (existingCreditors.isNotEmpty) {
          print('Warning: Creditor with order_number ${creditor["order_number"]} already exists. Skipping creation.');
          return existingCreditors.first['id'] as int;
        }
      }
      
      // Try to get customer_id if name is provided but customer_id is not
      if (!creditor.containsKey('customer_id') || creditor['customer_id'] == null) {
        if (creditor.containsKey('name') && creditor['name'] != null) {
          final customerData = await getCustomerByName(creditor['name']);
          if (customerData != null && customerData.containsKey('id')) {
            creditor['customer_id'] = customerData['id'];
          }
        }
      }
      
      // Ensure required fields exist with defaults if missing
      final Map<String, dynamic> safeCreditor = {
        'name': creditor['name'] ?? 'Unknown Customer',
        'balance': creditor['balance'] ?? 0.0,
        'status': creditor['status'] ?? 'PENDING',
        'created_at': creditor['created_at'] ?? DateTime.now().toIso8601String(),
        'details': creditor['details'] ?? 'Credit payment',
      };
      
      // Copy all other fields
      creditor.forEach((key, value) {
        if (!safeCreditor.containsKey(key) && value != null) {
          safeCreditor[key] = value;
        }
      });
      
      // Insert with safe data
      final id = await db.insert(
        tableCreditors,
        safeCreditor,
      );
      
      // Log the activity
      final currentUser = AuthService.instance.currentUser;
      if (currentUser != null) {
        await logActivity(
          currentUser.id ?? 0,
          currentUser.username,
          actionCreateCreditor,
          'Create creditor',
          'Added credit record for: ${safeCreditor['name']}, amount: ${safeCreditor['balance']}'
        );
      }
      
      return id;
    } catch (e) {
      print('Error adding creditor: $e');
      // Add detailed diagnostic info for troubleshooting
      if (e.toString().contains('no such column')) {
        // Get table info to see which columns exist
        try {
          final db = await database;
          final tableInfo = await db.rawQuery('PRAGMA table_info($tableCreditors)');
          print('Available columns in creditors table: ${tableInfo.map((c) => c['name']).join(', ')}');
          print('Attempted to insert: ${creditor.keys.join(', ')}');
        } catch (innerError) {
          print('Failed to get table info: $innerError');
        }
      }
      rethrow;
    }
  }

  // Update creditor balance and status
  Future<void> updateCreditorBalanceAndStatus(int id, double balance, String details, String status, {String? orderNumber}) async {
    try {
      final db = await database;
      
      await withTransaction((txn) async {
        // Get current creditor details for logging
        final currentCreditor = await txn.query(
          tableCreditors,
          columns: ['name', 'balance', 'customer_id'],
          where: 'id = ?',
          whereArgs: [id],
          limit: 1,
        );
        
        if (currentCreditor.isEmpty) {
          throw Exception('Creditor not found');
        }
        
        final updateData = {
          'balance': balance,
          'details': details,
          'status': status,
          'last_updated': DateTime.now().toIso8601String(),
        };
        
        // Add order number if provided
        if (orderNumber != null && orderNumber.isNotEmpty) {
          updateData['order_number'] = orderNumber;
        }
        
        await txn.update(
          tableCreditors,
          updateData,
          where: 'id = ?',
          whereArgs: [id],
        );
        
        // If balance is 0 or less, mark status as PAID
        if (balance <= 0 && status != 'PAID') {
          await txn.update(
            tableCreditors,
            {'status': 'PAID', 'last_updated': DateTime.now().toIso8601String()},
            where: 'id = ?',
            whereArgs: [id],
          );
        }
        
        // Log the activity
        final currentUser = AuthService.instance.currentUser;
        if (currentUser != null) {
          final oldBalance = currentCreditor.first['balance'] as double;
          await logActivity(
            currentUser.id ?? 0,
            currentUser.username,
            actionUpdateCreditor,
            'Update creditor',
            'Updated balance for ${currentCreditor.first['name']} from $oldBalance to $balance, status: $status'
          );
        }
      });
    } catch (e) {
      print('Error updating creditor: $e');
      rethrow;
    }
  }

  /// Log activity in the activity_logs table
  Future<void> logActivity(
    int? userId,
    String username,
    String action,
    String actionType,
    String details,
  ) async {
    try {
      final db = await database;
      await db.insert(
        tableActivityLogs,
        {
          'user_id': userId ?? 0,  // Use 0 as default if userId is null
          'username': username,
          'action': action,
          'action_type': actionType,
          'details': details,
          'timestamp': DateTime.now().toIso8601String(),
        },
      );
    } catch (e) {
      print('Error logging activity: $e');
      // Don't rethrow - logging should never interrupt the main operation
    }
  }

  /// Get activity logs with optional filters
  Future<List<Map<String, dynamic>>> getActivityLogs({
    String? userFilter,
    String? actionFilter,
    String? dateFilter,
  }) async {
    try {
      final db = await database;
      
      String whereClause = '';
      List<dynamic> whereArgs = [];
      
      if (userFilter != null) {
        whereClause += 'username = ?';
        whereArgs.add(userFilter);
      }
      
      if (actionFilter != null) {
        if (whereClause.isNotEmpty) whereClause += ' AND ';
        whereClause += 'action = ?';
        whereArgs.add(actionFilter);
      }
      
      if (dateFilter != null) {
        if (whereClause.isNotEmpty) whereClause += ' AND ';
        whereClause += 'date(timestamp) = date(?)';
        whereArgs.add(dateFilter);
      }
      
      return await db.query(
        tableActivityLogs,
        where: whereClause.isNotEmpty ? whereClause : null,
        whereArgs: whereArgs.isNotEmpty ? whereArgs : null,
        orderBy: 'timestamp DESC',
      );
    } catch (e) {
      print('Error getting activity logs: $e');
      return [];
    }
  }

  /// Get sales report data for a given date range
  Future<List<Map<String, dynamic>>> getSalesReport(
    DateTime startDate,
    DateTime endDate,
  ) async {
    try {
      final db = await database;
      
      return await db.rawQuery('''
        SELECT 
          o.id as order_id,
          o.order_number,
          o.customer_name,
          o.created_at,
          oi.id as item_id,
          oi.product_id,
          oi.product_name,
          oi.quantity,
          oi.unit_price,
          oi.selling_price,
          oi.total_amount,
          oi.is_sub_unit,
          oi.sub_unit_name,
          p.buying_price,
          p.sub_unit_quantity,
          CASE 
            WHEN oi.is_sub_unit = 1 THEN oi.total_amount / oi.quantity
            ELSE oi.unit_price 
          END as effective_price
        FROM $tableOrders o
        JOIN $tableOrderItems oi ON o.id = oi.order_id
        LEFT JOIN $tableProducts p ON oi.product_id = p.id
        WHERE 
          o.order_status = 'COMPLETED' AND
          date(o.created_at) >= date(?) AND
          date(o.created_at) <= date(?)
        ORDER BY o.created_at DESC
      ''', [
        startDate.toIso8601String(),
        endDate.toIso8601String(),
      ]);
    } catch (e) {
      print('Error getting sales report: $e');
      return [];
    }
  }

  /// Get sales summary data for a given date range
  Future<Map<String, dynamic>> getSalesSummary(
    DateTime startDate,
    DateTime endDate,
  ) async {
    try {
      final db = await database;
      
      final results = await db.rawQuery('''
        SELECT 
          COUNT(DISTINCT o.id) as total_orders,
          SUM(oi.total_amount) as total_sales,
          SUM(oi.quantity) as total_quantity,
          COUNT(DISTINCT o.customer_id) as unique_customers,
          SUM(oi.quantity * p.buying_price) as total_buying_cost
        FROM $tableOrders o
        JOIN $tableOrderItems oi ON o.id = oi.order_id
        LEFT JOIN $tableProducts p ON oi.product_id = p.id
        WHERE 
          o.order_status = 'COMPLETED' AND
          date(o.created_at) >= date(?) AND
          date(o.created_at) <= date(?)
      ''', [
        startDate.toIso8601String(),
        endDate.toIso8601String(),
      ]);
      
      final summary = results.first;
      
      // Calculate total profit
      final totalSales = (summary['total_sales'] as num?)?.toDouble() ?? 0.0;
      final totalBuyingCost = (summary['total_buying_cost'] as num?)?.toDouble() ?? 0.0;
      final totalProfit = totalSales - totalBuyingCost;
      
      // Create a new map with all the summary data including profit
      return {
        'total_orders': summary['total_orders'] ?? 0,
        'total_sales': totalSales,
        'total_quantity': summary['total_quantity'] ?? 0,
        'unique_customers': summary['unique_customers'] ?? 0,
        'total_buying_cost': totalBuyingCost,
        'total_profit': totalProfit,
      };
    } catch (e) {
      print('Error getting sales summary: $e');
      return {
        'total_orders': 0,
        'total_sales': 0.0,
        'total_quantity': 0,
        'unique_customers': 0,
        'total_buying_cost': 0.0,
        'total_profit': 0.0,
      };
    }
  }

  /// Insert a new product
  Future<int> insertProduct(Map<String, dynamic> product) async {
    try {
      final db = await database;
      
      // Ensure created_at and updated_at are set
      if (!product.containsKey('created_at')) {
        product['created_at'] = DateTime.now().toIso8601String();
      }
      if (!product.containsKey('updated_at')) {
        product['updated_at'] = DateTime.now().toIso8601String();
      }
      
      // Validate product_name
      if (!product.containsKey('product_name') || 
          product['product_name'] == null || 
          product['product_name'].toString().trim().isEmpty) {
        throw Exception('Product name is required');
      }
      
      return await db.insert(tableProducts, product);
    } catch (e) {
      print('Error inserting product: $e');
      return -1;
    }
  }

  /// Update an existing product
  Future<int> updateProduct(Map<String, dynamic> product) async {
    try {
      final db = await database;
      
      // Ensure updated_at is set
      if (!product.containsKey('updated_at')) {
        product['updated_at'] = DateTime.now().toIso8601String();
      }
      
      // Validate product_name if it's being updated
      if (product.containsKey('product_name') && 
          (product['product_name'] == null || 
           product['product_name'].toString().trim().isEmpty)) {
        throw Exception('Product name cannot be empty');
      }
      
      return await db.update(
        tableProducts,
        product,
        where: 'id = ?',
        whereArgs: [product['id']],
      );
    } catch (e) {
      print('Error updating product: $e');
      return 0;
    }
  }

  /// Get all products
  Future<List<Map<String, dynamic>>> getProducts() async {
    try {
      final db = await database;
      return await db.query(tableProducts, orderBy: 'product_name');
    } catch (e) {
      print('Error getting products: $e');
      return [];
    }
  }

  /// Get a product by ID
  Future<Map<String, dynamic>?> getProductById(int id) async {
    try {
      final db = await database;
      final results = await db.query(
        tableProducts,
        where: 'id = ?',
        whereArgs: [id],
        limit: 1,
      );
      
      return results.isNotEmpty ? results.first : null;
    } catch (e) {
      print('Error getting product by ID: $e');
      return null;
    }
  }

  /// Initialize the database
  Future<void> initialize() async {
    try {
      print('Initializing database service...');
      final db = await database;
      
      // Check if database upgrade is required
      await _checkAndUpgradeDatabase(db);
      
      // Migrate any unhashed passwords or activity logs if necessary
      await _migrateUnhashedPasswords();
      await _migrateActivityLogs();
      
      print('Database initialization complete');
    } catch (e) {
      print('Error initializing database: $e');
      rethrow;
    }
  }

  /// Check if admin user exists
  Future<bool> checkAdminUserExists() async {
    try {
      final db = await database;
      final result = await db.query(
        tableUsers,
        where: 'role = ?',
        whereArgs: [ROLE_ADMIN],
        limit: 1,
      );
      return result.isNotEmpty;
    } catch (e) {
      print('Error checking if admin user exists: $e');
      return false;
    }
  }

  /// Get the current authenticated user
  Future<Map<String, dynamic>?> getCurrentUser() async {
    try {
      final currentUser = AuthService.instance.currentUser;
      if (currentUser == null) {
        return null;
      }
      
      final db = await database;
      final results = await db.query(
        tableUsers,
        where: 'id = ?',
        whereArgs: [currentUser.id],
        limit: 1,
      );
      
      return results.isNotEmpty ? results.first : null;
    } catch (e) {
      print('Error getting current user: $e');
      return null;
    }
  }

  /// Get all products with optional filtering
  Future<List<Map<String, dynamic>>> getAllProducts({bool forceRefresh = false, int? timestamp}) async {
    try {
      final db = await database;
      final results = await db.query(tableProducts, orderBy: 'product_name ASC');
      return results;
    } catch (e) {
      print('Error getting all products: $e');
      return [];
    }
  }

  /// Get order items for an order
  Future<List<Map<String, dynamic>>> getOrderItems(int orderId) async {
    try {
      final db = await database;
      final results = await db.query(
        tableOrderItems,
        where: 'order_id = ?',
        whereArgs: [orderId],
      );
      return results;
    } catch (e) {
      print('Error getting order items: $e');
      return [];
    }
  }

  /// Get customer by name
  Future<Map<String, dynamic>?> getCustomerByName(String name) async {
    try {
      final db = await database;
      final result = await db.query(
        tableCustomers,
        where: 'name = ?',
        whereArgs: [name],
        limit: 1,
      );
      return result.isNotEmpty ? result.first : null;
    } catch (e) {
      print('Error getting customer by name: $e');
      return null;
    }
  }

  /// Create a new customer
  Future<Map<String, dynamic>?> createCustomer(Map<String, dynamic> customer) async {
    try {
      final db = await database;
      final id = await db.insert(tableCustomers, customer);
      return {...customer, 'id': id};
    } catch (e) {
      print('Error creating customer: $e');
      return null;
    }
  }

  /// Create a new order with transaction-safety
  Future<Map<String, dynamic>?> createOrder(Map<String, dynamic> orderMap, List<Map<String, dynamic>> orderItems) async {
    try {
      final db = await database;
      
      return await withTransaction((txn) async {
        // Generate a unique order number
        if (!orderMap.containsKey('order_number') || orderMap['order_number'] == null) {
          orderMap['order_number'] = await _generateOrderNumber(txn);
        }
        
        // Set timestamps
        final now = DateTime.now().toIso8601String();
        orderMap['created_at'] = now;
        orderMap['updated_at'] = now;
        
        // Create customer if not exists
        if (orderMap.containsKey('customer_id') && orderMap['customer_id'] == null && 
            orderMap.containsKey('customer_name') && orderMap['customer_name'] != null) {
          final customerId = await _getOrCreateCustomer(txn, orderMap['customer_name'] as String);
          orderMap['customer_id'] = customerId;
        }
        
        // Insert the order
        final orderId = await txn.insert(tableOrders, orderMap);
        
        // Process order items
        for (final item in orderItems) {
          // Set order ID for the item
          item['order_id'] = orderId;
          
          // Add created_at timestamp to the item
          item['created_at'] = DateTime.now().toIso8601String();
          
          // Insert order item
          await txn.insert(tableOrderItems, item);
          
          // Update product quantity
          if (item.containsKey('product_id') && item['product_id'] != null) {
            if (item['is_sub_unit'] != 1) {
              // For main units, simply decrease quantity
              await txn.rawUpdate(
                'UPDATE $tableProducts SET quantity = quantity - ? WHERE id = ?',
                [item['quantity'], item['product_id']],
              );
            } else {
              // For sub-units, fetch product details and calculate main unit quantity
              final product = await getProductByIdWithTxn(txn, item['product_id'] as int);
              if (product != null && product.containsKey('sub_unit_quantity') && 
                  product['sub_unit_quantity'] != null) {
                final subUnitQuantity = (product['sub_unit_quantity'] as num?)?.toDouble() ?? 0;
                if (subUnitQuantity > 0) {
                  // Calculate how many main units to reduce
                  final quantityToDeduct = ((item['quantity'] as int) / subUnitQuantity).floor();
                  if (quantityToDeduct > 0) {
                    await txn.rawUpdate(
                      'UPDATE $tableProducts SET quantity = quantity - ? WHERE id = ?',
                      [quantityToDeduct, item['product_id']],
                    );
                  }
                }
              }
            }
          }
        }
        
        // Update customer purchase total if applicable
        if (orderMap.containsKey('customer_id') && orderMap['customer_id'] != null) {
          await _updateCustomerPurchases(
            txn, 
            orderMap['customer_id'] as int, 
            orderMap['total_amount'] as double
          );
        }
        
        // Log the activity - using transaction-safe method
        final currentUser = await getCurrentUserWithTxn(txn);
        if (currentUser != null) {
          await txn.insert(
            tableActivityLogs,
            {
              'user_id': currentUser['id'] as int,
              'username': currentUser['username'] as String,
              'action': actionCreateOrder,
              'action_type': 'Create order',
              'details': 'Created order #${orderMap['order_number']} for ${orderMap['customer_name'] ?? 'Walk-in customer'}',
              'timestamp': DateTime.now().toIso8601String(),
            },
          );
        }
        
        return {...orderMap, 'id': orderId};
      });
    } catch (e) {
      print('Error creating order: $e');
      return null;
    }
  }

  /// Helper method to get or create a customer by name within transaction
  Future<int> _getOrCreateCustomer(DatabaseExecutor txn, String name) async {
    try {
      // Check if customer exists
      final customers = await txn.query(
        tableCustomers,
        where: 'name = ?',
        whereArgs: [name],
        limit: 1,
      );
      
      if (customers.isNotEmpty) {
        return customers.first['id'] as int;
      }
      
      // Create new customer
      final now = DateTime.now().toIso8601String();
      final id = await txn.insert(
        tableCustomers,
        {
          'name': name,
          'created_at': now,
          'updated_at': now,
        },
      );
      
      return id;
    } catch (e) {
      print('Error getting or creating customer: $e');
      return -1;
    }
  }

  /// Update an existing order with support for Order object input
  Future<bool> updateOrder(dynamic orderId, [dynamic orderData, List<Map<String, dynamic>>? items]) async {
    try {
      final db = await database;
      
      // Handle different input types
      int orderIdValue;
      Map<String, dynamic> orderMap = {};
      List<Map<String, dynamic>> orderItems = [];
      
      // Extract order ID
      if (orderId is Order) {
        orderIdValue = orderId.id!;
        // If Order object provided as first parameter, use it as the data source
        orderMap = orderId.toMap();
        orderItems = orderId.items?.map((item) => item.toMap()).toList() ?? [];
      } else if (orderId is int) {
        orderIdValue = orderId;
        
        // Extract order data from second parameter if available
        if (orderData is Order) {
          orderMap = orderData.toMap();
          orderItems = orderData.items?.map((item) => item.toMap()).toList() ?? [];
        } else if (orderData is Map<String, dynamic>) {
          orderMap = orderData;
          orderItems = items ?? [];
        }
      } else {
        throw ArgumentError('Invalid order ID or data type');
      }
      
      return await withTransaction((txn) async {
        // Update timestamp
        orderMap['updated_at'] = DateTime.now().toIso8601String();
        
        // Update order
        await txn.update(
          tableOrders,
          orderMap,
          where: 'id = ?',
          whereArgs: [orderIdValue],
        );
        
        // Delete existing order items
        await txn.delete(
          tableOrderItems,
          where: 'order_id = ?',
          whereArgs: [orderIdValue],
        );
        
        // Insert new order items
        for (final item in orderItems) {
          item['order_id'] = orderIdValue;
          
          // Add created_at timestamp if missing
          if (!item.containsKey('created_at') || item['created_at'] == null) {
            item['created_at'] = DateTime.now().toIso8601String();
          }
          
          await txn.insert(tableOrderItems, item);
        }
        
        // Log the activity - using transaction-safe method
        final currentUser = await getCurrentUserWithTxn(txn);
        if (currentUser != null) {
          await txn.insert(
            tableActivityLogs,
            {
              'user_id': currentUser['id'] as int,
              'username': currentUser['username'] as String,
              'action': actionUpdateOrder,
              'action_type': 'Update order',
              'details': 'Updated order #${orderMap['order_number'] ?? 'unknown'}',
              'timestamp': DateTime.now().toIso8601String(),
            },
          );
        }
        
        return true;
      });
    } catch (e) {
      print('Error updating order: $e');
      return false;
    }
  }

  /// Get orders by status
  Future<List<Map<String, dynamic>>> getOrdersByStatus(String status) async {
    try {
      final db = await database;
      return await db.rawQuery('''
        WITH order_items_json AS (
          SELECT 
            o.id as order_id,
            CASE 
              WHEN COUNT(oi.id) > 0 THEN
                json_group_array(
                  json_object(
                    'product_id', oi.product_id,
                    'quantity', oi.quantity,
                    'unit_price', oi.unit_price,
                    'selling_price', oi.selling_price,
                    'total_amount', oi.total_amount,
                    'product_name', p.product_name,
                    'is_sub_unit', oi.is_sub_unit,
                    'sub_unit_name', oi.sub_unit_name,
                    'sub_unit_quantity', oi.sub_unit_quantity,
                    'adjusted_price', oi.adjusted_price
                  )
                )
              ELSE '[]'
            END as items_json
          FROM $tableOrders o
          LEFT JOIN $tableOrderItems oi ON o.id = oi.order_id
          LEFT JOIN $tableProducts p ON oi.product_id = p.id
          WHERE o.order_status = ? AND (o.status != 'CONVERTED' OR o.status IS NULL)
          GROUP BY o.id
        )
        SELECT 
          o.*,
          COALESCE(oij.items_json, '[]') as items_json
        FROM $tableOrders o
        LEFT JOIN order_items_json oij ON o.id = oij.order_id
        WHERE o.order_status = ? AND (o.status != 'CONVERTED' OR o.status IS NULL)
        ORDER BY o.created_at DESC
      ''', [status, status]);
    } catch (e) {
      print('Error getting orders by status: $e');
      return [];
    }
  }
  
  /// Update order status
  Future<bool> updateOrderStatus(int orderId, String status) async {
    try {
      final db = await database;
      
      return await withTransaction((txn) async {
        // Get the order first to log details
        final orderQuery = await txn.query(
          tableOrders,
          columns: ['order_number', 'order_status'],
          where: 'id = ?',
          whereArgs: [orderId],
          limit: 1,
        );
        
        if (orderQuery.isEmpty) {
          throw Exception('Order not found');
        }
        
        final oldOrder = orderQuery.first;
        final oldStatus = oldOrder['order_status'] as String;
        final orderNumber = oldOrder['order_number'] as String;
        
        // Update the order status
        await txn.update(
          tableOrders,
          {
            'order_status': status,
            'updated_at': DateTime.now().toIso8601String(),
          },
          where: 'id = ?',
          whereArgs: [orderId],
        );
        
        // Log the status change
        final currentUser = AuthService.instance.currentUser;
        if (currentUser != null) {
          await txn.insert(
            tableActivityLogs,
            {
              'user_id': currentUser.id ?? 0,
              'username': currentUser.username,
              'action': 'change_order_status',
              'action_type': 'Change order status',
              'details': 'Changed order #$orderNumber status from $oldStatus to $status',
              'timestamp': DateTime.now().toIso8601String(),
            },
          );
        }
        
        return true;
      });
    } catch (e) {
      print('Error updating order status: $e');
      return false;
    }
  }

  /// Get product by name
  Future<List<Map<String, dynamic>>> getProductByName(String name) async {
    try {
      final db = await database;
      final results = await db.query(
        tableProducts,
        where: 'product_name LIKE ?',
        whereArgs: ['%$name%'],
      );
      return results;
    } catch (e) {
      print('Error getting product by name: $e');
      return [];
    }
  }

  /// Get all users
  Future<List<Map<String, dynamic>>> getAllUsers() async {
    try {
      final db = await database;
      final results = await db.query(tableUsers, orderBy: 'username ASC');
      return results;
    } catch (e) {
      print('Error getting all users: $e');
      return [];
    }
  }
  
  /// Migrate unhashed passwords if any exist
  Future<void> _migrateUnhashedPasswords() async {
    try {
      final db = await database;
      
      // Check for users with unhashed passwords
      final users = await db.query(tableUsers);
      
      // Check if admin user exists
      final adminExists = users.any((user) => user['username'] == 'admin');
      
      // Create admin user if it doesn't exist
      if (!adminExists) {
        print('Admin user not found. Creating default admin user...');
        
        // Create default admin user with a plain, simple password that BCrypt can reliably verify
        // Use a fixed plaintext password that will be consistently hashed and verified
        final plainPassword = 'admin123';
        
        // Important: Use the exact same hashing method that will be used for verification
        final hashedPassword = AuthService.instance.hashPassword(plainPassword);
        
        // Debug password hashing
        print('Creating admin with plain password: $plainPassword');
        print('Hashed admin password: $hashedPassword');
        
        final adminUserData = {
          'username': 'admin',
          'password': hashedPassword,
          'full_name': 'System Administrator',
          'email': 'admin@example.com',
          'role': ROLE_ADMIN,
          'permissions': PERMISSION_FULL_ACCESS,
          'created_at': DateTime.now().toIso8601String(),
        };
        
        final id = await createUser(adminUserData);
        if (id != null) {
          print('Default admin user created successfully with ID: $id');
          
          // Verify the password would work immediately after creation as a sanity check
          final verifyResult = AuthService.instance.verifyPassword(plainPassword, hashedPassword);
          print('Admin password verification test: ${verifyResult ? 'PASSED' : 'FAILED'}');
        } else {
          print('Failed to create default admin user.');
        }
      } else {
        print('Admin user already exists.');
      }
      
      for (final user in users) {
        final password = user['password'] as String?;
        final username = user['username'] as String?;
        
        // Skip the admin user to prevent double-hashing
        if (username == 'admin') {
          print('Skipping admin user in password migration to prevent double-hashing');
          continue;
        }
        
        if (password != null && !password.startsWith('\$2a\$')) {
          // Hash the password
          final hashedPassword = AuthService.instance.hashPassword(password);
          
          // Update the user record
          await db.update(
            tableUsers,
            {'password': hashedPassword},
            where: 'id = ?',
            whereArgs: [user['id']],
          );
        }
      }
    } catch (e) {
      print('Error migrating unhashed passwords: $e');
    }
  }
  
  /// Migrate activity logs if needed
  Future<void> _migrateActivityLogs() async {
    try {
      final db = await database;
      
      // Add any activity log migration logic here
      // For example, adding missing columns or updating formats
      
    } catch (e) {
      print('Error migrating activity logs: $e');
    }
  }

  /// Delete a user
  Future<bool> deleteUser(int userId) async {
    try {
      final db = await database;
      
      // Get user information for logging
      final userResult = await db.query(
        tableUsers,
        where: 'id = ?',
        whereArgs: [userId],
        limit: 1,
      );
      
      if (userResult.isEmpty) {
        return false;
      }
      
      final user = userResult.first;
      
      // Delete the user
      final deletedRows = await db.delete(
        tableUsers,
        where: 'id = ?',
        whereArgs: [userId],
      );
      
      // Log the activity
      final currentUser = await getCurrentUser();
      if (currentUser != null) {
        await logActivity(
          currentUser['id'] as int,
          currentUser['username'] as String,
          'delete_user',
          'Delete user',
          'Deleted user: ${user['username']}'
        );
      }
      
      return deletedRows > 0;
    } catch (e) {
      print('Error deleting user: $e');
      return false;
    }
  }

  /// Check if user has admin privileges
  Future<bool> hasAdminPrivileges(int userId) async {
    try {
      final db = await database;
      final result = await db.query(
        tableUsers,
        columns: ['role'],
        where: 'id = ?',
        whereArgs: [userId],
        limit: 1,
      );
      
      if (result.isEmpty) {
        return false;
      }
      
      final role = result.first['role'] as String?;
      return role == ROLE_ADMIN;
    } catch (e) {
      print('Error checking admin privileges: $e');
      return false;
    }
  }

  /// Check if user has a specific permission
  Future<bool> hasPermission(int userId, String permission) async {
    try {
      final db = await database;
      final result = await db.query(
        tableUsers,
        columns: ['permissions'],
        where: 'id = ?',
        whereArgs: [userId],
        limit: 1,
      );
      
      if (result.isEmpty) {
        return false;
      }
      
      final permissions = result.first['permissions'] as String?;
      return permissions?.contains(permission) ?? false;
    } catch (e) {
      print('Error checking permission: $e');
      return false;
    }
  }

  /// Get all usernames
  Future<List<String>> getAllUsernames() async {
    try {
      final db = await database;
      final results = await db.query(
        tableUsers,
        columns: ['username'],
        orderBy: 'username ASC',
      );
      
      return results.map((user) => user['username'] as String).toList();
    } catch (e) {
      print('Error getting all usernames: $e');
      return [];
    }
  }

  /// Get all customers
  Future<List<Map<String, dynamic>>> getAllCustomers() async {
    try {
      final db = await database;
      final results = await db.query(tableCustomers);
      return results;
    } catch (e) {
      print('Error getting all customers: $e');
      return [];
    }
  }

  /// Get orders for a specific customer
  Future<List<Map<String, dynamic>>> getCustomerOrders(int customerId) async {
    try {
      final db = await database;
      final results = await db.query(
        tableOrders,
        where: 'customer_id = ?',
        whereArgs: [customerId],
        orderBy: 'created_at DESC',
      );
      return results;
    } catch (e) {
      print('Error getting customer orders: $e');
      return [];
    }
  }

  /// Get orders by date range
  Future<List<Map<String, dynamic>>> getOrdersByDateRange(DateTime startDate, DateTime endDate) async {
    try {
      final db = await database;
      
      // Convert dates to ISO strings for SQLite comparison
      final startStr = startDate.toIso8601String();
      final endStr = endDate.add(const Duration(days: 1)).toIso8601String(); // Add a day to include the end date
      
      final results = await db.query(
        tableOrders,
        where: 'created_at BETWEEN ? AND ?',
        whereArgs: [startStr, endStr],
        orderBy: 'created_at DESC',
      );
      
      return results;
    } catch (e) {
      print('Error getting orders by date range: $e');
      return [];
    }
  }

  /// Hash a password
  String _hashPassword(String password) {
    try {
      final salt = BCrypt.gensalt(logRounds: 12);
      return BCrypt.hashpw(password, salt);
    } catch (e) {
      print('Error hashing password: $e');
      throw Exception('Password hashing failed');
    }
  }

  /// Delete an order transaction
  Future<bool> deleteOrderTransaction(int orderId) async {
    try {
      final db = await database;
      
      return await withTransaction((txn) async {
        // Get order info for logging
        final orderResult = await txn.query(
          tableOrders,
          where: 'id = ?',
          whereArgs: [orderId],
          limit: 1,
        );
        
        if (orderResult.isEmpty) {
          return false;
        }
        
        final order = orderResult.first;
        
        // Get order items to restore product quantities
        final items = await txn.query(
          tableOrderItems,
          where: 'order_id = ?',
          whereArgs: [orderId],
        );
        
        // Restore product quantities
        for (final item in items) {
          if (item['is_sub_unit'] != 1) {
            await _updateProductQuantity(
              txn, 
              item['product_id'] as int, 
              item['quantity'] as int
            );
          } else {
            // Restore sub-unit quantity - using transaction-safe method
            final product = await getProductByIdWithTxn(txn, item['product_id'] as int);
            if (product != null) {
              // Handle sub_unit_quantity as double since it's stored as REAL
              final subUnitQuantity = (product['sub_unit_quantity'] as num?)?.toDouble() ?? 0;
              if (subUnitQuantity > 0) {
                // Calculate how many main units to add back
                final quantityToAdd = ((item['quantity'] as int) / subUnitQuantity).floor();
                if (quantityToAdd > 0) {
                  await _updateProductQuantity(
                    txn, 
                    item['product_id'] as int, 
                    quantityToAdd
                  );
                }
              }
            }
          }
        }
        
        // Delete order items
        await txn.delete(
          tableOrderItems,
          where: 'order_id = ?',
          whereArgs: [orderId],
        );
        
        // Delete order
        await txn.delete(
          tableOrders,
          where: 'id = ?',
          whereArgs: [orderId],
        );
        
        // Log the activity - using transaction-safe method
        final currentUser = await getCurrentUserWithTxn(txn);
        if (currentUser != null) {
          await txn.insert(
            tableActivityLogs,
            {
              'user_id': currentUser['id'] as int,
              'username': currentUser['username'] as String,
              'action': 'delete_order',
              'action_type': 'Delete order',
              'details': 'Deleted order #${order['order_number']}',
              'timestamp': DateTime.now().toIso8601String(),
            },
          );
        }
        
        return true;
      });
    } catch (e) {
      print('Error deleting order transaction: $e');
      return false;
    }
  }

  /// Helper method to update product quantity
  Future<void> _updateProductQuantity(DatabaseExecutor db, int productId, int quantityChange) async {
    try {
      await db.rawUpdate(
        'UPDATE $tableProducts SET quantity = quantity + ? WHERE id = ?',
        [quantityChange, productId],
      );
    } catch (e) {
      print('Error updating product quantity: $e');
    }
  }

  /// Helper method to update customer purchase total
  Future<void> _updateCustomerPurchases(DatabaseExecutor db, int customerId, double amount) async {
    try {
      await db.rawUpdate(
        'UPDATE $tableCustomers SET total_purchases = total_purchases + ? WHERE id = ?',
        [amount, customerId],
      );
    } catch (e) {
      print('Error updating customer purchases: $e');
    }
  }

  /// Generate a unique order number
  Future<String> _generateOrderNumber(DatabaseExecutor db) async {
    final now = DateTime.now();
    final prefix = 'ORD';
    final date = DateFormat('yyyyMMdd').format(now);
    final time = DateFormat('HHmmss').format(now);
    
    final orderNumber = '$prefix-$date-$time';
    
    // Check if this order number already exists (unlikely but possible)
    final exists = await db.query(
      tableOrders,
      where: 'order_number = ?',
      whereArgs: [orderNumber],
    );
    
    if (exists.isNotEmpty) {
      // Add a random suffix to ensure uniqueness
      final random = Random().nextInt(1000).toString().padLeft(3, '0');
      return '$orderNumber-$random';
    }
    
    return orderNumber;
  }

  // Add or update the _checkAndUpgradeDatabase method
  Future<void> _checkAndUpgradeDatabase(Database db) async {
    try {
      // Check current version
      final version = await db.getVersion();
      print('Database version: $version');
      
      // If needed, perform migrations
      await _migrateDatabase(db);
      
    } catch (e) {
      print('Error checking or upgrading database: $e');
    }
  }

  // Add the _onUpgrade method
  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    print('Upgrading database from version $oldVersion to $newVersion');
    try {
      // Call the migration logic
      await _migrateDatabase(db);
    } catch (e) {
      print('Error in _onUpgrade: $e');
    }
  }

  /// Fix the syntax error at line 3309
  printDebug(String message) {
    print(message);
  }

  /// Create a new user
  Future<Map<String, dynamic>?> createUser(Map<String, dynamic> userData) async {
    try {
      final db = await database;
      
      // Hash the password if not already hashed
      if (userData.containsKey('password')) {
        final password = userData['password'] as String;
        userData['password'] = _hashPassword(password);
      }
      
      // Set default values if not provided
      if (!userData.containsKey('created_at')) {
        userData['created_at'] = DateTime.now().toIso8601String();
      }
      
      // Insert the user
      final id = await db.insert(tableUsers, userData);
      
      return {...userData, 'id': id};
    } catch (e) {
      print('Error creating user: $e');
      return null;
    }
  }

  /// Get a product by ID with transaction
  Future<Map<String, dynamic>?> getProductByIdWithTxn(DatabaseExecutor txn, int id) async {
    try {
      final results = await txn.query(
        tableProducts,
        where: 'id = ?',
        whereArgs: [id],
        limit: 1,
      );
      
      return results.isNotEmpty ? results.first : null;
    } catch (e) {
      print('Error getting product by ID with transaction: $e');
      return null;
    }
  }

  /// Get current user with transaction
  Future<Map<String, dynamic>?> getCurrentUserWithTxn(DatabaseExecutor txn) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getInt('userId');
      
      if (userId == null) {
        return null;
      }
      
      final results = await txn.query(
        tableUsers,
        where: 'id = ?',
        whereArgs: [userId],
        limit: 1,
      );
      
      return results.isNotEmpty ? results.first : null;
    } catch (e) {
      print('Error getting current user with transaction: $e');
      return null;
    }
  }

  /// Reads the headers from an Excel file without importing
  Future<Map<String, dynamic>> readExcelHeaders(String filePath) async {
    try {
      final bytes = await File(filePath).readAsBytes();
      final excel = Excel.decodeBytes(bytes);
      
      if (excel.tables.isEmpty) {
        return {
          'success': false,
          'message': 'No data found in Excel file',
          'headers': <String>[],
        };
      }
      
      final sheet = excel.tables.entries.first.value;
      
      // Get headers from first row
      final headers = <String>[];
      for (var cell in sheet.rows.first) {
        if (cell?.value != null) {
          headers.add(cell!.value.toString().trim());
        }
      }
      
      // Generate initial mapping using our existing header mappings
      final headerMappings = Product.getHeaderMappings();
      final alternateHeaderMappings = Product.getAlternateHeaderMappings();
      final initialMapping = <String, String>{};
      
      for (var header in headers) {
        String? mappedField = headerMappings[header];
        if (mappedField == null) {
          mappedField = alternateHeaderMappings[header.toLowerCase()];
        }
        if (mappedField != null) {
          initialMapping[header] = mappedField;
        }
      }
      
      return {
        'success': true,
        'message': 'Found ${headers.length} columns',
        'headers': headers,
        'initialMapping': initialMapping,
      };
    } catch (e) {
      print('Error reading Excel headers: $e');
      return {
        'success': false,
        'message': 'Error reading Excel file: $e',
        'headers': <String>[],
      };
    }
  }
  
  /// Imports products from an Excel file with custom column mapping
  Future<Map<String, dynamic>> importProductsFromExcelWithMapping(
    String filePath, 
    Map<String, String?> columnMapping,
    // Add a progress callback parameter
    Function(Map<String, dynamic> progressData)? onProgress
  ) async {
    final errors = <String>[];
    int imported = 0;
    int failed = 0;
    int current = 0;
    int total = 0;
    
    try {
      print('Starting Excel import from file: $filePath with custom mapping');
      final bytes = await File(filePath).readAsBytes();
      final excel = Excel.decodeBytes(bytes);
      
      if (excel.tables.isEmpty) {
        // Call progress callback with the error
        onProgress?.call({
          'success': false,
          'message': 'No data found in Excel file',
          'current': 0,
          'total': 0,
          'percentage': 0.0,
          'completed': true,
        });
        
        return {
          'success': false,
          'message': 'No data found in Excel file',
          'imported': 0,
          'failed': 0,
          'errors': errors,
          'current': 0,
          'total': 0,
          'percentage': 0.0,
          'completed': true,
        };
      }
      
      final sheet = excel.tables.entries.first.value;
      
      // Get headers from first row
      final headers = <String>[];
      for (var cell in sheet.rows.first) {
        if (cell?.value != null) {
          headers.add(cell!.value.toString().trim());
        }
      }
      
      // Calculate total rows
      total = sheet.rows.length - 1; // Subtract header row
      
      // Initial progress update
      onProgress?.call({
        'current': 0,
        'total': total,
        'percentage': 0.0,
        'message': 'Reading headers...',
        'completed': false,
      });
      
      // Create a mapping from column index to database field
      final headerMap = <int, String>{};
      for (int i = 0; i < headers.length; i++) {
        final header = headers[i];
        final dbField = columnMapping[header];
        if (dbField != null) {
          headerMap[i] = dbField;
        }
      }
      
      // Process each row from the Excel file
      for (var i = 1; i < sheet.rows.length; i++) {
        current = i;
        
        // Update progress every 5 rows or on the first/last row
        if (current % 5 == 0 || current == 1 || current == total) {
          double percentage = total > 0 ? (current / total * 100) : 0.0;
          onProgress?.call({
            'current': current,
            'total': total,
            'percentage': percentage,
            'message': 'Processing row $current of $total...',
            'completed': false,
          });
          
          // Small delay to allow UI to update
          await Future.delayed(Duration(milliseconds: 5));
        }
        
        try {
          final row = sheet.rows[i];
          
          // Skip empty rows
          if (row.isEmpty || row.every((cell) => cell?.value == null)) {
            continue;
          }
          
          final productData = <String, dynamic>{};
          
          // Map cell values to product fields using our custom mapping
          for (var j = 0; j < row.length; j++) {
            final cell = row[j];
            if (cell?.value != null && headerMap.containsKey(j)) {
              final fieldName = headerMap[j]!;
              
              // Process based on field type
              if (['buying_price', 'selling_price', 'sub_unit_price', 'price_per_sub_unit', 'sub_unit_buying_price'].contains(fieldName)) {
                // Convert to double
                final numValue = _parseDouble(cell!.value);
                if (numValue != null) {
                  productData[fieldName] = numValue;
                } else {
                  print('Warning: Could not parse "${cell.value}" as double for field $fieldName');
                  // Set a default value to prevent errors
                  productData[fieldName] = 0.0;
                }
              } else if (['quantity', 'sub_unit_quantity', 'number_of_sub_units'].contains(fieldName)) {
                // Convert to int
                final numValue = _parseInt(cell!.value);
                if (numValue != null) {
                  productData[fieldName] = numValue;
                } else {
                  print('Warning: Could not parse "${cell.value}" as int for field $fieldName. Using default 0.');
                  // Set a safe default for quantity
                  productData[fieldName] = 0;
                }
              } else if (fieldName == 'has_sub_units') {
                // Convert Yes/No to 1/0
                final strValue = cell!.value.toString().trim().toLowerCase();
                productData[fieldName] = (strValue == 'yes' || strValue == 'true' || strValue == '1') ? 1 : 0;
              } else if (fieldName == 'received_date') {
                // Parse date
                try {
                  final dateStr = cell!.value.toString().trim();
                  DateTime dateValue;
                  
                  if (dateStr.contains('T')) {
                    // ISO format
                    dateValue = DateTime.parse(dateStr);
                  } else {
                    // Attempt to parse MM/DD/YYYY or similar formats
                    final parts = dateStr.split(RegExp(r'[/\-]'));
                    if (parts.length == 3) {
                      // Assume month/day/year format
                      dateValue = DateTime(int.parse(parts[2]), int.parse(parts[0]), int.parse(parts[1]));
                    } else {
                      // Default to current date if format is unrecognized
                      dateValue = DateTime.now();
                    }
                  }
                  
                  productData[fieldName] = dateValue.toIso8601String();
                } catch (e) {
                  // Default to current date if parsing fails
                  productData[fieldName] = DateTime.now().toIso8601String();
                }
              } else if (fieldName == 'department') {
                // Use the department value from the Excel or default if empty
                String departmentValue = cell!.value.toString().trim();
                if (departmentValue.isEmpty) {
                  productData[fieldName] = Product.deptLubricants;
                } else {
                  productData[fieldName] = Product.normalizeDepartment(departmentValue);
                }
              } else if (fieldName == 'supplier' && (cell!.value == null || cell.value.toString().trim().isEmpty)) {
                // Ensure supplier is not empty
                productData[fieldName] = 'Unknown Supplier';
              } else {
                // For all other fields, just convert to string
                final stringValue = cell!.value.toString().trim();
                productData[fieldName] = stringValue.isEmpty ? null : stringValue;
              }
            }
          }
          
          // Set default values for required fields
          if (!productData.containsKey('received_date') || productData['received_date'] == null) {
            productData['received_date'] = DateTime.now().toIso8601String();
          }
          
          if (!productData.containsKey('department') || productData['department'] == null) {
            productData['department'] = Product.deptLubricants;
          }
          
          // Set has_sub_units based on whether sub_unit fields are provided
          if (productData.containsKey('sub_unit_name') && productData['sub_unit_name'] != null && productData['sub_unit_name'].toString().isNotEmpty) {
            productData['has_sub_units'] = 1;
          } else {
            productData['has_sub_units'] = 0;
          }
          
          // Fill in default values for required numeric fields
          if (!productData.containsKey('buying_price') || productData['buying_price'] == null) 
            productData['buying_price'] = 0.0;
          if (!productData.containsKey('selling_price') || productData['selling_price'] == null) 
            productData['selling_price'] = 0.0;
          if (!productData.containsKey('quantity') || productData['quantity'] == null) 
            productData['quantity'] = 0;
          
          // Make sure product_name is not empty
          if (!productData.containsKey('product_name') || productData['product_name'] == null || 
              productData['product_name'].toString().trim().isEmpty) {
            // For product name, we need some value - use a generated name
            productData['product_name'] = 'Product_${DateTime.now().millisecondsSinceEpoch}';
            print('Warning: Generated placeholder name for product at row ${i+1}');
          }
          
          // Ensure supplier has a value
          if (!productData.containsKey('supplier') || productData['supplier'] == null || 
              productData['supplier'].toString().trim().isEmpty) {
            productData['supplier'] = 'Unknown Supplier';
          }
          
          // Print product data for debugging
          print('Row ${i+1} data: ${productData.toString()}');
          
          // Check if product with same name exists
          try {
            final result = await createProduct(productData);
            if (result > 0) {
              imported++;
            } else {
              failed++;
              errors.add('Row ${i+1}: Failed to import product "${productData['product_name']}"');
            }
          } catch (e) {
            failed++;
            errors.add('Row ${i+1}: Error creating product: $e');
            print('Error creating product at row ${i+1}: $e');
          }
        } catch (e) {
          errors.add('Row ${i+1}: Error processing row: $e');
          failed++;
        }
      }
      
      // Final progress update
      final finalResult = {
        'success': failed == 0,
        'message': 'Imported $imported products. Failed: $failed',
        'imported': imported,
        'failed': failed,
        'errors': errors,
        'current': total,
        'total': total,
        'percentage': 100.0,
        'completed': true,
      };
      
      onProgress?.call(finalResult);
      return finalResult;
    } catch (e) {
      print('❌ Error importing products from Excel: $e');
      
      // Error progress update
      final errorResult = {
        'success': false,
        'message': 'Error importing products: $e',
        'imported': imported,
        'failed': failed + (total - current),
        'errors': [...errors, 'Global error: $e'],
        'current': current,
        'total': total > 0 ? total : 1,
        'percentage': total > 0 ? (current / total * 100) : 0.0,
        'completed': true,
      };
      
      onProgress?.call(errorResult);
      return errorResult;
    }
  }

  // Ensure the creditors table has all required columns
  Future<void> _ensureCreditorsTableColumns(Database db) async {
    try {
      print('Checking creditors table columns...');
      
      // Get table info
      final tableInfo = await db.rawQuery('PRAGMA table_info($tableCreditors)');
      final List<String> columnNames = tableInfo.map((col) => col['name'].toString()).toList();
      
      print('Existing columns in creditors table: ${columnNames.join(', ')}');
      
      // List of required columns and their definitions
      final requiredColumns = {
        'order_number': 'TEXT',
        'order_details': 'TEXT',
        'original_amount': 'REAL',
        'customer_id': 'INTEGER',
        'receipt_number': 'TEXT',
        'last_updated': 'TEXT',
      };
      
      // Add any missing columns
      for (var column in requiredColumns.entries) {
        if (!columnNames.contains(column.key)) {
          print('Adding missing column to creditors table: ${column.key}');
          await db.execute('ALTER TABLE $tableCreditors ADD COLUMN ${column.key} ${column.value}');
        }
      }
      
      print('Creditors table structure verification complete.');
    } catch (e) {
      print('Error checking creditors table structure: $e');
    }
  }

  // Creates a credit record for a customer
  Future<void> createCredit(
    int customerId, 
    String customerName, 
    int orderId,
    String orderNumber,
    double amount
  ) async {
    final db = await database;
    
    // First check if customer exists in creditors table
    final List<Map<String, dynamic>> existingCreditors = await db.query(
      tableCreditors,
      where: 'customer_id = ?',
      whereArgs: [customerId],
    );
    
    await db.transaction((txn) async {
      if (existingCreditors.isEmpty) {
        // Create new creditor record
        await txn.insert(tableCreditors, {
          'customer_id': customerId,
          'customer_name': customerName,
          'order_id': orderId,
          'order_number': orderNumber,
          'amount': amount,
          'status': 'OPEN',
          'payment_date': null,
          'payment_amount': 0.0,
          'payment_method': null,
          'payment_details': null,
          'balance': amount,
          'created_at': DateTime.now().toIso8601String(),
          'updated_at': DateTime.now().toIso8601String(),
        });
      } else {
        // Update existing creditor balance
        final currentBalance = existingCreditors.first['balance'] as double? ?? 0.0;
        await txn.update(
          tableCreditors,
          {
            'balance': currentBalance + amount,
            'updated_at': DateTime.now().toIso8601String(),
          },
          where: 'customer_id = ?',
          whereArgs: [customerId],
        );
      }
      
      // Add credit transaction record
      await txn.insert(tableCreditTransactions, {
        'customer_id': customerId,
        'customer_name': customerName,
        'order_id': orderId,
        'order_number': orderNumber,
        'amount': amount,
        'transaction_type': 'CREDIT',
        'payment_method': 'Credit',
        'date': DateTime.now().toIso8601String(),
        'description': 'Credit purchase for order #$orderNumber',
      });
      
      // Log the activity
      final currentUser = await getCurrentUserWithTxn(txn);
      if (currentUser != null) {
        await txn.insert(tableActivityLogs, {
          'user_id': currentUser['id'] ?? 0,
          'username': currentUser['username'],
          'action': 'Created credit',
          'action_type': 'CREDIT',
          'details': 'Created credit of ${amount.toStringAsFixed(2)} for $customerName (Order #$orderNumber)',
          'timestamp': DateTime.now().toIso8601String(),
        });
      }
    });
  }
  
  // Log activity with transaction
  Future<void> logActivityWithTxn(
    DatabaseExecutor txn,
    int? userId,
    String username,
    String action,
    String actionType,
    String details,
  ) async {
    await txn.insert(tableActivityLogs, {
      'user_id': userId ?? 0,
      'username': username,
      'action': action,
      'action_type': actionType,
      'details': details,
      'created_at': DateTime.now().toIso8601String(),
    });
  }

  /// Get user by username
  Future<Map<String, dynamic>?> getUserByUsername(String username) async {
    try {
      final db = await database;
      final users = await db.query(
        tableUsers,
        where: 'username = ?',
        whereArgs: [username],
        limit: 1,
      );
      
      if (users.isNotEmpty) {
        return users.first;
      }
      return null;
    } catch (e) {
      print('Error getting user by username: $e');
      return null;
    }
  }

  /// Check if admin user exists and create one if it doesn't
  Future<void> _ensureAdminUserExists() async {
    try {
      // Check if admin user exists
      final adminUser = await getUserByUsername('admin');
      final db = await database;
      
      if (adminUser == null) {
        print('No admin user found. Creating default admin user...');
        
        // Create default admin user with a plain, simple password that BCrypt can reliably verify
        // Use a fixed plaintext password that will be consistently hashed and verified
        final plainPassword = 'admin123';
        
        // Important: Use the exact same hashing method that will be used for verification
        // Avoid using _hashPassword() and use AuthService directly to ensure consistency
        final hashedPassword = AuthService.instance.hashPassword(plainPassword);
        
        // Debug password hashing
        print('Creating admin with plain password: $plainPassword');
        print('Hashed admin password: $hashedPassword');
        
        final adminUserData = {
          'username': 'admin',
          'password': hashedPassword,
          'full_name': 'System Administrator',
          'email': 'admin@example.com',
          'role': ROLE_ADMIN,
          'permissions': PERMISSION_FULL_ACCESS,
          'created_at': DateTime.now().toIso8601String(),
        };
        
        final id = await db.insert(tableUsers, adminUserData);
        
        if (id > 0) {
          print('Default admin user created successfully with ID: $id');
          
          // Verify the password would work immediately after creation as a sanity check
          final verifyResult = AuthService.instance.verifyPassword(plainPassword, hashedPassword);
          print('Admin password verification test: ${verifyResult ? 'PASSED' : 'FAILED'}');
          
          // Double-check if the hash is stored correctly
          final justCreatedUser = await getUserByUsername('admin');
          if (justCreatedUser != null) {
            final storedHash = justCreatedUser['password'] as String;
            print('Stored admin password hash after creation: $storedHash');
            print('Hash matches what we created: ${storedHash == hashedPassword ? 'YES' : 'NO'}');
          }
        } else {
          print('Failed to create default admin user.');
        }
      } else {
        print('Admin user already exists.');
        
        // Check if the admin password needs fixing (might have been double-hashed)
        if (adminUser['password'] != null && adminUser['password'].toString().startsWith('\$2a\$')) {
          final currentUser = await getUserByUsername('admin');
          if (currentUser != null) {
            try {
              // Test if current admin password works with the expected password
              final canVerify = AuthService.instance.verifyPassword('admin123', currentUser['password'].toString());
              if (!canVerify) {
                print('Admin password verification failed. Fixing admin password...');
                
                // Fix the admin password by resetting it to the known default
                final newHashedPassword = AuthService.instance.hashPassword('admin123');
                await db.update(
                  tableUsers,
                  {'password': newHashedPassword},
                  where: 'id = ?',
                  whereArgs: [currentUser['id']],
                );
                
                print('Admin password has been reset to default.');
              } else {
                print('Admin password is correctly set and verifiable.');
              }
            } catch (e) {
              print('Error checking admin password: $e');
            }
          }
        }
      }
    } catch (e) {
      print('Error ensuring admin user exists: $e');
    }
  }
  /// Get order by ID
  Future<Map<String, dynamic>?> getOrderById(int orderId) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      tableOrders,
      where: 'id = ?',
      whereArgs: [orderId],
      limit: 1,
    );
    
    return maps.isNotEmpty ? maps.first : null;
  }
}