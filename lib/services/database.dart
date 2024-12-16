import 'package:path/path.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:sqflite/sqflite.dart';
import 'package:my_flutter_app/models/order_model.dart';

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

    return await openDatabase(
      databasepath,
      version: 1,
      onCreate: (Database db, int version) async {
        // Products table
        await db.execute('''
          CREATE TABLE $tableProducts (
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
          CREATE TABLE $tableUsers (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT NOT NULL,
            email TEXT UNIQUE NOT NULL,
            password TEXT NOT NULL,
            role TEXT NOT NULL,
            phone TEXT,
            last_login DATETIME,
            is_active BOOLEAN DEFAULT true,
            created_at DATETIME DEFAULT CURRENT_TIMESTAMP
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

  Future<int> createUser(Map<String, dynamic> user) async {
    final db = await database;
    return await db.insert(tableUsers, user);
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
}
