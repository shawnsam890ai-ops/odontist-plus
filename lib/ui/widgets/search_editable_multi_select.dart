import 'package:flutter/material.dart';

class SearchEditableMultiSelect extends StatefulWidget {
  final String label;
  final List<String> options;
  final List<String> initial;
  final ValueChanged<List<String>> onChanged;
  final Future<void> Function(String value)? onAdd;
  final Future<void> Function(String value)? onDelete;
  const SearchEditableMultiSelect({super.key, required this.label, required this.options, required this.initial, required this.onChanged, this.onAdd, this.onDelete});

  @override
  State<SearchEditableMultiSelect> createState() => _SearchEditableMultiSelectState();
}

class _SearchEditableMultiSelectState extends State<SearchEditableMultiSelect> {
  @override
  Widget build(BuildContext context) {
    final current = widget.initial; // always reflect external source of truth
    return InkWell(
      onTap: _openDialog,
      child: InputDecorator(
        decoration: InputDecoration(labelText: widget.label, border: const OutlineInputBorder()),
        child: Wrap(
          spacing: 6,
          runSpacing: -4,
          children: current.isEmpty
              ? [Text('None', style: Theme.of(context).textTheme.bodySmall)]
              : current.map((e) => Chip(label: Text(e), materialTapTargetSize: MaterialTapTargetSize.shrinkWrap)).toList(),
        ),
      ),
    );
  }

  Future<void> _openDialog() async {
    List<String> temp = List.from(widget.initial);
    final controller = TextEditingController();
    String query = '';
    final result = await showDialog<List<String>>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSB) {
          final filtered = widget.options.where((o) => o.toLowerCase().contains(query.toLowerCase())).toList();
          return AlertDialog(
            title: Text(widget.label),
            content: SizedBox(
              width: 380,
              height: 420,
              child: Column(
                children: [
                  TextField(
                    decoration: const InputDecoration(prefixIcon: Icon(Icons.search), hintText: 'Search'),
                    onChanged: (v) => setSB(() => query = v),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: controller,
                          decoration: const InputDecoration(hintText: 'Add new option'),
                          onSubmitted: (_) => _addNew(controller, setSB),
                        ),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        onPressed: () => _addNew(controller, setSB),
                        child: const Text('Add'),
                      )
                    ],
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: Column(
                      children: [
                        Row(children: [
                          TextButton(onPressed: () { temp..clear()..addAll(widget.options); setSB((){}); }, child: const Text('All')),
                          const SizedBox(width: 8),
                          TextButton(onPressed: () { temp.clear(); setSB((){}); }, child: const Text('Clear')),
                        ]),
                        const SizedBox(height:4),
                        Align(alignment: Alignment.centerLeft, child: Text('Tap to select. Use trash icon to delete.', style: Theme.of(context).textTheme.bodySmall)),
                        const SizedBox(height:4),
                        Expanded(
                          child: ListView.builder(
                            itemCount: filtered.length,
                            itemBuilder: (c,i){
                              final o = filtered[i];
                              final selected = temp.contains(o);
                              return ListTile(
                                dense: true,
                                leading: Checkbox(
                                  value: selected,
                                  onChanged: (_){
                                    if (selected) {
                                      temp.remove(o);
                                    } else {
                                      temp.add(o);
                                    }
                                    setSB((){});
                                  },
                                ),
                                title: Text(o),
                                trailing: widget.onDelete == null ? null : IconButton(
                                  icon: const Icon(Icons.delete, color: Colors.red),
                                  onPressed: () async {
                                    await widget.onDelete!(o);
                                    setSB((){ temp.remove(o); });
                                  },
                                ),
                                onTap: () {
                                  if (selected) {
                                    temp.remove(o);
                                  } else {
                                    temp.add(o);
                                  }
                                  setSB((){});
                                },
                              );
                            },
                          ),
                        )
                      ],
                    ),
                  )
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
              ElevatedButton(onPressed: () => Navigator.pop(ctx, temp), child: const Text('Done'))
            ],
          );
        },
      ),
    );
    if (result != null) {
      widget.onChanged(result); // parent rebuild controls display
    }
  }

  Future<void> _addNew(TextEditingController controller, void Function(void Function()) setSB) async {
    final value = controller.text.trim();
    if (value.isEmpty) return;
    if (widget.onAdd != null) {
      await widget.onAdd!(value);
    }
    controller.clear();
    setSB((){}); // refresh list
  }
}
