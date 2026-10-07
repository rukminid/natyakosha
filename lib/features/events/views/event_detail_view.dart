import 'package:flutter/material.dart';
import 'package:flutter_redux/flutter_redux.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/router/routes.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/dance_event.dart';
import '../../../redux/state/app_state.dart';
import '../../../shared/widgets/common_widgets.dart';
import '../view_models/events_view_model.dart';
import 'event_card.dart';

final _rupees = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);

/// One event: schedule, venue, fee and dancers. Staff can edit or delete.
class EventDetailView extends StatelessWidget {
  const EventDetailView({super.key, required this.eventId});

  final String eventId;

  Future<void> _confirmDelete(BuildContext context, EventDetailViewModel vm, DanceEvent event) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete this event?'),
        content: Text('“${event.title}”, its dancer group and fee records will be removed. This cannot be undone.'),
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
    final error = await vm.delete(event);
    if (!context.mounted) return;
    if (error != null) {
      showSnack(context, error, error: true);
      return;
    }
    showSnack(context, 'Event deleted');
    context.pop();
  }

  @override
  Widget build(BuildContext context) {
    return StoreConnector<AppState, EventDetailViewModel>(
      ignoreChange: (s) => s.auth.user == null,
      converter: (store) => EventDetailViewModel.fromStore(store, eventId),
      distinct: true,
      onInit: (store) {
        final vm = EventDetailViewModel.fromStore(store, eventId);
        if (vm.isStaff) vm.loadStudents();
      },
      builder: (context, vm) {
        final e = vm.event;
        if (e == null) {
          return Scaffold(
            appBar: AppBar(),
            body: const EmptyState(icon: Icons.event_busy, title: 'Event not found'),
          );
        }
        final theme = Theme.of(context);
        final byId = {for (final s in vm.students) s.id: s.name};
        final iAmIn = e.participantIds.contains(vm.userId);

        return Scaffold(
          appBar: AppBar(
            title: const Text('Event'),
            actions: [
              if (vm.isStaff) ...[
                IconButton(
                  tooltip: 'Edit',
                  icon: const Icon(Icons.edit_outlined),
                  onPressed: () => context.push(Routes.eventEdit(e.id)),
                ),
                IconButton(
                  tooltip: 'Delete',
                  icon: const Icon(Icons.delete_outline),
                  onPressed: () => _confirmDelete(context, vm, e),
                ),
              ],
            ],
          ),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
            children: [
              Text(e.title, style: theme.textTheme.headlineSmall),
              if (iAmIn) ...[
                const SizedBox(height: 8),
                const Align(
                  alignment: Alignment.centerLeft,
                  child: StatusChip(label: 'You are performing', color: AppColors.success),
                ),
              ],
              const SizedBox(height: 16),
              Card(
                child: Column(
                  children: [
                    _Info(Icons.event_outlined, eventDateFormat.format(e.date)),
                    _Info(Icons.schedule, eventTimeRange(e)),
                    _Info(Icons.place_outlined, e.venue),
                    if (e.organiser != null) _Info(Icons.groups_2_outlined, 'Organiser: ${e.organiser}'),
                  ],
                ),
              ),
              if (e.description != null) ...[
                const SizedBox(height: 16),
                Text('Notes', style: theme.textTheme.titleMedium),
                const SizedBox(height: 4),
                Text(e.description!),
              ],
              if (e.fee != null) ...[
                const SizedBox(height: 16),
                Card(
                  color: AppColors.gold.withValues(alpha: 0.15),
                  child: Column(
                    children: [
                      _Info(Icons.currency_rupee, '${_rupees.format(e.fee!.amount)} per dancer'),
                      _Info(Icons.event_available_outlined, 'Pay by ${eventDateFormat.format(e.fee!.dueDate)}'),
                      if (e.fee!.upiId != null) _Info(Icons.account_balance_wallet_outlined, 'UPI: ${e.fee!.upiId}'),
                      if (e.fee!.description != null) _Info(Icons.sell_outlined, e.fee!.description!),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 16),
              Card(
                child: ListTile(
                  leading: const Icon(Icons.format_list_numbered),
                  title: const Text('Running order'),
                  subtitle: const Text('Songs and who performs them'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.push(Routes.eventOrder(e.id)),
                ),
              ),
              const SizedBox(height: 16),
              Text('Dancers (${e.totalParticipants})', style: theme.textTheme.titleMedium),
              const SizedBox(height: 8),
              if (e.participantIds.isEmpty)
                Text('No dancers added yet.', style: theme.textTheme.bodyMedium?.copyWith(color: Colors.grey))
              else if (vm.isStaff)
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: [
                    for (final id in e.participantIds) Chip(label: Text(byId[id] ?? '…')),
                  ],
                )
              else
                Text(
                  'Names are visible to your guru and teachers.',
                  style: theme.textTheme.bodyMedium?.copyWith(color: Colors.grey),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _Info extends StatelessWidget {
  const _Info(this.icon, this.text);
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) => ListTile(
        dense: true,
        leading: Icon(icon, color: AppColors.maroon),
        title: Text(text),
      );
}
