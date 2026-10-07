import 'package:equatable/equatable.dart';
import 'package:redux/redux.dart';

import '../../../data/models/dance_event.dart';
import '../../../data/models/event_fee.dart';
import '../../../redux/selectors/selectors.dart' as sel;
import '../../../redux/state/app_state.dart';
import '../../../redux/thunks/event_fee_thunks.dart' as thunks;

/// The Event fees list: events that charge a fee.
/// Staff see all of them; a student or parent sees the ones they take part in.
class EventFeesViewModel extends Equatable {
  const EventFeesViewModel({
    required this.events,
    required this.fees,
    required this.isStaff,
    required this.loadMine,
  });

  final List<DanceEvent> events;

  /// Loaded fees by event id (a student's own only).
  final Map<String, List<EventFee>> fees;
  final bool isStaff;

  /// Loads the signed-in student's own fee for every event in [events].
  final Future<void> Function() loadMine;

  static EventFeesViewModel fromStore(Store<AppState> store) {
    final state = store.state;
    final me = state.auth.user;
    final staff = sel.isStaff(state);
    final ids = me == null ? const <String>[] : thunks.feeStudentIds(me);
    final events = [
      for (final e in sel.eventsWithFee(state))
        if (staff || e.participantIds.any(ids.contains)) e,
    ];
    return EventFeesViewModel(
      events: events,
      fees: {for (final e in events) e.id: sel.feesForEvent(state, e.id)},
      isStaff: staff,
      loadMine: () async {
        if (staff) return;
        for (final e in events) {
          await thunks.loadEventFees(e.id)(store);
        }
      },
    );
  }

  @override
  List<Object?> get props => [events, fees, isStaff];
}

/// One event's fees: totals and per-student actions for staff, "my fee"
/// and upload for a student or parent.
class EventFeeDetailViewModel extends Equatable {
  const EventFeeDetailViewModel({
    required this.event,
    required this.fees,
    required this.loading,
    required this.error,
    required this.isStaff,
    required this.refresh,
    required this.update,
    required this.remind,
    required this.submitProof,
  });

  /// Null once the event was deleted (the screen then closes).
  final DanceEvent? event;
  final List<EventFee> fees;
  final bool loading;
  final String? error;
  final bool isStaff;

  final Future<void> Function() refresh;

  /// Each command returns an error message, or null on success.
  final Future<String?> Function(String studentId, {EventFeeStatus? status, double? amount}) update;
  final Future<String?> Function() remind;
  final Future<String?> Function(
    String studentId, {
    required String screenshotPath,
    String? upiTxnId,
    String? note,
    void Function(double progress)? onProgress,
  }) submitProof;

  sel.FeeSummary get summary => sel.summariseFees(fees);

  static EventFeeDetailViewModel fromStore(Store<AppState> store, String eventId) {
    final state = store.state;
    final slice = state.eventFees[eventId];
    return EventFeeDetailViewModel(
      event: sel.eventById(state, eventId),
      fees: sel.feesForEvent(state, eventId),
      loading: slice?.loading ?? false,
      error: slice?.error,
      isStaff: sel.isStaff(state),
      refresh: () => thunks.loadEventFees(eventId)(store),
      update: (studentId, {status, amount}) =>
          thunks.updateEventFee(eventId, studentId, status: status, amount: amount)(store),
      remind: () => thunks.remindPendingFees(eventId)(store),
      submitProof: (studentId, {required screenshotPath, upiTxnId, note, onProgress}) =>
          thunks.submitEventFeeProof(
            eventId,
            studentId,
            screenshotPath: screenshotPath,
            upiTxnId: upiTxnId,
            note: note,
            onProgress: onProgress,
          )(store),
    );
  }

  @override
  List<Object?> get props => [event, fees, loading, error, isStaff];
}
