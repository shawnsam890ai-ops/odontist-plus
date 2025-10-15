import 'package:flutter/material.dart';

/// A small tile that visually represents morning/evening attendance using left/right colors.
class HalfDayTile extends StatelessWidget {
  final bool? morning;
  final bool? evening;
  final double size;
  final double? width;
  final double? height;
  final double radius;
  final Color presentColor;
  final Color absentColor;
  final Color noneColor;

  const HalfDayTile({super.key, this.morning, this.evening, this.size = 30, this.width, this.height, this.radius = 8, this.presentColor = const Color(0xFF8B27E2), this.absentColor = const Color(0xFFD9B6FF), this.noneColor = Colors.grey});

  @override
  Widget build(BuildContext context) {
    final w = width ?? size;
    final h = height ?? size;
    return CustomPaint(
      size: Size(w, h),
      painter: _HalfDayPainter(morning: morning, evening: evening, radius: radius, presentColor: presentColor, absentColor: absentColor, noneColor: noneColor),
    );
  }
}

class _HalfDayPainter extends CustomPainter {
  final bool? morning;
  final bool? evening;
  final double radius;
  final Color presentColor;
  final Color absentColor;
  final Color noneColor;

  _HalfDayPainter({required this.morning, required this.evening, this.radius = 8, required this.presentColor, required this.absentColor, required this.noneColor});

  @override
  void paint(Canvas canvas, Size size) {
    final r = RRect.fromRectAndRadius(Offset.zero & size, Radius.circular(radius));
    final paint = Paint();

    if (morning == true && evening == true) {
      paint.color = presentColor;
      canvas.drawRRect(r, paint);
      return;
    }
    if (morning == false && evening == false) {
      paint.color = absentColor;
      canvas.drawRRect(r, paint);
      return;
    }

    final leftRect = Rect.fromLTWH(0, 0, size.width / 2, size.height);
    final rightRect = Rect.fromLTWH(size.width / 2, 0, size.width / 2, size.height);

    paint.color = morning == true ? presentColor : (morning == false ? absentColor : noneColor);
    canvas.drawRRect(RRect.fromRectAndCorners(leftRect, topLeft: Radius.circular(radius), bottomLeft: Radius.circular(radius)), paint);

    paint.color = evening == true ? presentColor : (evening == false ? absentColor : noneColor);
    canvas.drawRRect(RRect.fromRectAndCorners(rightRect, topRight: Radius.circular(radius), bottomRight: Radius.circular(radius)), paint);
  }

  @override
  bool shouldRepaint(covariant _HalfDayPainter oldDelegate) {
    return oldDelegate.morning != morning || oldDelegate.evening != evening || oldDelegate.presentColor != presentColor || oldDelegate.absentColor != absentColor;
  }
}
