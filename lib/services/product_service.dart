import 'package:flutter/foundation.dart';
import 'package:my_flutter_app/services/database.dart';

class ProductService {
  // Singleton instance
  static final ProductService instance = ProductService._internal();
  
  // Private constructor
  ProductService._internal();
  
  // Helper method to update product quantity with proper timestamp
  Future<bool> updateProductQuantity(int productId, double newQuantity) async {
    try {
      final db = await DatabaseService.instance.database;
      
      // Use updated_at instead of last_updated to avoid the column error
      await db.rawUpdate(
        'UPDATE ${DatabaseService.tableProducts} SET quantity = ?, updated_at = ? WHERE id = ?',
        [newQuantity, DateTime.now().toIso8601String(), productId]
      );
      
      return true;
    } catch (e) {
      debugPrint('Error updating product quantity: $e');
      return false;
    }
  }
  
  // Helper method to adjust product quantity by an amount
  Future<bool> adjustProductQuantity(int productId, double adjustment) async {
    try {
      final db = await DatabaseService.instance.database;
      
      // Get current quantity
      final result = await db.query(
        DatabaseService.tableProducts,
        columns: ['quantity'],
        where: 'id = ?',
        whereArgs: [productId],
        limit: 1,
      );
      
      if (result.isEmpty) {
        throw Exception('Product not found');
      }
      
      final currentQuantity = (result.first['quantity'] as num?)?.toDouble() ?? 0;
      final newQuantity = currentQuantity + adjustment;
      
      // Use updated_at with explicit timestamp instead of CURRENT_TIMESTAMP
      await db.rawUpdate(
        'UPDATE ${DatabaseService.tableProducts} SET quantity = ?, updated_at = ? WHERE id = ?',
        [newQuantity, DateTime.now().toIso8601String(), productId]
      );
      
      return true;
    } catch (e) {
      debugPrint('Error adjusting product quantity: $e');
      return false;
    }
  }
  
  // Helper method to update multiple products during checkout
  Future<bool> updateProductQuantitiesForCheckout(List<Map<String, dynamic>> items) async {
    try {
      final db = await DatabaseService.instance.database;
      
      await db.transaction((txn) async {
        for (var item in items) {
          final productId = item['product_id'] as int;
          final quantity = item['quantity'] as double;
          final isSubUnit = item['is_sub_unit'] == 1;
          
          // Get current product details
          final productResult = await txn.query(
            DatabaseService.tableProducts,
            columns: ['quantity', 'sub_unit_quantity'],
            where: 'id = ?',
            whereArgs: [productId],
            limit: 1,
          );
          
          if (productResult.isEmpty) continue;
          
          final currentQuantity = (productResult.first['quantity'] as num?)?.toDouble() ?? 0;
          
          // Calculate quantity to deduct
          double quantityToDeduct = 0;
          if (isSubUnit) {
            final subUnitQuantity = (productResult.first['sub_unit_quantity'] as num?)?.toDouble() ?? 0;
            if (subUnitQuantity > 0) {
              quantityToDeduct = (quantity / subUnitQuantity);
            }
          } else {
            quantityToDeduct = quantity;
          }
          
          // Calculate new quantity
          final newQuantity = currentQuantity - quantityToDeduct;
          
          // Update with the correct column name
          await txn.rawUpdate(
            'UPDATE ${DatabaseService.tableProducts} SET quantity = ?, updated_at = ? WHERE id = ?',
            [newQuantity, DateTime.now().toIso8601String(), productId]
          );
        }
      });
      
      return true;
    } catch (e) {
      debugPrint('Error updating product quantities for checkout: $e');
      return false;
    }
  }
}
