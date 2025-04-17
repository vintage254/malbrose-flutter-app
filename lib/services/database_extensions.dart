import 'package:my_flutter_app/services/database.dart';
import 'package:my_flutter_app/services/auth_service.dart';
import 'package:excel/excel.dart';
import 'dart:io';

/// This extension file adds extra methods to the DatabaseService class
/// without modifying the main database.dart file directly

extension DatabaseServiceExtensions on DatabaseService {
  
  /// Get an order by its order number
  Future<Map<String, dynamic>?> getOrderByNumber(String orderNumber) async {
    try {
      final db = await database;
      final results = await db.query(
        DatabaseService.tableOrders,
        where: 'order_number = ?',
        whereArgs: [orderNumber],
        limit: 1,
      );
      
      if (results.isNotEmpty) {
        return results.first;
      }
      return null;
    } catch (e) {
      print('Error getting order by number: $e');
      return null;
    }
  }
  
  /// Update an existing order with new data and items
  Future<bool> updateOrder(int orderId, Map<String, dynamic> orderMap, List<Map<String, dynamic>> orderItems) async {
    final db = await database;
    
    return await db.transaction((txn) async {
      try {
        // First, check if the order exists
        final orderCheck = await txn.query(
          DatabaseService.tableOrders,
          where: 'id = ?',
          whereArgs: [orderId],
          limit: 1,
        );
        
        if (orderCheck.isEmpty) {
          print('Order with ID $orderId not found for update');
          return false;
        }
        
        // Remove id from orderMap if it exists to avoid SQL error
        if (orderMap.containsKey('id')) {
          orderMap.remove('id');
        }
        
        // Add updated_at field
        orderMap['updated_at'] = DateTime.now().toIso8601String();
        
        // Update the order
        await txn.update(
          DatabaseService.tableOrders,
          orderMap,
          where: 'id = ?',
          whereArgs: [orderId],
        );
        
        // Delete existing order items
        await txn.delete(
          DatabaseService.tableOrderItems,
          where: 'order_id = ?',
          whereArgs: [orderId],
        );
        
        // Insert new order items
        for (var item in orderItems) {
          item['order_id'] = orderId;
          await txn.insert(DatabaseService.tableOrderItems, item);
        }
        
        // Log the update action
        final currentUser = AuthService.instance.currentUser;
        if (currentUser != null) {
          await txn.insert(
            DatabaseService.tableActivityLogs,
            {
              'user_id': currentUser.id,
              'username': currentUser.username,
              'action': DatabaseService.actionUpdateOrder,
              'details': 'Updated order #${orderMap['order_number']}',
              'timestamp': DateTime.now().toIso8601String(),
            },
          );
        }
        
        return true;
      } catch (e) {
        print('Error updating order: $e');
        return false;
      }
    });
  }
  
  /// Get order items for a specified order ID
  Future<List<Map<String, dynamic>>?> getOrderItems(int orderId) async {
    try {
      final db = await database;
      return await db.query(
        DatabaseService.tableOrderItems,
        where: 'order_id = ?',
        whereArgs: [orderId],
      );
    } catch (e) {
      print('Error getting order items: $e');
      return null;
    }
  }

  // Helper method to count rows in Excel file
  Future<Map<String, dynamic>> _countExcelRows(String filePath) async {
    try {
      // Use the excel library to count rows in the file
      final bytes = await File(filePath).readAsBytes();
      final excel = Excel.decodeBytes(bytes);
      
      if (excel.tables.isEmpty) {
        return {'totalRows': 0};
      }
      
      final sheet = excel.tables.entries.first.value;
      // Subtract 1 for header row
      return {'totalRows': sheet.rows.length - 1};
    } catch (e) {
      print('Error counting Excel rows: $e');
      return {'totalRows': 0};
    }
  }
}
