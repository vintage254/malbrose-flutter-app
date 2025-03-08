import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:my_flutter_app/models/order_model.dart';
import 'package:my_flutter_app/models/user_model.dart';
import 'package:my_flutter_app/services/auth_service.dart';
import 'package:flutter/foundation.dart';
import 'package:crypto/crypto.dart';
import 'dart:convert'; // For utf8 encoding
import 'package:synchronized/synchronized.dart';
import '../models/customer_model.dart';
import 'dart:io';
import 'dart:math';
import 'dart:async';
import 'package:my_flutter_app/models/product_model.dart';

class DatabaseService {
  static final DatabaseService instance = DatabaseService._init();
  static Database? _database;
  final _lock = Lock();
  bool _initialized = false;

  // Table Names
  static const String tableProducts = 'products';
  static const String tableUsers = 'users';
  static const String tableOrders = 'orders';
  static const String tableActivityLogs = 'activity_logs';
  static const String tableCreditors = 'creditors';
  static const String tableDebtors = 'debtors';
  static const String tableOrderItems = 'order_items';
  static const String tableCustomers = 'customers';
  static const String tableCustomerReports = 'customer_reports';
  static const String tableReportItems = 'report_items';

  // Add these constants at the top of the DatabaseService class
  static const String actionCreateOrder = 'create_order';
  static const String actionUpdateOrder = 'update_order';
  static const String actionCompleteSale = 'complete_sale';
  static const String actionUpdateProduct = 'update_product';
  static const String actionCreateProduct = 'create_product';
  static const String actionCreateCreditor = 'create_creditor';
  static const String actionUpdateCreditor = 'update_creditor';
  static const String actionCreateDebtor = 'create_debtor';
  static const String actionUpdateDebtor = 'update_debtor';
  static const String actionLogin = 'login';
  static const String actionLogout = 'logout';
  static const String actionCreateCustomerReport = 'create_customer_report';
  static const String actionUpdateCustomerReport = 'update_customer_report';
  static const String actionPrintCustomerReport = 'print_customer_report';

  // Add these admin privilege constants at the top of DatabaseService class
  static const String ROLE_ADMIN = 'ADMIN';
  static const String PERMISSION_FULL_ACCESS = 'FULL_ACCESS';
  static const String PERMISSION_BASIC = 'BASIC';

  DatabaseService._init();

  // Completely rewritten database getter to be more reliable
  Future<Database> get database async {
    if (_database != null && _initialized) {
      try {
        // Test if database is still valid with a simple query
        await _database!.rawQuery('SELECT 1');
        return _database!;
      } catch (e) {
        print('Database connection invalid, recreating: $e');
        await _closeDatabase();
        _database = null;
        _initialized = false;
      }
    }
    
    // Use a lock to prevent multiple initialization attempts
    return await _lock.synchronized(() async {
      if (_database != null && _initialized) return _database!;
      
      // Try to initialize the database
      try {
        _database = await _initDatabase();
        _initialized = true;
        return _database!;
      } catch (e) {
        print('Error initializing database: $e');
        
        // If initialization fails, try to reset the database
        await resetDatabase();
        return _database!;
      }
    });
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
      final path = join(databasePath, 'malbrose_db.db');
      
      // Check if the database file exists
      final dbFile = File(path);
      if (await dbFile.exists()) {
        // Check for lock files and delete them
        final lockFile = File('$path-shm');
        if (await lockFile.exists()) {
          await lockFile.delete();
          print('Deleted database lock file: $path-shm');
        }
        
        final journalFile = File('$path-wal');
        if (await journalFile.exists()) {
          await journalFile.delete();
          print('Deleted database journal file: $path-wal');
        }
        
        final journalFile2 = File('$path-journal');
        if (await journalFile2.exists()) {
          await journalFile2.delete();
          print('Deleted database journal file: $path-journal');
        }
      }
    } catch (e) {
      print('Error forcing database unlock: $e');
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
  Future<Database> _initDatabase() async {
    // Use a more reliable path for the database
    final databasePath = await getDatabasesPath();
    final path = join(databasePath, 'malbrose_db.db');

    // Print the exact database path
    print('DATABASE PATH: $path');

    try {
      // Ensure the directory exists with proper permissions
      final dbDir = Directory(databasePath);
      if (!await dbDir.exists()) {
        await dbDir.create(recursive: true);
      }
      
      // Set permissions for Linux platform
      if (Platform.isLinux) {
        try {
          // Ensure the directory has write permissions
          final result = await Process.run('chmod', ['-R', '777', databasePath]);
          if (result.exitCode != 0) {
            print('Warning: Could not set directory permissions: ${result.stderr}');
          }
        } catch (e) {
          print('Warning: Error setting directory permissions: $e');
        }
      }

      // Create a new database with minimal options
      final db = await openDatabase(
        path,
        version: 25,
        onCreate: _createTables,
        onUpgrade: _onUpgrade,
        // Use single instance to prevent locking issues
        singleInstance: true,
      );
      
      // Set pragmas outside of any transaction
      await _setPragmas(db);
      
      return db;
    } catch (e) {
      print('Database initialization error: $e');
      throw Exception('Failed to initialize the database: $e');
    }
  }

  // Add a method to force a clean database
  Future<void> _forceCleanDatabase(String path) async {
    try {
      // Check if the database file exists
      final dbFile = File(path);
      if (await dbFile.exists()) {
        // Delete the database file
        await dbFile.delete();
        print('Deleted existing database file for clean start');
      }
      
      // Also check for journal and shm files
      final walFile = File('$path-wal');
      if (await walFile.exists()) {
        await walFile.delete();
      }
      
      final shmFile = File('$path-shm');
      if (await shmFile.exists()) {
        await shmFile.delete();
      }
      
      final journalFile = File('$path-journal');
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

  Future<void> _createTables(Database db, int version) async {
    // First create users table since it's referenced by others
    await db.execute('''
      CREATE TABLE IF NOT EXISTS $tableUsers (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        username TEXT NOT NULL UNIQUE,
        password TEXT NOT NULL,
        full_name TEXT NOT NULL,
        email TEXT NOT NULL,
        role TEXT NOT NULL,
        permissions TEXT NOT NULL DEFAULT '$PERMISSION_BASIC',
        created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
        last_login TEXT
      )
    ''');

    // Check if admin exists before creating
    final hasAdmin = await _adminExists(db);
    
    if (!hasAdmin) {
      String plainPassword = 'admin123';
      String hashedPassword = _hashPassword(plainPassword);

      await db.insert(tableUsers, {
        'username': 'admin',
        'password': hashedPassword,
        'full_name': 'System Administrator',
        'email': 'admin@example.com',
        'role': ROLE_ADMIN,
        'permissions': PERMISSION_FULL_ACCESS,
        'created_at': DateTime.now().toIso8601String(),
      }, conflictAlgorithm: ConflictAlgorithm.ignore);
    }

    // Create customers table first
    await db.execute('''
      CREATE TABLE IF NOT EXISTS $tableCustomers (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL UNIQUE,
        phone TEXT,
        email TEXT,
        address TEXT,
        total_orders INTEGER DEFAULT 0,
        total_amount REAL DEFAULT 0.0,
        last_order_date TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT
      )
    ''');

    // Create creditors table
    await db.execute('''
      CREATE TABLE IF NOT EXISTS $tableCreditors (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL UNIQUE,
        balance REAL NOT NULL,
        details TEXT,
        status TEXT NOT NULL,
        created_at TEXT NOT NULL,
        last_updated TEXT
      )
    ''');

    // Create debtors table
    await db.execute('''
      CREATE TABLE IF NOT EXISTS $tableDebtors (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL UNIQUE,
        balance REAL NOT NULL,
        details TEXT,
        status TEXT NOT NULL,
        created_at TEXT NOT NULL,
        last_updated TEXT
      )
    ''');

    // Create products table
    await db.execute('''
      CREATE TABLE IF NOT EXISTS $tableProducts (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        image TEXT,
        supplier TEXT NOT NULL,
        received_date TEXT NOT NULL,
        product_name TEXT NOT NULL,
        buying_price REAL NOT NULL,
        selling_price REAL NOT NULL,
        quantity INTEGER NOT NULL,
        description TEXT,
        has_sub_units INTEGER DEFAULT 0,
        sub_unit_quantity INTEGER,
        sub_unit_price REAL,
        sub_unit_buying_price REAL,
        sub_unit_name TEXT,
        created_by INTEGER,
        updated_by INTEGER,
        updated_at TEXT,
        FOREIGN KEY (created_by) REFERENCES $tableUsers (id),
        FOREIGN KEY (updated_by) REFERENCES $tableUsers (id)
      )
    ''');

    // Create orders table with customer_id foreign key
    await db.execute('''
      CREATE TABLE IF NOT EXISTS $tableOrders (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        order_number TEXT NOT NULL UNIQUE,
        customer_id INTEGER,
        customer_name TEXT NOT NULL,
        total_amount REAL NOT NULL,
        status TEXT NOT NULL DEFAULT 'PENDING',
        payment_status TEXT NOT NULL DEFAULT 'PENDING',
        created_by INTEGER NOT NULL,
        created_at TEXT NOT NULL,
        updated_at TEXT,
        order_date TEXT NOT NULL,
        FOREIGN KEY (created_by) REFERENCES $tableUsers (id),
        FOREIGN KEY (customer_id) REFERENCES $tableCustomers (id)
      )
    ''');

    // Create activity logs table
    await db.execute('''
      CREATE TABLE IF NOT EXISTS $tableActivityLogs (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        user_id INTEGER NOT NULL,
        username TEXT NOT NULL,
        action TEXT NOT NULL,
        action_type TEXT,
        details TEXT NOT NULL,
        timestamp TEXT NOT NULL,
        FOREIGN KEY (user_id) REFERENCES $tableUsers (id)
      )
    ''');

    // Create order_items table with proper relations
    await db.execute('''
      CREATE TABLE IF NOT EXISTS $tableOrderItems (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        order_id INTEGER NOT NULL,
        product_id INTEGER NOT NULL,
        quantity INTEGER NOT NULL,
        unit_price REAL NOT NULL,
        selling_price REAL NOT NULL,
        adjusted_price REAL,
        total_amount REAL NOT NULL,
        product_name TEXT NOT NULL,
        is_sub_unit INTEGER DEFAULT 0,
        sub_unit_name TEXT,
        sub_unit_quantity INTEGER,
        status TEXT NOT NULL DEFAULT 'PENDING',
        FOREIGN KEY (order_id) REFERENCES $tableOrders (id) ON DELETE CASCADE,
        FOREIGN KEY (product_id) REFERENCES $tableProducts (id)
      )
    ''');
    
    // Create customer reports table with proper relations
    await db.execute('''
      CREATE TABLE IF NOT EXISTS $tableCustomerReports (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        report_number TEXT NOT NULL,
        customer_id INTEGER NOT NULL,
        customer_name TEXT NOT NULL,
        total_amount REAL NOT NULL,
        completed_amount REAL NOT NULL,
        pending_amount REAL NOT NULL,
        status TEXT NOT NULL DEFAULT 'PENDING',
        payment_status TEXT NOT NULL DEFAULT 'PENDING',
        created_at TEXT NOT NULL,
        due_date TEXT,
        FOREIGN KEY (customer_id) REFERENCES $tableCustomers (id)
      )
    ''');

    // Create report items table with proper schema
    await db.execute('''
      CREATE TABLE IF NOT EXISTS $tableReportItems (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        report_id INTEGER NOT NULL,
        order_id INTEGER NOT NULL,
        product_id INTEGER NOT NULL,
        product_name TEXT NOT NULL,
        quantity INTEGER NOT NULL,
        unit_price REAL NOT NULL,
        selling_price REAL NOT NULL,
        total_amount REAL NOT NULL,
        is_sub_unit INTEGER NOT NULL DEFAULT 0,
        sub_unit_name TEXT,
        status TEXT NOT NULL,
        created_at TEXT NOT NULL,
        FOREIGN KEY (report_id) REFERENCES $tableCustomerReports (id) ON DELETE CASCADE,
        FOREIGN KEY (order_id) REFERENCES $tableOrders (id) ON DELETE CASCADE,
        FOREIGN KEY (product_id) REFERENCES $tableProducts (id)
      )
    ''');
  }

  String _hashPassword(String password) {
    // Convert the password to bytes
    var bytes = utf8.encode(password); // Convert to UTF-8
    var digest = sha256.convert(bytes); // Hash the password
    return digest.toString(); // Return the hashed password as a string
  }

  // Add migration method for unhashed passwords
  Future<void> _migrateUnhashedPasswords(Database db) async {
    try {
      print('Starting password migration...');
      // Get all users
      final users = await db.query(tableUsers);
      var migratedCount = 0;
      
      for (var user in users) {
        final password = user['password'] as String;
        
        // Check if password is already hashed (SHA-256 produces 64 character hex string)
        if (password.length != 64) {
          // Hash the password using AuthService to ensure consistency
          final hashedPassword = AuthService.instance.hashPassword(password);
          
          // Update the user's password
          await db.update(
            tableUsers,
            {'password': hashedPassword},
            where: 'id = ?',
            whereArgs: [user['id']],
          );
          
          print('Migrated password for user: ${user['username']}');
          migratedCount++;
        }
      }
      
      print('Password migration completed. Migrated $migratedCount passwords.');
    } catch (e) {
      print('Error during password migration: $e');
      rethrow;
    }
  }

  // Add migration method for activity logs
  Future<void> _migrateActivityLogs(Database db) async {
    try {
      // Check if action_type column exists
      var tableInfo = await db.rawQuery('PRAGMA table_info($tableActivityLogs)');
      bool hasActionTypeColumn = tableInfo.any((column) => column['name'] == 'action_type');
      
      if (!hasActionTypeColumn) {
        await db.execute('ALTER TABLE $tableActivityLogs ADD COLUMN action_type TEXT');
      }
      
      // Update any existing records to use action as action_type if needed
      await db.execute('''
        UPDATE $tableActivityLogs 
        SET action_type = action 
        WHERE action_type IS NULL
      ''');
    } catch (e) {
      print('Error during activity logs migration: $e');
    }
  }

  // Migration logic
  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 18) {
      // Add payment_status column if it doesn't exist
      try {
        await db.execute(
          'ALTER TABLE $tableOrders ADD COLUMN payment_status TEXT NOT NULL DEFAULT "PENDING"'
        );
      } catch (e) {
        print('Column might already exist: $e');
      }
    }
    
    if (oldVersion < 21) {
      // Drop invoice tables if they exist
      try {
        await db.execute('DROP TABLE IF EXISTS invoice_items');
        await db.execute('DROP TABLE IF EXISTS invoices');
      } catch (e) {
        print('Error dropping invoice tables: $e');
      }
    }
    
    if (oldVersion < 22) {
      // Add product_name column to report_items table if it doesn't exist
      try {
        await db.execute('ALTER TABLE $tableReportItems ADD COLUMN product_name TEXT');
        print('Added product_name column to report_items table');
      } catch (e) {
        print('Error adding product_name column: $e');
      }
    }
    
    if (oldVersion < 23) {
      // Add created_at column to report_items table if it doesn't exist
      try {
        await db.execute('ALTER TABLE $tableReportItems ADD COLUMN created_at TEXT');
        print('Added created_at column to report_items table');
      } catch (e) {
        print('Error adding created_at column: $e');
      }
    }
    
    if (oldVersion < 24) {
      // Add order_id column to report_items table if it doesn't exist
      try {
        await db.execute('ALTER TABLE $tableReportItems ADD COLUMN order_id INTEGER NOT NULL DEFAULT 0');
        print('Added order_id column to report_items table');
      } catch (e) {
        print('Error adding order_id column: $e');
      }
    }
    
    if (oldVersion < 25) {
      // Add sub_unit_buying_price column to products table if it doesn't exist
      try {
        // Check if column exists first
        var tableInfo = await db.rawQuery('PRAGMA table_info($tableProducts)');
        bool hasSubUnitBuyingPriceColumn = tableInfo.any((column) => column['name'] == 'sub_unit_buying_price');
        
        if (!hasSubUnitBuyingPriceColumn) {
          await db.execute('ALTER TABLE $tableProducts ADD COLUMN sub_unit_buying_price REAL');
          
          // Initialize with calculated values for existing products
          var products = await db.query(
            tableProducts,
            where: 'has_sub_units = 1 AND sub_unit_quantity > 0'
          );
          
          for (var product in products) {
            final buyingPrice = (product['buying_price'] as num).toDouble();
            final subUnitQuantity = (product['sub_unit_quantity'] as num).toDouble();
            final calculatedSubUnitBuyingPrice = buyingPrice / subUnitQuantity;
            
            await db.update(
              tableProducts,
              {'sub_unit_buying_price': calculatedSubUnitBuyingPrice},
              where: 'id = ?',
              whereArgs: [product['id']],
            );
          }
          
          print('Added sub_unit_buying_price column and initialized values');
        }
      } catch (e) {
        print('Error adding sub_unit_buying_price column: $e');
      }
    }
    
    try {
      // Check if sub_unit_quantity column exists in order_items
      var tableInfo = await db.rawQuery('PRAGMA table_info($tableOrderItems)');
      bool hasSubUnitQuantity = tableInfo.any((column) => column['name'] == 'sub_unit_quantity');
      
      if (!hasSubUnitQuantity) {
        await db.execute(
          'ALTER TABLE $tableOrderItems ADD COLUMN sub_unit_quantity REAL'
        );
      }

      // Backup existing data
      final existingUsers = await db.query(tableUsers);
      
      // Create missing tables if needed
      await _createTables(db, newVersion);
      
      // Migrate unhashed passwords
      await _migrateUnhashedPasswords(db);
      
      // Migrate activity logs
      await _migrateActivityLogs(db);

      // Migrate customer data
      await _migrateCustomerData(db);

      // Restore users if needed
      if (existingUsers.isNotEmpty) {
        for (var user in existingUsers) {
          if (!user.containsKey('permissions')) {
            user['permissions'] = user['role'] == ROLE_ADMIN ? 
              PERMISSION_FULL_ACCESS : PERMISSION_BASIC;
          }
          
          // Ensure password is hashed
          if (user['password'].toString().length != 64) {
            user['password'] = _hashPassword(user['password'] as String);
          }
          
          user.remove('id');
          await db.insert(
            tableUsers,
            user,
            conflictAlgorithm: ConflictAlgorithm.ignore,
          );
        }
      }
    } catch (e) {
      print('Error during migration: $e');
    }
  }

  // User related methods
  Future<User?> createUser(Map<String, dynamic> userData) async {
    int retryCount = 0;
    const maxRetries = 3;
    const baseDelay = 200; // milliseconds
    
    while (true) {
    try {
      // Hash the password before storing
      if (userData.containsKey('password')) {
        userData['password'] = AuthService.instance.hashPassword(userData['password']);
      }

      // Ensure required fields are present
      if (!userData.containsKey('permissions')) {
        userData['permissions'] = userData['role'] == ROLE_ADMIN 
            ? PERMISSION_FULL_ACCESS 
            : PERMISSION_BASIC;
      }

      if (!userData.containsKey('created_at')) {
        userData['created_at'] = DateTime.now().toIso8601String();
      }

      final db = await database;
        
        // Use a transaction for better reliability
        final id = await db.transaction((txn) async {
          return await txn.insert(tableUsers, userData);
        });
      
      if (id != 0) {
        return User.fromMap({...userData, 'id': id});
      }
      return null;
    } catch (e) {
        print('Error creating user (attempt ${retryCount + 1}): $e');
        
        if (e is DatabaseException && 
            (e.toString().contains('database is locked') || 
             e.toString().contains('database locked')) && 
            retryCount < maxRetries) {
          retryCount++;
          // Exponential backoff with jitter
          final delay = baseDelay * (1 << retryCount) + (Random().nextInt(100));
          print('Database locked. Retrying createUser in $delay ms...');
          await Future.delayed(Duration(milliseconds: delay));
          
          // Force close and reopen the database
          await _closeDatabase();
          _database = null;
          _initialized = false;
          
          continue;
        }
        
        // If we've reached max retries or it's not a locking issue, rethrow
        print('Failed to create user after $retryCount retries: $e');
      rethrow;
      }
    }
  }

  Future<void> updateUser(User user) async {
    int retryCount = 0;
    const maxRetries = 3;
    const baseDelay = 200; // milliseconds
    
    while (true) {
      try {
        final db = await database;
        
        // Ensure permissions are maintained during update
        final userData = user.toMap();
        
        // If we're only updating specific fields, make sure we have the minimum required data
        if (!userData.containsKey('username') || !userData.containsKey('full_name') || !userData.containsKey('email')) {
          // This might be a partial update (like just updating password)
          // Get the existing user data to fill in missing fields
          final existingUser = await getUserById(user.id!);
          if (existingUser != null) {
            // Fill in missing fields from existing user data
            if (!userData.containsKey('username')) userData['username'] = existingUser['username'];
            if (!userData.containsKey('full_name')) userData['full_name'] = existingUser['full_name'];
            if (!userData.containsKey('email')) userData['email'] = existingUser['email'];
            if (!userData.containsKey('role')) userData['role'] = existingUser['role'];
            if (!userData.containsKey('permissions')) userData['permissions'] = existingUser['permissions'];
            if (!userData.containsKey('created_at')) userData['created_at'] = existingUser['created_at'];
          }
        }
      
        // If password is being updated, ensure it's hashed
        if (userData.containsKey('password')) {
          final currentUser = await getUserById(user.id!);
          if (currentUser != null) {
            // Only hash if the password has actually changed
            final currentPassword = currentUser['password'] as String;
            if (userData['password'] != currentPassword) {
              userData['password'] = AuthService.instance.hashPassword(userData['password']);
            }
          }
        }

        await db.transaction((txn) async {
          await txn.update(
            tableUsers,
            userData,
            where: 'id = ?',
            whereArgs: [user.id],
          );
        });
        
        // If we get here, the update was successful
        return;
      } catch (e) {
        print('Error updating user (attempt ${retryCount + 1}): $e');
        
        if (e is DatabaseException && 
            (e.toString().contains('database is locked') || 
             e.toString().contains('database locked')) && 
            retryCount < maxRetries) {
          retryCount++;
          // Exponential backoff with jitter
          final delay = baseDelay * (1 << retryCount) + (Random().nextInt(100));
          print('Database locked. Retrying user update in $delay ms...');
          await Future.delayed(Duration(milliseconds: delay));
          continue;
        }
        
        // If we've reached max retries or it's not a locking issue, rethrow
        rethrow;
      }
    }
  }

  Future<void> deleteUser(int userId) async {
    final db = await database;
    await db.delete(
      tableUsers,
      where: 'id = ?',
      whereArgs: [userId],
    );
  }

  Future<Map<String, dynamic>?> getUserByUsername(String username) async {
    int retryCount = 0;
    const maxRetries = 3;
    const baseDelay = 200; // milliseconds
    
    while (true) {
      try {
    final db = await database;
        
        final results = await db.transaction((txn) async {
          return await txn.query(
      tableUsers,
      where: 'username = ?',
      whereArgs: [username],
      limit: 1,
    );
        });
        
    return results.isNotEmpty ? results.first : null;
      } catch (e) {
        print('Error getting user by username (attempt ${retryCount + 1}): $e');
        
        if (e is DatabaseException && 
            (e.toString().contains('database is locked') || 
             e.toString().contains('database locked')) && 
            retryCount < maxRetries) {
          retryCount++;
          // Exponential backoff with jitter
          final delay = baseDelay * (1 << retryCount) + (Random().nextInt(100));
          print('Database locked. Retrying getUserByUsername in $delay ms...');
          await Future.delayed(Duration(milliseconds: delay));
          continue;
        }
        
        // If we've reached max retries or it's not a locking issue, return null
        print('Failed to get user after $retryCount retries: $e');
        return null;
      }
    }
  }

  Future<Map<String, dynamic>?> getUserById(int id) async {
    int retryCount = 0;
    const maxRetries = 3;
    const baseDelay = 200; // milliseconds
    
    while (true) {
      try {
    final db = await database;
        
        final results = await db.transaction((txn) async {
          return await txn.query(
      tableUsers,
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
        });
        
    return results.isNotEmpty ? results.first : null;
      } catch (e) {
        print('Error getting user by id (attempt ${retryCount + 1}): $e');
        
        if (e is DatabaseException && 
            (e.toString().contains('database is locked') || 
             e.toString().contains('database locked')) && 
            retryCount < maxRetries) {
          retryCount++;
          // Exponential backoff with jitter
          final delay = baseDelay * (1 << retryCount) + (Random().nextInt(100));
          print('Database locked. Retrying getUserById in $delay ms...');
          await Future.delayed(Duration(milliseconds: delay));
          continue;
        }
        
        // If we've reached max retries or it's not a locking issue, return null
        print('Failed to get user by id after $retryCount retries: $e');
        return null;
      }
    }
  }

  Future<List<String>> getAllUsernames() async {
    final db = await database;
    final results = await db.query(
      tableUsers,
      columns: ['username'],
      orderBy: 'username',
    );
    return results.map((row) => row['username'] as String).toList();
  }

  // Activity log related methods
  Future<List<Map<String, dynamic>>> getActivityLogs({
    String? userFilter,
    String? actionFilter,
    String? dateFilter,
  }) async {
    final db = await database;
    String whereClause = '';
    List<dynamic> whereArgs = [];

    if (userFilter != null) {
      whereClause += 'username LIKE ?';
      whereArgs.add('%$userFilter%');
    }

    if (actionFilter != null) {
      if (whereClause.isNotEmpty) whereClause += ' AND ';
      whereClause += 'action = ?';
      whereArgs.add(actionFilter);
    }

    if (dateFilter != null) {
      if (whereClause.isNotEmpty) whereClause += ' AND ';
      whereClause += "date(timestamp) = date(?)";
      whereArgs.add(dateFilter);
    }

    return await db.query(
      tableActivityLogs,
      where: whereClause.isEmpty ? null : whereClause,
      whereArgs: whereArgs.isEmpty ? null : whereArgs,
      orderBy: 'timestamp DESC',
    );
  }

  Future<void> logActivity(
    int userId,
    String username,
    String action,
    String actionType,
    String details
  ) async {
    final db = await database;
    try {
      await db.insert(tableActivityLogs, {
        'user_id': userId,
        'username': username,
        'action': action,
        'action_type': actionType,
        'details': details,
        'timestamp': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      print('Error logging activity: $e');
      rethrow;
    }
  }

  // Order related methods
  Future<int> createOrder(Order order) async {
    int retryCount = 0;
    const maxRetries = 3;
    const baseDelay = 200; // milliseconds
    
    while (true) {
      try {
        final db = await database;
        
        // Check if an order with this order number already exists
        final existingOrder = await db.query(
          tableOrders,
          where: 'order_number = ?',
          whereArgs: [order.orderNumber],
          limit: 1
        );
        
        if (existingOrder.isNotEmpty) {
          // Order already exists, return its ID
          print('Order with number ${order.orderNumber} already exists, skipping creation');
          return existingOrder.first['id'] as int;
        }
        
        // Start a transaction
        return await db.transaction((txn) async {
          // Insert the order
          final orderId = await txn.insert(tableOrders, order.toMap());
          
          // Insert each order item
          for (final item in order.items) {
            final orderItem = OrderItem(
              orderId: orderId,
              productId: item.productId,
              quantity: item.quantity,
              unitPrice: item.unitPrice,
              sellingPrice: item.sellingPrice,
              totalAmount: item.totalAmount,
              productName: item.productName,
              isSubUnit: item.isSubUnit,
              subUnitName: item.subUnitName,
              subUnitQuantity: item.subUnitQuantity,
            );
            
            await txn.insert(tableOrderItems, orderItem.toMap());
            
            // Update product inventory directly within this transaction
            if (order.orderStatus == 'COMPLETED') {
              // Get product information
              final productResult = await txn.query(
                tableProducts,
                where: 'id = ?',
                whereArgs: [item.productId],
                limit: 1
              );
              
              if (productResult.isNotEmpty) {
                final product = productResult.first;
                final currentQuantity = (product['quantity'] as num).toDouble();
                final subUnitQuantity = (product['sub_unit_quantity'] as num?)?.toDouble() ?? 1.0;
                
                // Calculate actual quantity to update based on sub-units
                double quantityToUpdate;
                if (item.isSubUnit) {
                  // For sub-units, we need to calculate the equivalent in whole units
                  quantityToUpdate = item.quantity.toDouble() / subUnitQuantity;
                } else {
                  quantityToUpdate = item.quantity.toDouble();
                }
                
                // Calculate new quantity (allow negative for tracking oversold items)
                final newQuantity = currentQuantity - quantityToUpdate;
                
                // Update product quantity directly in this transaction
                await txn.update(
                  tableProducts,
                  {'quantity': newQuantity},
                  where: 'id = ?',
                  whereArgs: [item.productId],
                );
              }
            }
          }
          
          // Log the activity directly within this transaction
          await txn.insert(tableActivityLogs, {
            'user_id': 1, // Default admin user ID
            'username': 'admin',
            'action': actionCreateOrder,
            'action_type': 'Order Created',
            'details': 'Order #${order.orderNumber} created with ${order.items.length} items for KSH ${order.totalAmount}',
            'timestamp': DateTime.now().toIso8601String(),
          });
          
          return orderId;
        });
      } catch (e) {
        print('Error creating order (attempt ${retryCount + 1}): $e');
        
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
  
  Future<void> updateOrder(Order order) async {
    if (order.id == null) {
      throw ArgumentError('Order ID is required for updating');
    }
    
    int retryCount = 0;
    const maxRetries = 3;
    const baseDelay = 200; // milliseconds
    
    while (true) {
      try {
        final db = await database;
        
        // Start a transaction
        await db.transaction((txn) async {
          // Create a map without the payment_method field
            final orderMap = {
            'id': order.id,
              'order_number': order.orderNumber,
            'customer_id': order.customerId,
            'customer_name': order.customerName,
              'total_amount': order.totalAmount,
              'status': order.orderStatus,
              'payment_status': order.paymentStatus,
              'created_by': order.createdBy,
            'created_at': order.createdAt.toIso8601String(),
            'order_date': order.orderDate.toIso8601String(),
          };
          
          // Update the order
          await txn.update(
            tableOrders, 
            orderMap,
                  where: 'id = ?',
            whereArgs: [order.id],
          );
          
          // Delete existing order items
          await txn.delete(
            tableOrderItems,
            where: 'order_id = ?',
            whereArgs: [order.id],
          );
          
          // Insert updated order items
          for (final item in order.items) {
            final orderItem = OrderItem(
              orderId: order.id!,
              productId: item.productId,
              quantity: item.quantity,
              unitPrice: item.unitPrice,
              sellingPrice: item.sellingPrice,
              totalAmount: item.totalAmount,
              productName: item.productName,
              isSubUnit: item.isSubUnit,
              subUnitName: item.subUnitName,
              subUnitQuantity: item.subUnitQuantity,
              adjustedPrice: item.adjustedPrice,
            );
            
            await txn.insert(tableOrderItems, orderItem.toMap());
          }
        });
        
        return;
      } catch (e) {
        print('Error updating order (attempt ${retryCount + 1}): $e');
        
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

  Future<List<Map<String, dynamic>>> getOrdersByDateRange(
    DateTime startDate,
    DateTime endDate,
  ) async {
    final db = await database;
    return await db.query(
      tableOrders,
      where: 'created_at BETWEEN ? AND ?',
      whereArgs: [
        startDate.toIso8601String(),
        endDate.toIso8601String(),
      ],
      orderBy: 'created_at DESC',
    );
  }

  Future<List<Map<String, dynamic>>> getRecentOrders() async {
    final db = await database;
    final today = DateTime.now().toIso8601String().substring(0, 10);
    
    try {
      return await db.rawQuery('''
        SELECT 
          o.*,
          GROUP_CONCAT(json_object(
            'product_id', oi.product_id,
            'quantity', oi.quantity,
            'unit_price', oi.unit_price,
            'selling_price', oi.selling_price,
            'adjusted_price', oi.adjusted_price,
            'total_amount', oi.total_amount,
            'product_name', p.product_name,
            'is_sub_unit', oi.is_sub_unit,
            'sub_unit_name', oi.sub_unit_name
          )) as items_json
        FROM $tableOrders o
        LEFT JOIN $tableOrderItems oi ON o.id = oi.order_id
        LEFT JOIN $tableProducts p ON oi.product_id = p.id
        WHERE o.status IN ('PENDING', 'COMPLETED')
          AND date(o.created_at) = ?
        GROUP BY o.order_number
        ORDER BY o.created_at DESC
      ''', [today]);
    } catch (e) {
      print('Error fetching recent orders: $e');
      return [];
    }
  }

  Future<void> updateOrderStatus(String orderNumber, String status) async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.update(
        tableOrders,
        {'status': status},
        where: 'order_number = ?',
        whereArgs: [orderNumber],
      );
    });
  }

  // Product related methods
  Future<Map<String, dynamic>?> getProductById(int id) async {
    try {
      final db = await database;
      final results = await db.rawQuery('''
        SELECT 
          p.*,
          COALESCE(p.product_name, 'Unknown Product') as product_name,
          COALESCE(p.selling_price, 0.0) as selling_price,
          COALESCE(p.buying_price, 0.0) as buying_price,
          COALESCE(p.quantity, 0) as quantity
        FROM $tableProducts p
        WHERE p.id = ?
        LIMIT 1
      ''', [id]);
      
      return results.isNotEmpty ? results.first : null;
    } catch (e) {
      print('Error getting product by id: $e');
      return null;
    }
  }

  Future<void> updateProduct(Map<String, dynamic> product) async {
    final db = await database;
    final currentUser = AuthService.instance.currentUser;
    
    // Add updated_at timestamp
    product['updated_at'] = DateTime.now().toIso8601String();
    
    await db.update(
      tableProducts,
      product,
      where: 'id = ?',
      whereArgs: [product['id']],
    );

    // Log the activity
    if (currentUser != null) {
      await logActivity(
        currentUser.id!,
        currentUser.username,
        'update_product',
        'Update product',
        'Updated product ID: ${product['id']}'
      );
    }
  }

  Future<void> insertProduct(Map<String, dynamic> product) async {
    final db = await database;
    await db.insert(tableProducts, product);
  }

  Future<void> updateProductQuantity(int productId, num quantity, bool isSubUnit, bool isDeducting) async {
    final db = await database;
    await db.transaction((txn) async {
      final product = await getProductById(productId);
      if (product == null) {
        throw Exception('Product not found');
      }

      final currentQuantity = (product['quantity'] as num).toDouble();
      final subUnitQuantity = (product['sub_unit_quantity'] as num?)?.toDouble() ?? 1.0;

      // Calculate actual quantity to update based on sub-units
      double quantityToUpdate;
      if (isSubUnit) {
        // For sub-units, we need to calculate the equivalent in whole units
        quantityToUpdate = quantity.toDouble() / subUnitQuantity;
      } else {
        quantityToUpdate = quantity.toDouble();
      }

      // Calculate new quantity (allow negative for tracking oversold items)
      double newQuantity;
      if (isDeducting) {
        // When deducting, we simply subtract the quantity
        newQuantity = currentQuantity - quantityToUpdate;
      } else {
        // When adding, if current quantity is negative, we first offset the negative balance
        newQuantity = currentQuantity + quantityToUpdate;
      }

      await txn.update(
        tableProducts,
        {'quantity': newQuantity},
        where: 'id = ?',
        whereArgs: [productId],
      );

      // Log stock update with detailed information
      final currentUser = AuthService.instance.currentUser;
      if (currentUser != null) {
        final String actionDetails;
        if (isDeducting) {
          if (isSubUnit) {
            actionDetails = 'Deducted ${quantity} ${product['sub_unit_name'] ?? 'pieces'} (${quantityToUpdate.toStringAsFixed(2)} units) from ${product['product_name']}. New quantity: ${newQuantity.toStringAsFixed(2)}';
          } else {
            actionDetails = 'Deducted ${quantity} units of ${product['product_name']}. New quantity: ${newQuantity.toStringAsFixed(2)}';
          }
        } else {
          if (isSubUnit) {
            actionDetails = 'Added ${quantity} ${product['sub_unit_name'] ?? 'pieces'} (${quantityToUpdate.toStringAsFixed(2)} units) to ${product['product_name']}. New quantity: ${newQuantity.toStringAsFixed(2)}';
          } else {
            actionDetails = 'Added ${quantity} units of ${product['product_name']}. New quantity: ${newQuantity.toStringAsFixed(2)}';
          }
        }
        
        await logActivity(
          currentUser.id!,
          currentUser.username,
          isDeducting ? 'deduct_stock' : 'add_stock',
          'Stock update',
          actionDetails
        );
      }
    });
  }

  // Creditor related methods
  Future<List<Map<String, dynamic>>> getCreditors() async {
    final db = await database;
    return await db.query(tableCreditors, orderBy: 'created_at DESC');
  }

  Future<bool> checkCreditorExists(String name) async {
    final db = await database;
    final result = await db.query(
      tableCreditors,
      where: 'name = ?',
      whereArgs: [name],
      limit: 1,
    );
    return result.isNotEmpty;
  }

  Future<int> addCreditor(Map<String, dynamic> creditor) async {
    try {
    final db = await database;
      int creditorId = await db.insert(tableCreditors, creditor);
      
      // Log the activity
      final currentUser = AuthService.instance.currentUser;
      if (currentUser != null) {
        await logActivity(
          currentUser.id!,
          currentUser.username,
          actionCreateCreditor,
          'Create creditor',
          'Created creditor: ${creditor['name']} with balance: ${creditor['balance']}'
        );
      }
      
      return creditorId;
    } catch (e) {
      print('Error adding creditor: $e');
      rethrow;
    }
  }

  Future<void> updateCreditorBalanceAndStatus(
    int id,
    double newBalance,
    String details,
    String status,
  ) async {
    try {
    final db = await database;
      
      // Get the creditor name for logging
      final creditor = await db.query(
        tableCreditors,
        columns: ['name'],
        where: 'id = ?',
        whereArgs: [id],
        limit: 1,
      );
      
      final creditorName = creditor.isNotEmpty ? creditor.first['name'] as String : 'Unknown';
      
    await db.update(
        tableCreditors,
      {
        'balance': newBalance,
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
        await logActivity(
          currentUser.id!,
          currentUser.username,
          actionUpdateCreditor,
          'Update creditor',
          'Updated creditor: $creditorName, new balance: $newBalance, status: $status'
        );
      }
    } catch (e) {
      print('Error updating creditor: $e');
      rethrow;
    }
  }

  Future<int> addDebtor(Map<String, dynamic> debtor) async {
    try {
      int debtorId = await withTransaction((txn) async {
        return await txn.insert(tableDebtors, debtor);
      });
      
      // Log the activity
      final currentUser = AuthService.instance.currentUser;
      if (currentUser != null) {
        await logActivity(
          currentUser.id!,
          currentUser.username,
          actionCreateDebtor,
          'Create debtor',
          'Created debtor: ${debtor['name']} with balance: ${debtor['balance']}'
        );
      }
      
      return debtorId;
    } catch (e) {
      print('Error adding debtor: $e');
      rethrow;
    }
  }

  // Stats related methods
  Future<Map<String, dynamic>> getDailyStats() async {
    final db = await database;
    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day);
    final endOfDay = startOfDay.add(const Duration(days: 1));

    final orders = await getOrdersByDateRange(startOfDay, endOfDay);
    final totalOrders = orders.length;
    final totalSales = orders.fold<double>(
      0,
      (sum, order) => sum + (order['total_amount'] as double),
    );
    final pendingOrders = orders
        .where((order) => order['order_status'] == 'PENDING')
        .length;

    return {
      'total_orders': totalOrders,
      'total_sales': totalSales,
      'pending_orders': pendingOrders,
    };
  }

  Future<void> checkAndCreateAdminUser() async {
    try {
      // Get a direct database connection
      final db = await database;
      
      // Check if admin user exists with a simple query
      final results = await db.rawQuery(
        'SELECT id FROM $tableUsers WHERE username = ?',
        ['admin']
      );
      
      if (results.isEmpty) {
        print('Admin user not found, creating...');
        
        // Create admin user with a simple insert
        await db.execute('''
          INSERT OR IGNORE INTO $tableUsers 
          (username, password, full_name, email, role, created_at, permissions)
          VALUES (?, ?, ?, ?, ?, ?, ?)
        ''', [
          'admin',
          AuthService.instance.hashPassword('Account@2024'),
          'System Administrator',
          'admin@example.com',
          ROLE_ADMIN,
          DateTime.now().toIso8601String(),
          PERMISSION_FULL_ACCESS,
        ]);
        
        print('Admin user created successfully');
      } else {
        print('Admin user already exists with ID: ${results.first['id']}');
      }
    } catch (e) {
      print('Error checking/creating admin user: $e');
      // Don't throw, just log the error
    }
  }

  Future<List<Map<String, dynamic>>> getAllProducts() async {
    final db = await database;
    return await db.query(tableProducts, orderBy: 'product_name');
  }

  Future<List<Map<String, dynamic>>> getAllUsers() async {
    final db = await database;
    return await db.query(tableUsers, orderBy: 'username');
  }

  Future<List<Map<String, dynamic>>> getOrdersByStatus(String status) async {
    final db = await database;
    try {
      return await db.rawQuery('''
        SELECT 
          o.*,
          oi.id as item_id,
          oi.product_id,
          oi.quantity,
          oi.unit_price,
          oi.selling_price,
          oi.adjusted_price,
          oi.total_amount as item_total,
          oi.is_sub_unit,
          oi.sub_unit_name,
          p.product_name,
          c.name as customer_name,
          c.id as customer_id
        FROM $tableOrders o
        LEFT JOIN $tableOrderItems oi ON o.id = oi.order_id
        LEFT JOIN $tableProducts p ON oi.product_id = p.id
        LEFT JOIN $tableCustomers c ON o.customer_id = c.id
        WHERE o.status = ?
        ORDER BY o.created_at DESC
      ''', [status]);
    } catch (e) {
      print('Error getting orders by status: $e');
      return [];
    }
  }

  Future<void> ensureCustomerExists(String customerName) async {
    final db = await database;
    await db.transaction((txn) async {
      final existingCustomer = await txn.query(
        tableCustomers,
        where: 'name = ?',
        whereArgs: [customerName],
        limit: 1,
      );

      if (existingCustomer.isEmpty) {
        await txn.insert(
          tableCustomers,
          {
            'name': customerName,
            'created_at': DateTime.now().toIso8601String(),
          },
        );
      }
    });
  }

  Future<Map<String, dynamic>?> getCustomerByName(String name) async {
    final db = await database;
    final results = await db.query(
      tableCustomers,
      where: 'name = ?',
      whereArgs: [name],
      limit: 1,
    );
    return results.isNotEmpty ? results.first : null;
  }

  // Add a method to completely reset the database
  Future<void> resetDatabase() async {
    print('Completely resetting database...');
    
    // Close any existing database connection
    await _closeDatabase();
    _database = null;
    _initialized = false;
    
    // Get the database path
    final databasePath = await getDatabasesPath();
    final path = join(databasePath, 'malbrose_db.db');
    
    // Delete all database files
    try {
      final dbFile = File(path);
      if (await dbFile.exists()) {
        await dbFile.delete();
        print('Deleted main database file: $path');
      }
      
      final shmFile = File('$path-shm');
      if (await shmFile.exists()) {
        await shmFile.delete();
        print('Deleted database shared memory file: $path-shm');
      }
      
      final walFile = File('$path-wal');
      if (await walFile.exists()) {
        await walFile.delete();
        print('Deleted database WAL file: $path-wal');
      }
      
      final journalFile = File('$path-journal');
      if (await journalFile.exists()) {
        await journalFile.delete();
        print('Deleted database journal file: $path-journal');
      }
    } catch (e) {
      print('Error deleting database files: $e');
    }
    
    // Reinitialize the database
    _database = await _initDatabase();
    _initialized = true;
    
    print('Database reset complete');
  }

  Future<void> addUsernameColumnToActivityLogs() async {
    final db = await database;
    try {
      // Check if username column exists
      var tableInfo = await db.rawQuery('PRAGMA table_info(activity_logs)');
      bool hasUsernameColumn = tableInfo.any((column) => column['name'] == 'username');
      
      if (!hasUsernameColumn) {
        // Add username column
        await db.execute('ALTER TABLE $tableActivityLogs ADD COLUMN username TEXT');
        
        // Update existing records with usernames
        var logs = await db.query(tableActivityLogs);
        for (var log in logs) {
          var user = await getUserById(log['user_id'] as int);
          if (user != null) {
            await db.update(
              tableActivityLogs,
              {'username': user['username']},
              where: 'id = ?',
              whereArgs: [log['id']],
            );
          }
        }
      }
    } catch (e) {
      print('Error adding username column: $e');
    }
  }

  Future<void> addUpdatedAtColumnToProducts() async {
    final db = await database;
    try {
      // Check if updated_at column exists
      var tableInfo = await db.rawQuery('PRAGMA table_info($tableProducts)');
      bool hasUpdatedAtColumn = tableInfo.any((column) => column['name'] == 'updated_at');
      
      if (!hasUpdatedAtColumn) {
        // Add updated_at column
        await db.execute('ALTER TABLE $tableProducts ADD COLUMN updated_at TEXT');
      }
    } catch (e) {
      print('Error adding updated_at column: $e');
    }
  }

  // Add migration method for sub_unit_buying_price column
  Future<void> addSubUnitBuyingPriceColumn() async {
    final db = await database;
    try {
      // Check if sub_unit_buying_price column exists
      var tableInfo = await db.rawQuery('PRAGMA table_info($tableProducts)');
      bool hasSubUnitBuyingPriceColumn = tableInfo.any((column) => column['name'] == 'sub_unit_buying_price');
      
      if (!hasSubUnitBuyingPriceColumn) {
        // Add sub_unit_buying_price column
        await db.execute('ALTER TABLE $tableProducts ADD COLUMN sub_unit_buying_price REAL');
        
        // Initialize with calculated values for existing products
        var products = await db.query(
          tableProducts,
          where: 'has_sub_units = 1 AND sub_unit_quantity > 0'
        );
        
        for (var product in products) {
          final buyingPrice = (product['buying_price'] as num).toDouble();
          final subUnitQuantity = (product['sub_unit_quantity'] as num).toDouble();
          final calculatedSubUnitBuyingPrice = buyingPrice / subUnitQuantity;
          
          await db.update(
            tableProducts,
            {'sub_unit_buying_price': calculatedSubUnitBuyingPrice},
            where: 'id = ?',
            whereArgs: [product['id']],
          );
        }
        
        print('Added sub_unit_buying_price column and initialized values');
      }
    } catch (e) {
      print('Error adding sub_unit_buying_price column: $e');
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
          // Update order status
          await txn.update(
            tableOrders,
            {
              'status': 'COMPLETED',
              'payment_status': 'PAID',
              'payment_method': paymentMethod,
              'updated_at': DateTime.now().toIso8601String(),
            },
            where: 'order_number = ?',
            whereArgs: [order.orderNumber],
          );

          // Get order items with complete information
          final orderItems = await txn.rawQuery('''
            SELECT oi.*, p.sub_unit_quantity, p.quantity as current_quantity
            FROM $tableOrderItems oi
            JOIN $tableProducts p ON oi.product_id = p.id
            WHERE oi.order_id = ?
          ''', [order.id]);

          // Update product quantities directly within this transaction
          for (var item in orderItems) {
            final productId = item['product_id'] as int;
            final quantity = (item['quantity'] as num).toInt();
            final isSubUnit = (item['is_sub_unit'] as num) == 1;
            final subUnitQuantity = (item['sub_unit_quantity'] as num?)?.toDouble();
            final currentQuantity = (item['current_quantity'] as num).toDouble();
            
            // Calculate quantity to deduct
            double quantityToDeduct;
            if (isSubUnit && subUnitQuantity != null && subUnitQuantity > 0) {
              // For sub-units, convert to whole units
              quantityToDeduct = quantity / subUnitQuantity;
            } else {
              quantityToDeduct = quantity.toDouble();
            }
            
            // Calculate new quantity
            final newQuantity = currentQuantity - quantityToDeduct;
            
            // Update product quantity directly in this transaction
            await txn.update(
              tableProducts,
              {'quantity': newQuantity},
              where: 'id = ?',
              whereArgs: [productId],
            );
          }
          
          // Log the completed sale directly within this transaction
          final currentUser = AuthService.instance.currentUser;
          if (currentUser != null) {
            await txn.insert(tableActivityLogs, {
              'user_id': currentUser.id,
              'username': currentUser.username,
              'action': actionCompleteSale,
              'action_type': 'Complete sale',
              'details': 'Completed sale for order #${order.orderNumber}, customer: ${order.customerName}, amount: ${order.totalAmount}',
              'timestamp': DateTime.now().toIso8601String(),
            });
          }
        });
        
        // If we get here, the transaction was successful
        return;
      } catch (e) {
        print('Error completing sale (attempt ${retryCount + 1}): $e');
        
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

  // Add this method to get proper order counts
  Future<Map<String, dynamic>> getDashboardStats() async {
    final db = await database;
    final today = DateTime.now().toIso8601String().split('T')[0];
    
    try {
      final results = await db.rawQuery('''
        SELECT
          COUNT(CASE WHEN DATE(created_at) = ? AND status = 'COMPLETED' THEN 1 END) as completed_orders,
          SUM(CASE WHEN DATE(created_at) = ? AND status = 'COMPLETED' THEN total_amount ELSE 0 END) as total_sales,
          COUNT(CASE WHEN status = 'PENDING' THEN 1 END) as pending_orders,
          COUNT(*) as total_orders
        FROM $tableOrders
        WHERE DATE(created_at) = ?
      ''', [today, today, today]);

      return {
        'today_orders': results.first['completed_orders'] ?? 0,
        'today_sales': results.first['total_sales'] ?? 0.0,
        'pending_orders': results.first['pending_orders'] ?? 0,
        'total_orders': results.first['total_orders'] ?? 0,
      };
    } catch (e) {
      print('Error getting dashboard stats: $e');
      return {
        'today_orders': 0,
        'today_sales': 0.0,
        'pending_orders': 0,
        'total_orders': 0,
      };
    }
  }

  Future<List<Map<String, dynamic>>> getPendingOrders() async {
    final db = await database;
    return await db.query(
      tableOrders,
      where: 'status = ?',
      whereArgs: ['PENDING'],
      orderBy: 'created_at DESC',
    );
  }

  // Add this method to add the status column to orders table
  Future<void> addStatusColumnToOrders() async {
    final db = await database;
    try {
      // Check if status column exists
      var tableInfo = await db.rawQuery('PRAGMA table_info($tableOrders)');
      bool hasStatusColumn = tableInfo.any((column) => column['name'] == 'status');
      
      if (!hasStatusColumn) {
        // Add status column with default value
        await db.execute('ALTER TABLE $tableOrders ADD COLUMN status TEXT DEFAULT "PENDING"');
        
        // Update existing rows to have the default status
        await db.update(
          tableOrders,
          {'status': 'PENDING'},
          where: 'status IS NULL'
        );
      }
    } catch (e) {
      print('Note: $e');
    }
  }

  // Add this method to handle transactions
  Future<void> createOrderWithTransaction(Order order, Transaction txn) async {
    await txn.insert(
      tableOrders,
      order.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> createOrderBatch(List<Order> orders) async {
    final db = await database;
    final batch = db.batch();
    
    for (final order in orders) {
      batch.insert(
        tableOrders,
        order.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    
    await batch.commit(noResult: true);
  }

  // Add this method for batch order creation
  Future<void> createOrdersInBatch(List<Order> orders) async {
    final db = await database;
    await db.transaction((txn) async {
      final batch = txn.batch();
      
      for (final order in orders) {
        batch.insert(
          tableOrders,
          order.toMap(),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
      
      await batch.commit(noResult: true);
    });
  }

  // Add a method to check admin privileges
  Future<bool> isUserAdmin(int userId) async {
    final db = await database;
    final results = await db.query(
      tableUsers,
      where: 'id = ? AND role = ?',
      whereArgs: [userId, ROLE_ADMIN],
      limit: 1,
    );
    return results.isNotEmpty;
  }

  // Add a method to verify admin permissions
  Future<bool> hasAdminPrivileges(int userId) async {
    try {
      final db = await database;
      final user = await db.query(
        tableUsers,
        columns: ['role', 'permissions'],
        where: 'id = ? AND role = ? AND permissions = ?',
        whereArgs: [userId, ROLE_ADMIN, PERMISSION_FULL_ACCESS],
        limit: 1,
      );
      
      return user.isNotEmpty;
    } catch (e) {
      print('Error checking admin privileges: $e');
      return false;
    }
  }

  // Add a method to verify specific admin permissions
  Future<bool> hasPermission(int userId, String permission) async {
    try {
      final db = await database;
      final user = await db.query(
        tableUsers,
        columns: ['permissions'],
        where: 'id = ? AND role = ?',
        whereArgs: [userId, ROLE_ADMIN],
        limit: 1,
      );
      
      if (user.isEmpty) return false;
      final permissions = user.first['permissions'] as String;
      return permissions == PERMISSION_FULL_ACCESS || permissions.contains(permission);
    } catch (e) {
      print('Error checking permission: $e');
      return false;
    }
  }

  // Add this method to check for existing admin user
  Future<bool> _adminExists(Database db) async {
    final result = await db.query(
      tableUsers,
      where: 'username = ? AND role = ?',
      whereArgs: ['admin', ROLE_ADMIN],
      limit: 1,
    );
    return result.isNotEmpty;
  }

  // Update getOrderItems to handle both Map and OrderItem responses
  Future<List<Map<String, dynamic>>> getOrderItems(
    int orderId, {
    String? status
  }) async {
    final db = await database;
    try {
      String query = '''
        SELECT 
          oi.*,
          p.product_name,
          p.buying_price,
          p.sub_unit_quantity,
          o.status as order_status,
          o.customer_name,
          o.order_number
        FROM $tableOrderItems oi
        JOIN $tableOrders o ON oi.order_id = o.id
        JOIN $tableProducts p ON oi.product_id = p.id
        WHERE oi.order_id = ?
      ''';
      
      List<dynamic> args = [orderId];
      if (status != null) {
        query += ' AND o.status = ?';
        args.add(status);
      }
      
      query += ' ORDER BY oi.id';
      
      final results = await db.rawQuery(query, args);
      return results;
    } catch (e) {
      print('Error getting order items: $e');
      return [];
    }
  }

  // Add a separate method for invoice items if needed
  Future<List<Map<String, dynamic>>> getInvoiceOrderItems(int invoiceId) async {
    final db = await database;
    try {
      return await db.rawQuery('''
        SELECT 
          oi.*,
          p.product_name,
          o.status as order_status,
          o.order_number
        FROM $tableOrders o
        JOIN $tableOrderItems oi ON o.id = oi.order_id
        JOIN $tableProducts p ON oi.product_id = p.id
        JOIN invoice_orders io ON o.id = io.order_id
        WHERE io.invoice_id = ?
        ORDER BY o.order_number, oi.id
      ''', [invoiceId]);
    } catch (e) {
      print('Error getting invoice order items: $e');
      return [];
    }
  }

  Future<void> addUpdatedAtColumnToOrders() async {
    final db = await database;
    try {
      // Check if updated_at column exists
      var tableInfo = await db.rawQuery('PRAGMA table_info($tableOrders)');
      bool hasUpdatedAtColumn = tableInfo.any((column) => column['name'] == 'updated_at');
      
      if (!hasUpdatedAtColumn) {
        // Add updated_at column with default value
        await db.execute('''
          ALTER TABLE $tableOrders 
          ADD COLUMN updated_at TEXT DEFAULT CURRENT_TIMESTAMP
        ''');
      }
    } catch (e) {
      print('Error adding updated_at column to orders: $e');
    }
  }

  // Add a helper method to get current stock information
  Future<Map<String, dynamic>> getProductStock(int productId) async {
    final product = await getProductById(productId);
    if (product == null) {
      throw Exception('Product not found');
    }

    final wholeUnits = (product['quantity'] as num).toDouble();
    final subUnitsPerUnit = (product['sub_unit_quantity'] as num?)?.toDouble() ?? 1.0;
    
    final completeUnits = wholeUnits.floor();
    final remainingSubUnits = ((wholeUnits - completeUnits) * subUnitsPerUnit).round();

    return {
      'whole_units': completeUnits,
      'remaining_sub_units': remainingSubUnits,
      'sub_units_per_unit': subUnitsPerUnit.toInt(),
      'product_name': product['product_name'],
      'sub_unit_name': product['sub_unit_name'],
    };
  }

  Future<List<Map<String, dynamic>>> getCustomerReportData({
    required int customerId,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    final db = await database;
    return await db.rawQuery('''
      SELECT 
        c.name as customer_name,
        o.order_number,
        o.created_at,
        oi.quantity,
        oi.unit_price as buying_price,
        oi.selling_price,
        oi.total_amount,
        p.product_name,
        o.status
      FROM $tableOrders o
      JOIN $tableOrderItems oi ON o.id = oi.order_id
      JOIN $tableProducts p ON oi.product_id = p.id
      JOIN customers c ON o.customer_name = c.name
      WHERE o.customer_id = ? 
      AND o.status = 'COMPLETED'
      ${startDate != null ? "AND date(o.created_at) >= date(?)" : ""}
      ${endDate != null ? "AND date(o.created_at) <= date(?)" : ""}
      ORDER BY o.created_at DESC
    ''', [
      customerId,
      if (startDate != null) startDate.toIso8601String(),
      if (endDate != null) endDate.toIso8601String(),
    ]);
  }

  Future<List<Map<String, dynamic>>> getAllCustomers() async {
    try {
      // Get a fresh database connection
      final db = await database;
      
      // Use a direct query with a timeout and no transaction
      return await db.rawQuery('SELECT * FROM customers ORDER BY name LIMIT 1000');
    } catch (e) {
      print('Error getting all customers: $e');
      
      // Try to recover by closing and reopening the database
      await _closeDatabase();
      _database = null;
      _initialized = false;
      
      // Return empty list on error instead of propagating the exception
      return [];
    }
  }

  // Simplified method to get orders by customer
  Future<List<Map<String, dynamic>>> getOrdersByCustomerId(
    int customerId, {
    String? status,
    Transaction? txn,
  }) async {
    final db = await database;
    final queryExecutor = txn ?? db;

    final query = '''
      SELECT 
        o.id as order_id,
        o.status,
        o.created_at,
        o.total_amount,
        o.customer_id,
        o.customer_name
      FROM $tableOrders o
      WHERE o.customer_id = ? 
      AND o.status != 'REPORTED'
      ${status != null ? 'AND o.status = ?' : ''}
      ORDER BY o.created_at DESC
    ''';

    return await queryExecutor.rawQuery(
      query, 
      status != null ? [customerId, status] : [customerId],
    );
  }

  Future<void> _migrateCustomerData(Database db) async {
    try {
      print('Starting customer data migration...');
      
      // First check if the customer_id column exists in orders table
      var tableInfo = await db.rawQuery('PRAGMA table_info($tableOrders)');
      bool hasCustomerId = tableInfo.any((column) => column['name'] == 'customer_id');
      
      if (!hasCustomerId) {
        // Add customer_id column if it doesn't exist
        await db.execute('ALTER TABLE $tableOrders ADD COLUMN customer_id INTEGER REFERENCES $tableCustomers (id)');
      }

      // Get all customers
      final customers = await db.query(tableCustomers);
      
      for (var customer in customers) {
        // Get orders for this customer by name
        final orders = await db.query(
          tableOrders,
          where: 'customer_name = ?',
          whereArgs: [customer['name']],
        );
        
        if (orders.isNotEmpty) {
          // Update customer statistics
          final totalOrders = orders.length;
          final totalAmount = orders.fold<double>(
            0.0,
            (sum, order) => sum + (order['total_amount'] as num).toDouble(),
          );
          final lastOrderDate = orders
              .map((o) => DateTime.parse(o['created_at'] as String))
              .reduce((a, b) => a.isAfter(b) ? a : b)
              .toIso8601String();

          // Update customer record
          await db.update(
            tableCustomers,
            {
              'total_orders': totalOrders,
              'total_amount': totalAmount,
              'last_order_date': lastOrderDate,
              'updated_at': DateTime.now().toIso8601String(),
            },
            where: 'id = ?',
            whereArgs: [customer['id']],
          );

          // Update orders with customer_id
          for (var order in orders) {
            await db.update(
              tableOrders,
              {'customer_id': customer['id']},
              where: 'id = ?',
              whereArgs: [order['id']],
            );
          }
        }
      }
      
      print('Customer data migration completed successfully.');
    } catch (e) {
      print('Error during customer data migration: $e');
    }
  }

  // Update getSalesReport method to include proper price calculations
  Future<List<Map<String, dynamic>>> getSalesReport(DateTime startDate, DateTime endDate) async {
    final db = await database;
    return await db.rawQuery('''
      SELECT 
        o.created_at,
        o.order_number,
        o.customer_name,
        oi.product_name,
        oi.quantity,
        oi.unit_price,
        oi.selling_price,
        COALESCE(oi.adjusted_price, oi.selling_price) as effective_price,
        oi.total_amount,
        oi.is_sub_unit,
        oi.sub_unit_name,
        p.sub_unit_quantity,
        p.buying_price as product_buying_price,
        p.sub_unit_buying_price,
        CASE 
          WHEN oi.is_sub_unit = 1 AND p.sub_unit_buying_price IS NOT NULL
          THEN p.sub_unit_buying_price
          WHEN oi.is_sub_unit = 1 AND p.sub_unit_quantity > 0
          THEN p.buying_price / p.sub_unit_quantity
          ELSE p.buying_price
        END as buying_price
      FROM $tableOrders o
      JOIN $tableOrderItems oi ON o.id = oi.order_id
      JOIN $tableProducts p ON oi.product_id = p.id
      WHERE o.status = 'COMPLETED'
      AND date(o.created_at) BETWEEN date(?) AND date(?)
      ORDER BY o.created_at DESC
    ''', [startDate.toIso8601String(), endDate.toIso8601String()]);
  }

  // Update getSalesSummary for accurate profit calculation
  Future<Map<String, dynamic>> getSalesSummary(
    DateTime startDate,
    DateTime endDate,
  ) async {
    final db = await database;
    final results = await db.rawQuery('''
      SELECT
        COUNT(DISTINCT o.id) as total_orders,
        SUM(oi.total_amount) as total_sales,
        SUM(
          CASE 
            WHEN oi.is_sub_unit = 1 AND p.sub_unit_quantity > 0
            THEN (p.buying_price / p.sub_unit_quantity) * oi.quantity
            ELSE p.buying_price * oi.quantity
          END
        ) as total_buying_cost,
        SUM(
          oi.total_amount - 
          CASE 
            WHEN oi.is_sub_unit = 1 AND p.sub_unit_quantity > 0
            THEN (p.buying_price / p.sub_unit_quantity) * oi.quantity
            ELSE p.buying_price * oi.quantity
          END
        ) as total_profit,
        COUNT(DISTINCT o.customer_id) as unique_customers,
        COUNT(oi.id) as total_items,
        SUM(oi.quantity) as total_quantity
      FROM $tableOrders o
      JOIN $tableOrderItems oi ON o.id = oi.order_id
      JOIN $tableProducts p ON oi.product_id = p.id
      WHERE o.status = 'COMPLETED'
      AND date(o.created_at) BETWEEN date(?) AND date(?)
    ''', [startDate.toIso8601String(), endDate.toIso8601String()]);

    final data = results.first;
    return {
      'total_orders': (data['total_orders'] as num?)?.toInt() ?? 0,
      'total_sales': (data['total_sales'] as num?)?.toDouble() ?? 0.0,
      'total_buying_cost': (data['total_buying_cost'] as num?)?.toDouble() ?? 0.0,
      'total_profit': (data['total_profit'] as num?)?.toDouble() ?? 0.0,
      'unique_customers': (data['unique_customers'] as num?)?.toInt() ?? 0,
      'total_items': (data['total_items'] as num?)?.toInt() ?? 0,
      'total_quantity': (data['total_quantity'] as num?)?.toInt() ?? 0
    };
  }

  // Update createCustomer to handle both Map and Customer objects
  Future<int> createCustomer(dynamic customerData) async {
    final Map<String, dynamic> customerMap;
    if (customerData is Customer) {
      customerMap = customerData.toMap();
    } else if (customerData is Map<String, dynamic>) {
      customerMap = customerData;
    } else {
      throw ArgumentError('Invalid customer data type');
    }

    return await withTransaction((txn) async {
      try {
        // Check if customer already exists
        final existing = await txn.query(
          tableCustomers,
          where: 'name = ?',
          whereArgs: [customerMap['name']],
          limit: 1,
        );

        if (existing.isNotEmpty) {
          return existing.first['id'] as int;
        }

        // Create new customer
        return await txn.insert(
          tableCustomers,
          {
            ...customerMap,
            'created_at': DateTime.now().toIso8601String(),
            'total_orders': 0,
            'total_amount': 0.0,
          },
        );
      } catch (e) {
        print('Error creating customer: $e');
        rethrow;
      }
    });
  }

  // Customer Report related methods
  Future<void> createCustomerReportWithItems(Map<String, dynamic> reportData, List<Map<String, dynamic>> items) async {
    final db = await database;
    await db.transaction((txn) async {
      // Insert report
      final reportId = await txn.insert(tableCustomerReports, reportData);
      
      // Insert report items
      for (var item in items) {
        item['report_id'] = reportId;
        await txn.insert(tableReportItems, item);
      }
      
      // Log activity
      final currentUser = await getCurrentUser();
      if (currentUser != null) {
        await logActivity(
          currentUser['id'] as int,
          currentUser['username'] as String,
          actionCreateCustomerReport,
          'Create customer report',
          'Created customer report #${reportData['report_number']} for ${reportData['customer_name']}'
        );
      }
    });
  }
  
  Future<List<Map<String, dynamic>>> getCustomerReports({
    int? customerId,
    String? status,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    final db = await database;
    String whereClause = '';
    List<dynamic> whereArgs = [];
    
    if (customerId != null) {
      whereClause += 'customer_id = ?';
      whereArgs.add(customerId);
    }
    
    if (status != null) {
      if (whereClause.isNotEmpty) whereClause += ' AND ';
      whereClause += 'status = ?';
      whereArgs.add(status);
    }
    
    if (startDate != null && endDate != null) {
      if (whereClause.isNotEmpty) whereClause += ' AND ';
      whereClause += 'date(created_at) BETWEEN date(?) AND date(?)';
      whereArgs.addAll([
        startDate.toIso8601String(),
        endDate.toIso8601String(),
      ]);
    }
    
    final reports = await db.query(
      tableCustomerReports,
      where: whereClause.isNotEmpty ? whereClause : null,
      whereArgs: whereArgs.isNotEmpty ? whereArgs : null,
      orderBy: 'created_at DESC',
    );
    
    return reports;
  }
  
  Future<List<Map<String, dynamic>>> getReportItems(int reportId) async {
    final db = await database;
    return await db.query(
      tableReportItems,
      where: 'report_id = ?',
      whereArgs: [reportId],
    );
  }
  
  Future<List<Map<String, dynamic>>> getDetailedReportItems(int reportId) async {
    final db = await database;
    return await db.rawQuery('''
      SELECT 
        ri.*,
        p.product_name,
        p.sub_unit_price,
        p.sub_unit_quantity
      FROM $tableReportItems ri
      LEFT JOIN $tableProducts p ON ri.product_id = p.id
      WHERE ri.report_id = ?
    ''', [reportId]);
  }
  
  Future<void> saveCustomerReport(Map<String, dynamic> reportData) async {
    final db = await database;
    
    if (reportData.containsKey('id')) {
      final id = reportData['id'];
      reportData.remove('id');
      
      await db.update(
        tableCustomerReports,
        reportData,
        where: 'id = ?',
        whereArgs: [id],
      );
      
      // Log activity
      final currentUser = await getCurrentUser();
      if (currentUser != null) {
        await logActivity(
          currentUser['id'] as int,
          currentUser['username'] as String,
          actionUpdateCustomerReport,
          'Update customer report',
          'Updated customer report #${reportData['report_number']}'
        );
      }
    } else {
      await db.insert(tableCustomerReports, reportData);
      
      // Log activity
      final currentUser = await getCurrentUser();
      if (currentUser != null) {
        await logActivity(
          currentUser['id'] as int,
          currentUser['username'] as String,
          actionCreateCustomerReport,
          'Create customer report',
          'Created customer report #${reportData['report_number']} for ${reportData['customer_name']}'
        );
      }
    }
  }

  Future<Map<String, dynamic>> getCustomerDetails(int customerId) async {
    final db = await database;
    try {
      final result = await db.rawQuery('''
        SELECT 
          c.id,
          c.name,
          c.phone,
          c.email,
          c.address,
          COUNT(DISTINCT o.id) as total_orders,
          SUM(CASE WHEN o.status = 'COMPLETED' THEN o.total_amount ELSE 0 END) as total_completed_sales,
          SUM(CASE WHEN o.status = 'PENDING' THEN o.total_amount ELSE 0 END) as pending_payments,
          MAX(o.created_at) as last_order_date
        FROM customers c
        LEFT JOIN orders o ON c.id = o.customer_id
        WHERE c.id = ?
        GROUP BY c.id
      ''', [customerId]);
      
      if (result.isNotEmpty) {
        return result.first;
      }
      return {};
    } catch (e) {
      print('Error getting customer details: $e');
      return {};
    }
  }

  Future<Map<String, dynamic>> getProductInventoryDetails(int productId) async {
    final db = await database;
    final product = await db.query(
      tableProducts,
      where: 'id = ?',
      whereArgs: [productId],
      limit: 1,
    );
    
    if (product.isEmpty) {
      return {};
    }

    final wholeUnits = (product.first['quantity'] as num).toDouble();
    final subUnitsPerUnit = (product.first['sub_unit_quantity'] as num?)?.toDouble() ?? 1.0;
    
    final completeUnits = wholeUnits.floor();
    final remainingSubUnits = ((wholeUnits - completeUnits) * subUnitsPerUnit).round();

    return {
      'whole_units': completeUnits,
      'remaining_sub_units': remainingSubUnits,
      'sub_units_per_unit': subUnitsPerUnit.toInt(),
      'product_name': product.first['product_name'],
      'sub_unit_name': product.first['sub_unit_name'],
    };
  }

  Future<List<Map<String, dynamic>>> getCustomerOrders(int customerId) async {
    final db = await database;
    return await db.query(
      tableOrders,
      where: 'customer_id = ?',
      whereArgs: [customerId],
      orderBy: 'created_at DESC',
    );
  }

  // Add the getCurrentUser method
  Future<Map<String, dynamic>?> getCurrentUser() async {
    final currentUser = AuthService.instance.currentUser;
    if (currentUser != null) {
      return await getUserById(currentUser.id!);
    }
    return null;
  }

  // Debtor related methods
  Future<List<Map<String, dynamic>>> getDebtors() async {
    final db = await database;
    return await db.query(tableDebtors, orderBy: 'created_at DESC');
  }

  Future<bool> checkDebtorExists(String name) async {
    final db = await database;
    final result = await db.query(
      tableDebtors,
      where: 'name = ?',
      whereArgs: [name],
      limit: 1,
    );
    return result.isNotEmpty;
  }

  Future<void> updateDebtorBalanceAndStatus(
    int id,
    double newBalance,
    String details,
    String status,
  ) async {
    try {
      final db = await database;
      
      // Get the debtor name for logging
      final debtor = await db.query(
        tableDebtors,
        columns: ['name'],
        where: 'id = ?',
        whereArgs: [id],
        limit: 1,
      );
      
      final debtorName = debtor.isNotEmpty ? debtor.first['name'] as String : 'Unknown';
      
      await db.update(
        tableDebtors,
        {
          'balance': newBalance,
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
        await logActivity(
          currentUser.id!,
          currentUser.username,
          actionUpdateDebtor,
          'Update debtor',
          'Updated debtor: $debtorName, new balance: $newBalance, status: $status'
        );
      }
    } catch (e) {
      print('Error updating debtor: $e');
      rethrow;
    }
  }

  // Delete an order and its items
  Future<void> deleteOrder(int orderId) async {
    int retryCount = 0;
    const maxRetries = 3;
    const baseDelay = 200; // milliseconds
    
    while (true) {
      try {
        final db = await database;
        
        await db.transaction((txn) async {
          // First, delete all order items
          await txn.delete(
            'order_items',
            where: 'order_id = ?',
            whereArgs: [orderId],
          );
          
          // Then delete the order
          await txn.delete(
            'orders',
            where: 'id = ?',
            whereArgs: [orderId],
          );
        });
        
        // If we get here, the transaction was successful
        return;
      } catch (e) {
        print('Error deleting order (attempt ${retryCount + 1}): $e');
        
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

  // Add a method to explicitly initialize the database
  Future<void> initialize() async {
    try {
      // Get a database connection to trigger initialization
      final db = await database;
      
      // Test the connection with a simple query
      final result = await db.rawQuery('SELECT 1');
      print('Database initialized successfully: $result');
    } catch (e) {
      print('Error initializing database: $e');
      
      // If initialization fails, try to reset the database
      await resetDatabase();
    }
  }
}
