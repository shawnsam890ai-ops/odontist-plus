import 'package:fl_chart/fl_chart.dart';
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
          final now = DateTime.now();
          final from = DateTime(now.year, now.month - (months - 1), 1);
          final filtered = provider.entries
              .where((e) => !e.date.isBefore(from))
              .toList()
            ..sort((a, b) => a.date.compareTo(b.date));

          // Initialize month buckets (ensures missing months show as 0).
            final Map<String, double> monthTotals = {};
            for (int i = months - 1; i >= 0; i--) {
              final d = DateTime(now.year, now.month - i, 1);
              monthTotals[_key(d)] = 0;
            }
            for (final e in filtered) {
              final k = _key(DateTime(e.date.year, e.date.month, 1));
              if (monthTotals.containsKey(k)) {
                monthTotals[k] = monthTotals[k]! + e.amount;
              }
            }
            final orderedKeys = monthTotals.keys.toList();
            final spots = <FlSpot>[];
            for (int i = 0; i < orderedKeys.length; i++) {
              spots.add(FlSpot(i.toDouble(), monthTotals[orderedKeys[i]]!));
            }

          // Build chart
          Widget chart;
          if (spots.length < 2) {
            chart = const Center(child: Text('Not enough data', style: TextStyle(fontSize: 11)));
          } else {
            final faintSpots = spots.map((s) => FlSpot(s.x, s.y * 0.99)).toList();
            chart = LineChart(
              LineChartData(
                minX: 0,
                maxX: (spots.length - 1).toDouble(),
                gridData: const FlGridData(show: false),
                borderData: FlBorderData(show: false),
                titlesData: FlTitlesData(
                  leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 20,
                      getTitlesWidget: (value, meta) {
                        final idx = value.toInt();
                        if (idx < 0 || idx >= orderedKeys.length) return const SizedBox.shrink();
                        final ym = orderedKeys[idx];
                        final month = int.parse(ym.split('-')[1]);
                        return Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Text(
                            _monthAbbrev(month),
                            style: const TextStyle(fontSize: 10, color: Colors.black54),
                          ),
                        );
                      },
                    ),
                  ),
                ),
                lineTouchData: LineTouchData(
                  touchTooltipData: LineTouchTooltipData(
                    tooltipRoundedRadius: 8,
                    tooltipPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    getTooltipColor: (_) => Colors.black87,
                    getTooltipItems: (touched) => touched.map((s) {
                      final idx = s.x.toInt();
                      final ym = orderedKeys[idx];
                      final month = int.parse(ym.split('-')[1]);
                      return LineTooltipItem(
                        '${_monthAbbrev(month)}: ${s.y.toStringAsFixed(0)}',
                        const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600),
                      );
                    }).toList(),
                  ),
                ),
                lineBarsData: [
                  _primaryLine(faintSpots, faintLineColor, 2, opacity: .35),
                  _primaryLine(spots, lineColor, 3.2),
                ],
              ),
            );
          }

          // Percentage change (latest vs previous month)
          double? pct;
          if (spots.length >= 2) {
            final last = spots.last.y;
            final prev = spots[spots.length - 2].y;
            if (prev != 0) pct = ((last - prev) / prev) * 100.0;
          }
      final pctColor = pct == null || pct == 0
        ? Colors.grey
        : (pct > 0 ? gainColor : lossColor);
      final arrow = pct == null || pct == 0
        ? Icons.horizontal_rule
        : (pct > 0 ? Icons.arrow_upward : Icons.arrow_downward);

          return ConstrainedBox(
            constraints: BoxConstraints(minHeight: minHeight, minWidth: c.maxWidth),
            child: Padding(
              padding: padding,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Text('Revenue', style: TextStyle(fontWeight: FontWeight.w600)),
                      const Spacer(),
                      if (pct != null)
                        Row(
                          children: [
                            Icon(arrow, size: 14, color: pctColor),
                            const SizedBox(width: 2),
                            Text(
                              '${pct.abs().toStringAsFixed(1)}%',
                              style: TextStyle(color: pctColor, fontSize: 12, fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Expanded(child: chart),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  static String _key(DateTime d) => '${d.year}-${d.month.toString().padLeft(2,'0')}';
  static String _monthAbbrev(int m) => const ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'][m-1];

  LineChartBarData _primaryLine(List<FlSpot> spots, Color color, double width, {double opacity = 1}) => LineChartBarData(
        spots: spots,
        isCurved: true,
        barWidth: width,
        color: color.withOpacity(opacity),
        dotData: const FlDotData(show: false),
      );
}
