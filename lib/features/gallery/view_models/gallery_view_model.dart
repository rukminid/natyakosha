import 'package:equatable/equatable.dart';
import 'package:redux/redux.dart';

import '../../../data/models/dance_event.dart';
import '../../../data/models/event_item.dart';
import '../../../data/models/media_item.dart';
import '../../../redux/selectors/selectors.dart' as sel;
import '../../../redux/state/app_state.dart';
import '../../../redux/thunks/content_thunks.dart';
import '../../../redux/thunks/event_item_thunks.dart' as item_thunks;
import '../../../redux/thunks/media_thunks.dart' as thunks;

/// Gallery: everything uploaded for the school's events. Staff upload and
/// delete; everyone else browses.
class GalleryViewModel extends Equatable {
  const GalleryViewModel({
    required this.media,
    required this.events,
    required this.songs,
    required this.loading,
    required this.error,
    required this.isStaff,
    required this.refresh,
    required this.loadSongs,
    required this.upload,
    required this.delete,
  });

  final List<MediaItem> media;

  /// Events newest first, for section titles and the upload picker.
  final List<DanceEvent> events;

  /// Running orders loaded so far, by event id (to name the song a clip is linked to).
  final Map<String, List<EventItem>> songs;
  final bool loading;
  final String? error;
  final bool isStaff;

  final Future<void> Function() refresh;
  final Future<void> Function(String eventId) loadSongs;

  /// Each command returns an error message, or null on success.
  final Future<String?> Function({
    required String eventId,
    required MediaType type,
    required List<String> paths,
    String? itemId,
    String? caption,
    void Function(int done, int total, double current)? onProgress,
  }) upload;
  final Future<String?> Function(MediaItem item) delete;

  String? eventTitle(String id) {
    for (final e in events) {
      if (e.id == id) return e.title;
    }
    return null;
  }

  String? songName(MediaItem m) {
    if (m.itemId == null) return null;
    for (final i in songs[m.eventId] ?? const <EventItem>[]) {
      if (i.id == m.itemId) return i.songName;
    }
    return null;
  }

  static GalleryViewModel fromStore(Store<AppState> store) {
    final s = store.state;
    return GalleryViewModel(
      media: s.media.items,
      events: [...s.events.items]..sort((a, b) => b.date.compareTo(a.date)),
      songs: {for (final e in s.eventItems.entries) e.key: sel.itemsForEvent(s, e.key)},
      loading: s.media.loading,
      error: s.media.error,
      isStaff: sel.isStaff(s),
      refresh: () async {
        if (s.events.items.isEmpty) store.dispatch(loadEvents());
        await thunks.loadMedia()(store);
      },
      loadSongs: (eventId) => item_thunks.loadEventItems(eventId)(store),
      upload: ({required eventId, required type, required paths, itemId, caption, onProgress}) =>
          thunks.uploadMedia(
            eventId: eventId,
            type: type,
            paths: paths,
            itemId: itemId,
            caption: caption,
            onProgress: onProgress,
          )(store),
      delete: (item) => thunks.deleteMedia(item)(store),
    );
  }

  @override
  List<Object?> get props => [media, events, songs, loading, error, isStaff];
}
