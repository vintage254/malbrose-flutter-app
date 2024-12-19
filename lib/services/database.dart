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

    final db = await openDatabase(
      databasepath,
      version: 1,
      onCreate: (Database db, int version) async {
        // Create users table
        await db.execute('''
          CREATE TABLE users (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            username TEXT UNIQUE,
            password TEXT,
            full_name TEXT,
            email TEXT,
            is_admin INTEGER,
            created_at TEXT,
            last_login TEXT
          )
        ''');

        // Create products table
        await db.execute('''
          CREATE TABLE products (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            image TEXT,
            supplier TEXT,
            received_date TEXT,
            product_name TEXT,
            buying_price REAL,
            selling_price REAL,
            quantity INTEGER,
            description TEXT,
            created_at TEXT
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
            payment_method TEXT,
            order_status TEXT,
            created_by INTEGER,
            created_at TEXT,
            order_date TEXT,
            FOREIGN KEY (product_id) REFERENCES products (id),
            FOREIGN KEY (created_by) REFERENCES users (id)
          )
        ''');

        // Create activity logs table
        await db.execute('''
          CREATE TABLE activity_logs (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            user_id INTEGER,
            action_type TEXT,
            details TEXT,
            timestamp TEXT,
            FOREIGN KEY (user_id) REFERENCES users (id)
          )
        ''');

        // Create default admin user
        final defaultAdmin = {
          'username': 'admin',
          'password': AuthService.instance.hashPassword('Account@2024'),
          'full_name': 'System Administrator',
          'email': 'admin@malbrose.com',
          'is_admin': 1,
          'created_at': DateTime.now().toIso8601String(),
        };
        
        await db.insert('users', defaultAdmin);
      },
    );

    return db;
  }

  // Product Operations
  Future<int> insertProduct(Map<String, dynamic> product) async {
    final db = await database;
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

  Future<bool> updateProductQuantity(int productId, int newQuantity) async {
    final db = await database;
    int count = await db.update(
      tableProducts,
      {'quantity': newQuantity},
      where: 'id = ?',
      whereArgs: [productId],
    );
    return count > 0;
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
    return await db.query(
      'orders',
      where: 'order_status = ?',
      whereArgs: [status],
      orderBy: 'created_at DESC',
    );
  }

  Future<bool> updateOrderStatus(int orderId, String status) async {
    final db = await database;
    int count = await db.update(
      tableOrders,
      {'order_status': status},
      where: 'id = ?',
      whereArgs: [orderId],
    );
    return count > 0;
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
    final db = await database;
    final id = await db.insert(tableUsers, userData);
    if (id != 0) {
      return User.fromMap({...userData, 'id': id});
    }
    return null;
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

  Future<bool> updateCreditorBalance(int creditorId, double newBalance) async {
    final db = await database;
    int count = await db.update(
      tableCreditors,
      {'balance': newBalance},
      where: 'id = ?',
      whereArgs: [creditorId],
    );
    return count > 0;
  }

  Future<bool> updateDebtorBalance(int debtorId, double newBalance) async {
    final db = await database;
    int count = await db.update(
      tableDebtors,
      {'balance': newBalance},
      where: 'id = ?',
      whereArgs: [debtorId],
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

  Future<bool> updateProduct(Map<String, dynamic> product) async {
    final db = await database;
    final count = await db.update(
      tableProducts,
      product,
      where: 'id = ?',
      whereArgs: [product['id']],
    );
    return count > 0;
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

  Future<void> logActivity(ActivityLog log) async {
    final db = await database;
    await db.insert('activity_logs', log.toMap());
  }

  Future<List<ActivityLog>> getActivityLogs({
    String? userFilter,
    String? actionFilter,
  }) async {
    final db = await database;
    
    String query = '''
      SELECT al.*, u.username 
      FROM activity_logs al
      LEFT JOIN users u ON al.user_id = u.id
      WHERE 1=1
    ''';
    
    List<dynamic> args = [];
    
    if (userFilter != null && userFilter.isNotEmpty) {
      query += ' AND u.username LIKE ?';
      args.add('%$userFilter%');
    }
    
    if (actionFilter != null && actionFilter.isNotEmpty) {
      query += ' AND al.action_type LIKE ?';
      args.add('%$actionFilter%');
    }
    
    query += ' ORDER BY al.timestamp DESC';
    
    final List<Map<String, dynamic>> maps = await db.rawQuery(query, args);
    return maps.map((map) => ActivityLog.fromMap(map)).toList();
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
        isAdmin: true,
        createdAt: DateTime.now(),
      );

      await db.insert('users', adminUser.toMap());
    }
  }

  Future<List<Order>> getRecentOrders() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'orders',
      orderBy: 'created_at DESC',
      limit: 5,
      groupBy: 'customer_name, created_at',
    );
    
    return maps.map((map) => Order.fromMap(map)).toList();
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
}
