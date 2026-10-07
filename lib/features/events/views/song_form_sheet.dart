import 'package:flutter/material.dart';

import '../../../data/models/event_item.dart';
import '../../../data/models/member.dart';
import '../../../shared/widgets/user_multi_picker.dart';

/// Bottom sheet to add or edit one song. Pops with the edited [EventItem]
/// (its `order` is unchanged; the repository assigns the order for new songs).
class SongFormSheet extends StatefulWidget {
  const SongFormSheet({super.key, this.item, required this.dancers});

  final EventItem? item;

  /// Performers a song can pick from: the event's dancers.
  final List<Member> dancers;

  @override
  State<SongFormSheet> createState() => _SongFormSheetState();
}

class _SongFormSheetState extends State<SongFormSheet> {
  final _formKey = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.item?.songName);
  late final _type = TextEditingController(text: widget.item?.itemType);
  late final _raga = TextEditingController(text: widget.item?.raga);
  late final _tala = TextEditingController(text: widget.item?.tala);
  late final _composer = TextEditingController(text: widget.item?.composer);
  late final _minutes = TextEditingController(text: widget.item?.durationMinutes?.toString());
  late Set<String> _performers = {...?widget.item?.performerIds};

  @override
  void dispose() {
    for (final c in [_name, _type, _raga, _tala, _composer, _minutes]) {
      c.dispose();
    }
    super.dispose();
  }

  String? _text(TextEditingController c) {
    final t = c.text.trim();
    return t.isEmpty ? null : t;
  }

  Future<void> _pickPerformers() async {
    final result = await showModalBottomSheet<Set<String>>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => UserMultiPicker(
        title: 'Choose performers',
        options: [for (final d in widget.dancers) PickerOption(d.id, d.name)],
        initial: _performers,
        emptyTitle: 'No dancers on this event',
        emptyMessage: 'Add dancers to the event first, then pick who performs each song.',
      ),
    );
    if (result != null) setState(() => _performers = result);
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    final old = widget.item;
    // Keep only performers still on the event.
    final valid = widget.dancers.map((d) => d.id).toSet();
    Navigator.pop(
      context,
      EventItem(
        id: old?.id ?? '',
        order: old?.order ?? 0,
        songName: _name.text.trim(),
        itemType: _text(_type),
        raga: _text(_raga),
        tala: _text(_tala),
        composer: _text(_composer),
        durationMinutes: int.tryParse(_minutes.text.trim()),
        performerIds: _performers.where(valid.contains).toList(),
        audioUrl: old?.audioUrl,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final names = {for (final d in widget.dancers) d.id: d.name};
    final chosen = _performers.where(names.containsKey).toList();
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 0, 16, MediaQuery.of(context).viewInsets.bottom + 16),
      child: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(widget.item == null ? 'Add song' : 'Edit song',
                  style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 12),
              TextFormField(
                controller: _name,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(labelText: 'Song name'),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Enter the song name' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _type,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                    labelText: 'Item type (optional)', hintText: 'Pushpanjali, Tillana…'),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _raga,
                      textCapitalization: TextCapitalization.words,
                      decoration: const InputDecoration(labelText: 'Raga'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _tala,
                      textCapitalization: TextCapitalization.words,
                      decoration: const InputDecoration(labelText: 'Tala'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: TextFormField(
                      controller: _composer,
                      textCapitalization: TextCapitalization.words,
                      decoration: const InputDecoration(labelText: 'Composer'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _minutes,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Minutes'),
                      validator: (v) {
                        final t = v?.trim() ?? '';
                        if (t.isEmpty) return null;
                        final n = int.tryParse(t);
                        return (n == null || n <= 0 || n > 300) ? 'Invalid' : null;
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text('Performers (${chosen.length})', style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 4),
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: [for (final id in chosen) Chip(label: Text(names[id]!))],
              ),
              TextButton.icon(
                onPressed: _pickPerformers,
                icon: const Icon(Icons.group_add_outlined),
                label: Text(chosen.isEmpty ? 'Choose performers' : 'Change performers'),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: FilledButton(onPressed: _submit, child: const Text('Save song')),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
