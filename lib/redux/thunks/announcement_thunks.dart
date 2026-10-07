import 'package:redux/redux.dart';

import '../../core/di/locator.dart';
import '../../core/errors/app_exception.dart';
import '../../data/models/announcement.dart';
import '../../data/repositories/announcement_repository.dart';
import '../state/app_state.dart';
import 'content_thunks.dart';

const _staffOnly = 'Only your guru or teacher can post announcements.';
const maxAnnouncementTitle = 100;
const maxAnnouncementBody = 2000;

/// Posts a new announcement, or edits [existing]. Staff only.
/// Returns an error message, or null on success.
Future<String?> Function(Store<AppState>) saveAnnouncement({
  Announcement? existing,
  required String title,
  required String body,
  required bool pinned,
}) =>
    (Store<AppState> store) async {
      final me = store.state.auth.user;
      if (me == null || !me.role.isStaff) return _staffOnly;
      final t = title.trim();
      final b = body.trim();
      if (t.isEmpty) return 'Enter a title.';
      if (b.isEmpty) return 'Write the announcement.';
      if (t.length > maxAnnouncementTitle) return 'Keep the title under $maxAnnouncementTitle characters.';
      if (b.length > maxAnnouncementBody) return 'Keep the message under $maxAnnouncementBody characters.';
      if (!store.state.isOnline) return AppException.offline.message;
      try {
        final repo = locator<AnnouncementRepository>();
        if (existing == null) {
          await repo.create(schoolId: me.schoolId, title: t, body: b, authorName: me.name, pinned: pinned);
        } else {
          await repo.update(schoolId: me.schoolId, id: existing.id, title: t, body: b, pinned: pinned);
        }
        await loadAnnouncements()(store);
        return null;
      } catch (e) {
        return AppException.from(e).message;
      }
    };

/// Staff only. Returns an error message, or null on success.
Future<String?> Function(Store<AppState>) deleteAnnouncement(Announcement a) =>
    (Store<AppState> store) async {
      final me = store.state.auth.user;
      if (me == null || !me.role.isStaff) return _staffOnly;
      if (!store.state.isOnline) return AppException.offline.message;
      try {
        await locator<AnnouncementRepository>().delete(me.schoolId, a.id);
        await loadAnnouncements()(store);
        return null;
      } catch (e) {
        return AppException.from(e).message;
      }
    };
