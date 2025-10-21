import 'package:flutter/material.dart';
import 'package:teeth_selector/teeth_selector.dart';
import '../../models/patient.dart';

/// Simple interactive odontogram for permanent dentition (FDI 11-48).
/// Aggregates per-tooth findings, plans, and treatments done across all sessions
/// for a patient, and color-codes each tooth by AI-style priority:
/// - critical (red): acute/severe findings like swelling/pain/abscess
/// - warning (orange): planned RCT/extraction/crown or active plans
/// - done (green): treatments done like RCT/Filling/Crown/Extraction
/// - none (grey): no data
class Odontogram extends StatefulWidget {
	final Patient patient;
	final EdgeInsets padding;
	final double toothSize;
	final void Function(List<String> selected)? onChange;
	// View-only mode disables pointer interactions
	final bool interactive;
	// List of FDI tooth numbers to visually highlight/select
	final List<String> highlightedTeeth;

	const Odontogram({
		super.key,
		required this.patient,
		this.padding = const EdgeInsets.all(12),
		this.toothSize = 36,
		this.onChange,
		this.interactive = false,
		this.highlightedTeeth = const [],
	});

	@override
	State<Odontogram> createState() => _OdontogramState();

}

class _OdontogramState extends State<Odontogram> {
	late Set<String> _selected;

	@override
	void initState() {
		super.initState();
		_selected = widget.highlightedTeeth.toSet();
	}

	@override
	void didUpdateWidget(covariant Odontogram oldWidget) {
		super.didUpdateWidget(oldWidget);
		// Keep internal selection in sync with highlighted list from parent
		if (oldWidget.highlightedTeeth.join(',') != widget.highlightedTeeth.join(',')) {
			_selected = widget.highlightedTeeth.toSet();
		}
	}

	void _handleChange(List<String> now) {
		final before = _selected;
		final nowSet = now.toSet();
		// detect newly selected tooth (tap)
		final newlySelected = nowSet.difference(before);
		_selected = nowSet;
		widget.onChange?.call(now);
		if (newlySelected.isNotEmpty) {
			final tooth = newlySelected.first;
			_openToothDetails(context, tooth);
		}
	}

	@override
	Widget build(BuildContext context) {
			// Build per-tooth summaries from patient's historical sessions
		final summaries = _summarizePatientTeeth(widget.patient);
			final doneSet = summaries.entries.where((e) => e.value.doneCount > 0).map((e) => e.key).toSet();
			final criticalFindings = summaries.entries.where((e) => e.value.hasCriticalFinding).map((e) => e.key).toSet();
			final anyFindings = summaries.entries.where((e) => e.value.findingsCount > 0 && !e.value.hasCriticalFinding).map((e) => e.key).toSet();

			// Visual encoding
			final colorize = <String, Color>{
				for (final t in doneSet) t: Colors.green.shade400,
			};
				final strokedColorized = <String, Color>{
				for (final t in anyFindings) t: Colors.orangeAccent,
				for (final t in criticalFindings) t: Colors.redAccent,
			};
				final strokeWidth = <String, double>{
					for (final t in anyFindings) t: 3.0,
					for (final t in criticalFindings) t: 3.8,
				};
				// Overlay current Rx highlight as a thicker primary stroke
				for (final t in widget.highlightedTeeth) {
					strokedColorized[t] = Theme.of(context).colorScheme.primary;
					strokeWidth[t] = 4.2;
				}

			// Tooltip content per tooth (shown via the notation string)
			final tooltipByTooth = <String, String>{
				for (final e in summaries.entries) e.key: e.value.tooltipLabel(),
			};

			return Card(
			elevation: 2,
			clipBehavior: Clip.antiAlias,
			child: Padding(
					padding: widget.padding,
				child: Column(
					crossAxisAlignment: CrossAxisAlignment.start,
					children: [
						Row(children: [
							const Icon(Icons.monitor_heart_outlined, size: 20),
							const SizedBox(width: 8),
							Text('Odontogram', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
						]),
						const SizedBox(height: 8),
									Center(
							child: IgnorePointer(
									ignoring: !widget.interactive,
												child: TeethSelector(
										key: ValueKey('teeth-${widget.highlightedTeeth.join(',')}'),
										onChange: _handleChange,
									showPermanent: true,
									showPrimary: true,
									multiSelect: true,
										// Preselect/highlight the provided FDI teeth (ISO/FDI codes)
										initiallySelected: widget.highlightedTeeth,
																	// Visual coding (requires README version of the package)
																						colorized: colorize,
																						StrokedColorized: strokedColorized,
																	strokeWidth: strokeWidth,
												  defaultStrokeWidth: 1.3,
												  defaultStrokeColor: Theme.of(context).colorScheme.outline.withOpacity(0.7),
																						// Keep fill unchanged for selection; rely on strokes + colorized for meaning
																						selectedColor: Colors.transparent,
												  unselectedColor: Theme.of(context).colorScheme.surface,
										// Tooltip label builder
										notation: (iso) => tooltipByTooth[iso] ?? iso,
								),
							),
						),
										const SizedBox(height: 8),
										// Compact legend chips to show Findings/Done teeth when per-tooth coloring is unavailable
										if (anyFindings.isNotEmpty || criticalFindings.isNotEmpty || doneSet.isNotEmpty)
											Center(
												child: Wrap(
													alignment: WrapAlignment.center,
													spacing: 6,
													runSpacing: 6,
													children: [
														if (doneSet.isNotEmpty)
															_legendGroup(context, 'Done', doneSet.toList()..sort(), Colors.green.shade400),
														if (anyFindings.isNotEmpty)
															_legendGroup(context, 'Findings', anyFindings.toList()..sort(), Colors.orangeAccent),
														if (criticalFindings.isNotEmpty)
															_legendGroup(context, 'Urgent', criticalFindings.toList()..sort(), Colors.redAccent),
													],
												),
											),
					],
				),
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
																	Icon(Icons.event, size: 18),
																	const SizedBox(width: 6),
																	Text(_fmtDate(r.date), style: Theme.of(context).textTheme.titleSmall),
																]),
																if (r.chiefComplaint.isNotEmpty) ...[
																	const SizedBox(height: 8),
																	Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
																		const SizedBox(width: 2),
																		Icon(Icons.report_problem_outlined, size: 18),
																		const SizedBox(width: 6),
																		Expanded(child: Text(r.chiefComplaint)),
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

	Map<String, _ToothSummary> _summarizePatientTeeth(Patient p) {
		final map = <String, _ToothSummary>{};
		_ToothSummary sum(String t) => map[t] ??= _ToothSummary();

		bool isCritical(String s) {
			final x = s.toLowerCase();
			return x.contains('swelling') || x.contains('abscess') || x.contains('severe') || x.contains('acute') || x.contains('sinus');
		}

		for (final s in p.sessions) {
			for (final f in s.oralExamFindings) {
				final t = f.toothNumber.trim(); if (t.isEmpty) continue;
				final sm = sum(t);
				sm.findingsCount += 1;
				sm.lastFinding = f.finding;
				if (isCritical(f.finding)) sm.hasCriticalFinding = true;
			}
			for (final f in s.rootCanalFindings) {
				final t = f.toothNumber.trim(); if (t.isEmpty) continue;
				final sm = sum(t);
				sm.findingsCount += 1;
				sm.lastFinding = f.finding;
				if (isCritical(f.finding)) sm.hasCriticalFinding = true;
			}
			for (final f in s.prosthodonticFindings) {
				final t = f.toothNumber.trim(); if (t.isEmpty) continue;
				final sm = sum(t);
				sm.findingsCount += 1;
				sm.lastFinding = f.finding;
				if (isCritical(f.finding)) sm.hasCriticalFinding = true;
			}
			for (final d in s.treatmentsDone) {
				final t = d.toothNumber.trim(); if (t.isEmpty) continue;
				final sm = sum(t);
				sm.doneCount += 1;
				sm.lastDone = d.treatment;
			}
		}

		return map;
	}

		Color _darken(Color color, [double amount = 0.1]) {
			final hsl = HSLColor.fromColor(color);
			final lightness = (hsl.lightness - amount).clamp(0.0, 1.0);
			return hsl.withLightness(lightness).toColor();
		}

			String _fmtDate(DateTime d) => '${d.year}-${d.month.toString().padLeft(2,'0')}-${d.day.toString().padLeft(2,'0')}';

		class _ToothRecord {
			final DateTime date;
			final String chiefComplaint;
			final List<String> plans;
			final List<String> done;
			_ToothRecord(this.date, this.chiefComplaint, this.plans, this.done);
		}

		List<_ToothRecord> _recordsForTooth(Patient p, String iso) {
			final recs = <_ToothRecord>[];
			for (final s in p.sessions) {
				final plans = <String>[];
				final done = <String>[];
				// collect plans for this tooth across categories
				for (final e in s.toothPlans) {
					if (e.toothNumber.trim() == iso) plans.add(e.plan);
				}
				for (final e in s.rootCanalPlans) {
					if (e.toothNumber.trim() == iso) plans.add(e.plan);
				}
				for (final e in s.prosthodonticPlans) {
					if (e.toothNumber.trim() == iso) plans.add(e.plan);
				}
				// done entries
				for (final d in s.treatmentsDone) {
					if (d.toothNumber.trim() == iso) done.add(d.treatment);
				}
				if (plans.isNotEmpty || done.isNotEmpty) {
					final cc = s.chiefComplaint?.complaints.join(', ') ?? '';
					recs.add(_ToothRecord(s.date, cc, plans, done));
				}
			}
			// most recent first
			recs.sort((a, b) => b.date.compareTo(a.date));
			return recs;
		}

