import 'package:flutter/material.dart';

class MultiSelectChip extends StatelessWidget {
  final List<String> options;
  final List<String> selected;
  final void Function(String value) onToggle;
  final String? title;
  const MultiSelectChip({super.key, required this.options, required this.selected, required this.onToggle, this.title});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (title != null) Text(title!, style: Theme.of(context).textTheme.labelLarge),
        Wrap(
          spacing: 6,
          children: options
              .map((o) => FilterChip(
                    label: Text(o),
                    selected: selected.contains(o),
                    onSelected: (_) => onToggle(o),
                  ))
              .toList(),
        )
      ],
    );
  }
}
