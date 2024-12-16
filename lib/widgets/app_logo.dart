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
        image: const DecorationImage(
          image: AssetImage('assets/images/logo.png'),
          fit: BoxFit.cover,
        ),
      ),
    );
  }
} 