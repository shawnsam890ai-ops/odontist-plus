import 'package:flutter/material.dart';
import 'dart:ui' as ui;
import '../../models/patient.dart';

/// Lightweight model aggregating per-tooth history and a priority level
class ToothAggregate {
  final String tooth; // FDI
  final List<String> done;
  final List<String> plans;
  final List<String> findings;
  final DateTime? lastDate;
  final int priority; // 0 none, 1 low, 2 med, 3 high
  const ToothAggregate({
    required this.tooth,
    this.done = const [],
    this.plans = const [],
    this.findings = const [],
    this.lastDate,
    this.priority = 0,
  });
}

Map<String, ToothAggregate> buildToothAggregates(Patient p, {int daysLookback = 365}) {
  final since = DateTime.now().subtract(Duration(days: daysLookback));
  final Map<String, List<String>> done = {};
  final Map<String, List<String>> plans = {};
  final Map<String, List<String>> findings = {};
  final Map<String, DateTime> lastDate = {};

  void accDate(String tooth, DateTime d) {
    final prev = lastDate[tooth];
    if (prev == null || d.isAfter(prev)) lastDate[tooth] = d;
  }

  for (final s in p.sessions) {
    if (s.date.isBefore(since)) continue;
    for (final td in s.treatmentsDone) {
      final t = td.toothNumber;
      done.putIfAbsent(t, () => []).add(td.treatment);
      accDate(t, s.date);
    }
    for (final pl in s.toothPlans) {
      final t = pl.toothNumber;
      plans.putIfAbsent(t, () => []).add(pl.plan);
      accDate(t, s.date);
    }
    for (final f in s.oralExamFindings) {
      final t = f.toothNumber;
      if (t.isEmpty) continue;
      findings.putIfAbsent(t, () => []).add(f.finding);
      accDate(t, s.date);
    }
    for (final f in s.rootCanalFindings) {
      final t = f.toothNumber;
      if (t.isEmpty) continue;
      findings.putIfAbsent(t, () => []).add(f.finding);
      accDate(t, s.date);
    }
    for (final f in s.prosthodonticFindings) {
      final t = f.toothNumber;
      if (t.isEmpty) continue;
      findings.putIfAbsent(t, () => []).add(f.finding);
      accDate(t, s.date);
    }
  }

  int priorityFor(List<String> plans, List<String> findings) {
    final txt = (plans + findings).map((e) => e.toLowerCase()).join(' | ');
    if (txt.contains('acute') || txt.contains('severe') || txt.contains('swelling') || txt.contains('extraction')) return 3;
    if (txt.contains('rct') || txt.contains('root canal') || txt.contains('pulp')) return 2;
    if (txt.contains('caries') || txt.contains('filling') || txt.contains('restoration') || txt.contains('sensitivity')) return 1;
    return 0;
  }

  final keys = <String>{...done.keys, ...plans.keys, ...findings.keys}.toList()..sort();
  return Map.fromEntries(keys.map((k) {
    final d = done[k] ?? const [];
    final pl = plans[k] ?? const [];
    final fd = findings[k] ?? const [];
    final pr = priorityFor(pl, fd);
    return MapEntry(k, ToothAggregate(tooth: k, done: d, plans: pl, findings: fd, lastDate: lastDate[k], priority: pr));
  }));
}

Color colorForPriority(int p, BuildContext context) {
  switch (p) {
    case 3:
      return Colors.redAccent;
    case 2:
      return Colors.orange;
    case 1:
      return Colors.amber;
    default:
      return Theme.of(context).disabledColor;
  }
}

/// An interactive odontogram laid out along smooth dental arches.
class Odontogram extends StatefulWidget {
  final Patient patient;
  final EdgeInsetsGeometry padding;
  final int daysLookback;
  const Odontogram({super.key, required this.patient, this.padding = const EdgeInsets.all(8), this.daysLookback = 3650});

  @override
  State<Odontogram> createState() => _OdontogramState();
}

class _OdontogramState extends State<Odontogram> {
  // FDI sequences across the arch from right to left
  static const List<String> upper = [
    '18','17','16','15','14','13','12','11','21','22','23','24','25','26','27','28'
  ];
  static const List<String> lower = [
    '48','47','46','45','44','43','42','41','31','32','33','34','35','36','37','38'
  ];

  String? _selected;
  String? _hovered;

  @override
  Widget build(BuildContext context) {
    final agg = buildToothAggregates(widget.patient, daysLookback: widget.daysLookback);

    return Card(
      child: Padding(
        padding: widget.padding,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Icon(Icons.stacked_line_chart, color: Theme.of(context).colorScheme.primary),
            const SizedBox(width: 8),
            Text('Odontogram of ${widget.patient.name}', style: Theme.of(context).textTheme.titleMedium),
            const Spacer(),
            _legend(context),
          ]),
          const SizedBox(height: 8),
          _archLayout(context, upper, agg, isUpper: true),
          const SizedBox(height: 12),
          _archLayout(context, lower, agg, isUpper: false),
        ]),
      ),
    );
  }

  Widget _legend(BuildContext context) {
    Widget item(Color c, String t) => Row(children: [
      Container(width: 10, height: 10, decoration: BoxDecoration(color: c, shape: BoxShape.circle)),
      const SizedBox(width: 4), Text(t, style: const TextStyle(fontSize: 12))
    ]);
    return Row(children: [
      item(colorForPriority(3, context), 'High'), const SizedBox(width: 8),
      item(colorForPriority(2, context), 'Med'), const SizedBox(width: 8),
      item(colorForPriority(1, context), 'Low'), const SizedBox(width: 8),
      item(colorForPriority(0, context), 'None'),
    ]);
  }

  Widget _archLayout(BuildContext context, List<String> numbers, Map<String, ToothAggregate> agg, {required bool isUpper}) {
    return LayoutBuilder(builder: (context, constraints) {
      final w = constraints.maxWidth;
      final h = isUpper ? 160.0 : 170.0;
      final toothBase = w / 22;
      final toothW = toothBase.clamp(28.0, 48.0);
      final toothH = (toothW * 1.45).clamp(40.0, 70.0);

      final path = Path();
      if (isUpper) {
        path.moveTo(w * 0.92, h * 0.18);
        path.quadraticBezierTo(w * 0.50, h * 0.98, w * 0.08, h * 0.18);
      } else {
        path.moveTo(w * 0.92, h * 0.82);
        path.quadraticBezierTo(w * 0.50, h * 0.02, w * 0.08, h * 0.82);
      }

  final metric = path.computeMetrics().first;
  final total = metric.length;
  final spacing = numbers.length > 1 ? total / (numbers.length - 1) : total;

      return SizedBox(
        height: h,
        width: w,
        child: Stack(children: [
          for (int i = 0; i < numbers.length; i++)
            _positionedTooth(
              context,
              metric.getTangentForOffset(((spacing * i).clamp(0.0, total)).toDouble())!,
              numbers[i],
              agg[numbers[i]],
              Size(toothW, toothH),
            ),
        ]),
      );
    });
  }

  Widget _positionedTooth(BuildContext context, ui.Tangent t, String fdi, ToothAggregate? data, Size size) {
    final pos = t.position;
    double angle = t.angle * 0.6; // reduce tilt
    const maxTilt = 0.20943951; // ~12 degrees
    angle = angle.clamp(-maxTilt, maxTilt);

    final pr = data?.priority ?? 0;
    final ring = colorForPriority(pr, context);
    final doneCount = data?.done.length ?? 0;
    final isSelected = _selected == fdi;
    final isHovered = _hovered == fdi;

    return Positioned(
      left: pos.dx - size.width / 2,
      top: pos.dy - size.height / 2,
      child: MouseRegion(
        onEnter: (_) => setState(() => _hovered = fdi),
        onExit: (_) => setState(() => _hovered = _hovered == fdi ? null : _hovered),
        child: GestureDetector(
          onTap: data != null
              ? () {
                  setState(() => _selected = fdi);
                  _openDetails(context, data);
                }
              : null,
          child: Transform.rotate(
            angle: angle,
            child: AnimatedScale(
              duration: const Duration(milliseconds: 140),
              curve: Curves.easeOut,
              scale: isSelected ? 1.08 : (isHovered ? 1.04 : 1.0),
              child: _ToothShape(
                fdi: fdi,
                priorityColor: ring,
                priority: pr,
                doneCount: doneCount,
                onTap: data != null ? () => _openDetails(context, data) : null,
                selected: isSelected,
                hovered: isHovered,
                width: size.width,
                height: size.height,
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _openDetails(BuildContext context, ToothAggregate data) {
    showModalBottomSheet(
      context: context,
      builder: (_) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              const Icon(Icons.medical_services_outlined, size: 20),
              const SizedBox(width: 6),
              Text('Tooth ${data.tooth}', style: Theme.of(context).textTheme.titleMedium),
              const Spacer(),
              if (data.lastDate != null)
                Text('Last: ${data.lastDate!.toLocal().toString().split(' ').first}', style: const TextStyle(fontSize: 12, color: Colors.grey)),
            ]),
            const SizedBox(height: 8),
            if (data.findings.isNotEmpty) ...[
              const Text('Findings', style: TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 4),
              ...data.findings.map((e) => Text('• $e')),
              const SizedBox(height: 8),
            ],
            if (data.plans.isNotEmpty) ...[
              const Text('Plans', style: TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 4),
              ...data.plans.map((e) => Text('• $e')),
              const SizedBox(height: 8),
            ],
            if (data.done.isNotEmpty) ...[
              const Text('Treatments Done', style: TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 4),
              ...data.done.map((e) => Text('• $e')),
            ],
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

/// Classify tooth silhouette roughly by FDI second digit
enum ToothType { incisor, canine, premolar, molar }

ToothType toothTypeFor(String fdi) {
  if (fdi.length < 2) return ToothType.incisor;
  final d = int.tryParse(fdi.substring(1, 2)) ?? 1;
  if (d <= 2) return ToothType.incisor;
  if (d == 3) return ToothType.canine;
  if (d <= 5) return ToothType.premolar;
  return ToothType.molar;
}

class _ToothShape extends StatelessWidget {
  final String fdi;
  final Color priorityColor;
  final int priority;
  final int doneCount;
  final VoidCallback? onTap;
  final bool selected;
  final bool hovered;
  final double? width;
  final double? height;

  const _ToothShape({
    required this.fdi,
    required this.priorityColor,
    required this.priority,
    required this.doneCount,
    this.onTap,
    this.selected = false,
    this.hovered = false,
    this.width,
    this.height,
  });

  @override
  Widget build(BuildContext context) {
    final type = toothTypeFor(fdi);
    return Semantics(
      label: 'Tooth $fdi',
      button: onTap != null,
      child: GestureDetector(
        onTap: onTap,
        child: SizedBox(
          width: width ?? 44,
          height: height ?? 64,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              CustomPaint(
                painter: ToothPainter(
                  type: type,
                  baseColor: Colors.white,
                  borderColor: Colors.grey.shade400,
                  priorityColor: priorityColor,
                  priority: priority,
                  selected: selected,
                  hovered: hovered,
                ),
                size: const Size(double.infinity, double.infinity),
              ),
              Align(
                alignment: Alignment.topCenter,
                child: Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text(
                    fdi,
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 11),
                  ),
                ),
              ),
              if (doneCount > 0)
                Positioned(
                  right: -2,
                  bottom: -2,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                    decoration: BoxDecoration(
                      color: const Color(0xFF2AA198).withOpacity(.95),
                      borderRadius: BorderRadius.circular(10),
                      boxShadow: const [BoxShadow(blurRadius: 2, color: Colors.black26, offset: Offset(0, 1))],
                    ),
                    child: Text('x$doneCount', style: const TextStyle(color: Colors.white, fontSize: 10)),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class ToothPainter extends CustomPainter {
  final ToothType type;
  final Color baseColor;
  final Color borderColor;
  final Color priorityColor;
  final int priority;
  final bool selected;
  final bool hovered;

  ToothPainter({
    required this.type,
    required this.baseColor,
    required this.borderColor,
    required this.priorityColor,
    required this.priority,
    this.selected = false,
    this.hovered = false,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final padding = 6.0;
    final rect = Rect.fromLTWH(padding, padding + 10, size.width - padding * 2, size.height - padding * 2 - 14);

    // Build silhouette path
    final path = _buildToothPath(rect, type);

    // Outer glow for priority
    if (priority > 0) {
      final glowPaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3 + priority.toDouble()
        ..color = priorityColor.withOpacity(0.7)
        ..maskFilter = const MaskFilter.blur(BlurStyle.outer, 6);
      canvas.drawPath(path, glowPaint);
    }

    // Base enamel gradient fill
    final gradient = LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [
        Colors.white,
        baseColor.withOpacity(0.95),
        const Color(0xFFE5E5E5),
      ],
      stops: const [0.0, 0.5, 1.0],
    );
    final fillPaint = Paint()
      ..shader = gradient.createShader(rect)
      ..style = PaintingStyle.fill;
    canvas.drawPath(path, fillPaint);

    // Inner highlight
    final inner = path.shift(const Offset(0, 0));
    final highlightPaint = Paint()
      ..shader = RadialGradient(
        center: const Alignment(-0.6, -0.6),
        radius: 1.2,
        colors: [Colors.white.withOpacity(.7), Colors.transparent],
        stops: const [0.0, 1.0],
      ).createShader(rect)
      ..blendMode = BlendMode.softLight;
    canvas.drawPath(inner, highlightPaint);

    // Internal occlusal/incisal lines for anatomy detail
    _drawInternalLines(canvas, rect, type);

    // Border
    final border = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..color = borderColor.withOpacity(.9);
    canvas.drawPath(path, border);

    // Selection/hover glow (cool tone) and priority ring
    if (selected || hovered) {
      final selColor = selected ? const Color(0xFF4CC3C7) : const Color(0xFF8ADBD6);
      final selGlow = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = selected ? 4.0 : 2.5
        ..color = selColor.withOpacity(selected ? 0.8 : 0.5)
        ..maskFilter = const MaskFilter.blur(BlurStyle.outer, 8);
      canvas.drawPath(path, selGlow);
    }
    // Priority ring on top of border (thin)
    if (priority > 0) {
      final ring = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.8
        ..color = priorityColor.withOpacity(.9);
      canvas.drawPath(path, ring);
    }
  }

  Path _buildToothPath(Rect r, ToothType type) {
    switch (type) {
      case ToothType.incisor:
        return _incisor(r);
      case ToothType.canine:
        return _canine(r);
      case ToothType.premolar:
        return _premolar(r);
      case ToothType.molar:
        return _molar(r);
    }
  }

  Path _incisor(Rect r) {
    final p = Path();
    final top = r.topLeft + Offset(r.width * 0.15, 0);
    final topRight = r.topRight - Offset(r.width * 0.15, 0);
    final midL = Offset(r.left + r.width * 0.05, r.top + r.height * 0.55);
    final midR = Offset(r.right - r.width * 0.05, r.top + r.height * 0.55);
    final bottomL = Offset(r.left + r.width * 0.25, r.bottom);
    final bottomR = Offset(r.right - r.width * 0.25, r.bottom);

    p.moveTo(top.dx, top.dy);
    p.quadraticBezierTo(r.center.dx, r.top - r.height * 0.1, topRight.dx, topRight.dy);
    p.cubicTo(r.right + r.width * 0.05, r.top + r.height * 0.35, midR.dx, midR.dy, bottomR.dx, bottomR.dy);
    p.quadraticBezierTo(r.center.dx, r.bottom + r.height * 0.05, bottomL.dx, bottomL.dy);
    p.cubicTo(midL.dx, midL.dy, r.left - r.width * 0.05, r.top + r.height * 0.35, top.dx, top.dy);
    p.close();
    return p;
  }

  Path _canine(Rect r) {
    final p = Path();
    final top = r.topCenter + const Offset(0, 0);
    final upperL = Offset(r.left + r.width * 0.1, r.top + r.height * 0.2);
    final upperR = Offset(r.right - r.width * 0.1, r.top + r.height * 0.2);
    final midL = Offset(r.left + r.width * 0.05, r.top + r.height * 0.65);
    final midR = Offset(r.right - r.width * 0.05, r.top + r.height * 0.65);
    final cusp = Offset(r.center.dx, r.bottom);
    p.moveTo(top.dx, top.dy);
    p.quadraticBezierTo(r.centerLeft.dx, r.top, upperL.dx, upperL.dy);
    p.cubicTo(r.left - r.width * 0.05, r.top + r.height * 0.45, midL.dx, midL.dy, cusp.dx, cusp.dy);
    p.cubicTo(midR.dx, midR.dy, r.right + r.width * 0.05, r.top + r.height * 0.45, upperR.dx, upperR.dy);
    p.quadraticBezierTo(r.centerRight.dx, r.top, top.dx, top.dy);
    p.close();
    return p;
  }

  Path _premolar(Rect r) {
    final p = Path();
    final topL = Offset(r.left + r.width * 0.2, r.top);
    final topR = Offset(r.right - r.width * 0.2, r.top);
    final cuspL = Offset(r.left + r.width * 0.35, r.top + r.height * 0.6);
    final cuspR = Offset(r.right - r.width * 0.35, r.top + r.height * 0.6);
    final bottomL = Offset(r.left + r.width * 0.2, r.bottom);
    final bottomR = Offset(r.right - r.width * 0.2, r.bottom);
    p.moveTo(topL.dx, topL.dy);
    p.quadraticBezierTo(r.center.dx, r.top - r.height * 0.08, topR.dx, topR.dy);
    p.cubicTo(r.right + r.width * 0.05, r.top + r.height * 0.35, cuspR.dx, cuspR.dy, bottomR.dx, bottomR.dy);
    p.quadraticBezierTo(r.center.dx, r.bottom + r.height * 0.08, bottomL.dx, bottomL.dy);
    p.cubicTo(cuspL.dx, cuspL.dy, r.left - r.width * 0.05, r.top + r.height * 0.35, topL.dx, topL.dy);
    p.close();
    return p;
  }

  Path _molar(Rect r) {
    final p = Path();
    final topL = Offset(r.left + r.width * 0.12, r.top + r.height * 0.02);
    final topR = Offset(r.right - r.width * 0.12, r.top + r.height * 0.02);
    final midL = Offset(r.left + r.width * 0.05, r.top + r.height * 0.55);
    final midR = Offset(r.right - r.width * 0.05, r.top + r.height * 0.55);
    final bottomL = Offset(r.left + r.width * 0.18, r.bottom - r.height * 0.02);
    final bottomR = Offset(r.right - r.width * 0.18, r.bottom - r.height * 0.02);

    p.moveTo(topL.dx, topL.dy);
    p.cubicTo(r.left - r.width * 0.05, r.top + r.height * 0.25, midL.dx, midL.dy, bottomL.dx, bottomL.dy);
    p.quadraticBezierTo(r.center.dx, r.bottom + r.height * 0.08, bottomR.dx, bottomR.dy);
    p.cubicTo(midR.dx, midR.dy, r.right + r.width * 0.05, r.top + r.height * 0.25, topR.dx, topR.dy);
    p.quadraticBezierTo(r.center.dx, r.top - r.height * 0.08, topL.dx, topL.dy);
    p.close();
    return p;
  }

  void _drawInternalLines(Canvas canvas, Rect r, ToothType t) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = const Color(0xFF666666).withOpacity(.6);
    final path = Path();
    switch (t) {
      case ToothType.incisor:
        final y = r.top + r.height * 0.18;
        path.moveTo(r.left + r.width * 0.25, y);
        path.quadraticBezierTo(r.center.dx, y - r.height * 0.06, r.right - r.width * 0.25, y);
        break;
      case ToothType.canine:
        final y = r.top + r.height * 0.22;
        path.moveTo(r.left + r.width * 0.3, y);
        path.quadraticBezierTo(r.center.dx, y - r.height * 0.05, r.right - r.width * 0.3, y);
        break;
      case ToothType.premolar:
        path.moveTo(r.left + r.width * 0.2, r.top + r.height * 0.45);
        path.quadraticBezierTo(r.center.dx, r.top + r.height * 0.55, r.right - r.width * 0.2, r.top + r.height * 0.45);
        path.moveTo(r.center.dx, r.top + r.height * 0.35);
        path.lineTo(r.center.dx, r.bottom - r.height * 0.25);
        break;
      case ToothType.molar:
        final cx = r.center.dx;
        final cy = r.top + r.height * 0.45;
        path.moveTo(r.left + r.width * 0.22, cy);
        path.quadraticBezierTo(cx, cy + r.height * 0.06, r.right - r.width * 0.22, cy);
        path.moveTo(cx - r.width * 0.12, r.top + r.height * 0.25);
        path.quadraticBezierTo(cx, cy, cx + r.width * 0.12, r.bottom - r.height * 0.22);
        break;
    }
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant ToothPainter oldDelegate) {
    return oldDelegate.type != type ||
        oldDelegate.baseColor != baseColor ||
        oldDelegate.borderColor != borderColor ||
        oldDelegate.priorityColor != priorityColor ||
        oldDelegate.priority != priority ||
        oldDelegate.selected != selected ||
        oldDelegate.hovered != hovered;
  }
}
