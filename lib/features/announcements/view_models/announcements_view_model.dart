import 'package:equatable/equatable.dart';
import 'package:redux/redux.dart';

import '../../../data/models/announcement.dart';
import '../../../redux/state/app_state.dart';
import '../../../redux/thunks/announcement_thunks.dart' as thunks;
import '../../../redux/thunks/content_thunks.dart';

class AnnouncementsViewModel extends Equatable {
  const AnnouncementsViewModel({
    required this.items,
    required this.loading,
    required this.error,
    required this.isStaff,
    required this.refresh,
    required this.save,
    required this.delete,
  });

  final List<Announcement> items;
  final bool loading;
  final String? error;
  final bool isStaff;
  final Future<void> Function() refresh;

  /// Posts a new announcement, or edits [existing]. Returns an error message, or null.
  final Future<String?> Function({
    Announcement? existing,
    required String title,
    required String body,
    required bool pinned,
  }) save;
  final Future<String?> Function(Announcement a) delete;

  Announcement? byId(String id) {
    for (final a in items) {
      if (a.id == id) return a;
    }
    return null;
  }

  static AnnouncementsViewModel fromStore(Store<AppState> store) => AnnouncementsViewModel(
        items: store.state.announcements.items,
        loading: store.state.announcements.loading,
        error: store.state.announcements.error,
        isStaff: store.state.auth.user?.role.isStaff ?? false,
        refresh: () async => store.dispatch(loadAnnouncements()),
        save: ({existing, required title, required body, required pinned}) =>
            thunks.saveAnnouncement(existing: existing, title: title, body: body, pinned: pinned)(store),
        delete: (a) => thunks.deleteAnnouncement(a)(store),
      );

  @override
  List<Object?> get props => [items, loading, error, isStaff];
}
