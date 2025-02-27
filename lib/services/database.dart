import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:my_flutter_app/models/order_model.dart';
import 'package:my_flutter_app/models/user_model.dart';
import 'package:my_flutter_app/services/auth_service.dart';
import 'package:flutter/foundation.dart';
import 'package:crypto/crypto.dart';
import 'dart:convert'; // For utf8 encoding
import 'package:synchronized/synchronized.dart';
import 'package:my_flutter_app/models/invoice_model.dart';
import '../models/customer_model.dart';

class DatabaseService {
  static final DatabaseService instance = DatabaseService._init();
  static Database? _database;
  final _lock = Lock();

  // Table Names
  static const String tableProducts = 'products';
  static const String tableUsers = 'users';
  static const String tableOrders = 'orders';
  static const String tableActivityLogs = 'activity_logs';
  static const String tableCreditors = 'creditors';
  static const String tableDebtors = 'debtors';
  static const String tableOrderItems = 'order_items';
  static const String tableCustomers = 'customers';
  static const String tableInvoices = 'invoices';
  static const String tableInvoiceItems = 'invoice_items';

  // Add these constants at the top of the DatabaseService class
  static const String actionCreateOrder = 'create_order';
  static const String actionCompleteSale = 'complete_sale';
  static const String actionUpdateProduct = 'update_product';
  static const String actionCreateProduct = 'create_product';
  static const String actionCreateCreditor = 'create_creditor';
  static const String actionUpdateCreditor = 'update_creditor';
  static const String actionCreateDebtor = 'create_debtor';
  static const String actionUpdateDebtor = 'update_debtor';
  static const String actionLogin = 'login';
  static const String actionLogout = 'logout';

  // Add these admin privilege constants at the top of DatabaseService class
  static const String ROLE_ADMIN = 'ADMIN';
  static const String PERMISSION_FULL_ACCESS = 'FULL_ACCESS';
  static const String PERMISSION_BASIC = 'BASIC';

  DatabaseService._init();

  Future<Database> get database async {
    _database ??= await _initDatabase();
    return _database!;
  }

  Future<T> withTransaction<T>(Future<T> Function(Transaction txn) action) async {
    return await _lock.synchronized(() async {
      final db = await database;
      return await db.transaction((txn) async {
        return await action(txn);
      });
    });
  }

  Future<Database> _initDatabase() async {
    final databasePath = await getDatabasesPath();
    final path = join(databasePath, 'malbrose_db.db');

    try {
      print('Initializing database at path: $path');
      
      // Delete existing database if it's corrupted
      if (await databaseExists(path)) {
        try {
          print('Database exists, checking if it can be opened...');
          final db = await openDatabase(path, readOnly: true);
          await db.close();
          print('Existing database is valid');
        } catch (e) {
          print('Database corrupted, recreating...');
          await deleteDatabase(path);
        }
      }

      print('Opening database with write permissions...');
      // Open database with write permissions
      final db = await openDatabase(
        path,
        version: 1,  // Reset to version 1 for clean slate
        onCreate: (db, version) async {
          print('Creating new database tables...');
          await _createTables(db, version);
          print('Database tables created successfully');
        },
        onUpgrade: (db, oldVersion, newVersion) async {
          print('Upgrading database from version $oldVersion to $newVersion');
          await _onUpgrade(db, oldVersion, newVersion);
        },
        readOnly: false,
        singleInstance: true,
        onConfigure: (db) async {
          print('Configuring database...');
          await db.execute('PRAGMA journal_mode=WAL');
          await db.execute('PRAGMA synchronous=NORMAL');
          await db.execute('PRAGMA busy_timeout=10000');
          await db.execute('PRAGMA foreign_keys=ON');
          print('Database configuration complete');
        },
      );
      
      print('Database initialized successfully');
      return db;
    } catch (e, stackTrace) {
      print('Database initialization error: $e');
      print('Stack trace: $stackTrace');
      
      // Try to recover by deleting and recreating the database
      try {
        print('Attempting database recovery...');
        await deleteDatabase(path);
        
        final db = await openDatabase(
          path,
          version: 1,
          onCreate: _createTables,
          readOnly: false,
          singleInstance: true,
        );
        
        print('Database recovered successfully');
        return db;
      } catch (recoveryError) {
        print('Database recovery failed: $recoveryError');
        throw Exception('Failed to initialize or recover the database: $e\nOriginal error: $recoveryError');
      }
    }
  }

  Future<void> _createTables(Database db, int version) async {
    try {
      print('Enabling foreign key support...');
      // Enable foreign key support
      await db.execute('PRAGMA foreign_keys = ON');

      print('Creating users table...');
      await db.execute('''
        CREATE TABLE IF NOT EXISTS $tableUsers (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          username TEXT NOT NULL UNIQUE,
          password TEXT NOT NULL,
          full_name TEXT NOT NULL,
          email TEXT NOT NULL,
          role TEXT NOT NULL CHECK (role IN ('ADMIN', 'USER')),
          permissions TEXT NOT NULL DEFAULT '$PERMISSION_BASIC' CHECK (permissions IN ('$PERMISSION_BASIC', '$PERMISSION_FULL_ACCESS')),
          created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
          last_login TEXT,
          updated_at TEXT DEFAULT CURRENT_TIMESTAMP
        )
      ''');

      print('Creating customers table...');
      await db.execute('''
        CREATE TABLE IF NOT EXISTS $tableCustomers (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          name TEXT NOT NULL UNIQUE,
          email TEXT,
          phone TEXT,
          address TEXT,
          created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
          updated_at TEXT DEFAULT CURRENT_TIMESTAMP
        )
      ''');

      print('Creating products table...');
      await db.execute('''
        CREATE TABLE IF NOT EXISTS $tableProducts (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          product_name TEXT NOT NULL,
          description TEXT,
          buying_price REAL NOT NULL CHECK (buying_price >= 0),
          selling_price REAL NOT NULL CHECK (selling_price >= 0),
          stock_quantity INTEGER NOT NULL DEFAULT 0,
          is_sub_unit INTEGER NOT NULL DEFAULT 0 CHECK (is_sub_unit IN (0, 1)),
          sub_unit_name TEXT,
          sub_unit_quantity INTEGER CHECK (sub_unit_quantity > 0),
          sub_unit_price REAL CHECK (sub_unit_price >= 0),
          created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
          updated_at TEXT DEFAULT CURRENT_TIMESTAMP
        )
      ''');

      print('Creating orders table...');
      await db.execute('''
        CREATE TABLE IF NOT EXISTS $tableOrders (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          order_number TEXT NOT NULL UNIQUE,
          customer_id INTEGER,
          customer_name TEXT,
          total_amount REAL NOT NULL CHECK (total_amount >= 0),
          status TEXT NOT NULL CHECK (status IN ('PENDING', 'COMPLETED', 'CANCELLED')),
          payment_status TEXT NOT NULL CHECK (payment_status IN ('PENDING', 'COMPLETED', 'PARTIAL')),
          created_by INTEGER NOT NULL,
          created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
          completed_at TEXT,
          FOREIGN KEY (customer_id) REFERENCES $tableCustomers (id) ON DELETE SET NULL,
          FOREIGN KEY (created_by) REFERENCES $tableUsers (id) ON DELETE RESTRICT
        )
      ''');

      print('Creating order items table...');
      await db.execute('''
        CREATE TABLE IF NOT EXISTS $tableOrderItems (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          order_id INTEGER NOT NULL,
          product_id INTEGER NOT NULL,
          quantity INTEGER NOT NULL CHECK (quantity > 0),
          unit_price REAL NOT NULL CHECK (unit_price >= 0),
          selling_price REAL NOT NULL CHECK (selling_price >= 0),
          total_amount REAL NOT NULL CHECK (total_amount >= 0),
          is_sub_unit INTEGER NOT NULL DEFAULT 0 CHECK (is_sub_unit IN (0, 1)),
          sub_unit_name TEXT,
          created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
          FOREIGN KEY (order_id) REFERENCES $tableOrders (id) ON DELETE CASCADE,
          FOREIGN KEY (product_id) REFERENCES $tableProducts (id) ON DELETE RESTRICT
        )
      ''');

      print('Creating invoices table...');
      await db.execute('''
        CREATE TABLE IF NOT EXISTS $tableInvoices (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          invoice_number TEXT NOT NULL UNIQUE,
          customer_id INTEGER NOT NULL,
          customer_name TEXT NOT NULL,
          total_amount REAL NOT NULL CHECK (total_amount >= 0),
          completed_amount REAL NOT NULL CHECK (completed_amount >= 0),
          pending_amount REAL NOT NULL CHECK (pending_amount >= 0),
          status TEXT NOT NULL CHECK (status IN ('PENDING', 'COMPLETED', 'CANCELLED')),
          created_by INTEGER NOT NULL,
          created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
          due_date TEXT,
          FOREIGN KEY (customer_id) REFERENCES $tableCustomers (id) ON DELETE RESTRICT,
          FOREIGN KEY (created_by) REFERENCES $tableUsers (id) ON DELETE RESTRICT
        )
      ''');

      print('Creating invoice items table...');
      await db.execute('''
        CREATE TABLE IF NOT EXISTS $tableInvoiceItems (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          invoice_id INTEGER NOT NULL,
          order_id INTEGER,
          product_id INTEGER NOT NULL,
          quantity INTEGER NOT NULL CHECK (quantity > 0),
          unit_price REAL NOT NULL CHECK (unit_price >= 0),
          total_amount REAL NOT NULL CHECK (total_amount >= 0),
          created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
          FOREIGN KEY (invoice_id) REFERENCES $tableInvoices (id) ON DELETE CASCADE,
          FOREIGN KEY (order_id) REFERENCES $tableOrders (id) ON DELETE SET NULL,
          FOREIGN KEY (product_id) REFERENCES $tableProducts (id) ON DELETE RESTRICT
        )
      ''');

      print('Creating activity logs table...');
      await db.execute('''
        CREATE TABLE IF NOT EXISTS $tableActivityLogs (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          user_id INTEGER NOT NULL,
          username TEXT NOT NULL,
          action TEXT NOT NULL,
          action_type TEXT NOT NULL CHECK (action_type IN (
            'create_order', 'complete_sale', 'update_product', 'create_product',
            'create_creditor', 'update_creditor', 'create_debtor', 'update_debtor',
            'login', 'logout', 'add_stock', 'deduct_stock'
          )),
          details TEXT NOT NULL,
          timestamp TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
          FOREIGN KEY (user_id) REFERENCES $tableUsers (id) ON DELETE CASCADE
        )
      ''');

      print('All tables created successfully');
      
      // Ensure admin user exists with proper credentials
      print('Creating admin user...');
      await checkAndCreateAdminUser();
      print('Admin user created/verified successfully');
    } catch (e, stackTrace) {
      print('Error creating tables: $e');
      print('Stack trace: $stackTrace');
      throw Exception('Failed to create database tables: $e');
    }
  }

  String _hashPassword(String password) {
    // This method is deprecated, use AuthService.instance.hashPassword instead
    return AuthService.instance.hashPassword(password);
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
      // First check if the table exists
      final tables = await db.rawQuery(
        "SELECT name FROM sqlite_master WHERE type='table' AND name=?",
        [tableActivityLogs]
      );
      
      if (tables.isEmpty) {
        // Table doesn't exist, create it with all required columns
        await db.execute('''
          CREATE TABLE IF NOT EXISTS $tableActivityLogs (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            user_id INTEGER NOT NULL,
            username TEXT NOT NULL,
            action TEXT NOT NULL,
            action_type TEXT,
            details TEXT NOT NULL,
            timestamp TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
            FOREIGN KEY (user_id) REFERENCES $tableUsers (id) ON DELETE CASCADE
          )
        ''');
        print('Created activity_logs table');
        return;
      }
      
      // Table exists, check for required columns
      var tableInfo = await db.rawQuery('PRAGMA table_info($tableActivityLogs)');
      
      // Check for username column
      bool hasUsername = tableInfo.any((column) => column['name'] == 'username');
      if (!hasUsername) {
        await db.execute('ALTER TABLE $tableActivityLogs ADD COLUMN username TEXT');
        print('Added username column to activity_logs');
      }
      
      // Check for action_type column
      bool hasActionType = tableInfo.any((column) => column['name'] == 'action_type');
      if (!hasActionType) {
        await db.execute('ALTER TABLE $tableActivityLogs ADD COLUMN action_type TEXT');
        print('Added action_type column to activity_logs');
      }
      
      // Update any existing records to use action as action_type if needed
      await db.execute('''
        UPDATE $tableActivityLogs 
        SET action_type = action 
        WHERE action_type IS NULL
      ''');
      
      // If username is NULL, try to populate it from users table
      await db.execute('''
        UPDATE $tableActivityLogs al
        SET username = (
          SELECT username 
          FROM $tableUsers u 
          WHERE u.id = al.user_id
        )
        WHERE al.username IS NULL
      ''');
      
    } catch (e) {
      print('Error during activity logs migration: $e');
    }
  }

  // Migration logic
  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    print('Upgrading database from version $oldVersion to $newVersion');
    
    try {
      // Backup existing data
      final existingUsers = await db.query(tableUsers);
      final existingCustomers = await db.query(tableCustomers);
      final existingProducts = await db.query(tableProducts);
      final existingOrders = await db.query(tableOrders);
      final existingOrderItems = await db.query(tableOrderItems);
      final existingInvoices = await db.query(tableInvoices);
      final existingInvoiceItems = await db.query(tableInvoiceItems);
      final existingActivityLogs = await db.query(tableActivityLogs);
      
      // Drop all existing tables
      await db.execute('DROP TABLE IF EXISTS $tableInvoiceItems');
      await db.execute('DROP TABLE IF EXISTS $tableInvoices');
      await db.execute('DROP TABLE IF EXISTS $tableOrderItems');
      await db.execute('DROP TABLE IF EXISTS $tableOrders');
      await db.execute('DROP TABLE IF EXISTS $tableProducts');
      await db.execute('DROP TABLE IF EXISTS $tableActivityLogs');
      await db.execute('DROP TABLE IF EXISTS $tableCustomers');
      await db.execute('DROP TABLE IF EXISTS $tableUsers');
      
      // Create new tables with updated schema
      await _createTables(db, newVersion);
      
      // Restore data with proper validation
      for (var user in existingUsers) {
        user.remove('id');
        if (!user.containsKey('permissions')) {
          user['permissions'] = user['role'] == ROLE_ADMIN ? PERMISSION_FULL_ACCESS : PERMISSION_BASIC;
        }
        if (user['password'].toString().length != 64) {
          user['password'] = AuthService.instance.hashPassword(user['password'] as String);
        }
        await db.insert(tableUsers, user, conflictAlgorithm: ConflictAlgorithm.ignore);
      }
      
      for (var customer in existingCustomers) {
        customer.remove('id');
        await db.insert(tableCustomers, customer, conflictAlgorithm: ConflictAlgorithm.ignore);
      }
      
      for (var product in existingProducts) {
        product.remove('id');
        await db.insert(tableProducts, product, conflictAlgorithm: ConflictAlgorithm.ignore);
      }
      
      for (var order in existingOrders) {
        order.remove('id');
        if (!order.containsKey('payment_status')) {
          order['payment_status'] = 'PENDING';
        }
        await db.insert(tableOrders, order, conflictAlgorithm: ConflictAlgorithm.ignore);
      }
      
      for (var item in existingOrderItems) {
        item.remove('id');
        await db.insert(tableOrderItems, item, conflictAlgorithm: ConflictAlgorithm.ignore);
      }
      
      for (var invoice in existingInvoices) {
        invoice.remove('id');
        await db.insert(tableInvoices, invoice, conflictAlgorithm: ConflictAlgorithm.ignore);
      }
      
      for (var item in existingInvoiceItems) {
        item.remove('id');
        await db.insert(tableInvoiceItems, item, conflictAlgorithm: ConflictAlgorithm.ignore);
      }
      
      for (var log in existingActivityLogs) {
        log.remove('id');
        if (!log.containsKey('action_type')) {
          log['action_type'] = log['action'];
        }
        await db.insert(tableActivityLogs, log, conflictAlgorithm: ConflictAlgorithm.ignore);
      }
      
      // Ensure admin user exists with correct credentials
      await checkAndCreateAdminUser();
      
      print('Database upgrade completed successfully');
    } catch (e) {
      print('Error during database upgrade: $e');
      rethrow;
    }
  }

  Future<void> _migrateInvoicePaymentStatus(Database db) async {
    try {
      // Check if payment_status column exists
      var tableInfo = await db.rawQuery('PRAGMA table_info($tableInvoices)');
      bool hasPaymentStatus = tableInfo.any((column) => column['name'] == 'payment_status');
      
      if (!hasPaymentStatus) {
        // Add payment_status column with default value
        await db.execute('''
          ALTER TABLE $tableInvoices 
          ADD COLUMN payment_status TEXT NOT NULL DEFAULT 'PENDING'
        ''');
        
        // Update existing rows to have the default status
        await db.update(
          tableInvoices,
          {'payment_status': 'PENDING'},
          where: 'payment_status IS NULL'
        );
      }
    } catch (e) {
      print('Error migrating invoice payment status: $e');
    }
  }

  // User related methods
  Future<User?> createUser(Map<String, dynamic> userData) async {
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
      final id = await db.insert(tableUsers, userData);
      
      if (id != 0) {
        return User.fromMap({...userData, 'id': id});
      }
      return null;
    } catch (e) {
      print('Error creating user: $e');
      rethrow;
    }
  }

  Future<void> updateUser(User user) async {
    // Ensure permissions are maintained during update
    final db = await database;
    try {
      final userData = user.toMap();
      
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

      if (!userData.containsKey('permissions')) {
        final existingUser = await getUserById(user.id!);
        if (existingUser != null) {
          userData['permissions'] = existingUser['permissions'];
        }
      }

      await db.update(
        tableUsers,
        userData,
        where: 'id = ?',
        whereArgs: [user.id],
      );
    } catch (e) {
      print('Error updating user: $e');
      rethrow;
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
    final db = await database;
    final results = await db.query(
      tableUsers,
      where: 'username = ?',
      whereArgs: [username],
      limit: 1,
    );
    return results.isNotEmpty ? results.first : null;
  }

  Future<Map<String, dynamic>?> getUserById(int id) async {
    final db = await database;
    final results = await db.query(
      tableUsers,
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    return results.isNotEmpty ? results.first : null;
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

  Future<void> logActivity(Map<String, dynamic> activity) async {
    final db = await database;
    try {
      // Get the username for the current user
      final user = await getUserById(activity['user_id'] as int);
      if (user == null) {
        throw Exception('User not found for logging activity');
      }

      // Add username to the activity log
      activity['username'] = user['username'] as String;
      
      await db.insert(tableActivityLogs, activity);
    } catch (e) {
      print('Error logging activity: $e');
      rethrow;
    }
  }

  // Order related methods
  Future<int> createOrder(Order order) async {
    int orderId = 0;
    
    await withTransaction((txn) async {
      try {
        // First ensure customer exists and get/create customer ID
        int? customerId = order.customerId;
        String? customerName = order.customerName;
        
        if (customerName != null && customerName.isNotEmpty) {
          final existingCustomer = await txn.query(
            tableCustomers,
            where: 'name = ?',
            whereArgs: [customerName],
            limit: 1,
          );

          if (existingCustomer.isEmpty) {
            // Create new customer
            customerId = await txn.insert(
              tableCustomers,
              {
                'name': customerName,
                'created_at': DateTime.now().toIso8601String(),
                'total_orders': 1,
                'total_amount': order.totalAmount,
                'last_order_date': DateTime.now().toIso8601String(),
                'updated_at': DateTime.now().toIso8601String(),
              },
            );
          } else {
            customerId = existingCustomer.first['id'] as int;
            // Update existing customer's stats within transaction
            await txn.update(
              tableCustomers,
              {
                'total_orders': (existingCustomer.first['total_orders'] as int) + 1,
                'total_amount': (existingCustomer.first['total_amount'] as num).toDouble() + order.totalAmount,
                'last_order_date': DateTime.now().toIso8601String(),
                'updated_at': DateTime.now().toIso8601String(),
              },
              where: 'id = ?',
              whereArgs: [customerId],
            );
          }
        }

        // Get current user's username within transaction
        final userResult = await txn.query(
          tableUsers,
          columns: ['username'],
          where: 'id = ?',
          whereArgs: [order.createdBy],
          limit: 1,
        );
        
        final username = userResult.isNotEmpty ? userResult.first['username'] as String : 'Unknown';

        // Create order with the customer information
        final orderMap = {
          'order_number': order.orderNumber,
          'customer_id': customerId,
          'customer_name': customerName,
          'total_amount': order.totalAmount,
          'status': order.orderStatus,
          'payment_status': order.paymentStatus,
          'created_by': order.createdBy,
          'created_at': order.createdAt.toIso8601String(),
          'order_date': order.orderDate.toIso8601String(),
          'updated_at': DateTime.now().toIso8601String(),
        };
        
        orderId = await txn.insert(tableOrders, orderMap);
        
        // Create order items within the same transaction
        for (var item in order.items) {
          // Get product name if not provided
          String productName = item.productName;
          if (productName.isEmpty) {
            final productResult = await txn.query(
              tableProducts,
              columns: ['product_name'],
              where: 'id = ?',
              whereArgs: [item.productId],
              limit: 1,
            );
            if (productResult.isNotEmpty) {
              productName = productResult.first['product_name'] as String;
            } else {
              throw Exception('Product not found for ID: ${item.productId}');
            }
          }

          await txn.insert(tableOrderItems, {
            ...item.toMap(),
            'order_id': orderId,
            'product_name': productName,
          });
        }

        // Log activity within the same transaction
        await txn.insert(
          tableActivityLogs,
          {
            'user_id': order.createdBy,
            'username': username,
            'action': 'create_order',
            'details': 'Created order #${order.orderNumber} for ${customerName ?? "Walk-in Customer"}',
            'timestamp': DateTime.now().toIso8601String(),
          },
        );

        return orderId;
      } catch (e) {
        print('Error in transaction: $e');
        rethrow;
      }
    });
    
    return orderId;
  }

  Future<void> updateOrder(Order order) async {
    final db = await database;
    await db.transaction((txn) async {
      // Update order status
      await txn.update(
        tableOrders,
        {
          'status': order.orderStatus,
          'payment_status': order.paymentStatus,
          'total_amount': order.totalAmount,
        },
        where: 'id = ?',
        whereArgs: [order.id],
      );

      // Update order items if needed
      for (var item in order.items) {
        if (item.id != null) {
          await txn.update(
            tableOrderItems,
            item.toMap(),
            where: 'id = ?',
            whereArgs: [item.id],
          );
        }
      }
    });
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
      await logActivity({
        'user_id': currentUser.id!,
        'action': 'update_product',
        'details': 'Updated product ID: ${product['id']}',
        'timestamp': DateTime.now().toIso8601String(),
        'username': currentUser.username,
      });
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
        // Convert sub-units to whole units
        quantityToUpdate = quantity.toDouble() / subUnitQuantity;
      } else {
        quantityToUpdate = quantity.toDouble();
      }

      // Calculate new quantity (allow negative for tracking oversold items)
      final newQuantity = isDeducting 
          ? currentQuantity - quantityToUpdate 
          : currentQuantity + quantityToUpdate;

      // If adding new stock and current quantity is negative,
      // calculate the actual new quantity by adding to the negative value
      final finalQuantity = !isDeducting && currentQuantity < 0
          ? newQuantity // This will effectively add to the negative value
          : newQuantity;

      await txn.update(
        tableProducts,
        {'quantity': finalQuantity},
        where: 'id = ?',
        whereArgs: [productId],
      );

      // Log stock update
      final currentUser = AuthService.instance.currentUser;
      if (currentUser != null) {
        await logActivity({
          'user_id': currentUser.id!,
          'action': isDeducting ? 'deduct_stock' : 'add_stock',
          'details': '${isDeducting ? 'Deducted' : 'Added'} ${quantity} ${isSubUnit ? product['sub_unit_name'] ?? 'pieces' : 'units'} of ${product['product_name']}. New quantity: ${finalQuantity}',
          'timestamp': DateTime.now().toIso8601String(),
          'username': currentUser.username,
        });
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

  Future<void> updateCreditorBalanceAndStatus(
    int id,
    double newBalance,
    String details,
    String status,
  ) async {
    final db = await database;
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
  }

  Future<void> addCreditor(Map<String, dynamic> creditor) async {
    final db = await database;
    await db.insert(tableCreditors, creditor);
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
    final db = await database;
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
  }

  Future<void> addDebtor(Map<String, dynamic> debtor) async {
    await withTransaction((txn) async {
      await txn.insert(tableDebtors, debtor);
    });
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
      print('Checking for admin user...');
      final db = await database;
      
      // Check if admin user exists
      final adminUser = await getUserByUsername('admin');
      
      if (adminUser == null) {
        print('Admin user not found, creating...');
        // Create admin user with proper credentials
        final adminData = {
          'username': 'admin',
          'password': AuthService.instance.hashPassword('admin123'),
          'full_name': 'System Administrator',
          'email': 'admin@example.com',
          'role': ROLE_ADMIN,
          'created_at': DateTime.now().toIso8601String(),
          'permissions': PERMISSION_FULL_ACCESS,
        };
        
        await db.transaction((txn) async {
          try {
            await txn.insert(
              tableUsers,
              adminData,
              conflictAlgorithm: ConflictAlgorithm.ignore,
            );
            print('Admin user created successfully');
          } catch (e) {
            print('Error creating admin user in transaction: $e');
            rethrow;
          }
        });
      } else {
        print('Admin user already exists');
        // Ensure admin user has correct role and permissions
        if (adminUser['role'] != ROLE_ADMIN || adminUser['permissions'] != PERMISSION_FULL_ACCESS) {
          print('Updating admin user permissions...');
          await db.update(
            tableUsers,
            {
              'role': ROLE_ADMIN,
              'permissions': PERMISSION_FULL_ACCESS,
              'updated_at': DateTime.now().toIso8601String(),
            },
            where: 'username = ?',
            whereArgs: ['admin'],
          );
          print('Admin user permissions updated');
        }
      }
    } catch (e, stackTrace) {
      print('Error checking/creating admin user: $e');
      print('Stack trace: $stackTrace');
      throw Exception('Failed to check/create admin user: $e');
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

  Future<void> resetDatabase() async {
    try {
      final databasePath = await getDatabasesPath();
      final path = join(databasePath, 'malbrose_db.db');
      
      // Delete the database
      await deleteDatabase(path);
      
      // Reinitialize the database
      _database = null;
      await database;
      
      // Create admin user after reset
      await checkAndCreateAdminUser();
    } catch (e) {
      print('Error resetting database: $e');
      rethrow;
    }
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

  // Update the completeSale method to log properly
  Future<void> completeSale(Order order) async {
    final db = await database;
    await db.transaction((txn) async {
      // Update order status
      await txn.update(
        tableOrders,
        {
          'status': 'COMPLETED',
          'payment_status': 'PAID'
        },
        where: 'order_number = ?',
        whereArgs: [order.orderNumber],
      );

      // Update product quantities
      for (var item in order.items ?? []) {
        await txn.rawUpdate('''
          UPDATE $tableProducts 
          SET quantity = quantity - ?
          WHERE id = ?
        ''', [item.quantity, item.productId]);
      }
    });
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
    String? status,
    DatabaseExecutor? executor,
  }) async {
    final db = executor ?? await database;
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
      
      return await db.rawQuery(query, args);
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

  Future<List<Map<String, dynamic>>> getCustomerInvoiceData({
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
    return await withTransaction((txn) async {
      return await txn.query('customers');
    });
  }

  Future<List<Map<String, dynamic>>> getAllInvoices() async {
    final db = await database;
    return await db.query('invoices', orderBy: 'created_at DESC');
  }

  // Simplified invoice creation with proper transaction handling
  Future<Invoice> createInvoiceWithItems(Invoice invoice, {Transaction? txn}) async {
    return await withTransaction((transaction) async {
      final db = txn ?? transaction;
      
      try {
        // Insert invoice
        final invoiceId = await db.insert(tableInvoices, invoice.toMap());
        
        // Insert completed items
        if (invoice.completedItems != null) {
          for (var item in invoice.completedItems!) {
            await db.insert(tableInvoiceItems, {
              'invoice_id': invoiceId,
              'order_id': item.orderId,
              'product_id': item.productId,
              'quantity': item.quantity,
              'unit_price': item.unitPrice,
              'selling_price': item.sellingPrice,
              'total_amount': item.totalAmount,
              'is_sub_unit': item.isSubUnit ? 1 : 0,
              'sub_unit_name': item.subUnitName,
              'status': 'COMPLETED'
            });
          }
        }

        // Insert pending items
        if (invoice.pendingItems != null) {
          for (var item in invoice.pendingItems!) {
            await db.insert(tableInvoiceItems, {
              'invoice_id': invoiceId,
              'order_id': item.orderId,
              'product_id': item.productId,
              'quantity': item.quantity,
              'unit_price': item.unitPrice,
              'selling_price': item.sellingPrice,
              'total_amount': item.totalAmount,
              'is_sub_unit': item.isSubUnit ? 1 : 0,
              'sub_unit_name': item.subUnitName,
              'status': 'PENDING'
            });
          }
        }

        return invoice.copyWith(id: invoiceId);
      } catch (e) {
        print('Error creating invoice: $e');
        rethrow;
      }
    });
  }

  // Simplified method to get orders by customer
  Future<List<Map<String, dynamic>>> getOrdersByCustomerId(
    int customerId, {
    String? status,
    DateTime? startDate,
    DateTime? endDate,
    DatabaseExecutor? executor,
  }) async {
    final db = executor ?? await database;

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
      AND o.status IN ('PENDING', 'COMPLETED')
      ${status != null ? 'AND o.status = ?' : ''}
      ${startDate != null ? 'AND date(o.created_at) >= date(?)' : ''}
      ${endDate != null ? 'AND date(o.created_at) <= date(?)' : ''}
      ORDER BY o.created_at DESC
    ''';

    final args = [
      customerId,
      if (status != null) status,
      if (startDate != null) startDate.toIso8601String(),
      if (endDate != null) endDate.toIso8601String(),
    ];

    return await db.rawQuery(query, args);
  }

  // Simple method to get invoices with basic filtering
  Future<List<Map<String, dynamic>>> getInvoices({
    DateTime? startDate,
    DateTime? endDate,
    String? searchQuery,
    DatabaseExecutor? executor,
  }) async {
    final db = executor ?? await database;
    
    String whereClause = '1=1';
    List<dynamic> whereArgs = [];
    
    if (startDate != null) {
      whereClause += ' AND date(created_at) >= date(?)';
      whereArgs.add(startDate.toIso8601String());
    }
    
    if (endDate != null) {
      whereClause += ' AND date(created_at) <= date(?)';
      whereArgs.add(endDate.toIso8601String());
    }
    
    if (searchQuery != null && searchQuery.isNotEmpty) {
      whereClause += ' AND (invoice_number LIKE ? OR customer_name LIKE ?)';
      whereArgs.addAll(['%$searchQuery%', '%$searchQuery%']);
    }
    
    return await db.query(
      tableInvoices,
      where: whereClause,
      whereArgs: whereArgs,
      orderBy: 'created_at DESC',
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
        COALESCE(oi.adjusted_price, 
          CASE 
            WHEN oi.is_sub_unit = 1 AND p.sub_unit_quantity > 0
            THEN oi.selling_price / p.sub_unit_quantity
            ELSE oi.selling_price
          END
        ) as effective_price,
        oi.total_amount,
        oi.is_sub_unit,
        oi.sub_unit_name,
        p.sub_unit_quantity,
        p.buying_price as base_buying_price
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
        SUM(
          CASE 
            WHEN oi.is_sub_unit = 1 AND p.sub_unit_price IS NOT NULL
            THEN p.sub_unit_price * oi.quantity
            ELSE oi.selling_price * oi.quantity
          END
        ) as total_sales,
        SUM(
          CASE 
            WHEN oi.is_sub_unit = 1 AND p.sub_unit_quantity > 0
            THEN (p.buying_price / p.sub_unit_quantity) * oi.quantity
            ELSE p.buying_price * oi.quantity
          END
        ) as total_buying_cost,
        SUM(
          CASE 
            WHEN oi.is_sub_unit = 1 AND p.sub_unit_quantity > 0 AND p.sub_unit_price IS NOT NULL
            THEN (p.sub_unit_price - (p.buying_price / p.sub_unit_quantity)) * oi.quantity
            ELSE (oi.selling_price - p.buying_price) * oi.quantity
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
}
