export 'odontogram_new.dart';
/* legacy disabled below
	import 'package:teeth_selector/teeth_selector.dart';
	import '../../models/patient.dart';

	/// Interactive odontogram with 3D enamel fill under TeethSelector overlays.
	class Odontogram extends StatefulWidget {
	  final Patient patient;
	  final EdgeInsets padding;
	  final double toothSize;
	  final void Function(List<String> selected)? onChange;
	  final bool interactive;
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

	    return Card(
	      elevation: 2,
	      clipBehavior: Clip.antiAlias,
	      color: Theme.of(context).colorScheme.surfaceVariant,
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
						  defaultStrokeWidth: 1.2,
*/
