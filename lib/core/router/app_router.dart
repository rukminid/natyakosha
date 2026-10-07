import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';
import 'package:redux/redux.dart';

import '../../features/announcements/views/announcement_form_view.dart';
import '../../features/announcements/views/announcements_view.dart';
import '../../features/attendance/views/attendance_view.dart';
import '../../features/attendance/views/my_attendance_view.dart';
import '../../features/batches/views/batches_view.dart';
import '../../features/auth/views/forgot_password_view.dart';
import '../../features/auth/views/login_view.dart';
import '../../features/auth/views/pending_approval_view.dart';
import '../../features/auth/views/signup_view.dart';
import '../../features/chat/views/chat_room_view.dart';
import '../../features/chat/views/chat_view.dart';
import '../../features/chat/views/new_chat_view.dart';
import '../../features/chat/views/new_group_view.dart';
import '../../features/dashboard/views/dashboard_view.dart';
import '../../features/event_fees/views/event_fee_detail_view.dart';
import '../../features/event_fees/views/event_fees_view.dart';
import '../../features/events/views/event_detail_view.dart';
import '../../features/events/views/event_form_view.dart';
import '../../features/events/views/running_order_view.dart';
import '../../features/events/views/events_view.dart';
import '../../features/gallery/views/gallery_view.dart';
import '../../features/members/views/approvals_view.dart';
import '../../features/members/views/student_form_view.dart';
import '../../features/members/views/students_view.dart';
import '../../features/payments/views/payments_view.dart';
import '../../features/payments/views/upload_payment_view.dart';
import '../../features/profile/views/edit_profile_view.dart';
import '../../features/profile/views/profile_view.dart';
import '../../features/shell/views/app_shell.dart';
import '../../features/splash/views/splash_view.dart';
import '../../features/theory/views/theory_detail_view.dart';
import '../../features/theory/views/theory_form_view.dart';
import '../../features/theory/views/theory_view.dart';
import '../../redux/state/app_state.dart';
import 'routes.dart';

/// Screens reachable while signed out.
const _publicRoutes = {Routes.login, Routes.signup, Routes.forgotPassword};

/// go_router wired to Redux: whenever the auth status (or approval status)
/// changes the router re-runs [redirect], so the user moves automatically.
GoRouter createRouter(Store<AppState> store) {
  final refresh = _StoreListenable(
    store.onChange.map((s) => '${s.auth.status.name}|${s.auth.user?.status.name}').distinct(),
  );

  // Forms and detail screens open above the bottom bar, on the root navigator.
  final rootKey = GlobalKey<NavigatorState>();

  return GoRouter(
    navigatorKey: rootKey,
    initialLocation: Routes.splash,
    refreshListenable: refresh,
    redirect: (context, state) {
      final status = store.state.auth.status;
      final at = state.matchedLocation;

      if (status == AuthStatus.unknown) return at == Routes.splash ? null : Routes.splash;
      if (status == AuthStatus.unauthenticated) {
        return _publicRoutes.contains(at) ? null : Routes.login;
      }
      // Signed in but not yet approved by the institute's guru.
      final approved = store.state.auth.user?.isApproved ?? false;
      if (!approved) return at == Routes.pendingApproval ? null : Routes.pendingApproval;
      // Approved: never show splash / auth screens again.
      if (at == Routes.splash || at == Routes.pendingApproval || _publicRoutes.contains(at)) {
        return Routes.dashboard;
      }
      return null;
    },
    routes: [
      GoRoute(path: Routes.splash, builder: (_, __) => const SplashView()),
      GoRoute(path: Routes.login, builder: (_, __) => const LoginView()),
      GoRoute(path: Routes.signup, builder: (_, __) => const SignupView()),
      GoRoute(
        path: Routes.forgotPassword,
        builder: (_, state) => ForgotPasswordView(initialMobile: state.uri.queryParameters['mobile']),
      ),
      GoRoute(path: Routes.pendingApproval, builder: (_, __) => const PendingApprovalView()),
      GoRoute(path: Routes.approvals, builder: (_, __) => const ApprovalsView()),
      StatefulShellRoute.indexedStack(
        builder: (_, __, shell) => AppShell(navigationShell: shell),
        branches: [
          StatefulShellBranch(routes: [
            GoRoute(path: Routes.dashboard, builder: (_, __) => const DashboardView()),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
              path: Routes.profile,
              builder: (_, __) => const ProfileView(),
              routes: [
                GoRoute(
                  path: 'edit',
                  parentNavigatorKey: rootKey,
                  builder: (_, __) => const EditProfileView(),
                ),
              ],
            ),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
              path: Routes.events,
              builder: (_, __) => const EventsView(),
              routes: [
                // 'new' must come before ':id' so it is not read as an id.
                GoRoute(
                  path: 'new',
                  parentNavigatorKey: rootKey,
                  builder: (_, state) => EventFormView(
                    initialDate: DateTime.tryParse(state.uri.queryParameters['date'] ?? ''),
                  ),
                ),
                GoRoute(
                  path: ':id',
                  parentNavigatorKey: rootKey,
                  builder: (_, state) => EventDetailView(eventId: state.pathParameters['id']!),
                  routes: [
                    GoRoute(
                      path: 'edit',
                      parentNavigatorKey: rootKey,
                      builder: (_, state) => EventFormView(eventId: state.pathParameters['id']),
                    ),
                    GoRoute(
                      path: 'order',
                      parentNavigatorKey: rootKey,
                      builder: (_, state) => RunningOrderView(eventId: state.pathParameters['id']!),
                    ),
                  ],
                ),
              ],
            ),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
              path: Routes.chat,
              builder: (_, __) => const ChatView(),
              routes: [
                // 'new' and 'new-group' must come before ':id'.
                GoRoute(
                  path: 'new',
                  parentNavigatorKey: rootKey,
                  builder: (_, __) => const NewChatView(),
                ),
                GoRoute(
                  path: 'new-group',
                  parentNavigatorKey: rootKey,
                  builder: (_, __) => const NewGroupView(),
                ),
                GoRoute(
                  path: ':id',
                  parentNavigatorKey: rootKey,
                  builder: (_, state) => ChatRoomView(chatId: state.pathParameters['id']!),
                ),
              ],
            ),
          ]),
        ],
      ),
      GoRoute(path: Routes.attendance, builder: (_, __) => const AttendanceView()),
      GoRoute(path: Routes.myAttendance, builder: (_, __) => const MyAttendanceView()),
      GoRoute(path: Routes.batches, builder: (_, __) => const BatchesView()),
      GoRoute(
        path: Routes.students,
        builder: (_, __) => const StudentsView(),
        routes: [
          // 'new' must come before ':id'.
          GoRoute(path: 'new', builder: (_, __) => const StudentFormView()),
          GoRoute(
            path: ':id/edit',
            builder: (_, state) => StudentFormView(studentId: state.pathParameters['id']),
          ),
        ],
      ),
      GoRoute(
        path: Routes.payments,
        builder: (_, __) => const PaymentsView(),
        routes: [
          GoRoute(path: 'upload', builder: (_, __) => const UploadPaymentView()),
        ],
      ),
      GoRoute(
        path: Routes.eventFees,
        builder: (_, __) => const EventFeesView(),
        routes: [
          GoRoute(
            path: ':id',
            builder: (_, state) => EventFeeDetailView(eventId: state.pathParameters['id']!),
          ),
        ],
      ),
      GoRoute(path: Routes.gallery, builder: (_, __) => const GalleryView()),
      GoRoute(
        path: Routes.announcements,
        builder: (_, __) => const AnnouncementsView(),
        routes: [
          // 'new' must come before ':id'.
          GoRoute(path: 'new', builder: (_, __) => const AnnouncementFormView()),
          GoRoute(
            path: ':id/edit',
            builder: (_, state) => AnnouncementFormView(announcementId: state.pathParameters['id']),
          ),
        ],
      ),
      GoRoute(
        path: Routes.theory,
        builder: (_, __) => const TheoryView(),
        routes: [
          // 'new' must come before ':id'.
          GoRoute(path: 'new', builder: (_, __) => const TheoryFormView()),
          GoRoute(
            path: ':id',
            builder: (_, state) => TheoryDetailView(noteId: state.pathParameters['id']!),
            routes: [
              GoRoute(
                path: 'edit',
                builder: (_, state) => TheoryFormView(noteId: state.pathParameters['id']),
              ),
            ],
          ),
        ],
      ),
    ],
  );
}

class _StoreListenable extends ChangeNotifier {
  _StoreListenable(Stream<Object?> stream) {
    _sub = stream.listen((_) => notifyListeners());
  }

  late final StreamSubscription<Object?> _sub;

  @override
  void dispose() {
    _sub.cancel();
    super.dispose();
  }
}
