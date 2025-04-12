import 'package:my_flutter_app/services/database.dart';
import 'package:my_flutter_app/services/auth_service.dart';

/// This extension file adds extra methods to the DatabaseService class
/// without modifying the main database.dart file directly

extension DatabaseServiceExtensions on DatabaseService {
  
  /// Get an order by its order number
  Future<Map<String, dynamic>?> getOrderByNumber(String orderNumber) async {
    try {
      final db = await database;
      final results = await db.query(
        tableOrders,
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
          tableOrders,
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
          tableOrders,
          orderMap,
          where: 'id = ?',
          whereArgs: [orderId],
        );
        
        // Delete existing order items
        await txn.delete(
          tableOrderItems,
          where: 'order_id = ?',
          whereArgs: [orderId],
        );
        
        // Insert new order items
        for (var item in orderItems) {
          item['order_id'] = orderId;
          await txn.insert(tableOrderItems, item);
        }
        
        // Log the update action
        final currentUser = AuthService.instance.currentUser;
        if (currentUser != null) {
          await txn.insert(
            tableActivityLogs,
            {
              'user_id': currentUser.id,
              'username': currentUser.username,
              'action': actionUpdateOrder,
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
        tableOrderItems,
        where: 'order_id = ?',
        whereArgs: [orderId],
      );
    } catch (e) {
      print('Error getting order items: $e');
      return null;
    }
  }

  /// Stream progress during import for showing a progress bar
  Stream<Map<String, dynamic>> importProductsFromExcelWithMapping(
    String filePath, 
    Map<String, String?> columnMapping, {
    bool onProgress = false
  }) async* {
    // Initialize progress values
    int totalRows = 0;
    int currentRow = 0;
    double percentage = 0.0;
    
    try {
      // First, get an estimate of the total rows
      final result = await _countExcelRows(filePath);
      totalRows = result['totalRows'] as int? ?? 0;
      
      // Yield initial progress
      yield {
        'current': 0,
        'total': totalRows,
        'percentage': 0.0,
        'message': 'Starting import...',
      };
      
      // Now perform the actual import with progress updates
      final importResult = await _importWithProgress(
        filePath, 
        columnMapping,
        (progress) {
          currentRow = progress['current'] as int? ?? 0;
          percentage = progress['percentage'] as double? ?? 0.0;
        }
      );
      
      // Yield the final result with complete flag
      yield {
        ...importResult,
        'current': totalRows,
        'total': totalRows,
        'percentage': 100.0,
        'completed': true,
        'message': 'Import complete!',
      };
    } catch (e) {
      yield {
        'success': false,
        'message': 'Error during import: $e',
        'current': currentRow,
        'total': totalRows,
        'percentage': percentage,
        'completed': true,
      };
    }
  }
  
  // Helper method to count rows in Excel file
  Future<Map<String, dynamic>> _countExcelRows(String filePath) async {
    try {
      // Use the existing importProductsFromExcel method but just count rows
      // This is a placeholder - in a real implementation, you would add the actual counting code
      return {'totalRows': 100};  // Example hardcoded value
    } catch (e) {
      print('Error counting Excel rows: $e');
      return {'totalRows': 0};
    }
  }
  
  // Helper method to perform import with progress updates
  Future<Map<String, dynamic>> _importWithProgress(
    String filePath,
    Map<String, String?> columnMapping,
    Function(Map<String, dynamic>) progressCallback
  ) async {
    // In a real implementation, you would modify your existing import code
    // to call progressCallback periodically during the import process
    
    // For now, we'll simulate progress with a simple delay
    await Future.delayed(const Duration(seconds: 2));
    
    // Call the existing import method
    return await importProductsFromExcelWithMapping(filePath, columnMapping);
  }
}
