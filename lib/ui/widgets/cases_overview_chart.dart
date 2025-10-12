import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';

/// Compact radar (spider) chart for Cases Overview.
/// Expects 4 categories (Root Canal, Orthodontic, Prosthodontic, Filling) but
/// will render any provided map in radial order.
class CasesOverviewChart extends StatefulWidget {
  final Map<String, int> data;
  final Color strokeColor;
  final Color fillColor;
  final double size;
  final Duration animationDuration;
  final bool showTitle;
  const CasesOverviewChart({super.key, required this.data, this.strokeColor = const Color(0xFF1D4ED8), this.fillColor = const Color(0xFF1D4ED8), this.size = 200, this.animationDuration = const Duration(milliseconds: 700), this.showTitle = false});

  @override
  State<CasesOverviewChart> createState() => _CasesOverviewChartState();
}

class _CasesOverviewChartState extends State<CasesOverviewChart> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  List<double> _prevValues = [];
  List<double> _targetValues = [];
  List<String> _categories = [];
  double _maxValue = 1;
  // For tooltip interaction
  Offset? _hoverPosition; // local position
  int? _hoverIndex;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: widget.animationDuration)..addListener(() => setState(() {}));
    _syncData(initial: true);
  }

  @override
  void didUpdateWidget(covariant CasesOverviewChart oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_mapEquals(widget.data, oldWidget.data)) {
      _syncData();
    }
  }

  bool _mapEquals(Map<String,int> a, Map<String,int> b) {
    if (a.length != b.length) return false;
    for (final k in a.keys) { if (!b.containsKey(k) || b[k] != a[k]) return false; }
    return true;
  }

  void _syncData({bool initial = false}) {
    _categories = widget.data.keys.toList();
    final newVals = _categories.map((c) => (widget.data[c] ?? 0).toDouble()).toList();
    _maxValue = newVals.fold<double>(1, (p, e) => e > p ? e : p).clamp(1, double.infinity);
    if (initial || _prevValues.isEmpty) {
      _prevValues = List<double>.from(newVals);
      _targetValues = List<double>.from(newVals);
      _controller.value = 1;
    } else {
      _prevValues = List<double>.from(_currentValues());
      _targetValues = List<double>.from(newVals);
      _controller.forward(from: 0);
    }
  }

  List<double> _currentValues() {
    final t = Curves.easeInOut.transform(_controller.value);
    return List.generate(_targetValues.length, (i) {
      final a = i < _prevValues.length ? _prevValues[i] : 0.0;
      final b = _targetValues[i];
      return a + (b - a) * t;
    });
  }

  void _handleHover(PointerHoverEvent e) {
    setState(() {
      _hoverPosition = e.localPosition;
      _hoverIndex = _nearestPointIndex(e.localPosition);
    });
  }
  void _handleExit(PointerExitEvent e) {
    setState(() { _hoverPosition = null; _hoverIndex = null; });
  }
  void _handleTapDown(TapDownDetails d) {
    setState(() {
      _hoverPosition = d.localPosition;
      _hoverIndex = _nearestPointIndex(d.localPosition, tap: true);
    });
  }

  int? _nearestPointIndex(Offset pos, {bool tap = false}) {
    if (_categories.isEmpty) return null;
    final size = widget.size;
    final chartRadius = (math.min(size, size)/2) - 28; // must mirror painter radius padding
    final center = Offset(size/2, size/2);
    final currentVals = _currentValues();
    final pts = <Offset>[];
    for (int i=0;i<_categories.length;i++) {
      final angle = -math.pi/2 + i * 2*math.pi/_categories.length;
      final factor = (currentVals[i] / _maxValue).clamp(0.0, 1.0);
      final p = center + Offset(math.cos(angle), math.sin(angle))*chartRadius*factor;
      pts.add(p);
    }
    double bestDist = 24; // threshold
    int? bestIndex;
    for (int i=0;i<pts.length;i++) {
      final d = (pts[i] - pos).distance;
      if (d < bestDist) { bestDist = d; bestIndex = i; }
    }
    return bestIndex;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.data.isEmpty) {
      return SizedBox(height: widget.size, child: const Center(child: Text('No data')));
    }
    final animatedValues = _currentValues();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (widget.showTitle)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              'Cases Overview',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
          ),
        // Chart (fixed-size box so it works in scroll/unbounded contexts)
        Center(
          child: SizedBox(
            height: widget.size,
            width: widget.size,
            child: MouseRegion(
              onHover: _handleHover,
              onExit: _handleExit,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTapDown: _handleTapDown,
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: CustomPaint(
                        painter: _RadarPainter(
                          categories: _categories,
                          values: animatedValues,
                          maxValue: _maxValue,
                          stroke: widget.strokeColor,
                          fill: widget.fillColor.withOpacity(.15),
                          gridColor: Colors.grey.withOpacity(.25),
                          showTicks: true,
                        ),
                      ),
                    ),
                    // Category labels
                    Positioned.fill(
                      child: LayoutBuilder(builder: (context, box){
                        final radius = (math.min(box.maxWidth, box.maxHeight)/2) - 22;
                        final center = Offset(box.maxWidth/2, box.maxHeight/2);
                        final n = _categories.length;
                        return Stack(children: [
                          for (int i=0;i<n;i++) ...(){
                            final angle = -math.pi/2 + i * 2*math.pi / n;
                            final pos = center + Offset(math.cos(angle), math.sin(angle)) * (radius + 8);
                            return [
                              Positioned(
                                left: pos.dx - 40,
                                top: pos.dy - 9,
                                width: 80,
                                child: Center(
                                  child: Text(
                                    _categories[i],
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w500),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              )
                            ];
                          }(),
                        ]);
                      }),
                    ),
                    if (_hoverIndex != null && _hoverIndex! < _categories.length && _hoverPosition != null)
                      Positioned(
                        left: (_hoverPosition!.dx + 12).clamp(0, widget.size - 110),
                        top: (_hoverPosition!.dy - 36).clamp(0, widget.size - 44),
                        width: 110,
                        child: AnimatedOpacity(
                          opacity: 1,
                          duration: const Duration(milliseconds: 150),
                          child: _PointTooltip(
                            label: _categories[_hoverIndex!],
                            value: _targetValues[_hoverIndex!].toInt(),
                            animatedValue: animatedValues[_hoverIndex!],
                            color: widget.strokeColor,
                          ),
                        ),
                      )
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _RadarPainter extends CustomPainter {
  final List<String> categories;
  final List<double> values;
  final double maxValue;
  final Color stroke;
  final Color fill;
  final Color gridColor;
  final bool showTicks;
  _RadarPainter({required this.categories, required this.values, required this.maxValue, required this.stroke, required this.fill, required this.gridColor, this.showTicks = false});

  @override
  void paint(Canvas canvas, Size size) {
    final n = categories.length;
    if (n == 0) return;
    final center = Offset(size.width/2, size.height/2);
    final radius = math.min(size.width, size.height)/2 - 28; // padding for labels
    final gridPaint = Paint()..color = gridColor..style = PaintingStyle.stroke..strokeWidth = 1;
    const rings = 4;
    for (int r=1;r<=rings;r++) {
      final l = radius * r / rings;
      final path = Path();
      for (int i=0;i<n;i++) {
        final angle = -math.pi/2 + i * 2*math.pi/n;
        final p = center + Offset(math.cos(angle), math.sin(angle))*l;
        if (i==0) {
          path.moveTo(p.dx, p.dy);
        } else {
          path.lineTo(p.dx, p.dy);
        }
      }
      path.close();
      canvas.drawPath(path, gridPaint);
    }
    // Axes
    final axisPaint = Paint()..color = gridColor..strokeWidth = 1;
    for (int i=0;i<n;i++) {
      final angle = -math.pi/2 + i * 2*math.pi/n;
      final p = center + Offset(math.cos(angle), math.sin(angle))*radius;
      canvas.drawLine(center, p, axisPaint);
    }
    if (showTicks) {
      _drawTicks(canvas, center, radius);
    }
    // Data polygon
    final poly = Path();
    for (int i=0;i<n;i++) {
      final angle = -math.pi/2 + i * 2*math.pi/n;
      final factor = (values[i] / maxValue).clamp(0.0, 1.0);
      final p = center + Offset(math.cos(angle), math.sin(angle))*radius*factor;
      if (i==0) {
        poly.moveTo(p.dx, p.dy);
      } else {
        poly.lineTo(p.dx, p.dy);
      }
    }
    poly.close();
    final fillPaint = Paint()..color = fill..style = PaintingStyle.fill;
    final strokePaint = Paint()..color = stroke..style = PaintingStyle.stroke..strokeWidth = 2;
    canvas.drawPath(poly, fillPaint);
    canvas.drawPath(poly, strokePaint);
    // Points
    final pointPaint = Paint()..color = stroke..style = PaintingStyle.fill;
    for (int i=0;i<n;i++) {
      final angle = -math.pi/2 + i * 2*math.pi/n;
      final factor = (values[i] / maxValue).clamp(0.0, 1.0);
      final p = center + Offset(math.cos(angle), math.sin(angle))*radius*factor;
      canvas.drawCircle(p, 3.2, pointPaint);
    }
  }

  void _drawTicks(Canvas canvas, Offset center, double radius) {
    // Choose up to 5 tick levels including max.
    final textStyle = const TextStyle(fontSize: 8, color: Colors.black54, fontWeight: FontWeight.w500);
    final tpList = <TextPainter>[];
    int desired = 4; // excluding max label to avoid overlap at edge
    // Derive a reasonable step using 1,2,5 * 10^n progression.
    double rawStep = maxValue / (desired + 1);
    double magnitude = math.pow(10, rawStep.floor().toString().length - 1).toDouble();
    double normalized = rawStep / magnitude;
    double step;
    if (normalized <= 1) step = 1 * magnitude; else if (normalized <= 2) step = 2 * magnitude; else if (normalized <= 5) step = 5 * magnitude; else step = 10 * magnitude;
    for (double v = step; v < maxValue; v += step) {
      final ratio = (v / maxValue).clamp(0.0, 1.0);
      final pos = center + Offset(0, -radius * ratio); // place along vertical axis upwards
      final tp = TextPainter(text: TextSpan(text: v.toStringAsFixed(v % 1 == 0 ? 0 : 1), style: textStyle), textDirection: TextDirection.ltr)..layout();
      tp.paint(canvas, pos - Offset(tp.width/2, tp.height/2));
      tpList.add(tp);
      if (tpList.length > 5) break;
    }
    // Max label slightly outside
    final maxTp = TextPainter(text: TextSpan(text: maxValue.toStringAsFixed(maxValue % 1 == 0 ? 0 : 1), style: textStyle.copyWith(fontWeight: FontWeight.bold)), textDirection: TextDirection.ltr)..layout();
    maxTp.paint(canvas, center - Offset(maxTp.width/2, radius + maxTp.height + 2));
  }

  @override
  bool shouldRepaint(covariant _RadarPainter old) =>
    old.values != values || old.categories != categories || old.maxValue != maxValue || old.stroke != stroke || old.fill != fill || old.gridColor != gridColor || old.showTicks != showTicks;
}

class _PointTooltip extends StatelessWidget {
  final String label;
  final int value;
  final double animatedValue;
  final Color color;
  const _PointTooltip({required this.label, required this.value, required this.animatedValue, required this.color});
  @override
  Widget build(BuildContext context) {
    return Material(
      elevation: 4,
      borderRadius: BorderRadius.circular(8),
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        child: DefaultTextStyle(
          style: const TextStyle(fontSize: 11, color: Colors.black87),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(children: [
                Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
                const SizedBox(width: 6),
                Flexible(fit: FlexFit.loose, child: Text(label, style: const TextStyle(fontWeight: FontWeight.w600)))
              ]),
              const SizedBox(height: 2),
              Text('Value: $value'),
              Text('Animated: ${animatedValue.toStringAsFixed(1)}'),
            ],
          ),
        ),
      ),
    );
  }
}
