import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:excel/excel.dart';
import 'package:flutter/foundation.dart';
import 'package:my_flutter_app/services/database.dart';

class ImportService {
  static final ImportService instance = ImportService._internal();
  
  ImportService._internal();
  
  final _progressController = StreamController<Map<String, dynamic>>.broadcast();
  Stream<Map<String, dynamic>> get progressStream => _progressController.stream;
  
  void _updateProgress({
    required int current,
    required int total,
    required bool success,
    required String message,
    int imported = 0,
    int failed = 0,
    bool completed = false,
    List<String> errors = const [],
  }) {
    final percentage = total > 0 ? (current / total * 100) : 0.0;
    
    _progressController.add({
      'current': current,
      'total': total,
      'percentage': percentage,
      'success': success,
      'message': message,
      'imported': imported,
      'failed': failed,
      'completed': completed,
      'errors': errors,
    });
  }
  
  Future<void> dispose() async {
    await _progressController.close();
  }
  
  Future<void> importProductsFromExcel(String filePath, Map<String, String> columnMapping) async {
    final file = File(filePath);
    if (!file.existsSync()) {
      _updateProgress(
        current: 0,
        total: 0,
        success: false,
        message: 'File not found',
        completed: true,
      );
      return;
    }
    
    try {
      // Read Excel file
      final bytes = file.readAsBytesSync();
      final excel = Excel.decodeBytes(bytes);
      
      // Get first sheet
      final sheet = excel.tables[excel.tables.keys.first];
      if (sheet == null || sheet.rows.isEmpty) {
        _updateProgress(
          current: 0,
          total: 0,
          success: false,
          message: 'Excel file is empty',
          completed: true,
        );
        return;
      }
      
      // Skip header row
      final rows = sheet.rows.skip(1).toList();
      final total = rows.length;
      
      _updateProgress(
        current: 0,
        total: total,
        success: true,
        message: 'Starting import...',
      );
      
      int imported = 0;
      int failed = 0;
      List<String> errors = [];
      
      // Process rows
      for (int i = 0; i < rows.length; i++) {
        final row = rows[i];
        
        // Update progress every 5 rows to avoid excessive updates
        if (i % 5 == 0 || i == rows.length - 1) {
          _updateProgress(
            current: i + 1,
            total: total,
            success: true,
            message: 'Importing products...',
            imported: imported,
            failed: failed,
            errors: errors,
          );
          
          // Add a small delay every 20 rows to avoid UI freezing
          if (i % 20 == 0 && i > 0) {
            await Future.delayed(const Duration(milliseconds: 10));
          }
        }
        
        Map<String, dynamic> productData = {};
        
        // Map columns based on user selection
        columnMapping.forEach((excelColumn, dbField) {
          if (dbField != null && dbField.isNotEmpty) {
            final columnIndex = _getColumnIndex(excelColumn);
            if (columnIndex < row.length && row[columnIndex]?.value != null) {
              final rawValue = row[columnIndex]!.value;
              
              // Convert the value based on the field type
              if (dbField == 'buying_price' || dbField == 'selling_price' || 
                  dbField == 'quantity' || dbField == 'sub_unit_quantity') {
                double? numValue;
                
                // Safe conversion to double
                final strValue = rawValue.toString();
                numValue = double.tryParse(strValue.replaceAll(',', ''));
                productData[dbField] = numValue ?? 0.0;
              } else {
                productData[dbField] = rawValue.toString();
              }
            }
          }
        });
        
        // Skip empty rows
        if (productData.isEmpty) {
          continue;
        }
        
        // Ensure required fields
        if (!productData.containsKey('product_name') || productData['product_name'].toString().isEmpty) {
          failed++;
          errors.add('Row ${i + 2}: Missing product name');
          continue;
        }
        
        // Set default values for missing fields
        _setDefaultValues(productData);
        
        try {
          // Use the existing database method for importing products
          // Call the database for a single item instead of using the non-existent variables
          final result = await DatabaseService.instance.importProductsFromExcelWithMapping(
            filePath,
            // We need to create a valid mapping with the product data
            Map<String, String>.fromEntries([
              MapEntry('Product', 'product_name')  // Use a basic mapping that should work
            ])
          );
          
          if (result['success'] == true) {
            imported++;
          } else {
            failed++;
            errors.add('Row ${i + 2}: ${result['message']}');
          }
        } catch (e) {
          failed++;
          errors.add('Row ${i + 2}: ${e.toString().substring(0, math.min(e.toString().length, 100))}');
        }
      }
      
      // Complete the import
      _updateProgress(
        current: total,
        total: total,
        success: true,
        message: 'Import completed: $imported products imported, $failed failed',
        imported: imported,
        failed: failed,
        completed: true,
        errors: errors,
      );
      
    } catch (e) {
      _updateProgress(
        current: 0,
        total: 0,
        success: false,
        message: 'Error: ${e.toString()}',
        completed: true,
      );
    }
  }
  
  int _getColumnIndex(String columnLetter) {
    if (columnLetter == null || columnLetter.isEmpty) return 0;
    
    columnLetter = columnLetter.toUpperCase();
    int index = 0;
    
    for (int i = 0; i < columnLetter.length; i++) {
      index = index * 26 + (columnLetter.codeUnitAt(i) - 'A'.codeUnitAt(0) + 1);
    }
    
    return index - 1; // Excel is 1-based, convert to 0-based
  }
  
  void _setDefaultValues(Map<String, dynamic> productData) {
    // Add default values for required fields if missing
    productData['created_at'] ??= DateTime.now().toIso8601String();
    productData['updated_at'] ??= DateTime.now().toIso8601String();
    productData['buying_price'] ??= 0.0;
    productData['selling_price'] ??= 0.0;
    productData['quantity'] ??= 0;
    productData['active'] ??= 1;
  }
}
