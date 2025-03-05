import 'package:flutter/material.dart';

class AppLogo extends StatelessWidget {
  final double size;

  const AppLogo({
    super.key,
    this.size = 100,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: size,
      width: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(size / 4),
        color: Colors.orange.shade100,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(size / 4),
        child: Image.asset(
          'assets/images/logo.png',
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            debugPrint('Error loading logo: $error');
            debugPrint('Stack trace: $stackTrace');
            return Icon(
              Icons.store,
              size: size * 0.6,
              color: Colors.orange.shade900,
            );
          },
        ),
      ),
    );
  }
} 