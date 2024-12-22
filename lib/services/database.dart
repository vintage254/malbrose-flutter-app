import 'package:path/path.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:sqflite/sqflite.dart';
import 'package:my_flutter_app/models/order_model.dart';
import 'package:my_flutter_app/models/user_model.dart';
import 'package:my_flutter_app/models/activity_log_model.dart';
import 'package:my_flutter_app/services/auth_service.dart';

class DatabaseService {
  static final DatabaseService instance = DatabaseService._constructor();
  static Database? _database;

  // Table Names
  static const String tableProducts = 'products';
  static const String tableUsers = 'users';
  static const String tableCreditors = 'creditors';
  static const String tableDebtors = 'debtors';
  static const String tableOrders = 'orders';

  DatabaseService._constructor() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  }

  Future<Database> get database async {
    _database ??= await getDatabase();
    return _database!;
  }

  Future<Database> getDatabase() async {
    final databaseDirpath = await getDatabasesPath();
    final databasepath = join(databaseDirpath, "malbrose_db.db");

    // Delete existing database to force recreation
    await deleteDatabase(databasepath);

    return await openDatabase(
      databasepath,
      version: 2,
      onCreate: (Database db, int version) async {
        // Create users table
        await db.execute('''
          CREATE TABLE users (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            username TEXT UNIQUE,
            password TEXT,
            full_name TEXT,
            email TEXT,
            role TEXT NOT NULL DEFAULT 'USER',
            created_at TEXT,
            last_login TEXT
          )
        ''');

        // Create products table
        await db.execute('''
          CREATE TABLE products (
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
            FOREIGN KEY (created_by) REFERENCES users (id),
            FOREIGN KEY (updated_by) REFERENCES users (id)
          )
        ''');

        // Create orders table
        await db.execute('''
          CREATE TABLE orders (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            order_number TEXT,
            product_id INTEGER,
            quantity INTEGER,
            selling_price REAL,
            buying_price REAL,
            total_amount REAL,
            customer_name TEXT,
            payment_status TEXT,
            order_status TEXT,
            created_by INTEGER,
            updated_by INTEGER,
            created_at TEXT,
            updated_at TEXT,
            order_date TEXT,
            FOREIGN KEY (product_id) REFERENCES products (id),
            FOREIGN KEY (created_by) REFERENCES users (id),
            FOREIGN KEY (updated_by) REFERENCES users (id)
          )
        ''');

        // Create activity logs table
        await db.execute('''
          CREATE TABLE IF NOT EXISTS activity_logs (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            user_id INTEGER NOT NULL,
            action TEXT NOT NULL,
            details TEXT NOT NULL,
            timestamp TEXT NOT NULL,
            FOREIGN KEY (user_id) REFERENCES users (id)
          )
        ''');

        // Create indexes for activity_logs table
        await db.execute('CREATE INDEX idx_user_id ON activity_logs (user_id)');
        await db.execute('CREATE INDEX idx_action ON activity_logs (action)');
        await db.execute('CREATE INDEX idx_timestamp ON activity_logs (timestamp)');

        // Create creditors table
        await db.execute('''
          CREATE TABLE $tableCreditors (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT UNIQUE,
            balance REAL,
            details TEXT,
            status TEXT,
            created_at TEXT,
            last_updated TEXT
          )
        ''');

        // Create debtors table
        await db.execute('''
          CREATE TABLE $tableDebtors (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT UNIQUE,
            balance REAL,
            details TEXT,
            status TEXT,
            created_at TEXT,
            last_updated TEXT
          )
        ''');

        // Create default admin user
        final defaultAdmin = {
          'username': 'admin',
          'password': AuthService.instance.hashPassword('Account@2024'),
          'full_name': 'System Administrator',
          'email': 'admin@malbrose.com',
          'role': 'ADMIN',
          'created_at': DateTime.now().toIso8601String(),
        };
        
        await db.insert('users', defaultAdmin);
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await _updateOrdersTable(db);
        }
      },
    );
  }

  // Product Operations
  Future<int> insertProduct(Map<String, dynamic> product) async {
    final db = await database;
    // Ensure created_by is set
    if (product['created_by'] == null) {
      product['created_by'] = AuthService.instance.currentUser?.id;
    }
    return await db.insert(tableProducts, product);
  }

  Future<List<Map<String, dynamic>>> getAllProducts({
    String sortColumn = 'product_name',
    bool sortAscending = true,
  }) async {
    final db = await database;
    return await db.query(
      tableProducts,
      orderBy: '$sortColumn ${sortAscending ? 'ASC' : 'DESC'}',
    );
  }

  Future<Map<String, dynamic>?> getProductById(int id) async {
    final db = await database;
    final List<Map<String, dynamic>> results = await db.query(
      tableProducts,
      where: 'id = ?',
      whereArgs: [id],
    );
    return results.isNotEmpty ? results.first : null;
  }

  Future<bool> updateProductQuantity(int productId, int quantity, {bool subtract = false}) async {
    final db = await database;
    
    // First get the current quantity
    final result = await db.query(
      tableProducts,
      columns: ['quantity'],
      where: 'id = ?',
      whereArgs: [productId],
    );
    
    if (result.isEmpty) {
      throw Exception('Product not found');
    }
    
    final currentQuantity = result.first['quantity'] as int;
    final newQuantity = subtract ? currentQuantity - quantity : currentQuantity + quantity;
    
    if (newQuantity < 0) {
      throw Exception('Insufficient stock');
    }
    
    await db.update(
      tableProducts,
      {'quantity': newQuantity},
      where: 'id = ?',
      whereArgs: [productId],
    );
    return true;
  }

  // Order Operations
  Future<int> createOrder(Order order) async {
    final db = await database;
    return await db.transaction((txn) async {
      // Get current product quantity
      final product = await txn.query(
        tableProducts,
        columns: ['quantity'],
        where: 'id = ?',
        whereArgs: [order.productId],
      );

      if (product.isEmpty) {
        throw Exception('Product not found');
      }

      final currentQuantity = product.first['quantity'] as int;
      
      if (currentQuantity < order.quantity) {
        throw Exception('Insufficient stock');
      }

      // Insert the order
      final orderId = await txn.insert(tableOrders, order.toMap());

      return orderId;
    });
  }

  Future<List<Map<String, dynamic>>> getOrdersByStatus(String status) async {
    final db = await database;
    try {
      final List<Map<String, dynamic>> orders = await db.query(
        'orders',
        where: 'order_status = ?',
        whereArgs: [status],
        orderBy: 'created_at DESC',
      );

      // Ensure all numeric fields are properly converted to double
      return orders.map((order) => {
        ...order,
        'selling_price': (order['selling_price'] ?? 0).toDouble(),
        'buying_price': (order['buying_price'] ?? 0).toDouble(),
        'total_amount': (order['total_amount'] ?? 0).toDouble(),
        'quantity': order['quantity'] ?? 0,
        'payment_status': order['payment_status'] ?? 'PENDING',
        'order_status': order['order_status'] ?? 'PENDING',
      }).toList();
    } catch (e) {
      print('Error getting orders by status: $e');
      return [];
    }
  }

  Future<void> updateOrderStatus(String orderNumber, String status) async {
    final db = await database;
    final currentUser = AuthService.instance.currentUser;
    if (currentUser == null) throw Exception('No user logged in');

    await db.transaction((txn) async {
      // Update the order status
      await txn.update(
        tableOrders,
        {
          'order_status': status,
          'updated_by': currentUser.id,
          'updated_at': DateTime.now().toIso8601String(),
        },
        where: 'order_number = ?',
        whereArgs: [orderNumber],
      );

      // Log the activity
      await txn.insert(
        'activity_logs',
        {
          'user_id': currentUser.id,
          'action': 'update_order_status',
          'details': 'Updated order #$orderNumber status to $status',
          'timestamp': DateTime.now().toIso8601String(),
        },
      );
    });
  }

  // User Operations
  Future<Map<String, dynamic>?> getUserByEmail(String email) async {
    final db = await database;
    final results = await db.query(
      tableUsers,
      where: 'email = ?',
      whereArgs: [email],
    );
    return results.isNotEmpty ? results.first : null;
  }

  Future<User?> createUser(Map<String, dynamic> userData) async {
    try {
      final db = await database;
      
      // Check if username already exists
      final existingUser = await getUserByUsername(userData['username']);
      if (existingUser != null) {
        throw Exception('Username already exists');
      }

      // Ensure required fields
      final userToCreate = {
        'username': userData['username'],
        'password': AuthService.instance.hashPassword(userData['password']),
        'full_name': userData['full_name'],
        'email': userData['email'],
        'role': userData['role'] ?? 'USER',
        'created_at': DateTime.now().toIso8601String(),
      };

      final id = await db.insert(tableUsers, userToCreate);
      if (id != 0) {
        print('User created with ID: $id'); // Debug print
        return User.fromMap({...userToCreate, 'id': id});
      }
      return null;
    } catch (e) {
      print('Error creating user: $e'); // Debug print
      rethrow;
    }
  }

  // Creditor/Debtor Operations
  Future<List<Map<String, dynamic>>> getCreditors() async {
    final db = await database;
    return await db.query(tableCreditors);
  }

  Future<List<Map<String, dynamic>>> getDebtors() async {
    final db = await database;
    return await db.query(tableDebtors);
  }

  Future<bool> updateCreditorBalanceAndStatus(
    int id,
    double newBalance,
    String details,
    String status,
  ) async {
    final db = await database;
    final count = await db.update(
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
    return count > 0;
  }

  Future<bool> updateDebtorBalanceAndStatus(
    int id,
    double newBalance,
    String details,
    String status,
  ) async {
    final db = await database;
    final count = await db.update(
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
    return count > 0;
  }

  // Helper method to close database
  Future<void> close() async {
    final db = await database;
    db.close();
  }

  // Add this method to your DatabaseService class
  Future<bool> deleteProduct(int id) async {
    final db = await database;
    final count = await db.delete(
      tableProducts,
      where: 'id = ?',
      whereArgs: [id],
    );
    return count > 0;
  }

  Future<int> updateProduct(Map<String, dynamic> product) async {
    final db = await database;
    // Ensure updated_by is set
    if (product['updated_by'] == null) {
      product['updated_by'] = AuthService.instance.currentUser?.id;
    }
    return await db.update(
      tableProducts,
      product,
      where: 'id = ?',
      whereArgs: [product['id']],
    );
  }

  // User operations
  Future<Map<String, dynamic>?> getUserByUsername(String username) async {
    final db = await database;
    final results = await db.query(
      tableUsers,
      where: 'username = ?',
      whereArgs: [username],
    );
    return results.isNotEmpty ? results.first : null;
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

  Future<List<Map<String, dynamic>>> getAllUsers() async {
    final db = await database;
    return await db.query(tableUsers);
  }

  Future<void> logUserActivity(int userId, String actionType, String details) async {
    final db = await database;
    await db.insert('user_activity_log', {
      'user_id': userId,
      'action_type': actionType,
      'action_details': details,
    });
  }

  Future<void> deleteUser(int userId) async {
    final db = await database;
    await db.delete(
      tableUsers,
      where: 'id = ?',
      whereArgs: [userId],
    );
  }

  Future<void> logActivity(Map<String, dynamic> activity) async {
    final db = await database;
    await db.insert('activity_logs', activity);
  }

  Future<List<Map<String, dynamic>>> getActivityLogs({
    String? userFilter,
    String? actionFilter,
    String? dateFilter,
    String? groupBy,
  }) async {
    final db = await database;
    
    String query = '''
      SELECT al.*, u.username 
      FROM activity_logs al
      LEFT JOIN users u ON al.user_id = u.id
      WHERE 1=1
    ''';
    
    List<dynamic> args = [];
    
    if (userFilter != null) {
      query += ' AND u.username LIKE ?';
      args.add('%$userFilter%');
    }
    
    if (actionFilter != null) {
      query += ' AND al.action = ?';
      args.add(actionFilter);
    }
    
    if (dateFilter != null) {
      query += ' AND DATE(al.timestamp) = ?';
      args.add(dateFilter);
    }
    
    query += ' ORDER BY al.timestamp DESC';
    
    return await db.rawQuery(query, args);
  }

  Future<void> _initializeDatabase() async {
    final db = await database;

    // Check if admin user exists
    final adminCheck = await db.query(
      'users',
      where: 'username = ?',
      whereArgs: ['admin'],
    );

    // Create admin user if it doesn't exist
    if (adminCheck.isEmpty) {
      final adminUser = User(
        username: 'admin',
        password: AuthService.instance.hashPassword('Account@2024'),
        fullName: 'System Administrator',
        email: 'admin@malbrose.com',
        role: 'ADMIN',
        createdAt: DateTime.now(),
      );

      await db.insert('users', adminUser.toMap());
    }
  }

  Future<List<Map<String, dynamic>>> getRecentOrders() async {
    final db = await database;
    try {
      final List<Map<String, dynamic>> orders = await db.query(
        tableOrders,
      orderBy: 'created_at DESC',
        groupBy: 'order_number',
      limit: 5,
      );

      // Ensure all numeric fields are properly converted
      return orders.map((order) => {
        ...order,
        'id': order['id'],
        'order_number': order['order_number'],
        'product_id': order['product_id'],
        'customer_name': order['customer_name'],
        'order_date': order['order_date'],
        'created_at': order['created_at'],
        'created_by': order['created_by'],
        'order_status': order['order_status'] ?? 'PENDING',
        'payment_status': order['payment_status'] ?? 'PENDING',
        'selling_price': (order['selling_price'] ?? 0).toDouble(),
        'buying_price': (order['buying_price'] ?? 0).toDouble(),
        'total_amount': (order['total_amount'] ?? 0).toDouble(),
        'quantity': order['quantity'] ?? 0,
      }).toList();
    } catch (e) {
      print('Error getting recent orders: $e');
      return [];
    }
  }

  // Add this method to the DatabaseService class
  Future<Map<String, dynamic>?> getUserById(int userId) async {
    final db = await database;
    final results = await db.query(
      tableUsers,
      where: 'id = ?',
      whereArgs: [userId],
    );
    return results.isNotEmpty ? results.first : null;
  }

  Future<List<Map<String, dynamic>>> getOrdersByDateRange(
    DateTime startDate,
    DateTime endDate,
  ) async {
    final db = await database;
    return db.query(
      tableOrders,
      where: 'order_date BETWEEN ? AND ?',
      whereArgs: [
        startDate.toIso8601String(),
        endDate.toIso8601String(),
      ],
      orderBy: 'order_date DESC',
    );
  }

  // Add these methods to DatabaseService class
  Future<int> addCreditor(Map<String, dynamic> creditor) async {
    final db = await database;
    final id = await db.insert(tableCreditors, creditor);
    
    // Log creditor creation
    await logActivity({
      'user_id': AuthService.instance.currentUser!.id!,
      'action': 'create_creditor',
      'details': 'Added creditor: ${creditor['name']}, balance: ${creditor['balance']}',
      'timestamp': DateTime.now().toIso8601String(),
    });
    
    return id;
  }

  Future<int> addDebtor(Map<String, dynamic> debtor) async {
    final db = await database;
    final id = await db.insert(tableDebtors, debtor);
    
    // Log debtor creation
    await logActivity({
      'user_id': AuthService.instance.currentUser!.id!,
      'action': 'create_debtor',
      'details': 'Added debtor: ${debtor['name']}, balance: ${debtor['balance']}',
      'timestamp': DateTime.now().toIso8601String(),
    });
    
    return id;
  }

  Future<List<Map<String, dynamic>>> getCreditorsByStatus(String status) async {
    final db = await database;
    return await db.query(
      tableCreditors,
      where: 'status = ?',
      whereArgs: [status],
      orderBy: 'created_at DESC',
    );
  }

  Future<List<Map<String, dynamic>>> getDebtorsByStatus(String status) async {
    final db = await database;
    return await db.query(
      tableDebtors,
      where: 'status = ?',
      whereArgs: [status],
      orderBy: 'created_at DESC',
    );
  }

  Future<bool> checkCreditorExists(String name) async {
    final db = await database;
    final result = await db.query(
      tableCreditors,
      where: 'name = ?',
      whereArgs: [name],
    );
    return result.isNotEmpty;
  }

  Future<bool> checkDebtorExists(String name) async {
    final db = await database;
    final result = await db.query(
      tableDebtors,
      where: 'name = ?',
      whereArgs: [name],
    );
    return result.isNotEmpty;
  }

  Future<void> checkAndCreateAdminUser() async {
    final db = await database;
    final adminUser = await getUserByUsername('admin');
    
    if (adminUser == null) {
      print('Creating default admin user'); // Debug print
      final defaultAdmin = {
        'username': 'admin',
        'password': AuthService.instance.hashPassword('Account@2024'),
        'full_name': 'System Administrator',
        'email': 'admin@malbrose.com',
        'role': 'ADMIN',
        'created_at': DateTime.now().toIso8601String(),
      };
      
      await db.insert(tableUsers, defaultAdmin);
      print('Admin user created with role: ${defaultAdmin['role']}'); // Debug print
    } else {
      print('Existing admin user found with role: ${adminUser['role']}'); // Debug print
    }
  }

  Future<void> resetDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'malbrose_db.db');
    
    // Delete existing database
    await deleteDatabase(path);
    
    // Reinitialize database
    await database;
    
    // Recreate admin user
    await checkAndCreateAdminUser();
  }

  // Add these methods to DatabaseService class

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

  Future<Map<String, dynamic>> getDailyStats() async {
    final db = await database;
    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day);
    final endOfDay = startOfDay.add(const Duration(days: 1));

    try {
      // Get total orders for today
      final totalOrdersResult = await db.rawQuery('''
        SELECT COUNT(DISTINCT order_number) as total_orders
        FROM orders
        WHERE created_at BETWEEN ? AND ?
      ''', [startOfDay.toIso8601String(), endOfDay.toIso8601String()]);

      // Get total sales for completed orders today
      final totalSalesResult = await db.rawQuery('''
        SELECT SUM(total_amount) as total_sales
        FROM orders
        WHERE order_status = 'COMPLETED'
        AND created_at BETWEEN ? AND ?
      ''', [startOfDay.toIso8601String(), endOfDay.toIso8601String()]);

      // Get pending orders count
      final pendingOrdersResult = await db.rawQuery('''
        SELECT COUNT(DISTINCT order_number) as pending_orders
        FROM orders
        WHERE order_status = 'PENDING'
      ''');

      return {
        'total_orders': totalOrdersResult.first['total_orders'] ?? 0,
        'total_sales': totalSalesResult.first['total_sales'] ?? 0,
        'pending_orders': pendingOrdersResult.first['pending_orders'] ?? 0,
      };
    } catch (e) {
      print('Error getting daily stats: $e');
      return {
        'total_orders': 0,
        'total_sales': 0.0,
        'pending_orders': 0,
      };
    }
  }

  Future<void> _createTables(Database db) async {
    // Update the products table creation to include the new columns
    await db.execute('''
      CREATE TABLE IF NOT EXISTS products (
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
        updated_by INTEGER
      )
    ''');
    // ... rest of your table creation code ...
  }

  Future<void> _updateOrdersTable(Database db) async {
    // Create a new table with the updated schema
    await db.execute('''
      CREATE TABLE new_orders (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        order_number TEXT,
        product_id INTEGER,
        quantity INTEGER,
        selling_price REAL,
        buying_price REAL,
        total_amount REAL,
        customer_name TEXT,
        payment_status TEXT,
        order_status TEXT,
        created_by INTEGER,
        updated_by INTEGER,
        created_at TEXT,
        updated_at TEXT,
        order_date TEXT,
        FOREIGN KEY (product_id) REFERENCES products (id),
        FOREIGN KEY (created_by) REFERENCES users (id),
        FOREIGN KEY (updated_by) REFERENCES users (id)
      )
    ''');

    // Copy existing data
    await db.execute('''
      INSERT INTO new_orders 
      SELECT 
        id, order_number, product_id, quantity, selling_price, 
        buying_price, total_amount, customer_name, payment_status, 
        order_status, created_by, created_at, NULL, order_date, NULL 
      FROM orders
    ''');

    await db.execute('DROP TABLE orders');
    await db.execute('ALTER TABLE new_orders RENAME TO orders');
  }
}
