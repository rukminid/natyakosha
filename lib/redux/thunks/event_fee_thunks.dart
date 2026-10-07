import 'package:redux/redux.dart';

import '../../core/di/locator.dart';
import '../../core/errors/app_exception.dart';
import '../../data/models/app_user.dart';
import '../../data/models/event_fee.dart';
import '../../data/repositories/event_repository.dart';
import '../../data/services/api_service.dart';
import '../actions/app_actions.dart';
import '../selectors/selectors.dart';
import '../state/app_state.dart';

const _staffOnly = 'Only your guru or teacher can manage event fees.';

/// Student ids whose fees this user may see: themselves, or a parent's children.
List<String> feeStudentIds(AppUser user) =>
    user.role == UserRole.parent ? user.childIds : [user.id];

/// Loads one event's fees. Staff get every participant's record; everyone
/// else gets only their own (or their children's), as the security rules allow.
Future<void> Function(Store<AppState>) loadEventFees(String eventId) =>
    (Store<AppState> store) async {
      final me = store.state.auth.user;
      if (me == null) return;
      store.dispatch(EventFeesRequestAction(eventId));
      try {
        final repo = locator<EventRepository>();
        final List<EventFee> fees;
        if (me.role.isStaff) {
          fees = await repo.fetchFees(me.schoolId, eventId);
        } else {
          final mine = <EventFee>[];
          for (final id in feeStudentIds(me)) {
            final fee = await repo.fetchFee(me.schoolId, eventId, id);
            if (fee != null) mine.add(fee);
          }
          fees = mine;
        }
        store.dispatch(EventFeesLoadedAction(eventId, fees));
      } catch (e) {
        store.dispatch(EventFeesFailureAction(eventId, AppException.from(e).message));
      }
    };

/// Staff ticks a participant Paid / Waived / back to Pending, and may change
/// that student's amount. Returns an error message, or null on success.
Future<String?> Function(Store<AppState>) updateEventFee(
  String eventId,
  String studentId, {
  EventFeeStatus? status,
  double? amount,
}) =>
    (Store<AppState> store) async {
      final me = store.state.auth.user;
      if (me == null || !me.role.isStaff) return _staffOnly;
      if (!store.state.isOnline) return AppException.offline.message;
      try {
        await locator<EventRepository>().updateFee(
          schoolId: me.schoolId,
          eventId: eventId,
          studentId: studentId,
          markedBy: me.id,
          status: status,
          amount: amount,
        );
        await loadEventFees(eventId)(store);
        return null;
      } catch (e) {
        return AppException.from(e).message;
      }
    };

/// A participant (or parent) uploads the UPI screenshot for [studentId]'s fee.
Future<String?> Function(Store<AppState>) submitEventFeeProof(
  String eventId,
  String studentId, {
  required String screenshotPath,
  String? upiTxnId,
  String? note,
  void Function(double progress)? onProgress,
}) =>
    (Store<AppState> store) async {
      final me = store.state.auth.user;
      if (me == null) return 'Please sign in again.';
      if (!feeStudentIds(me).contains(studentId)) return 'You can only pay your own fees.';
      if (!store.state.isOnline) return AppException.offline.message;
      try {
        await locator<EventRepository>().submitFeeProof(
          schoolId: me.schoolId,
          eventId: eventId,
          studentId: studentId,
          screenshotPath: screenshotPath,
          upiTxnId: upiTxnId,
          note: note,
          onProgress: onProgress,
        );
        await loadEventFees(eventId)(store);
        return null;
      } catch (e) {
        return AppException.from(e).message;
      }
    };

/// Asks the server to push a reminder to everyone still pending.
/// Returns an error message, or null on success.
Future<String?> Function(Store<AppState>) remindPendingFees(String eventId) =>
    (Store<AppState> store) async {
      final me = store.state.auth.user;
      if (me == null || !me.role.isStaff) return _staffOnly;
      if (!store.state.isOnline) return AppException.offline.message;
      if (!feesForEvent(store.state, eventId).any((f) => f.status == EventFeeStatus.pending)) {
        return 'Nobody is pending for this event.';
      }
      try {
        await locator<ApiService>().remindPendingEventFees(schoolId: me.schoolId, eventId: eventId);
        return null;
      } catch (e) {
        return AppException.from(e).message;
      }
    };
