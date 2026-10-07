import 'package:equatable/equatable.dart';

/// Reusable "list loaded from the server" slice: items + loading + error.
class ListState<T> extends Equatable {
  const ListState({
    this.items = const [],
    this.loading = false,
    this.error,
    this.lastLoaded,
  });

  const ListState.initial() : this();

  final List<T> items;
  final bool loading;
  final String? error;
  final DateTime? lastLoaded;

  ListState<T> startLoading() =>
      ListState<T>(items: items, loading: true, lastLoaded: lastLoaded);

  ListState<T> loaded(List<T> newItems) =>
      ListState<T>(items: newItems, loading: false, lastLoaded: DateTime.now());

  ListState<T> failed(String message) =>
      ListState<T>(items: items, loading: false, error: message, lastLoaded: lastLoaded);

  @override
  List<Object?> get props => [items, loading, error, lastLoaded];
}
