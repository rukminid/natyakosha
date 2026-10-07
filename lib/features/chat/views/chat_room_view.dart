import 'package:flutter/material.dart';
import 'package:flutter_redux/flutter_redux.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_theme.dart';
import '../../../redux/state/app_state.dart';
import '../../../shared/widgets/common_widgets.dart';
import '../../../shared/widgets/user_avatar.dart';
import '../view_models/chat_view_models.dart';

final _time = DateFormat('h:mm a');
final _day = DateFormat('EEE, d MMM');

/// One conversation: bubbles, newest at the bottom, and a message box.
class ChatRoomView extends StatefulWidget {
  const ChatRoomView({super.key, required this.chatId});

  final String chatId;

  @override
  State<ChatRoomView> createState() => _ChatRoomViewState();
}

class _ChatRoomViewState extends State<ChatRoomView> {
  final _text = TextEditingController();
  bool _canSend = false;

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  void _send(ChatRoomViewModel vm) {
    final body = _text.text.trim();
    if (body.isEmpty) return;
    vm.send(body);
    _text.clear();
    setState(() => _canSend = false);
  }

  void _showMembers(BuildContext context, ChatRoomViewModel vm) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (_) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            ListTile(title: Text('${vm.title} · ${vm.members.length} members')),
            for (final m in vm.members)
              ListTile(
                leading: UserAvatar(name: m.name, photoUrl: m.photoUrl, radius: 20),
                title: Text(m.id == vm.myId ? '${m.name} (you)' : m.name),
                subtitle: Text(m.role.label),
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return StoreConnector<AppState, ChatRoomViewModel>(
      ignoreChange: (s) => s.auth.user == null,
      converter: (store) => ChatRoomViewModel.fromStore(store, widget.chatId),
      distinct: true,
      onInit: (store) => ChatRoomViewModel.fromStore(store, widget.chatId).open(),
      onDispose: (store) => ChatRoomViewModel.fromStore(store, widget.chatId).close(),
      onWillChange: (prev, next) {
        if (next.sendError != null && next.sendError != prev?.sendError) {
          showSnack(context, next.sendError!, error: true);
          next.clearSendError();
        }
      },
      builder: (context, vm) {
        final messages = vm.messages;
        return Scaffold(
          appBar: AppBar(
            title: Text(vm.title),
            actions: [
              if (vm.isGroup)
                IconButton(
                  tooltip: 'Members',
                  icon: const Icon(Icons.groups_outlined),
                  onPressed: () => _showMembers(context, vm),
                ),
            ],
          ),
          body: Column(
            children: [
              Expanded(
                child: messages.isEmpty
                    ? const EmptyState(
                        icon: Icons.chat_bubble_outline,
                        title: 'No messages yet',
                        message: 'Say namaskaram 🙏',
                      )
                    : ListView.builder(
                        // Newest first + reverse keeps the latest message at the bottom.
                        reverse: true,
                        padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
                        itemCount: messages.length,
                        itemBuilder: (context, i) {
                          final m = messages[i];
                          final older = i + 1 < messages.length ? messages[i + 1] : null;
                          final newDay = older == null ||
                              older.createdAt.year != m.createdAt.year ||
                              older.createdAt.month != m.createdAt.month ||
                              older.createdAt.day != m.createdAt.day;
                          final mine = m.senderId == vm.myId;
                          // Show the sender above the first of a run in a group.
                          final showName = vm.isGroup && !mine && (newDay || older.senderId != m.senderId);
                          return Column(
                            children: [
                              if (newDay) _DayLabel(_day.format(m.createdAt)),
                              _Bubble(
                                text: m.text,
                                time: _time.format(m.createdAt),
                                mine: mine,
                                sender: showName ? m.senderName : null,
                              ),
                            ],
                          );
                        },
                      ),
              ),
              SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 4, 8, 8),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _text,
                          minLines: 1,
                          maxLines: 5,
                          maxLength: 2000,
                          textCapitalization: TextCapitalization.sentences,
                          onChanged: (v) => setState(() => _canSend = v.trim().isNotEmpty),
                          decoration: AppTheme.input('Message').copyWith(
                            counterText: '',
                            isDense: true,
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(24)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 4),
                      IconButton.filled(
                        tooltip: 'Send',
                        onPressed: _canSend ? () => _send(vm) : null,
                        icon: const Icon(Icons.send),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _DayLabel extends StatelessWidget {
  const _DayLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Text(text, style: Theme.of(context).textTheme.bodySmall),
      );
}

class _Bubble extends StatelessWidget {
  const _Bubble({required this.text, required this.time, required this.mine, this.sender});

  final String text;
  final String time;
  final bool mine;
  final String? sender;

  @override
  Widget build(BuildContext context) {
    final fg = mine ? AppColors.ivory : AppColors.ink;
    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 2),
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 6),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.78),
        decoration: BoxDecoration(
          color: mine ? AppColors.maroon : Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(mine ? 16 : 4),
            bottomRight: Radius.circular(mine ? 4 : 16),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (sender != null)
              Text(
                sender!,
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.maroon),
              ),
            Text(text, style: TextStyle(color: fg)),
            const SizedBox(height: 2),
            Align(
              alignment: Alignment.centerRight,
              child: Text(time, style: TextStyle(fontSize: 10, color: fg.withValues(alpha: 0.7))),
            ),
          ],
        ),
      ),
    );
  }
}
