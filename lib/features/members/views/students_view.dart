import 'package:flutter/material.dart';
import 'package:flutter_redux/flutter_redux.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/routes.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/app_user.dart';
import '../../../redux/state/app_state.dart';
import '../../../shared/widgets/common_widgets.dart';
import '../../../shared/widgets/user_avatar.dart';
import '../view_models/students_view_model.dart';

/// Everyone on the roster. Students the guru added (who may never install the
/// app) can be edited or removed; students with their own login manage themselves.
class StudentsView extends StatefulWidget {
  const StudentsView({super.key});

  @override
  State<StudentsView> createState() => _StudentsViewState();
}

class _StudentsViewState extends State<StudentsView> {
  String _query = '';

  Future<void> _confirmRemove(StudentsViewModel vm, AppUser s) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Remove ${s.name}?'),
        content: const Text('They will no longer appear when you take attendance or pick dancers. '
            'Past attendance is kept.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.danger),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    final error = await vm.remove(s);
    if (!mounted) return;
    showSnack(context, error ?? '${s.name} removed', error: error != null);
  }

  @override
  Widget build(BuildContext context) {
    return StoreConnector<AppState, StudentsViewModel>(
      ignoreChange: (s) => s.auth.user == null,
      converter: StudentsViewModel.fromStore,
      distinct: true,
      onInit: (store) => StudentsViewModel.fromStore(store).refresh(),
      builder: (context, vm) {
        if (!vm.isStaff) {
          return Scaffold(
            appBar: AppBar(title: const Text('Students')),
            body: const EmptyState(
              icon: Icons.lock_outline,
              title: 'Only for guru and teachers',
            ),
          );
        }
        final q = _query.trim().toLowerCase();
        final list = [
          for (final s in vm.students)
            if (q.isEmpty || s.name.toLowerCase().contains(q)) s,
        ];
        return Scaffold(
          appBar: AppBar(title: Text('Students (${vm.students.length})')),
          floatingActionButton: FloatingActionButton.extended(
            onPressed: () => context.push(Routes.studentNew),
            icon: const Icon(Icons.person_add_alt_1),
            label: const Text('Add student'),
          ),
          body: RefreshIndicator(
            onRefresh: vm.refresh,
            child: vm.error != null && vm.students.isEmpty
                ? ListView(children: [ErrorRetry(message: vm.error!, onRetry: vm.refresh)])
                : ListView(
                    padding: const EdgeInsets.only(bottom: 96),
                    children: [
                      if (vm.loading) const LinearProgressIndicator(minHeight: 2),
                      if (vm.students.length > 8)
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                          child: TextField(
                            onChanged: (v) => setState(() => _query = v),
                            decoration: AppTheme.input('Search student', prefixIcon: const Icon(Icons.search)),
                          ),
                        ),
                      if (!vm.loading && vm.students.isEmpty)
                        EmptyState(
                          icon: Icons.groups_outlined,
                          title: 'No students yet',
                          message: 'Add your students here. They do not need to install the app: '
                              'you can still take their attendance and add them to events.',
                          action: FilledButton.icon(
                            onPressed: () => context.push(Routes.studentNew),
                            icon: const Icon(Icons.person_add_alt_1),
                            label: const Text('Add student'),
                          ),
                        ),
                      for (final s in list)
                        ListTile(
                          leading: UserAvatar(name: s.name, photoUrl: s.photoUrl, radius: 22),
                          title: Text(s.name),
                          subtitle: Text(
                            s.managed
                                ? (s.guardianPhone == null ? 'Added by you' : 'Parent: ${s.guardianPhone}')
                                : 'Has their own login',
                          ),
                          onTap: s.managed ? () => context.push(Routes.studentEdit(s.id)) : null,
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              StatusChip(
                                label: s.managed ? 'Not on app' : 'On app',
                                color: s.managed ? AppColors.warning : AppColors.success,
                              ),
                              if (s.managed)
                                PopupMenuButton<String>(
                                  tooltip: 'More',
                                  onSelected: (v) =>
                                      v == 'edit' ? context.push(Routes.studentEdit(s.id)) : _confirmRemove(vm, s),
                                  itemBuilder: (_) => const [
                                    PopupMenuItem(value: 'edit', child: Text('Edit')),
                                    PopupMenuItem(value: 'remove', child: Text('Remove')),
                                  ],
                                ),
                            ],
                          ),
                        ),
                    ],
                  ),
          ),
        );
      },
    );
  }
}
