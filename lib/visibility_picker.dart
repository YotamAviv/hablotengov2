import 'package:flutter/material.dart';

const _kVisOptions = [
  ('permissive', 'Permissive', Colors.green),
  ('standard',   'Standard',   Colors.orange),
  ('strict',     'Strict',     Colors.red),
];

class VisibilityPicker extends StatelessWidget {
  final String value;
  final ValueChanged<String> onChanged;
  final bool showLabels;

  const VisibilityPicker({
    super.key,
    required this.value,
    required this.onChanged,
    this.showLabels = true,
  });

  @override
  Widget build(BuildContext context) {
    final surface = Theme.of(context).colorScheme.surface;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: _kVisOptions.map(((String v, String label, Color color) rec) {
        final selected = value == rec.$1;
        final EdgeInsets padding = showLabels
            ? const EdgeInsets.symmetric(horizontal: 14, vertical: 8)
            : const EdgeInsets.symmetric(horizontal: 7, vertical: 6);
        return GestureDetector(
          onTap: () => onChanged(selected && !showLabels ? 'default' : rec.$1),
          child: Container(
            padding: padding,
            decoration: BoxDecoration(
              color: selected ? rec.$3 : surface,
              border: Border.all(color: selected ? rec.$3 : Colors.grey.shade300),
              borderRadius: BorderRadius.horizontal(
                left:  rec.$1 == 'permissive' ? const Radius.circular(20) : Radius.zero,
                right: rec.$1 == 'strict'     ? const Radius.circular(20) : Radius.zero,
              ),
            ),
            child: showLabels
                ? Text(
                    rec.$2,
                    style: TextStyle(
                      fontSize: 13,
                      color: selected ? Colors.white : Colors.grey.shade500,
                    ),
                  )
                : const SizedBox.shrink(),
          ),
        );
      }).toList(),
    );
  }
}

// ---------------------------------------------------------------------------

class VisibilityHelpButton extends StatelessWidget {
  const VisibilityHelpButton({super.key});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: () => _showHelp(context),
      child: const Padding(
        padding: EdgeInsets.symmetric(horizontal: 4, vertical: 2),
        child: Text('?',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.blueGrey)),
      ),
    );
  }

  void _showHelp(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Visibility levels'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _row(ctx, 'permissive', 'Permissive',
                'Anyone reachable in your network.'),
            _row(ctx, 'standard', 'Standard',
                '≤3 hops: 1 path. 4 hops: 2 paths. 5+: 3 paths.'),
            _row(ctx, 'strict', 'Strict',
                '≤2 hops: 1 path. 3 hops: 2 paths. 4+: 3 paths.'),
            _row(ctx, 'default', 'Default',
                'Uses your default visibility setting.'),
            const SizedBox(height: 10),
            const Text(
              'You have one default visibility setting that applies to all fields, '
              'but you can override it per field — for example: email on Permissive, phone on Strict.',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('OK')),
        ],
      ),
    );
  }

  Widget _row(BuildContext context, String visValue, String label, String description) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          VisibilityPicker(
            showLabels: false,
            value: visValue,
            onChanged: (_) {},
          ),
          const SizedBox(width: 10),
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                Text(description, style: const TextStyle(fontSize: 12, color: Colors.grey)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
