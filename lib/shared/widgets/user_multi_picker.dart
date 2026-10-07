import 'package:flutter/material.dart';

import 'common_widgets.dart';

/// One row in [UserMultiPicker].
class PickerOption {
  const PickerOption(this.id, this.name);
  final String id;
  final String name;
}

/// Bottom sheet with a checkbox per person and Select all / Clear.
/// Pops with the set of picked ids when "Done" is tapped.
class UserMultiPicker extends StatefulWidget {
  const UserMultiPicker({
    super.key,
    required this.title,
    required this.options,
    required this.initial,
    this.emptyTitle = 'Nobody to choose from',
    this.emptyMessage,
  });

  final String title;
  final List<PickerOption> options;
  final Set<String> initial;
  final String emptyTitle;
  final String? emptyMessage;

  @override
  State<UserMultiPicker> createState() => _UserMultiPickerState();
}

class _UserMultiPickerState extends State<UserMultiPicker> {
  late final Set<String> _picked = {...widget.initial};

  @override
  Widget build(BuildContext context) {
    final all = widget.options;
    final allPicked = all.isNotEmpty && all.every((o) => _picked.contains(o.id));
    return SafeArea(
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.7,
        child: Column(
          children: [
            ListTile(
              title: Text('${widget.title} (${_picked.length})'),
              trailing: TextButton(
                onPressed: all.isEmpty
                    ? null
                    : () => setState(() {
                          if (allPicked) {
                            _picked.clear();
                          } else {
                            _picked.addAll(all.map((o) => o.id));
                          }
                        }),
                child: Text(allPicked ? 'Clear' : 'Select all'),
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: all.isEmpty
                  ? EmptyState(
                      icon: Icons.groups_outlined,
                      title: widget.emptyTitle,
                      message: widget.emptyMessage,
                    )
                  : ListView(
                      children: [
                        for (final o in all)
                          CheckboxListTile(
                            value: _picked.contains(o.id),
                            title: Text(o.name),
                            onChanged: (on) =>
                                setState(() => on == true ? _picked.add(o.id) : _picked.remove(o.id)),
                          ),
                      ],
                    ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: FilledButton(
                onPressed: () => Navigator.pop(context, _picked),
                child: const Text('Done'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
