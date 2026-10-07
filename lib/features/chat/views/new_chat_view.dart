import 'package:flutter/material.dart';
import 'package:flutter_redux/flutter_redux.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/routes.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/member.dart';
import '../../../redux/state/app_state.dart';
import '../../../shared/widgets/common_widgets.dart';
import '../../../shared/widgets/user_avatar.dart';
import '../view_models/chat_view_models.dart';

/// Pick one person to message. Students and parents see staff only.
class NewChatView extends StatefulWidget {
  const NewChatView({super.key});

  @override
  State<NewChatView> createState() => _NewChatViewState();
}

class _NewChatViewState extends State<NewChatView> {
  String _query = '';
  bool _opening = false;

  Future<void> _open(PeopleViewModel vm, Member m) async {
    if (_opening) return;
    setState(() => _opening = true);
    final result = await vm.startDirect(m.id);
    if (!mounted) return;
    setState(() => _opening = false);
    if (result.error != null) {
      showSnack(context, result.error!, error: true);
      return;
    }
    // Replace the picker so Back from the chat returns to the chat list.
    context.pushReplacement(Routes.chatRoom(result.chatId!));
  }

  @override
  Widget build(BuildContext context) {
    return StoreConnector<AppState, PeopleViewModel>(
      ignoreChange: (s) => s.auth.user == null,
      converter: PeopleViewModel.fromStore,
      distinct: true,
      onInit: (store) => PeopleViewModel.fromStore(store).load(),
      builder: (context, vm) {
        final q = _query.trim().toLowerCase();
        final people = [
          for (final m in vm.people)
            if (q.isEmpty || m.name.toLowerCase().contains(q)) m,
        ];
        return Scaffold(
          appBar: AppBar(title: const Text('New chat')),
          body: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                child: TextField(
                  onChanged: (v) => setState(() => _query = v),
                  decoration: AppTheme.input('Search by name', prefixIcon: const Icon(Icons.search)),
                ),
              ),
              if (vm.loading || _opening) const LinearProgressIndicator(minHeight: 2),
              Expanded(
                child: vm.error != null && vm.people.isEmpty
                    ? ErrorRetry(message: vm.error!, onRetry: vm.load)
                    : people.isEmpty
                        ? EmptyState(
                            icon: Icons.person_search_outlined,
                            title: vm.loading ? 'Loading…' : 'Nobody found',
                            message: vm.isStaff || vm.loading
                                ? null
                                : 'You can message your guru and teachers.',
                          )
                        : ListView.builder(
                            itemCount: people.length,
                            itemBuilder: (context, i) {
                              final m = people[i];
                              return ListTile(
                                enabled: !_opening,
                                leading: UserAvatar(name: m.name, photoUrl: m.photoUrl, radius: 22),
                                title: Text(m.name),
                                subtitle: Text(m.role.label),
                                onTap: () => _open(vm, m),
                              );
                            },
                          ),
              ),
            ],
          ),
        );
      },
    );
  }
}
