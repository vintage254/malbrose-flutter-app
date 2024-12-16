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
        color: Colors.amber,
        borderRadius: BorderRadius.circular(size / 4),
      ),
      child: Center(
        child: Icon(
          Icons.shopping_cart,
          size: size * 0.6,
          color: Colors.orange.shade900,
        ),
      ),
    );
  }
} 