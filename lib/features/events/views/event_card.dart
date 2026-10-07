import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/router/routes.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/dance_event.dart';

final eventDateFormat = DateFormat('EEE, d MMM yyyy');
final eventTimeFormat = DateFormat('h:mm a');

/// "5:00 PM – 7:30 PM", or just the start when there is no end time.
String eventTimeRange(DanceEvent e) {
  final start = eventTimeFormat.format(e.date);
  return e.endsAt == null ? start : '$start – ${eventTimeFormat.format(e.endsAt!)}';
}

class EventCard extends StatelessWidget {
  const EventCard({super.key, required this.event, this.showDate = true});

  final DanceEvent event;

  /// The calendar already shows the day, so it hides the date line.
  final bool showDate;

  @override
  Widget build(BuildContext context) {
    final fee = event.fee;
    return Card(
      child: ListTile(
        onTap: () => context.push(Routes.eventDetail(event.id)),
        leading: const CircleAvatar(
          backgroundColor: AppColors.maroon,
          child: Icon(Icons.theater_comedy, color: AppColors.gold),
        ),
        title: Text(event.title),
        subtitle: Text(
          '${showDate ? '${eventDateFormat.format(event.date)} · ' : ''}${eventTimeRange(event)}\n'
          '${event.venue}${fee != null ? ' · Fee ₹${fee.amount.toStringAsFixed(0)}' : ''}',
        ),
        isThreeLine: true,
        trailing: Text('${event.totalParticipants}\ndancers', textAlign: TextAlign.center),
      ),
    );
  }
}
