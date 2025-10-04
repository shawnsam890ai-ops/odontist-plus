import 'package:flutter/material.dart';

/// Simple reusable multi-select dropdown using a dialog with checkboxes.
class MultiSelectDropdown extends StatefulWidget {
  final List<String> options;
  final List<String> initialSelected;
  final String label;
  final ValueChanged<List<String>> onChanged;
  const MultiSelectDropdown({
    super.key,
    required this.options,
    required this.initialSelected,
    required this.label,
    required this.onChanged,
  });

  @override
  State<MultiSelectDropdown> createState() => _MultiSelectDropdownState();
}

class _MultiSelectDropdownState extends State<MultiSelectDropdown> {
  late List<String> _selected;

  @override
  void initState() {
    super.initState();
    _selected = List.from(widget.initialSelected);
  }

  @override
  void didUpdateWidget(covariant MultiSelectDropdown oldWidget) {
    super.didUpdateWidget(oldWidget);
    // sync if external list length changed
    if (oldWidget.initialSelected.length != widget.initialSelected.length) {
      _selected = List.from(widget.initialSelected);
    }
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: _openDialog,
      child: InputDecorator(
        decoration: InputDecoration(labelText: widget.label, border: const OutlineInputBorder()),
        child: Wrap(
          spacing: 6,
          runSpacing: -4,
          children: _selected.isEmpty
              ? [Text('None', style: Theme.of(context).textTheme.bodySmall)]
              : _selected.map((e) => Chip(label: Text(e), materialTapTargetSize: MaterialTapTargetSize.shrinkWrap)).toList(),
        ),
      ),
    );
  }

  Future<void> _openDialog() async {
    final temp = List<String>.from(_selected);
    final result = await showDialog<List<String>>(
        context: context,
        builder: (_) => StatefulBuilder(builder: (ctx, localSet) {
              void refresh() => localSet(() {});
              return AlertDialog(
                title: Text(widget.label),
                content: SizedBox(
                  width: 320,
                  child: ListView(
                    shrinkWrap: true,
                    children: [
                      Row(
                        children: [
                          TextButton(
                              onPressed: () {
                                temp
                                  ..clear()
                                  ..addAll(widget.options);
                                refresh();
                              },
                              child: const Text('Select All')),
                          const SizedBox(width: 8),
                          TextButton(
                              onPressed: () {
                                temp.clear();
                                refresh();
                              },
                              child: const Text('Clear')),
                        ],
                      ),
                      for (final o in widget.options)
                        ListTile(
                          dense: true,
                          leading: Icon(
                            temp.contains(o) ? Icons.check_circle : Icons.radio_button_unchecked,
                            color: temp.contains(o) ? Colors.green : null,
                          ),
                          title: Text(o),
                          onTap: () {
                            if (temp.contains(o)) {
                              temp.remove(o);
                            } else {
                              temp.add(o);
                            }
                            refresh();
                          },
                        )
                    ],
                  ),
                ),
                actions: [
                  TextButton(onPressed: () => Navigator.pop(ctx, null), child: const Text('Cancel')),
                  ElevatedButton(onPressed: () => Navigator.pop(ctx, temp), child: const Text('Done')),
                ],
              );
            }));
    if (result != null) {
      setState(() => _selected = result);
      widget.onChanged(_selected);
    }
  }
}
