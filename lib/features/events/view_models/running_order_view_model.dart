import 'package:equatable/equatable.dart';
import 'package:redux/redux.dart';

import '../../../data/models/dance_event.dart';
import '../../../data/models/event_item.dart';
import '../../../data/models/member.dart';
import '../../../redux/selectors/selectors.dart' as sel;
import '../../../redux/state/app_state.dart';
import '../../../redux/thunks/chat_thunks.dart' as chat_thunks;
import '../../../redux/thunks/event_item_thunks.dart' as thunks;

/// One event's running order: the songs, who performs them, and the staff
/// commands to add, edit, delete and reorder.
class RunningOrderViewModel extends Equatable {
  const RunningOrderViewModel({
    required this.event,
    required this.items,
    required this.loading,
    required this.error,
    required this.isStaff,
    required this.directory,
    required this.refresh,
    required this.save,
    required this.delete,
    required this.reorder,
  });

  /// Null once the event was deleted (the screen then closes).
  final DanceEvent? event;
  final List<EventItem> items;
  final bool loading;
  final String? error;
  final bool isStaff;

  /// Everyone in the school, so students can see performer names too.
  final List<Member> directory;

  final Future<void> Function() refresh;

  /// Each command returns an error message, or null on success.
  final Future<String?> Function(EventItem item) save;
  final Future<String?> Function(EventItem item) delete;
  final Future<String?> Function(List<EventItem> reordered) reorder;

  /// Performers a song can pick from: this event's dancers, by name.
  List<Member> get dancers {
    final ids = event?.participantIds.toSet() ?? const <String>{};
    return directory.where((m) => ids.contains(m.id)).toList()
      ..sort((a, b) => a.name.compareTo(b.name));
  }

  String nameOf(String id) {
    for (final m in directory) {
      if (m.id == id) return m.name;
    }
    return '…';
  }

  static RunningOrderViewModel fromStore(Store<AppState> store, String eventId) {
    final state = store.state;
    final slice = state.eventItems[eventId];
    return RunningOrderViewModel(
      event: sel.eventById(state, eventId),
      items: sel.itemsForEvent(state, eventId),
      loading: slice?.loading ?? false,
      error: slice?.error,
      isStaff: sel.isStaff(state),
      directory: state.directory.items,
      refresh: () async {
        store.dispatch(chat_thunks.loadDirectory());
        await thunks.loadEventItems(eventId)(store);
      },
      save: (item) => thunks.saveEventItem(eventId, item)(store),
      delete: (item) => thunks.deleteEventItem(eventId, item)(store),
      reorder: (reordered) => thunks.reorderEventItems(eventId, reordered)(store),
    );
  }

  @override
  List<Object?> get props => [event, items, loading, error, isStaff, directory];
}
