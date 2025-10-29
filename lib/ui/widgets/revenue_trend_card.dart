import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/revenue_provider.dart';

/// A responsive revenue trend card that displays a line chart of recent revenue
/// (positive net -> purple line, negative segments drawn in light purple) and an optional decorative image.
/// It auto-scales to its parent constraints.
class RevenueTrendCard extends StatelessWidget {
  final int months; // number of months including current
  final ImageProvider? overlayImage; // optional faded decorative image
  final EdgeInsetsGeometry padding;
  final double minHeight;
  final Color lineColor; // main purple line
  final Color faintLineColor; // faint background line
  final Color gainColor; // positive percentage color (green)
  final Color lossColor; // negative percentage color (red)

  const RevenueTrendCard({
    super.key,
    this.months = 6,
    this.overlayImage,
    this.padding = const EdgeInsets.fromLTRB(14, 14, 14, 12),
    this.minHeight = 120,
    this.lineColor = const Color(0xFF8B27E2),
    this.faintLineColor = const Color(0xFFD9B6FF),
    this.gainColor = const Color(0xFF07B348),
    this.lossColor = const Color(0xFFE53935),
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      elevation: 1.5,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: LayoutBuilder(
        builder: (context, c) {
          final provider = context.watch<RevenueProvider>();
          // Compute today's (or current) total revenue and format compactly (k for thousands, L for lakhs)
          final todayTotal = provider.total;
          String _shortNumber(double v) {
            if (v.abs() >= 100000) {
              final val = (v / 100000).toStringAsFixed(v % 100000 == 0 ? 0 : 1);
              return '${val}L';
            }
            if (v.abs() >= 1000) {
              final val = (v / 1000).toStringAsFixed(v % 1000 == 0 ? 0 : 1);
              return '${val}k';
            }
            return v.toStringAsFixed(0);
          }
          final displayTotal = (todayTotal == 0) ? '00' : _shortNumber(todayTotal);
          // Compute effective height from parent constraints (SizedBox in dashboard sets this).
          final effectiveH = c.hasBoundedHeight && c.maxHeight.isFinite ? c.maxHeight : minHeight;
          // Match PatientOverviewCard visuals: circle/avatar uses height * 0.62 and
          // numeric font caps at 120 * 0.18 for consistent sizing across tiles.
          final circleSize = effectiveH * 0.62;
          final numberFontSize = (effectiveH.clamp(0.0, 120.0)) * 0.18;
          return ConstrainedBox(
            constraints: BoxConstraints(minHeight: minHeight, minWidth: c.maxWidth),
            child: Padding(
              padding: padding,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Left circular icon
                  Container(
                    width: circleSize,
                    height: circleSize,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      boxShadow: [BoxShadow(color: Colors.black.withOpacity(.08), blurRadius: 8, offset: const Offset(0,2))],
                    ),
                    child: overlayImage != null
                        ? ClipOval(child: Image(image: overlayImage!, fit: BoxFit.cover))
                        : Container(
                            decoration: BoxDecoration(shape: BoxShape.circle, color: lineColor.withOpacity(.08)),
                            child: Icon(Icons.show_chart, color: lineColor, size: minHeight * 0.28),
                          ),
                  ),
                  const SizedBox(width: 22),
                  // Right text and value
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('Revenue', style: TextStyle(fontWeight: FontWeight.w700, fontSize: effectiveH * 0.10, color: Colors.black87)),
                        const SizedBox(height: 8),
                        Text(displayTotal, style: TextStyle(color: Colors.black87, fontWeight: FontWeight.w800, fontSize: numberFontSize)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // No helper functions required for compact revenue card
}
