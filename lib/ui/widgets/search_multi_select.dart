import 'package:flutter/material.dart';

class SearchMultiSelect extends StatefulWidget {
  final List<String> options;
  final List<String> initial;
  final String label;
  final ValueChanged<List<String>> onChanged;
  final bool enableSearch;
  const SearchMultiSelect({super.key, required this.options, required this.initial, required this.label, required this.onChanged, this.enableSearch = true});

  @override
  State<SearchMultiSelect> createState() => _SearchMultiSelectState();
}

class _SearchMultiSelectState extends State<SearchMultiSelect> {
  late List<String> _selected;
  String _query = '';
  @override
  void initState() { super.initState(); _selected = List.from(widget.initial); }

  @override
  void didUpdateWidget(covariant SearchMultiSelect oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_equals(oldWidget.initial, widget.initial)) {
      _selected = List.from(widget.initial);
    }
  }

  bool _equals(List<String> a, List<String> b) {
    if (a.length != b.length) return false;
    for (int i=0;i<a.length;i++){ if(a[i]!=b[i]) return false; }
    return true;
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
        builder: (_) => StatefulBuilder(builder: (ctx, setStateDialog) {
              final filtered = widget.options.where((o) => o.toLowerCase().contains(_query.toLowerCase())).toList();
              return AlertDialog(
                title: Text(widget.label),
                content: SizedBox(
                  width: 350,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (widget.enableSearch)
                        TextField(
                          decoration: const InputDecoration(prefixIcon: Icon(Icons.search), hintText: 'Search'),
                          onChanged: (v) => setStateDialog(() => _query = v),
                        ),
                      const SizedBox(height: 8),
                      Expanded(
                        child: ListView(
                          children: [
                            Row(children: [
                              TextButton(onPressed: () {
                                temp
                                  ..clear()
                                  ..addAll(widget.options);
                                setStateDialog((){});
                              }, child: const Text('All')),
                              const SizedBox(width:8),
                              TextButton(onPressed: () {
                                temp.clear();
                                setStateDialog((){});
                              }, child: const Text('Clear')),
                            ]),
                            for (final o in filtered)
                              CheckboxListTile(
                                dense: true,
                                value: temp.contains(o),
                                onChanged: (_){
                                  if (temp.contains(o)) {
                                    temp.remove(o);
                                  } else {
                                    temp.add(o);
                                  }
                                  setStateDialog((){});
                                },
                                title: Text(o),
                              )
                          ],
                        ),
                      )
                    ],
                  ),
                ),
                actions: [
                  TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
                  ElevatedButton(onPressed: () => Navigator.pop(ctx, temp), child: const Text('Done')),
                ],
              );
            }));
    if (result != null) { setState(() => _selected = result); widget.onChanged(_selected); }
  }
}