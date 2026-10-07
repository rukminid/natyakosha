import 'package:flutter/material.dart';
import 'package:flutter_redux/flutter_redux.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/router/routes.dart';
import '../../../core/theme/app_theme.dart';
import '../../../redux/state/app_state.dart';
import '../../../shared/widgets/common_widgets.dart';
import '../../../shared/widgets/user_avatar.dart';
import '../view_models/chat_view_models.dart';

/// "5:30 PM" today, otherwise "12 Oct".
String chatTime(DateTime t, {DateTime? now}) {
  final n = now ?? DateTime.now();
  final today = t.year == n.year && t.month == n.month && t.day == n.day;
  return today ? DateFormat('h:mm a').format(t) : DateFormat('d MMM').format(t);
}

/// Fourth tab: Individual chats and Groups.
class ChatView extends StatefulWidget {
  const ChatView({super.key});

  @override
  State<ChatView> createState() => _ChatViewState();
}

class _ChatViewState extends State<ChatView> with SingleTickerProviderStateMixin {
  late final TabController _tabs = TabController(length: 2, vsync: this)
    ..addListener(() => setState(() {}));

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return StoreConnector<AppState, ChatListViewModel>(
      ignoreChange: (s) => s.auth.user == null,
      converter: ChatListViewModel.fromStore,
      distinct: true,
      onInit: (store) => ChatListViewModel.fromStore(store).start(),
      builder: (context, vm) {
        final onGroups = _tabs.index == 1;
        return Scaffold(
          appBar: AppBar(
            title: const Text('Chat'),
            bottom: TabBar(
              controller: _tabs,
              tabs: [
                Tab(text: 'Individual${vm.direct.isEmpty ? '' : ' (${vm.direct.length})'}'),
                Tab(text: 'Groups${vm.groups.isEmpty ? '' : ' (${vm.groups.length})'}'),
              ],
            ),
          ),
          // Only staff can create groups; everyone can start a one-to-one chat.
          floatingActionButton: onGroups
              ? (vm.isStaff
                  ? FloatingActionButton.extended(
                      onPressed: () => context.push(Routes.newGroup),
                      icon: const Icon(Icons.group_add_outlined),
                      label: const Text('New group'),
                    )
                  : null)
              : FloatingActionButton.extended(
                  onPressed: () => context.push(Routes.newChat),
                  icon: const Icon(Icons.chat_outlined),
                  label: const Text('New chat'),
                ),
          body: vm.error != null && vm.direct.isEmpty && vm.groups.isEmpty
              ? ErrorRetry(message: vm.error!, onRetry: vm.start)
              : TabBarView(
                  controller: _tabs,
                  children: [
                    _ChatList(
                      items: vm.direct,
                      loading: vm.loading,
                      empty: EmptyState(
                        icon: Icons.chat_bubble_outline,
                        title: 'No conversations yet',
                        message: vm.isStaff
                            ? 'Tap “New chat” to message a student, parent or teacher.'
                            : 'Tap “New chat” to message your guru or a teacher.',
                      ),
                    ),
                    _ChatList(
                      items: vm.groups,
                      loading: vm.loading,
                      empty: EmptyState(
                        icon: Icons.groups_outlined,
                        title: 'No groups yet',
                        message: vm.isStaff
                            ? 'Create a group for a batch or an event.'
                            : 'Groups your guru adds you to will show here.',
                      ),
                    ),
                  ],
                ),
        );
      },
    );
  }
}

class _ChatList extends StatelessWidget {
  const _ChatList({required this.items, required this.loading, required this.empty});

  final List<ChatListItem> items;
  final bool loading;
  final Widget empty;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return loading ? const Center(child: CircularProgressIndicator()) : empty;
    }
    return ListView.separated(
      padding: const EdgeInsets.only(bottom: 96),
      itemCount: items.length,
      separatorBuilder: (_, __) => const Divider(height: 1, indent: 72),
      itemBuilder: (context, i) {
        final item = items[i];
        final c = item.chat;
        return ListTile(
          onTap: () => context.push(Routes.chatRoom(c.id)),
          leading: c.isGroup
              ? const CircleAvatar(
                  radius: 24,
                  backgroundColor: AppColors.maroon,
                  child: Icon(Icons.groups, color: AppColors.gold),
                )
              : UserAvatar(name: item.title, photoUrl: item.other?.photoUrl, radius: 24),
          title: Text(item.title, maxLines: 1, overflow: TextOverflow.ellipsis),
          subtitle: Text(item.preview, maxLines: 1, overflow: TextOverflow.ellipsis),
          trailing: c.lastMessageAt == null
              ? null
              : Text(chatTime(c.lastMessageAt!), style: Theme.of(context).textTheme.bodySmall),
        );
      },
    );
  }
}
