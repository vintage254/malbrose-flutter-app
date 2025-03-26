import 'dart:io';
import 'package:flutter/material.dart';

/// A utility to clean the database
/// Currently disabled to avoid accidental deletion
void main() async {
  // Ensure Flutter is initialized
  WidgetsFlutterBinding.ensureInitialized();
  
  print('Database cleaning function is currently disabled for safety.');
  print('Please modify this file to enable database cleaning if needed.');
  
  /*
  // Clean the database
  print('Preparing to clean the database...');
  final db = DatabaseService.instance;
  
  try {
    int count = await db.deleteAllProducts();
    print('Successfully deleted $count products from the database.');
  } catch (e) {
    print('Error deleting products: $e');
  }
  */
  
  // Exit the app
  exit(0);
} 