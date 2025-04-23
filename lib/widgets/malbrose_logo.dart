import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

class MalbroseLogo extends StatelessWidget {
  final double size;
  final bool useSvg;

  const MalbroseLogo({
    super.key, 
    this.size = 120.0,
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
      // Fallback to PNG if needed
      return Image.asset(
        'assets/images/malbrose.png',
        width: size,
        height: size,
      );
    }
  }
} 