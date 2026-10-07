import 'package:flutter/material.dart';
import 'package:flutter_redux/flutter_redux.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/router/routes.dart';
import '../../../data/models/announcement.dart';

import '../../../core/theme/app_theme.dart';
import '../../../redux/state/app_state.dart';
import '../../../shared/widgets/common_widgets.dart';
import '../view_models/announcements_view_model.dart';

final _date = DateFormat('d MMM yyyy, h:mm a');

/// Announcements list (cached for offline reading). Staff post, edit and delete.
class AnnouncementsView extends StatelessWidget {
  const AnnouncementsView({super.key});

  Future<void> _confirmDelete(BuildContext context, AnnouncementsViewModel vm, Announcement a) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete this announcement?'),
        content: Text('“${a.title}” will be removed for everyone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.danger),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    final error = await vm.delete(a);
    if (!context.mounted) return;
    showSnack(context, error ?? 'Announcement deleted', error: error != null);
  }

  @override
  Widget build(BuildContext context) {
    return StoreConnector<AppState, AnnouncementsViewModel>(
      converter: AnnouncementsViewModel.fromStore,
      distinct: true,
      onInit: (store) => AnnouncementsViewModel.fromStore(store).refresh(),
      builder: (context, vm) => Scaffold(
        appBar: AppBar(title: const Text('Announcements')),
        floatingActionButton: vm.isStaff
            ? FloatingActionButton.extended(
                onPressed: () => context.push(Routes.announcementNew),
                icon: const Icon(Icons.edit_outlined),
                label: const Text('New'),
              )
            : null,
        body: RefreshIndicator(
          onRefresh: vm.refresh,
          child: vm.items.isEmpty
              ? ListView(
                  children: [
                    if (vm.loading) const LinearProgressIndicator(minHeight: 2),
                    if (vm.error != null)
                      ErrorRetry(message: vm.error!, onRetry: vm.refresh)
                    else if (!vm.loading)
                      const EmptyState(icon: Icons.campaign_outlined, title: 'No announcements yet'),
                  ],
                )
              : ListView.separated(
                  padding: EdgeInsets.fromLTRB(16, 16, 16, vm.isStaff ? 88 : 16),
                  itemCount: vm.items.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, i) {
                    final a = vm.items[i];
                    return Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                if (a.pinned)
                                  const Padding(
                                    padding: EdgeInsets.only(right: 6),
                                    child: Icon(Icons.push_pin, size: 16, color: AppColors.gold),
                                  ),
                                Expanded(
                                  child: Text(a.title, style: Theme.of(context).textTheme.titleMedium),
                                ),
                                if (vm.isStaff)
                                  PopupMenuButton<String>(
                                    onSelected: (v) => v == 'edit'
                                        ? context.push(Routes.announcementEdit(a.id))
                                        : _confirmDelete(context, vm, a),
                                    itemBuilder: (_) => const [
                                      PopupMenuItem(value: 'edit', child: Text('Edit')),
                                      PopupMenuItem(value: 'delete', child: Text('Delete')),
                                    ],
                                  ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(a.body),
                            const SizedBox(height: 8),
                            Text(
                              '${a.authorName ?? 'School'} · ${_date.format(a.createdAt)}',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),
      ),
    );
  }
}
