import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:teeth_selector/teeth_selector.dart';
import '../../models/patient.dart';
import 'dart:math' as math;
import '../../core/enums.dart';

/// Interactive odontogram with 3D enamel fill under TeethSelector overlays.
class Odontogram extends StatefulWidget {
  final Patient patient;
  final EdgeInsets padding;
  final double toothSize;
  final void Function(List<String> selected)? onChange;
  final bool interactive;
  final List<String> highlightedTeeth;
  final Color? backgroundColor; // optional override
  // Optional: request parent to add a per-tooth plan of a specific type
  final void Function(String toothNumber, TreatmentType type)? onAddPlan;

  const Odontogram({
    super.key,
    required this.patient,
    this.padding = const EdgeInsets.all(12),
    this.toothSize = 36,
    this.onChange,
    this.interactive = false,
    this.highlightedTeeth = const [],
    this.backgroundColor,
    this.onAddPlan,
  });
  @override
  State<Odontogram> createState() => _OdontogramState();
}

class _OdontogramState extends State<Odontogram> {
  Set<String> _selected = {};
  final Data _data = loadTeeth();
  // Cached computed data derived from patient sessions to avoid recomputing every build
  Map<String, _ToothSummary>? _cachedSummaries;
  Map<String, List<_Mark>>? _cachedMarks;
  _GlobalNotes? _cachedGlobals;
  String _cacheKey = '';

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
    // Invalidate cache when patient identity changes or sessions likely changed (cheap heuristic)
    if (!identical(oldWidget.patient, widget.patient)) {
      _cacheKey = '';
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
    // Ensure cached computed data is up to date
    _ensureCache();
    final summaries = _cachedSummaries!;
    final doneSet = summaries.entries.where((e) => e.value.doneCount > 0).map((e) => e.key).toSet();
    final criticalFindings = summaries.entries.where((e) => e.value.hasCriticalFinding).map((e) => e.key).toSet();
    final anyFindings = summaries.entries.where((e) => e.value.findingsCount > 0 && !e.value.hasCriticalFinding).map((e) => e.key).toSet();

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

  final toothMarks = _cachedMarks!;
  final globals = _cachedGlobals!;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        Card(
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

              // Global notes/annotations above the diagram
              if (globals.notes.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Wrap(
                    alignment: WrapAlignment.center,
                    spacing: 12,
                    runSpacing: 6,
                    children: globals.notes
                        .map((n) => InkWell(
                              onTap: () => _openGeneralInfoSheet(context, n.label),
                              child: Text(
                                n.label,
                                style: Theme.of(context).textTheme.bodyMedium?.copyWith(decoration: TextDecoration.underline, color: n.color ?? Theme.of(context).colorScheme.primary),
                              ),
                            ))
                        .toList(),
                  ),
                ),

              Center(
                child: FittedBox(
                  child: RepaintBoundary(
                    child: SizedBox.fromSize(
                      size: _data.size,
                      child: Stack(children: [
                        // Enamel/base layer (static for given patient state)
                        CustomPaint(size: _data.size, painter: _ToothFillPainter(_data.teeth, skipFill: doneSet), isComplex: true, willChange: false),
                        // Per-tooth letter/short-code marks
                        IgnorePointer(child: CustomPaint(size: _data.size, painter: _ToothMarkPainter(_data.teeth, toothMarks), isComplex: true, willChange: false)),
                        // Hit-test & selection overlay
                        IgnorePointer(
                          ignoring: !widget.interactive,
                          child: TeethSelector(
                            key: ValueKey('teeth-${widget.highlightedTeeth.join(',')}'),
                            onChange: _handleChange,
                            showPermanent: true,
                            showPrimary: true,
                            multiSelect: true,
                            initiallySelected: widget.highlightedTeeth,
                            // Disable package-drawn fills/strokes; we draw our own enamel + glow
                            colorized: const <String, Color>{},
                            StrokedColorized: const <String, Color>{},
                            strokeWidth: const <String, double>{},
                            // Prevent package from drawing any interior strokes entirely
                            defaultStrokeWidth: 0.0,
                            defaultStrokeColor: Colors.transparent,
                            selectedColor: Colors.transparent,
                            unselectedColor: Colors.transparent,
                            notation: (iso) => tooltipByTooth[iso] ?? iso,
                          ),
                        ),
                        // Thin yellow halo around highlighted teeth
                        IgnorePointer(
                          child: CustomPaint(
                            size: _data.size,
                            painter: _ToothHighlightPainter(_data.teeth, _selected),
                            isComplex: true,
                            willChange: true,
                          ),
                        ),
                        if (globals.showCD)
                          Positioned(
                            top: 4,
                            left: 0,
                            right: 0,
                            child: Center(
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.green.shade600,
                                  borderRadius: BorderRadius.circular(8),
                                  boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 4, offset: Offset(0, 1))],
                                ),
                                child: Text(
                                  'CD',
                                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w800,
                                      ),
                                ),
                              ),
                            ),
                          ),
                      ]),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              // intentionally removed the Done/Findings legend here per user request
            ]),
          ),
        ),
        // Info icon positioned at top-right corner of the Card
        Positioned(
          right: 8,
          top: -4,
          child: Material(
            color: Colors.transparent,
            child: IconButton(
              tooltip: 'Abbreviations',
              icon: const Icon(Icons.info_outline, size: 20),
              onPressed: () => _showAbbrevDialog(context),
            ),
          ),
        ),
      ],
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
              if (widget.onAddPlan != null) ...[
                const SizedBox(height: 8),
                Wrap(spacing: 8, children: [
                  ElevatedButton.icon(
                    icon: const Icon(Icons.medical_services_outlined, size: 18),
                    label: const Text('Add Rx – Root Canal'),
                    onPressed: () {
                      Navigator.of(context).maybePop();
                      widget.onAddPlan!.call(iso, TreatmentType.rootCanal);
                    },
                  ),
                  OutlinedButton.icon(
                    icon: const Icon(Icons.brush_outlined, size: 18),
                    label: const Text('Add Rx – Prosthodontic'),
                    onPressed: () {
                      Navigator.of(context).maybePop();
                      widget.onAddPlan!.call(iso, TreatmentType.prosthodontic);
                    },
                  ),
                ]),
              ],
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

  void _openGeneralInfoSheet(BuildContext context, String title) {
    // Gather latest non-empty sections across sessions
    String chief = '';
    final plans = <String>[];
    final done = <String>[];
    for (final s in widget.patient.sessions.reversed) {
      chief = chief.isEmpty ? (s.chiefComplaint?.complaints.join(', ') ?? '') : chief;
      if (plans.isEmpty && (s.generalTreatmentPlan.isNotEmpty || s.planOptions.isNotEmpty || s.toothPlans.isNotEmpty)) {
        plans.addAll(s.generalTreatmentPlan);
        plans.addAll(s.planOptions);
        plans.addAll(s.toothPlans.map((e) => (e.toothNumber.isEmpty ? e.plan : '${e.toothNumber}: ${e.plan}')));
      }
      if (done.isEmpty && (s.treatmentsDone.isNotEmpty || s.treatmentDoneOptions.isNotEmpty)) {
        done.addAll(s.treatmentDoneOptions);
        done.addAll(s.treatmentsDone.map((e) => (e.toothNumber.isEmpty ? e.treatment : '${e.toothNumber}: ${e.treatment}')));
      }
      if (chief.isNotEmpty && plans.isNotEmpty && done.isNotEmpty) break;
    }

    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      builder: (_) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: ListView(
          children: [
            Text(title, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            if (chief.isNotEmpty) ...[
              Text('Chief Complaint', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 4),
              Text(chief),
              const SizedBox(height: 12),
            ],
            if (plans.isNotEmpty) ...[
              Text('Treatment Plan', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 4),
              Wrap(spacing: 6, runSpacing: 6, children: plans.map((e) => Chip(label: Text(e))).toList()),
              const SizedBox(height: 12),
            ],
            if (done.isNotEmpty) ...[
              Text('Treatment Done', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 4),
              Wrap(spacing: 6, runSpacing: 6, children: done.map((e) => Chip(label: Text(e))).toList()),
            ],
            if (chief.isEmpty && plans.isEmpty && done.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Text('No information recorded yet.'),
              )
          ],
        ),
      ),
    );
  }

  void _showAbbrevDialog(BuildContext context) {
    final items = <Map<String, dynamic>>[
      {'code': 'R', 'label': 'Root canal', 'color': Colors.red.shade700},
      {'code': 'Xn', 'label': 'Extraction', 'color': Colors.red.shade700},
      {'code': 'M', 'label': 'Missing', 'color': Colors.black},
      {'code': 'C', 'label': 'Crown', 'color': Colors.blue},
      {'code': 'Rp', 'label': 'Removable partial denture (RPD)', 'color': Colors.pink.shade400},
      {'code': 'CD', 'label': 'Complete denture', 'color': Colors.green.shade700},
      {'code': 'R + C', 'label': 'Root canal + Crown', 'color': null},
      {'code': 'D', 'label': 'Dry socket', 'color': Colors.brown.shade700},
      {'code': 'DC', 'label': 'Dental caries', 'color': Colors.black},
      {'code': 'DDC', 'label': 'Deep dental caries', 'color': Colors.black},
      {'code': 'GD', 'label': 'Grossly decayed', 'color': Colors.black},
      {'code': 'Rs', 'label': 'Root stumps', 'color': Colors.amber.shade700},
      {'code': 'CA', 'label': 'Cervical abrasion', 'color': Colors.amber.shade700},
      {'code': 'IDC', 'label': 'Initial carious lesion', 'color': Colors.black},
      {'code': 'E1/E2/E3', 'label': 'Ellis fracture (levels)', 'color': Colors.brown.shade700},
      {'code': 'G1/G2/G3', 'label': 'Mobile Grade 1/2/3', 'color': Colors.red.shade700},
      {'code': 'Er', 'label': 'Erosion', 'color': Colors.purple},
      {'code': 'EEC', 'label': 'Early enamel caries', 'color': Colors.blue},
      {'code': 'Gen. stains', 'label': 'Generalised stains and deposits (note)', 'color': Colors.teal},
    ];

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Odontogram abbreviations'),
        content: SizedBox(
          width: 420,
          child: ListView.separated(
            shrinkWrap: true,
            itemCount: items.length,
            separatorBuilder: (_, __) => const Divider(height: 12),
            itemBuilder: (context, i) {
              final it = items[i];
              final color = it['color'] as Color?;
              return Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  if (color != null)
                    Container(width: 14, height: 14, margin: const EdgeInsets.only(right: 8), decoration: BoxDecoration(color: color, shape: BoxShape.circle))
                  else
                    const SizedBox(width: 14, height: 14),
                  const SizedBox(width: 8),
                  Text(it['code'] as String, style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
                  const SizedBox(width: 12),
                  Expanded(child: Text(it['label'] as String)),
                ],
              );
            },
          ),
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close'))],
      ),
    );
  }
}

// ----------------------------------------------------------------------------
// Cache helpers inside state
extension on _OdontogramState {
  void _ensureCache() {
    final newKey = _makeCacheKey(widget.patient);
    if (newKey == _cacheKey &&
        _cachedSummaries != null &&
        _cachedMarks != null &&
        _cachedGlobals != null) {
      return;
    }
    _cachedSummaries = _summarizePatientTeeth(widget.patient);
    _cachedMarks = _computeToothMarks(widget.patient);
    _cachedGlobals = _computeGlobalNotes(widget.patient);
    _cacheKey = newKey;
  }

  String _makeCacheKey(Patient p) {
    int count = p.sessions.length;
    int maxTs = 0;
    for (final s in p.sessions) {
      final ts = s.date.millisecondsSinceEpoch;
      if (ts > maxTs) maxTs = ts;
    }
    // Include highlighted teeth set in the key only for highlight painter; summaries/marks depend on sessions only.
    return '$count:$maxTs';
  }
}

// ignore: unused_element
Widget _legendGroup(BuildContext context, String title, List<String> teeth, Color color) {
  final labelStyle = Theme.of(context).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600);
  return Wrap(
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

      canvas.restore();

      if (outer != null) {
        final outerStroke = Paint()
          ..color = Colors.white.withOpacity(0.95)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.2
          ..strokeJoin = StrokeJoin.round;
        canvas.drawPath(outer, outerStroke);
      }

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
    if (area < smallestArea) {
      smallest = sub;
      smallestArea = area;
    }
    if (area > rectArea * 0.15 && area < rectArea * 0.95) {
      if (area > candidateArea) {
        candidate = sub;
        candidateArea = area;
      }
    }
  }
  return candidate ?? smallest ?? input;
}

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

bool _isUpperArch(String iso) {
  if (iso.isEmpty) return true;
  final first = iso.codeUnitAt(0) - 48;
  return first == 1 || first == 2 || first == 5 || first == 6;
}

Path? _incisalCurveFromOuter(Path outer, Rect rect, {required bool isUpper, double insetPx = 2.0}) {
  final metrics = outer.computeMetrics(forceClosed: false).toList();
  if (metrics.isEmpty) return null;
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
  final bandFrac = 0.12;
  final band = points.where((p) => isUpper ? (p.dy <= rect.top + rect.height * bandFrac) : (p.dy >= rect.bottom - rect.height * bandFrac)).toList();
  if (band.length < 4) return null;
  band.sort((a, b) => a.dx.compareTo(b.dx));
  final minX = band.first.dx;
  final maxX = band.last.dx;
  final span = maxX - minX;
  final trimmed = band.where((p) => p.dx >= minX + span * 0.1 && p.dx <= maxX - span * 0.1).toList();
  if (trimmed.length >= 4) {
    band
      ..clear()
      ..addAll(trimmed);
  }
  final c = rect.center;
  final inset = band.map((p) {
    final dx = c.dx - p.dx;
    final dy = c.dy - p.dy;
    final len = math.sqrt(dx * dx + dy * dy);
    if (len == 0) return p;
    return Offset(p.dx + dx / len * insetPx, p.dy + dy / len * insetPx);
  }).toList();
  final path = Path();
  path.moveTo(inset.first.dx, inset.first.dy);
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
    for (final f in sess.prosthodonticFindings) {
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
    plans.addAll(s.rootCanalPlans.where((e) => e.toothNumber == iso).map((e) => e.plan));
    plans.addAll(s.prosthodonticPlans.where((e) => e.toothNumber == iso).map((e) => e.plan));
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

// --- Marks and global notes -------------------------------------------------

class _Mark {
  final String text;
  final Color color;
  const _Mark(this.text, this.color);
}

class _GlobalNotes {
  final bool showCD;
  final List<_Note> notes;
  const _GlobalNotes({this.showCD = false, this.notes = const []});
}

class _Note {
  final String label;
  final Color? color;
  const _Note(this.label, {this.color});
}

Map<String, List<_Mark>> _computeToothMarks(Patient patient) {
  final map = <String, List<_Mark>>{};
  void add(String tooth, _Mark m) {
    if (tooth.isEmpty) return;
    final list = map.putIfAbsent(tooth, () => []);
    if (list.any((x) => x.text == m.text)) return;
    list.add(m);
  }

  List<_Mark> parse(String text) {
    final t = text.toLowerCase();
    final out = <_Mark>[];
    Color brown = Colors.brown.shade700;
    Color yellow = Colors.amber.shade700;
    Color pink = Colors.pink.shade400;
  if (t.contains('deep dental caries') || t.contains('ddc')) out.add(const _Mark('DDC', Colors.black));
    if (t.contains('initial carious lesion') || t.contains('icl') || t.contains('idl') || t.contains('idc')) out.add(const _Mark('IDC', Colors.black));
  // Generic dental caries (exclude deep variants)
  if (!t.contains('deep') && (t.contains('dental caries') || t.contains('caries'))) out.add(const _Mark('DC', Colors.black));
    if (t.contains('root canal') || t.contains('rct')) out.add(_Mark('R', Colors.red.shade700));
    if (t.contains('extraction') || t.contains('extract')) out.add(_Mark('Xn', Colors.red.shade700));
    if (t.contains('missing')) out.add(const _Mark('M', Colors.black));
    if (t.contains('crown')) out.add(const _Mark('C', Colors.blue));
    if (t.contains('rpd') || t.contains('removable partial') || t.contains('removable')) out.add(_Mark('Rp', pink));
    if (t.contains('dry socket')) out.add(_Mark('D', brown));
    if (t.contains('grossly decayed') || t.contains('grossly carious')) out.add(const _Mark('GD', Colors.black));
    if (t.contains('root stump')) out.add(_Mark('Rs', yellow));
    if (t.contains('cervical abrasion') || (t.contains('abrasion') && t.contains('cervical'))) out.add(_Mark('CA', yellow));
    if (t.contains('ellis')) {
      final match = RegExp(r'e\s*([1-9])').firstMatch(t);
      if (match != null) out.add(_Mark('E${match.group(1)}', brown));
    }
    if (RegExp(r'\bg[1-3]\b').hasMatch(t) || t.contains('grade 1') || t.contains('grade 2') || t.contains('grade 3')) {
      String grade = 'G1';
      if (t.contains('g2') || t.contains('grade 2')) grade = 'G2';
      if (t.contains('g3') || t.contains('grade 3')) grade = 'G3';
      out.add(_Mark(grade, Colors.red.shade700));
    }
    if (t.contains('erosion')) out.add(_Mark('Er', Colors.purple));
    if (t.contains('early enamel caries') || t.contains('eec')) out.add(const _Mark('EEC', Colors.blue));
    return out;
  }

  for (final s in patient.sessions) {
    for (final f in s.oralExamFindings) {
      for (final m in parse(f.finding)) add(f.toothNumber, m);
    }
    for (final f in s.investigationFindings) {
      for (final m in parse(f.finding)) add(f.toothNumber, m);
    }
    for (final f in s.rootCanalFindings) {
      for (final m in parse(f.finding)) add(f.toothNumber, m);
    }
    for (final p in s.toothPlans) {
      for (final m in parse(p.plan)) add(p.toothNumber, m);
    }
    for (final d in s.treatmentsDone) {
      for (final m in parse(d.treatment)) add(d.toothNumber, m);
    }
    for (final p in s.rootCanalPlans) {
      for (final m in parse(p.plan)) add(p.toothNumber, m);
    }
    for (final p in s.prosthodonticPlans) {
      for (final m in parse(p.plan)) add(p.toothNumber, m);
    }
  }
  // limit to first two marks per tooth to avoid clutter
  for (final e in map.entries) {
    if (e.value.length > 2) e.value.removeRange(2, e.value.length);
  }
  return map;
}

_GlobalNotes _computeGlobalNotes(Patient patient) {
  bool showCD = false;
  bool showGenStains = false;
  bool showGenBlackStains = false;
  for (final s in patient.sessions) {
    for (final f in s.oralExamFindings) {
      if (f.toothNumber.trim().isEmpty) {
        final t = f.finding.toLowerCase();
        if (t.contains('complete denture')) showCD = true;
        if (t.contains('stain') || t.contains('deposit')) showGenStains = true;
        if (t.contains('black stain')) showGenBlackStains = true;
      }
    }
  }
  final notes = <_Note>[];
  if (showGenStains) notes.add(const _Note('Gen. stains and deposits noted.', color: Colors.teal));
  if (showGenBlackStains) notes.add(const _Note('Gen. black stains noted.', color: Colors.black87));
  return _GlobalNotes(showCD: showCD, notes: notes);
}

class _ToothMarkPainter extends CustomPainter {
  final Map<String, Tooth> teeth;
  final Map<String, List<_Mark>> marks;
  _ToothMarkPainter(this.teeth, this.marks);

  @override
  void paint(Canvas canvas, Size size) {
    final tp = TextPainter(textDirection: TextDirection.ltr, textAlign: TextAlign.center);
    for (final entry in marks.entries) {
      final iso = entry.key;
      final tooth = teeth[iso];
      if (tooth == null) continue;
      final rect = tooth.rect;
      final center = rect.center;
      final items = entry.value.take(2).toList();
      final totalHeight = items.length == 1 ? 0.0 : 12.0;
      double y = center.dy - totalHeight / 2;
      for (final m in items) {
        final maxW = rect.width * 0.7;
        double font = (rect.width * 0.38).clamp(8.0, 14.0);
        if (m.text.length >= 3) font *= 0.75; else if (m.text.length == 2) font *= 0.9;
        final style = TextStyle(fontSize: font, fontWeight: FontWeight.w800, color: m.color);
        tp.text = TextSpan(text: m.text, style: style.copyWith(shadows: const [Shadow(offset: Offset(0.6, 0.6), blurRadius: 0.8, color: Colors.white)]));
        tp.layout(maxWidth: maxW);
        final dx = center.dx - tp.width / 2;
        final dy = y - tp.height / 2;
        tp.paint(canvas, Offset(dx, dy));
        y += 12.0;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _ToothMarkPainter oldDelegate) => !mapEquals(oldDelegate.teeth, teeth) || oldDelegate.marks != marks;
}

// Paints a small outer yellow halo around highlighted/selected teeth without filling or stroking interior
class _ToothHighlightPainter extends CustomPainter {
  final Map<String, Tooth> teeth;
  final Set<String> highlighted;
  _ToothHighlightPainter(this.teeth, this.highlighted);

  @override
  void paint(Canvas canvas, Size size) {
    if (highlighted.isEmpty) return;
    for (final iso in highlighted) {
      final tooth = teeth[iso];
      if (tooth == null) continue;
      final rect = tooth.rect;
      final path = rect.topLeft == Offset.zero ? tooth.path : tooth.path.shift(rect.topLeft);
      // Prefer the outer closed contour for a halo drawn outside the tooth
      final outer = _largestClosedSubpath(path) ?? _bestInnerContour(path, rect);
      // Draw a small outer halo using a subtle shadow (no inner stroke to keep text visible)
      canvas.drawShadow(outer, Colors.yellow.shade700, 3.0, false);
    }
  }

  @override
  bool shouldRepaint(covariant _ToothHighlightPainter oldDelegate) => !mapEquals(oldDelegate.teeth, teeth) || !setEquals(oldDelegate.highlighted, highlighted);
}

