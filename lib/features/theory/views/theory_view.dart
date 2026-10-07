import 'package:flutter/material.dart';
import 'package:flutter_redux/flutter_redux.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/routes.dart';
import '../../../data/models/theory_note.dart';
import '../../../redux/selectors/selectors.dart' as sel;
import '../../../redux/state/app_state.dart';
import '../../../shared/widgets/common_widgets.dart';
import '../view_models/theory_view_model.dart';

/// Theory library: search, filter by topic, open a note. Staff add notes.
class TheoryView extends StatefulWidget {
  const TheoryView({super.key});

  @override
  State<TheoryView> createState() => _TheoryViewState();
}

class _TheoryViewState extends State<TheoryView> {
  String _query = '';
  String? _topic;

  @override
  Widget build(BuildContext context) {
    return StoreConnector<AppState, TheoryViewModel>(
      ignoreChange: (s) => s.auth.user == null,
      converter: TheoryViewModel.fromStore,
      distinct: true,
      onInit: (store) => TheoryViewModel.fromStore(store).refresh(),
      builder: (context, vm) {
        // A topic that no longer has notes (deleted) is dropped from the filter.
        final topic = vm.topics.contains(_topic) ? _topic : null;
        final shown = sel.filterTheory(vm.notes, query: _query, topic: topic);
        return Scaffold(
          appBar: AppBar(title: const Text('Theory')),
          floatingActionButton: vm.isStaff
              ? FloatingActionButton.extended(
                  onPressed: () => context.push(Routes.theoryNew),
                  icon: const Icon(Icons.add),
                  label: const Text('Add note'),
                )
              : null,
          body: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: TextField(
                  onChanged: (v) => setState(() => _query = v),
                  decoration: const InputDecoration(
                    hintText: 'Search notes',
                    prefixIcon: Icon(Icons.search),
                  ),
                ),
              ),
              if (vm.topics.isNotEmpty)
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Row(
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          label: const Text('All'),
                          selected: topic == null,
                          onSelected: (_) => setState(() => _topic = null),
                        ),
                      ),
                      for (final t in vm.topics)
                        Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: ChoiceChip(
                            label: Text(t),
                            selected: topic == t,
                            onSelected: (_) => setState(() => _topic = t),
                          ),
                        ),
                    ],
                  ),
                ),
              Expanded(child: _body(context, vm, shown)),
            ],
          ),
        );
      },
    );
  }

  Widget _body(BuildContext context, TheoryViewModel vm, List<TheoryNote> shown) {
    if (shown.isEmpty) {
      return RefreshIndicator(
        onRefresh: vm.refresh,
        child: ListView(
          children: [
            if (vm.loading) const LinearProgressIndicator(minHeight: 2),
            if (vm.error != null && vm.notes.isEmpty)
              ErrorRetry(message: vm.error!, onRetry: vm.refresh)
            else if (!vm.loading)
              SizedBox(
                height: 360,
                child: EmptyState(
                  icon: Icons.menu_book_outlined,
                  title: vm.notes.isEmpty ? 'No notes yet' : 'No notes match',
                  message: vm.notes.isEmpty
                      ? (vm.isStaff
                          ? 'Tap “Add note” to start the theory library.'
                          : 'Your guru will add theory notes here.')
                      : 'Try another search or topic.',
                ),
              ),
          ],
        ),
      );
    }

    // Notes arrive sorted by topic, so a header goes wherever the topic changes.
    final rows = <Widget>[];
    String? current;
    for (final n in shown) {
      if (n.topic != current) {
        current = n.topic;
        rows.add(Padding(
          padding: const EdgeInsets.fromLTRB(0, 16, 0, 4),
          child: Text(n.topic, style: Theme.of(context).textTheme.titleMedium),
        ));
      }
      rows.add(Card(
        child: ListTile(
          onTap: () => context.push(Routes.theoryDetail(n.id)),
          title: Text(n.title),
          subtitle: Text(
            n.body,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          trailing: n.level == null ? null : Chip(label: Text(n.level!), visualDensity: VisualDensity.compact),
        ),
      ));
    }
    return RefreshIndicator(
      onRefresh: vm.refresh,
      child: ListView(
        padding: EdgeInsets.fromLTRB(16, 0, 16, vm.isStaff ? 88 : 24),
        children: rows,
      ),
    );
  }
}
