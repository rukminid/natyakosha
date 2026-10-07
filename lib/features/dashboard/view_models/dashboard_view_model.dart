import 'package:equatable/equatable.dart';
import 'package:redux/redux.dart';

import '../../../data/models/announcement.dart';
import '../../../data/models/app_user.dart';
import '../../../data/models/dance_event.dart';
import '../../../data/models/payment.dart';
import '../../../redux/selectors/selectors.dart' as sel;
import '../../../redux/state/app_state.dart';
import '../../../redux/thunks/content_thunks.dart';

class DashboardViewModel extends Equatable {
  const DashboardViewModel({
    required this.user,
    required this.isOnline,
    required this.loading,
    required this.announcements,
    required this.upcomingEvents,
    required this.awaitingReview,
    required this.collectedThisMonth,
    required this.myOpenPayments,
    required this.joinRequests,
    required this.refresh,
  });

  final AppUser user;
  final bool isOnline;
  final bool loading;
  final List<Announcement> announcements;
  final List<DanceEvent> upcomingEvents;

  /// Guru: screenshots waiting to be verified.
  final int awaitingReview;

  /// Guru: verified fees for the current month.
  final double collectedThisMonth;

  /// Student: payments still awaiting check or rejected.
  final List<Payment> myOpenPayments;

  /// Guru: sign-ups waiting for approval.
  final int joinRequests;

  final Future<void> Function() refresh;

  bool get isStaff => user.role.isStaff;

  static DashboardViewModel fromStore(Store<AppState> store) {
    final s = store.state;
    return DashboardViewModel(
      user: s.auth.user!,
      isOnline: s.isOnline,
      loading: s.announcements.loading || s.events.loading || s.payments.loading,
      announcements: s.announcements.items.take(3).toList(),
      upcomingEvents: sel.upcomingEvents(s).take(3).toList(),
      awaitingReview: sel.paymentsAwaitingReview(s).length,
      collectedThisMonth: sel.collectedThisMonth(s),
      myOpenPayments: s.payments.items
          .where((p) => p.status == PaymentStatus.submitted || p.status == PaymentStatus.rejected)
          .toList(),
      joinRequests: s.pendingMembers.items.length,
      refresh: () async => store.dispatch(loadDashboard()),
    );
  }

  @override
  List<Object?> get props => [
        user, isOnline, loading, announcements, upcomingEvents,
        awaitingReview, collectedThisMonth, myOpenPayments, joinRequests,
      ];
}
