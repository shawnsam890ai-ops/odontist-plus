import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:teeth_selector/teeth_selector.dart';
import '../../models/patient.dart';
import 'dart:math' as math;

/// Interactive odontogram with 3D enamel fill under TeethSelector overlays.
class Odontogram extends StatefulWidget {
  final Patient patient;
  final EdgeInsets padding;
  final double toothSize;
  final void Function(List<String> selected)? onChange;
  final bool interactive;
  final List<String> highlightedTeeth;
  final Color? backgroundColor; // optional override

  const Odontogram({
    super.key,
    required this.patient,
    this.padding = const EdgeInsets.all(12),
    this.toothSize = 36,
    this.onChange,
    this.interactive = false,
    this.highlightedTeeth = const [],
    this.backgroundColor,
  });
  @override
  State<Odontogram> createState() => _OdontogramState();
}

class _OdontogramState extends State<Odontogram> {
  Set<String> _selected = {};
  final Data _data = loadTeeth();

  @override
  void initState() {
    super.initState();
    _selected = widget.highlightedTeeth.toSet();
  }

  @override
  void didUpdateWidget(covariant Odontogram oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.highlightedTeeth.join(',') != widget.highlightedTeeth.join(',')) {
      _selected = widget.highlightedTeeth.toSet();
    }
  }

  void _handleChange(List<String> now) {
    final before = _selected;
    final nowSet = now.toSet();
    final newlySelected = nowSet.difference(before);
    _selected = nowSet;
    widget.onChange?.call(now);
    if (newlySelected.isNotEmpty) _openToothDetails(context, newlySelected.first);
  }

  @override
  Widget build(BuildContext context) {
    final summaries = _summarizePatientTeeth(widget.patient);
    final doneSet = summaries.entries.where((e) => e.value.doneCount > 0).map((e) => e.key).toSet();
    final criticalFindings = summaries.entries.where((e) => e.value.hasCriticalFinding).map((e) => e.key).toSet();
    final anyFindings = summaries.entries.where((e) => e.value.findingsCount > 0 && !e.value.hasCriticalFinding).map((e) => e.key).toSet();

    final colorize = <String, Color>{for (final t in doneSet) t: Colors.green.shade400};
    final strokedColorized = <String, Color>{
      for (final t in anyFindings) t: Colors.orangeAccent,
      for (final t in criticalFindings) t: Colors.redAccent,
    };
    final strokeWidth = <String, double>{
      for (final t in anyFindings) t: 3.0,
      for (final t in criticalFindings) t: 3.8,
    };
    for (final t in widget.highlightedTeeth) {
      strokedColorized[t] = Theme.of(context).colorScheme.primary;
      strokeWidth[t] = 4.2;
    }

    final tooltipByTooth = <String, String>{for (final e in summaries.entries) e.key: e.value.tooltipLabel()};

    // Compute a darker, theme-aware background so white enamel pops
    final scheme = Theme.of(context).colorScheme;
    final darkBg = _darken(scheme.surfaceVariant, Theme.of(context).brightness == Brightness.light ? 0.45 : 0.2);

    return Card(
      elevation: 2,
      clipBehavior: Clip.antiAlias,
      color: widget.backgroundColor ?? darkBg,
      child: Padding(
        padding: widget.padding,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            const Icon(Icons.monitor_heart_outlined, size: 20),
            const SizedBox(width: 8),
            Text('Odontogram', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
          ]),
          const SizedBox(height: 8),
          Center(
            child: FittedBox(
              child: SizedBox.fromSize(
                size: _data.size,
                child: Stack(children: [
                  CustomPaint(size: _data.size, painter: _ToothFillPainter(_data.teeth, skipFill: doneSet)),
                  IgnorePointer(
                    ignoring: !widget.interactive,
                    child: TeethSelector(
                      key: ValueKey('teeth-${widget.highlightedTeeth.join(',')}'),
                      onChange: _handleChange,
                      showPermanent: true,
                      showPrimary: true,
                      multiSelect: true,
                      initiallySelected: widget.highlightedTeeth,
                      colorized: colorize,
                      StrokedColorized: strokedColorized,
                      strokeWidth: strokeWidth,
                      // Prevent package from drawing any interior strokes (we'll draw outer outline ourselves)
                      defaultStrokeWidth: 1.2,
                      defaultStrokeColor: Colors.transparent,
                      selectedColor: Colors.transparent,
                      unselectedColor: Colors.transparent,
                      notation: (iso) => tooltipByTooth[iso] ?? iso,
                    ),
                  ),
                ]),
              ),
            ),
          ),
          const SizedBox(height: 8),
          if (anyFindings.isNotEmpty || criticalFindings.isNotEmpty || doneSet.isNotEmpty)
            Center(
              child: Wrap(
                alignment: WrapAlignment.center,
                spacing: 6,
                runSpacing: 6,
                children: [
                  if (doneSet.isNotEmpty) _legendGroup(context, 'Done', doneSet.toList()..sort(), Colors.green.shade400),
                  if (anyFindings.isNotEmpty) _legendGroup(context, 'Findings', anyFindings.toList()..sort(), Colors.orangeAccent),
                  if (criticalFindings.isNotEmpty) _legendGroup(context, 'Urgent', criticalFindings.toList()..sort(), Colors.redAccent),
                ],
              ),
            ),
        ]),
      ),
    );
  }

  void _openToothDetails(BuildContext context, String iso) {
    final records = _recordsForTooth(widget.patient, iso);
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (_) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.6,
        minChildSize: 0.4,
        maxChildSize: 0.95,
        builder: (context, controller) {
          return Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Text('Tooth $iso', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
                const SizedBox(width: 12),
                Chip(label: Text('${records.length} record${records.length == 1 ? '' : 's'}')),
              ]),
              const SizedBox(height: 8),
              Expanded(
                child: records.isEmpty
                    ? Center(child: Text('No records for tooth $iso'))
                    : ListView.builder(
                        controller: controller,
                        itemCount: records.length,
                        itemBuilder: (context, i) {
                          final r = records[i];
                          return Card(
                            margin: const EdgeInsets.symmetric(vertical: 6),
                            child: Padding(
                              padding: const EdgeInsets.all(12),
                              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                Row(children: [
                                  const Icon(Icons.event, size: 18),
                                  const SizedBox(width: 6),
                                  Text(_fmtDate(r.date), style: Theme.of(context).textTheme.titleSmall),
                                ]),
                                if (r.chiefComplaint.isNotEmpty) ...[
                                  const SizedBox(height: 8),
                                  Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                    const SizedBox(width: 2),
                                    const Icon(Icons.report_problem_outlined, size: 18),
                                    const SizedBox(width: 6),
                                    Expanded(child: Text(r.chiefComplaint)),
                                  ]),
                                ],
                                if (r.findings.isNotEmpty) ...[
                                  const SizedBox(height: 8),
                                  Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                    const Icon(Icons.search, size: 18),
                                    const SizedBox(width: 6),
                                    Expanded(child: Wrap(spacing: 6, runSpacing: 6, children: r.findings.map((e) => Chip(label: Text(e))).toList())),
                                  ]),
                                ],
                                if (r.plans.isNotEmpty) ...[
                                  const SizedBox(height: 8),
                                  Row(children: [
                                    const Icon(Icons.flag_outlined, size: 18),
                                    const SizedBox(width: 6),
                                    Expanded(child: Wrap(spacing: 6, runSpacing: 6, children: r.plans.map((e) => Chip(label: Text(e))).toList())),
                                  ]),
                                ],
                                if (r.done.isNotEmpty) ...[
                                  const SizedBox(height: 8),
                                  Row(children: [
                                    const Icon(Icons.check_circle_outline, size: 18),
                                    const SizedBox(width: 6),
                                    Expanded(child: Wrap(spacing: 6, runSpacing: 6, children: r.done.map((e) => Chip(label: Text(e))).toList())),
                                  ]),
                                ],
                              ]),
                            ),
                          );
                        },
                      ),
              ),
            ]),
          );
        },
      ),
    );
  }
}

Widget _legendGroup(BuildContext context, String title, List<String> teeth, Color color) {
  final labelStyle = Theme.of(context).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600);
  return Wrap(
    crossAxisAlignment: WrapCrossAlignment.center,
    spacing: 6,
    runSpacing: 6,
    children: [
      Container(width: 10, height: 10, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
      Text('$title:', style: labelStyle),
      ...teeth.map((t) => Chip(
            label: Text(t),
            visualDensity: VisualDensity.compact,
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            padding: const EdgeInsets.symmetric(horizontal: 6),
            labelStyle: Theme.of(context).textTheme.labelSmall?.copyWith(color: _darken(color, 0.15)),
            backgroundColor: color.withOpacity(0.15),
            side: BorderSide(color: color.withOpacity(0.4)),
          )),
    ],
  );
}

class _ToothSummary {
  int findingsCount = 0;
  int doneCount = 0;
  bool hasCriticalFinding = false;
  String lastFinding = '';
  String lastDone = '';

  String tooltipLabel() {
    final parts = <String>[];
    if (findingsCount > 0) parts.add('F:$findingsCount${lastFinding.isNotEmpty ? ' ($lastFinding)' : ''}');
    if (doneCount > 0) parts.add('D:$doneCount${lastDone.isNotEmpty ? ' ($lastDone)' : ''}');
    if (parts.isEmpty) return 'No records';
    return parts.join(' | ');
  }
}

class _ToothFillPainter extends CustomPainter {
  final Map<String, Tooth> teeth;
  final Set<String> skipFill;
  _ToothFillPainter(this.teeth, {this.skipFill = const {}});

  @override
  void paint(Canvas canvas, Size size) {
    for (final entry in teeth.entries) {
      final iso = entry.key;
      final tooth = entry.value;
      if (skipFill.contains(iso)) continue;

      final rect = tooth.rect;
      final path = rect.topLeft == Offset.zero ? tooth.path : tooth.path.shift(rect.topLeft);
  final inner = _bestInnerContour(path, rect);
      final outer = _largestClosedSubpath(path); // for outer white outline only

      canvas.drawShadow(path, Colors.black.withOpacity(0.20), 4.5, false);

      // Whiter enamel base (avoid overall grey cast)
      final baseGradient = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: const [Color(0xFFFCFCFE), Color(0xFFF4F7FB)],
      ).createShader(rect);
      final basePaint = Paint()..style = PaintingStyle.fill..shader = baseGradient;

      canvas.save();
      canvas.clipPath(inner);
      canvas.drawRect(rect, basePaint);

      final isAnterior = () {
        final d = _lastDigit(iso);
        return d == 1 || d == 2 || d == 3;
      }();

      // Subtle occlusal shading to suggest depth; keep light to preserve whiteness
      final innerShadePaint = Paint()
        ..shader = RadialGradient(
          center: Alignment.center,
          radius: isAnterior ? 0.75 : 0.6,
          colors: [Colors.black.withOpacity(0.09), Colors.transparent],
        ).createShader(rect)
        ..blendMode = BlendMode.srcOver;
      canvas.drawRect(rect, innerShadePaint);

      // Specular highlight for glossy enamel (top-left edge)
      // Use an explicit saveLayer confined to the inner enamel bounds so
      // blend artifacts don't escape as rectangular tiles outside the tooth.
      final specularPaint = Paint()
        ..shader = const RadialGradient(
          center: Alignment(-0.75, -0.8), // near top-left corner
          radius: 0.35,
          colors: [Color(0xFFFFFFFF), Color(0x00FFFFFF)],
          stops: [0.0, 1.0],
        ).createShader(rect)
        ..blendMode = BlendMode.screen;
      final specBounds = inner.getBounds().inflate(1.0);
      canvas.saveLayer(specBounds, Paint());
      canvas.drawRect(specBounds, specularPaint);
      canvas.restore();

      if (!isAnterior) {
        final fissure = Path();
        final c = rect.center;
        fissure.moveTo(c.dx - rect.width * 0.20, c.dy);
        fissure.quadraticBezierTo(c.dx, c.dy - rect.height * 0.12, c.dx + rect.width * 0.18, c.dy + rect.height * 0.06);
        final fissurePaint = Paint()
          ..color = Colors.black
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.0
          ..strokeCap = StrokeCap.round
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.2);
        final clipped = Path.combine(PathOperation.intersect, fissure, inner);
        canvas.drawPath(clipped, fissurePaint);
      } else {
        // Anterior: derive the incisal edge by following the outer contour
        // near the incisal margin, then inset slightly towards the center so
        // it sits just inside the enamel outline.
        if (outer != null) {
          final isUpper = _isUpperArch(iso);
          final incisalPath = _incisalCurveFromOuter(outer, rect, isUpper: isUpper, insetPx: 2.0);
          if (incisalPath != null) {
            final incisalPaint = Paint()
              ..color = Colors.black
              ..style = PaintingStyle.stroke
              ..strokeWidth = 1.0
              ..strokeCap = StrokeCap.round
              ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.3);
            final incisalClipped = Path.combine(PathOperation.intersect, incisalPath, inner);
            canvas.drawPath(incisalClipped, incisalPaint);
          }
        }
      }

      // No inner white rim stroke — avoids a white line sitting above black occlusal/incisal strokes

      canvas.restore();

      // Draw a clean outer white outline (since TeethSelector strokes are disabled)
      if (outer != null) {
        final outerStroke = Paint()
          ..color = Colors.white.withOpacity(0.95)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.2
          ..strokeJoin = StrokeJoin.round;
        canvas.drawPath(outer, outerStroke);
      }

      // Optional subtle inner dark rim for depth
      final darkRim = Paint()
        ..color = Colors.black.withOpacity(0.06)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.9;
      canvas.drawPath(inner, darkRim);
    }
  }

  @override
  bool shouldRepaint(covariant _ToothFillPainter oldDelegate) => !mapEquals(oldDelegate.teeth, teeth) || oldDelegate.skipFill != skipFill;
}

int _lastDigit(String iso) {
  if (iso.isEmpty) return 0;
  final ch = iso.codeUnitAt(iso.length - 1);
  return ch >= 48 && ch <= 57 ? ch - 48 : 0;
}

// Heuristic: pick the largest closed contour that is clearly inside the rect (not the outer ring)
// and not tiny (to ignore decorative grooves). Fallback to smallest closed if nothing matches.
Path _bestInnerContour(Path input, Rect rect) {
  final metrics = input.computeMetrics(forceClosed: false).toList();
  if (metrics.isEmpty) return input;
  final rectArea = rect.width * rect.height;
  Path? candidate;
  double candidateArea = -1;
  Path? smallest;
  double smallestArea = double.infinity;
  for (final m in metrics) {
    if (!m.isClosed) continue;
    final sub = m.extractPath(0, m.length);
    final b = sub.getBounds();
    final area = (b.width * b.height).abs();
    // Track smallest (fallback)
    if (area < smallestArea) {
      smallest = sub;
      smallestArea = area;
    }
    // Accept areas between 15% and 95% of the rect area; pick the largest among them
    if (area > rectArea * 0.15 && area < rectArea * 0.95) {
      if (area > candidateArea) {
        candidate = sub;
        candidateArea = area;
      }
    }
  }
  return candidate ?? smallest ?? input;
}

// Pick the largest closed subpath (assumed to be the outer contour)
Path? _largestClosedSubpath(Path input) {
  final metrics = input.computeMetrics(forceClosed: false).toList();
  if (metrics.isEmpty) return null;
  Path? largest;
  double largestArea = -1;
  for (final m in metrics) {
    if (!m.isClosed) continue;
    final sub = m.extractPath(0, m.length);
    final b = sub.getBounds();
    final area = (b.width * b.height).abs();
    if (area > largestArea) {
      largest = sub;
      largestArea = area;
    }
  }
  return largest;
}

// Determine if the ISO tooth belongs to the upper arch (permanent: 1,2; primary: 5,6)
bool _isUpperArch(String iso) {
  if (iso.isEmpty) return true;
  final first = iso.codeUnitAt(0) - 48; // '0' => 0
  return first == 1 || first == 2 || first == 5 || first == 6;
}

// Build a curve that follows the outer contour near the incisal margin.
// - isUpper: if true, take the bottom-most band; otherwise top-most band.
// - insetPx: move the curve inward towards the rect center to sit inside enamel.
Path? _incisalCurveFromOuter(Path outer, Rect rect, {required bool isUpper, double insetPx = 2.0}) {
  final metrics = outer.computeMetrics(forceClosed: false).toList();
  if (metrics.isEmpty) return null;
  // Sample along the outer path
  final points = <Offset>[];
  const samplesPerMetric = 80;
  for (final m in metrics) {
    final step = m.length / samplesPerMetric;
    for (double d = 0; d <= m.length; d += step) {
      final t = m.getTangentForOffset(d);
      if (t != null) points.add(t.position);
    }
  }
  if (points.length < 4) return null;
  // Filter to a narrow band right at the incisal edge
  final bandFrac = 0.12; // 12% of height from the edge
  final band = points.where((p) => isUpper
      ? (p.dy <= rect.top + rect.height * bandFrac)
      : (p.dy >= rect.bottom - rect.height * bandFrac)).toList();
  if (band.length < 4) return null;
  // Sort band points by x to get a monotonic curve left->right
  band.sort((a, b) => a.dx.compareTo(b.dx));
  // Trim extremes to avoid side-wall wrap
  final minX = band.first.dx;
  final maxX = band.last.dx;
  final span = maxX - minX;
  final trimmed = band.where((p) => p.dx >= minX + span * 0.1 && p.dx <= maxX - span * 0.1).toList();
  if (trimmed.length >= 4) {
    band
      ..clear()
      ..addAll(trimmed);
  }
  // Inset points slightly towards the center to avoid sitting on the outline
  final c = rect.center;
  final inset = band.map((p) {
    final dx = c.dx - p.dx;
    final dy = c.dy - p.dy;
  final len = math.sqrt(dx * dx + dy * dy);
    if (len == 0) return p;
    return Offset(p.dx + dx / len * insetPx, p.dy + dy / len * insetPx);
  }).toList();
  // Build a path from the inset points
  final path = Path();
  path.moveTo(inset.first.dx, inset.first.dy);
  // Use quadratic segments every few points for smoothness
  for (int i = 1; i < inset.length - 1; i += 2) {
    final cp = inset[i];
    final to = inset[i + 1];
    path.quadraticBezierTo(cp.dx, cp.dy, to.dx, to.dy);
  }
  return path;
}

Map<String, _ToothSummary> _summarizePatientTeeth(Patient patient) {
  final map = <String, _ToothSummary>{};
  bool isCritical(String s) {
    final t = s.toLowerCase();
    return t.contains('abscess') || t.contains('swelling') || t.contains('acute') || t.contains('severe') || t.contains('pain') || t.contains('fracture');
  }
  void bumpFinding(String tooth, String label) {
    final s = map.putIfAbsent(tooth, () => _ToothSummary());
    s.findingsCount += 1;
    s.lastFinding = label;
    if (isCritical(label)) s.hasCriticalFinding = true;
  }
  void bumpDone(String tooth, String label) {
    final s = map.putIfAbsent(tooth, () => _ToothSummary());
    s.doneCount += 1;
    s.lastDone = label;
  }
  for (final sess in patient.sessions) {
    for (final f in sess.oralExamFindings) {
      if (f.toothNumber.isNotEmpty) bumpFinding(f.toothNumber, f.finding);
    }
    for (final f in sess.investigationFindings) {
      if (f.toothNumber.isNotEmpty) bumpFinding(f.toothNumber, f.finding);
    }
    for (final f in sess.rootCanalFindings) {
      if (f.toothNumber.isNotEmpty) bumpFinding(f.toothNumber, f.finding);
    }
    for (final p in sess.toothPlans) {
      if (p.toothNumber.isNotEmpty) bumpFinding(p.toothNumber, p.plan);
    }
    for (final d in sess.treatmentsDone) {
      if (d.toothNumber.isNotEmpty) bumpDone(d.toothNumber, d.treatment);
    }
  }
  return map;
}

class _ToothRecordExt {
  final DateTime date;
  final String chiefComplaint;
  final List<String> findings;
  final List<String> plans;
  final List<String> done;
  _ToothRecordExt({required this.date, this.chiefComplaint = '', List<String>? findings, List<String>? plans, List<String>? done})
      : findings = findings ?? [],
        plans = plans ?? [],
        done = done ?? [];
}

List<_ToothRecordExt> _recordsForTooth(Patient patient, String iso) {
  final out = <_ToothRecordExt>[];
  for (final s in patient.sessions) {
    final cc = s.chiefComplaint?.complaints.join(', ') ?? '';
    final findings = <String>[];
    findings.addAll(s.oralExamFindings.where((e) => e.toothNumber == iso).map((e) => e.finding));
    findings.addAll(s.investigationFindings.where((e) => e.toothNumber == iso).map((e) => e.finding));
    findings.addAll(s.rootCanalFindings.where((e) => e.toothNumber == iso).map((e) => e.finding));
    final plans = <String>[];
    plans.addAll(s.toothPlans.where((e) => e.toothNumber == iso).map((e) => e.plan));
    final done = <String>[];
    done.addAll(s.treatmentsDone.where((e) => e.toothNumber == iso).map((e) => e.treatment));
    if (findings.isEmpty && plans.isEmpty && done.isEmpty && cc.isEmpty) continue;
    out.add(_ToothRecordExt(date: s.date, chiefComplaint: cc, findings: findings, plans: plans, done: done));
  }
  out.sort((a, b) => b.date.compareTo(a.date));
  return out;
}

String _fmtDate(DateTime d) {
  const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
  return '${d.day.toString().padLeft(2, '0')} ${months[d.month - 1]} ${d.year}';
}

Color _darken(Color color, double amount) {
  assert(amount >= 0 && amount <= 1);
  final hsl = HSLColor.fromColor(color);
  final h = hsl.withLightness((hsl.lightness - amount).clamp(0.0, 1.0));
  return h.toColor();
}