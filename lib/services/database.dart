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

    // Delete existing database to start fresh
    try {
      await deleteDatabase(databasepath);
    } catch (e) {
      print('Error deleting database: $e');
    }

    return await openDatabase(
      databasepath,
      version: 1,
      onCreate: (Database db, int version) async {
        // Create users table first
        await db.execute('''
          CREATE TABLE IF NOT EXISTS users (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            username TEXT UNIQUE NOT NULL,
            password TEXT NOT NULL,
            full_name TEXT NOT NULL,
            email TEXT NOT NULL,
            is_admin INTEGER NOT NULL DEFAULT 0,
            created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
            last_login DATETIME
          )
        ''');

        // Create activity logs table
        await db.execute('''
          CREATE TABLE IF NOT EXISTS activity_logs (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            user_id INTEGER NOT NULL,
            action_type TEXT NOT NULL,
            details TEXT NOT NULL,
            timestamp DATETIME DEFAULT CURRENT_TIMESTAMP,
            FOREIGN KEY (user_id) REFERENCES users (id)
          )
        ''');

        // Create default admin
        final defaultAdmin = User(
          username: 'admin',
          password: AuthService.instance.hashPassword('Account@2024'),
          fullName: 'System Administrator',
          email: 'derricknjuguna414@gmail.com',
          isAdmin: true,
        );
        await db.insert('users', defaultAdmin.toMap());

        // Create other tables...
        // Products table
        await db.execute('''
          CREATE TABLE products (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            image TEXT NULL,
            supplier TEXT NOT NULL,
            received_date DATETIME NOT NULL,
            product_name TEXT NOT NULL,
            buying_price DECIMAL(10,2) NOT NULL,
            selling_price DECIMAL(10,2) NOT NULL,
            quantity INTEGER NOT NULL,
            description TEXT NULL,
            created_at DATETIME DEFAULT CURRENT_TIMESTAMP
          )
        ''');

        // Users table
        await db.execute('''
          CREATE TABLE IF NOT EXISTS $tableUsers (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            username TEXT UNIQUE NOT NULL,
            password TEXT NOT NULL,
            full_name TEXT NOT NULL,
            email TEXT UNIQUE NOT NULL,
            is_admin INTEGER NOT NULL DEFAULT 0,
            created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
            last_login DATETIME
          )
        ''');

        // Creditors table
        await db.execute('''
          CREATE TABLE $tableCreditors (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT NOT NULL,
            date_credited DATETIME NOT NULL,
            amount_credited DECIMAL(10,2) NOT NULL,
            amount_paid DECIMAL(10,2) DEFAULT 0,
            balance DECIMAL(10,2) NOT NULL,
            due_date DATETIME,
            status TEXT DEFAULT 'PENDING',
            notes TEXT,
            created_at DATETIME DEFAULT CURRENT_TIMESTAMP
          )
        ''');

        // Debtors table
        await db.execute('''
          CREATE TABLE $tableDebtors (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT NOT NULL,
            date_debited DATETIME NOT NULL,
            amount_debited DECIMAL(10,2) NOT NULL,
            amount_received DECIMAL(10,2) DEFAULT 0,
            balance DECIMAL(10,2) NOT NULL,
            due_date DATETIME,
            status TEXT DEFAULT 'PENDING',
            notes TEXT,
            created_at DATETIME DEFAULT CURRENT_TIMESTAMP
          )
        ''');

        // Orders table
        await db.execute('''
          CREATE TABLE $tableOrders (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            order_number TEXT UNIQUE NOT NULL,
            product_id INTEGER NOT NULL,
            quantity INTEGER NOT NULL,
            selling_price DECIMAL(10,2) NOT NULL,
            buying_price DECIMAL(10,2) NOT NULL,
            total_amount DECIMAL(10,2) NOT NULL,
            customer_name TEXT,
            payment_status TEXT DEFAULT 'PENDING',
            payment_method TEXT,
            order_status TEXT DEFAULT 'PENDING',
            created_by INTEGER NOT NULL,
            created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
            FOREIGN KEY (product_id) REFERENCES $tableProducts (id),
            FOREIGN KEY (created_by) REFERENCES $tableUsers (id)
          )
        ''');

        // Add to your existing database creation
        await db.execute('''
          CREATE TABLE IF NOT EXISTS user_activity_log (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            user_id INTEGER NOT NULL,
            action_type TEXT NOT NULL,
            action_details TEXT NOT NULL,
            created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
            FOREIGN KEY (user_id) REFERENCES $tableUsers (id)
          )
        ''');

        // Add to your existing database creation
        await db.execute('''
          CREATE TABLE IF NOT EXISTS activity_logs (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            user_id INTEGER NOT NULL,
            action_type TEXT NOT NULL,
            details TEXT NOT NULL,
            timestamp DATETIME DEFAULT CURRENT_TIMESTAMP,
            FOREIGN KEY (user_id) REFERENCES users (id)
          )
        ''');

        // Check if admin exists
        final List<Map<String, dynamic>> adminCheck = await db.query(
          'users',
          where: 'username = ?',
          whereArgs: ['admin'],
        );

        // Create default admin if not exists
        if (adminCheck.isEmpty) {
          final defaultAdmin = User(
            username: 'admin',
            password: AuthService.instance.hashPassword('Account@2024'),
            fullName: 'System Administrator',
            email: 'derricknjuguna414@gmail.com',
            isAdmin: true,
          );
          await db.insert('users', defaultAdmin.toMap());
        }
      },
    );
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
      tableOrders,
      where: 'order_status = ?',
      whereArgs: [status],
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

  Future<User?> createUser(User user) async {
    final db = await database;
    final id = await db.insert(tableUsers, user.toMap());
    return user.copyWith(id: id);
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
  Future<User?> getUserByUsername(String username) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      tableUsers,
      where: 'username = ?',
      whereArgs: [username],
    );
    if (maps.isNotEmpty) {
      return User.fromMap(maps.first);
    }
    return null;
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

  Future<List<User>> getAllUsers() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(tableUsers);
    return maps.map((map) => User.fromMap(map)).toList();
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
}
