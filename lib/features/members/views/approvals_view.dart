import 'package:flutter/material.dart';
import 'package:flutter_redux/flutter_redux.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_theme.dart';
import '../../../data/models/app_user.dart';
import '../../../redux/state/app_state.dart';
import '../../../shared/widgets/common_widgets.dart';
import '../view_models/approvals_view_model.dart';

final _dob = DateFormat('d MMM yyyy');

/// Guru approves or rejects people who signed up for the institute.
class ApprovalsView extends StatefulWidget {
  const ApprovalsView({super.key});

  @override
  State<ApprovalsView> createState() => _ApprovalsViewState();
}

class _ApprovalsViewState extends State<ApprovalsView> {
  /// Rows with a request in flight (local UI state).
  final Set<String> _busy = {};

  Future<void> _review(ApprovalsViewModel vm, AppUser user, {required bool approve}) async {
    if (!approve) {
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Reject request?'),
          content: Text('${user.name} will not get access to the institute.'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
            TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Reject')),
          ],
        ),
      );
      if (ok != true || !mounted) return;
    }
    setState(() => _busy.add(user.id));
    final error = await vm.review(user.id, approve: approve);
    if (!mounted) return;
    setState(() => _busy.remove(user.id));
    showSnack(
      context,
      error ?? (approve ? '${user.name} approved' : 'Request rejected'),
      error: error != null,
    );
  }

  @override
  Widget build(BuildContext context) {
    return StoreConnector<AppState, ApprovalsViewModel>(
      converter: ApprovalsViewModel.fromStore,
      distinct: true,
      onInit: (store) => ApprovalsViewModel.fromStore(store).refresh(),
      builder: (context, vm) => Scaffold(
        appBar: AppBar(title: const Text('Join requests')),
        body: RefreshIndicator(
          onRefresh: vm.refresh,
          child: vm.pending.isEmpty
              ? ListView(
                  children: [
                    if (vm.loading) const LinearProgressIndicator(minHeight: 2),
                    if (vm.error != null)
                      ErrorRetry(message: vm.error!, onRetry: vm.refresh)
                    else if (!vm.loading)
                      const EmptyState(
                        icon: Icons.how_to_reg_outlined,
                        title: 'No pending requests',
                        message: 'Students and gurus who sign up for your institute appear here.',
                      ),
                  ],
                )
              : ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: vm.pending.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, i) {
                    final u = vm.pending[i];
                    final busy = _busy.contains(u.id);
                    return Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                CircleAvatar(
                                  backgroundColor: AppColors.maroon,
                                  child: Text(
                                    u.name.isEmpty ? '?' : u.name[0].toUpperCase(),
                                    style: const TextStyle(color: AppColors.gold),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(u.name, style: Theme.of(context).textTheme.titleMedium),
                                ),
                                StatusChip(
                                  label: u.role.label,
                                  color: u.role.isStaff ? AppColors.maroon : AppColors.info,
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              [
                                if (u.phone != null) u.phone!,
                                if (u.dob != null) 'Born ${_dob.format(u.dob!)}',
                                if (u.gender != null) u.gender!.label,
                              ].join(' · '),
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                            if (u.role.isStaff)
                              Padding(
                                padding: const EdgeInsets.only(top: 6),
                                child: Text(
                                  'Approving gives this person guru access to all school data.',
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodySmall
                                      ?.copyWith(color: AppColors.warning),
                                ),
                              ),
                            const SizedBox(height: 12),
                            busy
                                ? const Center(
                                    child: SizedBox(
                                      width: 22,
                                      height: 22,
                                      child: CircularProgressIndicator(strokeWidth: 2),
                                    ),
                                  )
                                : Row(
                                    children: [
                                      Expanded(
                                        child: OutlinedButton(
                                          onPressed: vm.isOnline
                                              ? () => _review(vm, u, approve: false)
                                              : null,
                                          style: OutlinedButton.styleFrom(
                                            foregroundColor: AppColors.danger,
                                          ),
                                          child: const Text('Reject'),
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: FilledButton(
                                          onPressed: vm.isOnline
                                              ? () => _review(vm, u, approve: true)
                                              : null,
                                          style: FilledButton.styleFrom(
                                            minimumSize: const Size(0, 44),
                                          ),
                                          child: const Text('Approve'),
                                        ),
                                      ),
                                    ],
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
