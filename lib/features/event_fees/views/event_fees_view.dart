import 'package:flutter/material.dart';
import 'package:flutter_redux/flutter_redux.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/router/routes.dart';
import '../../../data/models/dance_event.dart';
import '../../../data/models/event_fee.dart';
import '../../../redux/state/app_state.dart';
import '../../../shared/widgets/common_widgets.dart';
import '../view_models/event_fee_view_models.dart';
import 'event_fee_detail_view.dart';

final _rupees = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);
final _day = DateFormat('d MMM yyyy');

/// Events that charge a fee. Staff open one to track who has paid;
/// students and parents open theirs to pay.
class EventFeesView extends StatelessWidget {
  const EventFeesView({super.key});

  @override
  Widget build(BuildContext context) {
    return StoreConnector<AppState, EventFeesViewModel>(
      ignoreChange: (s) => s.auth.user == null,
      converter: EventFeesViewModel.fromStore,
      distinct: true,
      onInit: (store) => EventFeesViewModel.fromStore(store).loadMine(),
      builder: (context, vm) => Scaffold(
        appBar: AppBar(title: const Text('Event fees')),
        body: vm.events.isEmpty
            ? EmptyState(
                icon: Icons.request_quote_outlined,
                title: 'No event fees',
                message: vm.isStaff
                    ? 'Add a fee when you create an event and it will show up here.'
                    : 'Fees for events you dance in will show up here.',
              )
            : RefreshIndicator(
                onRefresh: vm.loadMine,
                child: ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: vm.events.length,
                  itemBuilder: (_, i) => _EventFeeCard(event: vm.events[i], fees: vm.fees[vm.events[i].id] ?? const []),
                ),
              ),
      ),
    );
  }
}

class _EventFeeCard extends StatelessWidget {
  const _EventFeeCard({required this.event, required this.fees});

  final DanceEvent event;
  final List<EventFee> fees;

  @override
  Widget build(BuildContext context) {
    final fee = event.fee!;
    final theme = Theme.of(context);
    return Card(
      child: ListTile(
        onTap: () => context.push(Routes.eventFeeDetail(event.id)),
        title: Text(event.title),
        subtitle: Text('${_rupees.format(fee.amount)} per dancer · due ${_day.format(fee.dueDate)}'),
        trailing: fees.isEmpty
            ? const Icon(Icons.chevron_right)
            : Wrap(
                spacing: 4,
                children: [for (final f in fees) EventFeeStatusChip(status: f.status)],
              ),
        isThreeLine: false,
        titleTextStyle: theme.textTheme.titleMedium,
      ),
    );
  }
}
