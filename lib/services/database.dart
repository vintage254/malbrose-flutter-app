import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:my_flutter_app/models/order_model.dart';
import 'package:my_flutter_app/models/user_model.dart';
import 'package:my_flutter_app/services/auth_service.dart';
import 'package:flutter/foundation.dart';

class DatabaseService {
  static final DatabaseService instance = DatabaseService._init();
  static Database? _database;

  // Table Names
  static const String tableProducts = 'products';
  static const String tableUsers = 'users';
  static const String tableOrders = 'orders';
  static const String tableActivityLogs = 'activity_logs';
  static const String tableCreditors = 'creditors';
  static const String tableDebtors = 'debtors';
  static const String tableOrderItems = 'order_items';

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

  DatabaseService._init();

  Future<Database> get database async {
    _database ??= await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final databasePath = await getDatabasesPath();
    final path = join(databasePath, 'malbrose_db.db');

    return await openDatabase(
      path,
      version: 1,
      onCreate: _createTables,
    );
  }

  Future<void> _createTables(Database db, int version) async {
    // Create products table
    await db.execute('''
      CREATE TABLE $tableProducts (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        image TEXT,
        supplier TEXT NOT NULL,
        received_date TEXT NOT NULL,
        product_name TEXT NOT NULL,
        buying_price REAL NOT NULL,
        selling_price REAL NOT NULL,
        quantity INTEGER NOT NULL,
        description TEXT,
        created_by INTEGER,
        updated_by INTEGER,
        updated_at TEXT,
        FOREIGN KEY (created_by) REFERENCES users (id),
        FOREIGN KEY (updated_by) REFERENCES users (id)
      )
    ''');

    // Create users table
    await db.execute('''
      CREATE TABLE $tableUsers (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        username TEXT NOT NULL UNIQUE,
        password TEXT NOT NULL,
        full_name TEXT NOT NULL,
        email TEXT NOT NULL,
        role TEXT NOT NULL,
        created_at TEXT NOT NULL,
        last_login TEXT
      )
    ''');

    // Create orders table
    await db.execute('''
      CREATE TABLE $tableOrders (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        order_number TEXT NOT NULL UNIQUE,
        customer_name TEXT NOT NULL,
        total_amount REAL NOT NULL,
        order_status TEXT NOT NULL,
        payment_status TEXT NOT NULL,
        created_by INTEGER NOT NULL,
        created_at TEXT NOT NULL,
        FOREIGN KEY (created_by) REFERENCES users (id)
      )
    ''');

    // Create activity logs table
    await db.execute('''
      CREATE TABLE $tableActivityLogs (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        user_id INTEGER NOT NULL,
        username TEXT NOT NULL,
        action TEXT NOT NULL,
        details TEXT NOT NULL,
        timestamp TEXT NOT NULL,
        FOREIGN KEY (user_id) REFERENCES users (id)
      )
    ''');

    // Create creditors table
    await db.execute('''
      CREATE TABLE $tableCreditors (
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
      CREATE TABLE $tableDebtors (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL UNIQUE,
        balance REAL NOT NULL,
        details TEXT,
        status TEXT NOT NULL,
        created_at TEXT NOT NULL,
        last_updated TEXT
      )
    ''');
  }

  // User related methods
  Future<User?> createUser(Map<String, dynamic> userData) async {
    final db = await database;
    final id = await db.insert(tableUsers, userData);
    return id != 0 ? User.fromMap({...userData, 'id': id}) : null;
  }

  Future<void> updateUser(User user) async {
    final db = await database;
    await db.update(
      tableUsers,
      user.toMap(),
      where: 'id = ?',
      whereArgs: [user.id],
    );
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
    final user = await getUserById(activity['user_id'] as int);
    if (user != null) {
      final logEntry = {
        'user_id': user['id'],
        'username': user['username'],
        'action': activity['action'],
        'details': activity['details'],
        'timestamp': DateTime.now().toIso8601String(),
      };
      await db.insert(tableActivityLogs, logEntry);
    }
  }

  // Order related methods
  Future<int> addOrder(Order order) async {
    final db = await database;
    return await db.insert(tableOrders, order.toMap());
  }

  Future<void> updateOrder(Order order) async {
    final db = await database;
    await db.update(
      tableOrders,
      order.toMap(),
      where: 'id = ?',
      whereArgs: [order.id],
    );
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
    return await db.query(
      tableOrders,
      orderBy: 'created_at DESC',
      limit: 5,
    );
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
    final db = await database;
    final results = await db.query(
      tableProducts,
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    return results.isNotEmpty ? results.first : null;
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
      });
    }
  }

  Future<void> insertProduct(Map<String, dynamic> product) async {
    final db = await database;
    await db.insert(tableProducts, product);
  }

  Future<void> updateProductQuantity(
    int productId,
    int quantity,
    {bool subtract = false}
  ) async {
    final db = await database;
    await db.transaction((txn) async {
      final product = await txn.query(
        'products',
        where: 'id = ?',
        whereArgs: [productId],
        limit: 1,
      );

      if (product.isEmpty) throw Exception('Product not found');

      final currentQuantity = product.first['quantity'] as int;
      final newQuantity = subtract ? currentQuantity - quantity : currentQuantity + quantity;

      await txn.update(
        'products',
        {'quantity': newQuantity},
        where: 'id = ?',
        whereArgs: [productId],
      );
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
    String newStatus,
    String lastUpdated,
  ) async {
    final db = await database;
    await db.update(
      tableCreditors,
      {
        'balance': newBalance,
        'status': newStatus,
        'last_updated': lastUpdated,
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
    String newStatus,
    String lastUpdated,
  ) async {
    final db = await database;
    await db.update(
      tableDebtors,
      {
        'balance': newBalance,
        'status': newStatus,
        'last_updated': lastUpdated,
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> addDebtor(Map<String, dynamic> debtor) async {
    final db = await database;
    await db.insert(tableDebtors, debtor);
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
    final db = await database;
    final adminUser = await getUserByUsername('admin');
    
    if (adminUser == null) {
      await createUser({
        'username': 'admin',
        'password': AuthService.instance.hashPassword('Account@2024'),
        'full_name': 'System Administrator',
        'email': 'admin@example.com',
        'role': 'ADMIN',
        'created_at': DateTime.now().toIso8601String(),
      });
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
    return await db.rawQuery('''
      SELECT o.*, oi.product_id, oi.quantity, oi.selling_price, oi.total_amount
      FROM $tableOrders o
      LEFT JOIN order_items oi ON o.id = oi.order_id
      WHERE o.status = ?
      ORDER BY o.created_at DESC
    ''', [status]);
  }

  Future<int> createOrder(Order order) async {
    final db = await database;
    final currentUser = AuthService.instance.currentUser;
    
    int orderId = 0;
    await db.transaction((txn) async {
      // Create the order
      orderId = await txn.insert(tableOrders, order.toMap());
      
      // Insert order items
      if (order.items != null) {
        for (var item in order.items!) {
          await txn.insert(tableOrderItems, {
            'order_id': orderId,
            'product_id': item.productId,
            'quantity': item.quantity,
            'selling_price': item.sellingPrice,
            'total_amount': item.totalAmount,
          });
        }
      }

      // Log the activity
      if (currentUser != null) {
        final totalItems = order.items?.fold(0, (sum, item) => sum + item.quantity) ?? 0;
        await logActivity({
          'user_id': currentUser.id!,
          'action': 'create_order',
          'details': 'Created order #$orderId with $totalItems items. Total: KSH ${order.totalAmount.toStringAsFixed(2)}',
        });
      }
    });
    
    return orderId;
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
    final now = DateTime.now();
    
    // Get today's orders and sales
    final todayStats = await db.rawQuery('''
      SELECT 
        COUNT(DISTINCT o.id) as order_count,
        SUM(oi.quantity * oi.selling_price) as total_sales
      FROM orders o
      LEFT JOIN order_items oi ON o.id = oi.order_id
      WHERE DATE(o.created_at) = DATE(?)
    ''', [now.toIso8601String()]);

    // Get total orders and sales
    final totalStats = await db.rawQuery('''
      SELECT 
        COUNT(DISTINCT o.id) as order_count,
        SUM(oi.quantity * oi.selling_price) as total_sales
      FROM orders o
      LEFT JOIN order_items oi ON o.id = oi.order_id
    ''');

    return {
      'today_orders': todayStats.first['order_count'] ?? 0,
      'today_sales': todayStats.first['total_sales'] ?? 0.0,
      'total_orders': totalStats.first['order_count'] ?? 0,
      'total_sales': totalStats.first['total_sales'] ?? 0.0,
    };
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
}
