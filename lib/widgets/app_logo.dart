import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

class AppLogo extends StatelessWidget {
  final double size;
  final bool useSvg;

  const AppLogo({
    super.key,
    this.size = 100,
    this.useSvg = true,
  });

  @override
  Widget build(BuildContext context) {
    if (useSvg) {
      return SvgPicture.asset(
        'assets/images/malbrose.svg',
        width: size,
        height: size,
      );
    } else {
      // Fallback to PNG with container for backward compatibility
      return Container(
        height: size,
        width: size,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(size / 4),
          image: const DecorationImage(
            image: AssetImage('assets/images/malbrose.png'),
            fit: BoxFit.cover,
          ),
        ),
      );
    }
  }
} 