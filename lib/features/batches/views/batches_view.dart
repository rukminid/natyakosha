import 'package:flutter/material.dart';
import 'package:flutter_redux/flutter_redux.dart';
import 'package:flutter/services.dart';

import '../../../core/theme/app_theme.dart';
import '../../../data/models/batch.dart';
import '../../../redux/state/app_state.dart';
import '../../../shared/widgets/common_widgets.dart';
import '../../../shared/widgets/user_multi_picker.dart';
import '../view_models/batches_view_model.dart';

/// Class batches: add, edit, delete and choose their students. Staff only.
class BatchesView extends StatelessWidget {
  const BatchesView({super.key});

  Future<void> _edit(BuildContext context, BatchesViewModel vm, [Batch? batch]) async {
    final result = await showModalBottomSheet<Batch>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _BatchSheet(batch: batch),
    );
    if (result == null || !context.mounted) return;
    final error = await vm.save(result);
    if (!context.mounted) return;
    showSnack(context, error ?? (batch == null ? 'Batch added' : 'Batch updated'), error: error != null);
  }

  Future<void> _pickMembers(BuildContext context, BatchesViewModel vm, Batch batch) async {
    final picked = await showModalBottomSheet<Set<String>>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => UserMultiPicker(
        title: 'Students in ${batch.name}',
        options: [for (final s in vm.students) PickerOption(s.id, s.name)],
        initial: {for (final s in vm.membersOf(batch)) s.id},
        emptyTitle: 'No approved students yet',
        emptyMessage: 'Add students or approve join requests first.',
      ),
    );
    if (picked == null || !context.mounted) return;
    final error = await vm.setMembers(batch, picked);
    if (!context.mounted) return;
    showSnack(context, error ?? 'Batch updated', error: error != null);
  }

  Future<void> _confirmDelete(BuildContext context, BatchesViewModel vm, Batch batch) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete this batch?'),
        content: Text('“${batch.name}” is removed and its students become unassigned. '
            'Past attendance for the batch is kept.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.danger),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    final error = await vm.delete(batch);
    if (!context.mounted) return;
    showSnack(context, error ?? 'Batch deleted', error: error != null);
  }

  @override
  Widget build(BuildContext context) {
    return StoreConnector<AppState, BatchesViewModel>(
      ignoreChange: (s) => s.auth.user == null,
      converter: BatchesViewModel.fromStore,
      distinct: true,
      onInit: (store) {
        final vm = BatchesViewModel.fromStore(store);
        if (vm.isStaff) vm.refresh();
      },
      builder: (context, vm) {
        if (!vm.isStaff) {
          return Scaffold(
            appBar: AppBar(title: const Text('Batches')),
            body: const EmptyState(icon: Icons.lock_outline, title: 'Only for guru and teachers'),
          );
        }
        return Scaffold(
          appBar: AppBar(title: const Text('Batches')),
          floatingActionButton: FloatingActionButton.extended(
            onPressed: () => _edit(context, vm),
            icon: const Icon(Icons.add),
            label: const Text('New batch'),
          ),
          body: RefreshIndicator(
            onRefresh: vm.refresh,
            child: vm.batches.isEmpty
                ? ListView(
                    children: [
                      if (vm.loading) const LinearProgressIndicator(minHeight: 2),
                      if (vm.error != null)
                        ErrorRetry(message: vm.error!, onRetry: vm.refresh)
                      else if (!vm.loading)
                        const SizedBox(
                          height: 360,
                          child: EmptyState(
                            icon: Icons.layers_outlined,
                            title: 'No batches yet',
                            message: 'Group your students into classes like “Beginners – Sat 5pm”, '
                                'then take attendance for each batch.',
                          ),
                        ),
                    ],
                  )
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 88),
                    itemCount: vm.batches.length,
                    itemBuilder: (_, i) {
                      final b = vm.batches[i];
                      final count = vm.membersOf(b).length;
                      final details = [
                        if (b.level != null) b.level!,
                        if (b.timing != null) b.timing!,
                        if (b.monthlyFee != null) '₹${b.monthlyFee!.toStringAsFixed(b.monthlyFee! % 1 == 0 ? 0 : 2)}/month',
                      ].join(' · ');
                      return Card(
                        child: ListTile(
                          onTap: () => _pickMembers(context, vm, b),
                          title: Text(b.name),
                          subtitle: Text([if (details.isNotEmpty) details, '$count ${count == 1 ? 'student' : 'students'}'].join('\n')),
                          isThreeLine: details.isNotEmpty,
                          trailing: PopupMenuButton<String>(
                            onSelected: (v) => switch (v) {
                              'students' => _pickMembers(context, vm, b),
                              'edit' => _edit(context, vm, b),
                              _ => _confirmDelete(context, vm, b),
                            },
                            itemBuilder: (_) => const [
                              PopupMenuItem(value: 'students', child: Text('Choose students')),
                              PopupMenuItem(value: 'edit', child: Text('Edit')),
                              PopupMenuItem(value: 'delete', child: Text('Delete')),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        );
      },
    );
  }
}

class _BatchSheet extends StatefulWidget {
  const _BatchSheet({this.batch});

  final Batch? batch;

  @override
  State<_BatchSheet> createState() => _BatchSheetState();
}

class _BatchSheetState extends State<_BatchSheet> {
  final _formKey = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.batch?.name);
  late final _level = TextEditingController(text: widget.batch?.level);
  late final _timing = TextEditingController(text: widget.batch?.timing);
  late final _fee = TextEditingController(
    text: widget.batch?.monthlyFee == null
        ? null
        : widget.batch!.monthlyFee!.toStringAsFixed(widget.batch!.monthlyFee! % 1 == 0 ? 0 : 2),
  );

  @override
  void dispose() {
    for (final c in [_name, _level, _timing, _fee]) {
      c.dispose();
    }
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    Navigator.pop(
      context,
      Batch(
        id: widget.batch?.id ?? '',
        name: _name.text.trim(),
        level: _level.text.trim(),
        timing: _timing.text.trim(),
        monthlyFee: double.tryParse(_fee.text.trim()),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 0, 16, MediaQuery.of(context).viewInsets.bottom + 16),
      child: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(widget.batch == null ? 'New batch' : 'Edit batch', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 12),
              TextFormField(
                controller: _name,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(labelText: 'Batch name', hintText: 'Beginners – Sat 5pm'),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Enter a name' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _level,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(labelText: 'Level (optional)'),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _timing,
                decoration: const InputDecoration(labelText: 'Timing (optional)', hintText: 'Sat 5–6:30 pm'),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _fee,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
                decoration: const InputDecoration(labelText: 'Monthly fee (optional)', prefixIcon: Icon(Icons.currency_rupee)),
                validator: (v) {
                  final t = v?.trim() ?? '';
                  if (t.isEmpty) return null;
                  final n = double.tryParse(t);
                  return (n == null || n <= 0) ? 'Enter a valid amount' : null;
                },
              ),
              const SizedBox(height: 16),
              SizedBox(width: double.infinity, child: FilledButton(onPressed: _submit, child: const Text('Save batch'))),
            ],
          ),
        ),
      ),
    );
  }
}
