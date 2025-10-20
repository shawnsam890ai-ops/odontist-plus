import 'package:flutter/material.dart';
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

/// An interactive odontogram grid for 32 permanent teeth (FDI 11-18,21-28,31-38,41-48).
/// Displays AI-priority color ring and a compact history chip count. Tapping a tooth opens details.
class Odontogram extends StatelessWidget {
  final Patient patient;
  final EdgeInsetsGeometry padding;
  final int daysLookback;
  const Odontogram({super.key, required this.patient, this.padding = const EdgeInsets.all(8), this.daysLookback = 3650});

  static const List<String> upperRight = ['18','17','16','15','14','13','12','11'];
  static const List<String> upperLeft  = ['21','22','23','24','25','26','27','28'];
  static const List<String> lowerLeft  = ['38','37','36','35','34','33','32','31'];
  static const List<String> lowerRight = ['41','42','43','44','45','46','47','48'];

  @override
  Widget build(BuildContext context) {
    final agg = buildToothAggregates(patient, daysLookback: daysLookback);

    Widget row(List<String> numbers) => Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: numbers.map((n) => _toothTile(context, n, agg[n])).toList(),
        );

    return Card(
      child: Padding(
        padding: padding,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Icon(Icons.stacked_line_chart, color: Theme.of(context).colorScheme.primary),
            const SizedBox(width: 8),
            Text('Odontogram (last year)', style: Theme.of(context).textTheme.titleMedium),
            const Spacer(),
            _legend(context),
          ]),
          const SizedBox(height: 8),
          row(upperRight + upperLeft),
          const SizedBox(height: 6),
          row(lowerLeft + lowerRight),
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

  Widget _toothTile(BuildContext context, String tooth, ToothAggregate? data) {
    final pr = data?.priority ?? 0;
    final ring = colorForPriority(pr, context);
    final has = data != null;
    final doneCount = data?.done.length ?? 0;
    final label = tooth;
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: has ? () => _openDetails(context, data) : null,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 2),
        padding: const EdgeInsets.all(6),
        width: 40,
        height: 56,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: ring.withOpacity(0.9), width: pr == 0 ? 1 : 2),
          color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.35),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(label, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
            const SizedBox(height: 2),
            if (doneCount > 0)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                decoration: BoxDecoration(color: Colors.teal.withOpacity(.85), borderRadius: BorderRadius.circular(10)),
                child: Text('x$doneCount', style: const TextStyle(color: Colors.white, fontSize: 10)),
              ),
          ],
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
