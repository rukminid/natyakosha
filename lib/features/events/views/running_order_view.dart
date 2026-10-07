import 'package:flutter/material.dart';
import 'package:flutter_redux/flutter_redux.dart';

import '../../../core/theme/app_theme.dart';
import '../../../data/models/event_item.dart';
import '../../../redux/state/app_state.dart';
import '../../../shared/widgets/common_widgets.dart';
import '../view_models/running_order_view_model.dart';
import 'song_form_sheet.dart';

/// An event's songs in performance order. Staff drag to reorder and add,
/// edit or delete songs; everyone else sees a read-only list.
class RunningOrderView extends StatelessWidget {
  const RunningOrderView({super.key, required this.eventId});

  final String eventId;

  Future<void> _edit(BuildContext context, RunningOrderViewModel vm, [EventItem? item]) async {
    final result = await showModalBottomSheet<EventItem>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => SongFormSheet(item: item, dancers: vm.dancers),
    );
    if (result == null || !context.mounted) return;
    final error = await vm.save(result);
    if (context.mounted && error != null) showSnack(context, error, error: true);
  }

  Future<void> _confirmDelete(BuildContext context, RunningOrderViewModel vm, EventItem item) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete this song?'),
        content: Text('“${item.songName}” will be removed from the running order.'),
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
    final error = await vm.delete(item);
    if (context.mounted && error != null) showSnack(context, error, error: true);
  }

  Future<void> _onReorder(BuildContext context, RunningOrderViewModel vm, int from, int to) async {
    if (from == to) return;
    final list = [...vm.items];
    list.insert(to, list.removeAt(from));
    final error = await vm.reorder(list);
    if (context.mounted && error != null) showSnack(context, error, error: true);
  }

  @override
  Widget build(BuildContext context) {
    return StoreConnector<AppState, RunningOrderViewModel>(
      ignoreChange: (s) => s.auth.user == null,
      converter: (store) => RunningOrderViewModel.fromStore(store, eventId),
      distinct: true,
      onInit: (store) => RunningOrderViewModel.fromStore(store, eventId).refresh(),
      builder: (context, vm) {
        final event = vm.event;
        if (event == null) {
          return Scaffold(
            appBar: AppBar(),
            body: const EmptyState(icon: Icons.event_busy, title: 'Event not found'),
          );
        }
        return Scaffold(
          appBar: AppBar(title: Text(event.title, overflow: TextOverflow.ellipsis)),
          floatingActionButton: vm.isStaff
              ? FloatingActionButton.extended(
                  onPressed: () => _edit(context, vm),
                  icon: const Icon(Icons.add),
                  label: const Text('Add song'),
                )
              : null,
          body: _body(context, vm),
        );
      },
    );
  }

  Widget _body(BuildContext context, RunningOrderViewModel vm) {
    if (vm.items.isEmpty) {
      if (vm.loading) return const Center(child: CircularProgressIndicator());
      if (vm.error != null) return ErrorRetry(message: vm.error!, onRetry: vm.refresh);
      return EmptyState(
        icon: Icons.format_list_numbered,
        title: 'No songs yet',
        message: vm.isStaff
            ? 'Tap “Add song” to build the running order.'
            : 'Your guru will add the songs soon.',
      );
    }
    final bottom = vm.isStaff ? 88.0 : 24.0;
    if (!vm.isStaff) {
      return RefreshIndicator(
        onRefresh: vm.refresh,
        child: ListView.builder(
          padding: EdgeInsets.fromLTRB(16, 8, 16, bottom),
          itemCount: vm.items.length,
          itemBuilder: (_, i) => _SongCard(vm: vm, item: vm.items[i]),
        ),
      );
    }
    return ReorderableListView.builder(
      padding: EdgeInsets.fromLTRB(16, 8, 16, bottom),
      itemCount: vm.items.length,
      onReorderItem: (from, to) => _onReorder(context, vm, from, to),
      itemBuilder: (_, i) {
        final item = vm.items[i];
        return _SongCard(
          key: ValueKey(item.id),
          vm: vm,
          item: item,
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              PopupMenuButton<String>(
                onSelected: (v) =>
                    v == 'edit' ? _edit(context, vm, item) : _confirmDelete(context, vm, item),
                itemBuilder: (_) => const [
                  PopupMenuItem(value: 'edit', child: Text('Edit')),
                  PopupMenuItem(value: 'delete', child: Text('Delete')),
                ],
              ),
              ReorderableDragStartListener(
                index: i,
                child: const Padding(
                  padding: EdgeInsets.all(8),
                  child: Icon(Icons.drag_handle),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _SongCard extends StatelessWidget {
  const _SongCard({super.key, required this.vm, required this.item, this.trailing});

  final RunningOrderViewModel vm;
  final EventItem item;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final details = [
      if (item.itemType != null) item.itemType!,
      if (item.raga != null) 'Raga ${item.raga}',
      if (item.tala != null) '${item.tala} tala',
      if (item.composer != null) item.composer!,
      if (item.durationMinutes != null) '${item.durationMinutes} min',
    ].join(' · ');
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 4, 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(radius: 16, child: Text('${item.order}')),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(item.songName, style: theme.textTheme.titleMedium),
                  if (details.isNotEmpty)
                    Text(details, style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey)),
                  if (item.performerIds.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 0,
                      children: [
                        for (final id in item.performerIds)
                          Chip(
                            label: Text(vm.nameOf(id)),
                            visualDensity: VisualDensity.compact,
                            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            if (trailing != null) trailing!,
          ],
        ),
      ),
    );
  }
}
