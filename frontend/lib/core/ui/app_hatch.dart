import 'package:flutter/material.dart';

import '../theme/app_tokens.dart';

/// Static 45 degree stripes: "remaining / free / not yet", never a fact.
/// No animation, so tests using pumpAndSettle never hang.
class AppHatchPainter extends CustomPainter {
  const AppHatchPainter({this.color = AppColors.hatch, this.period = 6});

  final Color color;
  final double period;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.5;
    for (double x = -size.height; x < size.width; x += period) {
      canvas.drawLine(
          Offset(x, size.height), Offset(x + size.height, 0), paint);
    }
  }

  @override
  bool shouldRepaint(AppHatchPainter old) =>
      old.color != color || old.period != period;
}

class AppHatch extends StatelessWidget {
  const AppHatch({super.key, this.child});

  final Widget? child;

  @override
  Widget build(BuildContext context) => CustomPaint(
        painter: const AppHatchPainter(),
        child: child,
      );
}
