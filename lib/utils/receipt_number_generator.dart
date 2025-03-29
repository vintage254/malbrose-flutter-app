import 'dart:math';

/// A utility class for generating unique and traceable receipt numbers
/// for different types of transactions in the application.
class ReceiptNumberGenerator {
  /// Generates a unique order number with a prefix 'ORD'
  /// Format: ORD-YYYYMMDD-HHMMSSXX (where XX is a random number)
  /// 
  /// This is used when an order is first created in the system
  /// but not yet processed as a sale.
  static String generateOrderNumber() {
    final now = DateTime.now();
    final datePrefix = '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}';
    final timeComponent = '${now.hour.toString().padLeft(2, '0')}${now.minute.toString().padLeft(2, '0')}${now.second.toString().padLeft(2, '0')}';
    
    // Add a random 2-digit number to prevent collisions in case of
    // multiple orders created in the same second
    final randomComponent = Random().nextInt(100).toString().padLeft(2, '0');
    
    return 'ORD-$datePrefix-$timeComponent$randomComponent';
  }

  /// Generates a unique sales receipt number with a prefix 'SLS'
  /// Format: SLS-YYYYMMDD-HHMMSSXX (where XX is a random number)
  /// 
  /// This is used when an order is processed as a completed sale
  /// and a receipt is generated.
  static String generateSalesReceiptNumber() {
    final now = DateTime.now();
    final datePrefix = '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}';
    final timeComponent = '${now.hour.toString().padLeft(2, '0')}${now.minute.toString().padLeft(2, '0')}${now.second.toString().padLeft(2, '0')}';
    
    // Add a random 2-digit number to prevent collisions in case of
    // multiple sales receipts created in the same second
    final randomComponent = Random().nextInt(100).toString().padLeft(2, '0');
    
    return 'SLS-$datePrefix-$timeComponent$randomComponent';
  }

  /// Generates a unique held receipt number with a prefix 'HLD'
  /// Format: HLD-YYYYMMDD-HHMMSSXX (where XX is a random number)
  /// 
  /// This is used for orders that are on hold/pending and not yet completed.
  static String generateHeldReceiptNumber() {
    final now = DateTime.now();
    final datePrefix = '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}';
    final timeComponent = '${now.hour.toString().padLeft(2, '0')}${now.minute.toString().padLeft(2, '0')}${now.second.toString().padLeft(2, '0')}';
    
    // Add a random 2-digit number to prevent collisions
    final randomComponent = Random().nextInt(100).toString().padLeft(2, '0');
    
    return 'HLD-$datePrefix-$timeComponent$randomComponent';
  }

  /// Generates a unique credit receipt number with a prefix 'CRD'
  /// Format: CRD-YYYYMMDD-HHMMSSXX (where XX is a random number)
  /// 
  /// This is used when an order is processed as a credit transaction.
  static String generateCreditReceiptNumber() {
    final now = DateTime.now();
    final datePrefix = '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}';
    final timeComponent = '${now.hour.toString().padLeft(2, '0')}${now.minute.toString().padLeft(2, '0')}${now.second.toString().padLeft(2, '0')}';
    
    // Add a random 2-digit number to prevent collisions
    final randomComponent = Random().nextInt(100).toString().padLeft(2, '0');
    
    return 'CRD-$datePrefix-$timeComponent$randomComponent';
  }

  /// Generates a unique payment receipt number with a prefix 'PMT'
  /// Format: PMT-YYYYMMDD-HHMMSSXX (where XX is a random number)
  /// 
  /// This is used when a payment is made against a credit balance.
  static String generatePaymentReceiptNumber() {
    final now = DateTime.now();
    final datePrefix = '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}';
    final timeComponent = '${now.hour.toString().padLeft(2, '0')}${now.minute.toString().padLeft(2, '0')}${now.second.toString().padLeft(2, '0')}';
    
    // Add a random 2-digit number to prevent collisions
    final randomComponent = Random().nextInt(100).toString().padLeft(2, '0');
    
    return 'PMT-$datePrefix-$timeComponent$randomComponent';
  }
}
