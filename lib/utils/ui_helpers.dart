import 'package:flutter/material.dart';

/// Helper class for UI operations that prevents common errors
class UIHelpers {
  /// Global key for the main scaffold messenger
  static final GlobalKey<ScaffoldMessengerState> scaffoldMessengerKey = 
      GlobalKey<ScaffoldMessengerState>();
      
  /// Shows a snackbar safely without context
  static void showSnackBar(String message, {bool isError = false}) {
    final messengerState = scaffoldMessengerKey.currentState;
    if (messengerState != null) {
      messengerState.showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: isError ? Colors.red : Colors.green,
        ),
      );
    } else {
      print('Could not show snackbar: $message');
    }
  }
  
  /// Shows a snackbar with context safety check
  static void showSnackBarWithContext(BuildContext context, String message, {bool isError = false}) {
    if (!context.mounted) {
      // Fall back to the global method if context is not mounted
      showSnackBar(message, isError: isError);
      return;
    }
    
    try {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: isError ? Colors.red : Colors.green,
        ),
      );
    } catch (e) {
      print('Error showing snackbar with context: $e');
      // Fall back to the global method
      showSnackBar(message, isError: isError);
    }
  }
} 