import 'package:equatable/equatable.dart';

import 'model_utils.dart';

/// Fee charged to every participant of an event (costume, travel, hall…).
class EventFeeConfig extends Equatable {
  const EventFeeConfig({
    required this.amount,
    required this.dueDate,
    this.description,
    this.upiId,
  });

  final double amount;
  final DateTime dueDate;
  final String? description;
  final String? upiId;

  factory EventFeeConfig.fromMap(Map<String, dynamic> map) => EventFeeConfig(
        amount: readDouble(map['amount']),
        dueDate: readDate(map['dueDate']) ?? DateTime.now(),
        description: map['description'] as String?,
        upiId: map['upiId'] as String?,
      );

  Map<String, dynamic> toMap() => {
        'amount': amount,
        'dueDate': writeTimestamp(dueDate),
        'description': description,
        'upiId': upiId,
      };

  @override
  List<Object?> get props => [amount, dueDate, description, upiId];
}

/// `schools/{schoolId}/events/{eventId}` — a performance, e.g. Ravindra Bharathi.
class DanceEvent extends Equatable {
  const DanceEvent({
    required this.id,
    required this.title,
    required this.date,
    required this.venue,
    this.endsAt,
    this.organiser,
    this.description,
    this.participantIds = const [],
    this.groupId,
    this.fee,
    this.coverUrl,
  });

  final String id;
  final String title;
  /// Start date and time.
  final DateTime date;

  /// Optional end time, for the schedule.
  final DateTime? endsAt;

  /// Venue typed as plain text (no maps), e.g. "Ravindra Bharathi, Hyderabad".
  final String venue;
  final String? organiser;
  final String? description;
  final List<String> participantIds;

  /// Group auto-created for this event's participants.
  final String? groupId;

  /// Null when the event has no participation fee.
  final EventFeeConfig? fee;
  final String? coverUrl;

  int get totalParticipants => participantIds.length;
  bool get isUpcoming => (endsAt ?? date).isAfter(DateTime.now());

  /// True when the event happens on the same calendar day as [day].
  bool isOn(DateTime day) => date.year == day.year && date.month == day.month && date.day == day.day;

  factory DanceEvent.fromMap(String id, Map<String, dynamic> map) => DanceEvent(
        id: id,
        title: map['title'] as String? ?? '',
        date: readDate(map['date']) ?? DateTime.now(),
        endsAt: readDate(map['endsAt']),
        venue: map['venue'] as String? ?? '',
        organiser: map['organiser'] as String?,
        description: map['description'] as String?,
        participantIds: readStringList(map['participantIds']),
        groupId: map['groupId'] as String?,
        fee: map['fee'] is Map<String, dynamic>
            ? EventFeeConfig.fromMap(map['fee'] as Map<String, dynamic>)
            : null,
        coverUrl: map['coverUrl'] as String?,
      );

  Map<String, dynamic> toMap() => {
        'title': title,
        'date': writeTimestamp(date),
        'endsAt': writeTimestamp(endsAt),
        'venue': venue,
        'organiser': organiser,
        'description': description,
        'participantIds': participantIds,
        'groupId': groupId,
        'fee': fee?.toMap(),
        'coverUrl': coverUrl,
      };

  @override
  List<Object?> get props =>
      [id, title, date, endsAt, venue, organiser, description, participantIds, groupId, fee, coverUrl];
}
