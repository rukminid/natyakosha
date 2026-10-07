import 'package:flutter/material.dart';
import 'package:flutter_redux/flutter_redux.dart';

import '../../../core/theme/app_theme.dart';
import '../../../data/models/app_user.dart';
import '../../../redux/state/app_state.dart';
import '../view_models/pending_approval_view_model.dart';

/// Shown after sign-up until the institute's guru approves the account.
/// The router moves the user to the dashboard as soon as they're approved.
class PendingApprovalView extends StatefulWidget {
  const PendingApprovalView({super.key});

  @override
  State<PendingApprovalView> createState() => _PendingApprovalViewState();
}

class _PendingApprovalViewState extends State<PendingApprovalView> {
  bool _checking = false;

  Future<void> _check(PendingApprovalViewModel vm) async {
    setState(() => _checking = true);
    await vm.checkAgain();
    if (mounted) setState(() => _checking = false);
  }

  @override
  Widget build(BuildContext context) {
    return StoreConnector<AppState, PendingApprovalViewModel>(
      converter: PendingApprovalViewModel.fromStore,
      distinct: true,
      builder: (context, vm) {
        final rejected = vm.status == AccountStatus.rejected;
        return Scaffold(
          body: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Icon(
                    rejected ? Icons.block : Icons.hourglass_top_rounded,
                    size: 72,
                    color: rejected ? AppColors.danger : AppColors.gold,
                  ),
                  const SizedBox(height: 20),
                  Text(
                    rejected ? 'Request not approved' : 'Namaskaram, ${vm.name.split(' ').first}!',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    rejected
                        ? 'The guru at ${vm.instituteName} did not approve this account. '
                            'Please contact your guru if you think this is a mistake.'
                        : 'Your account is waiting for approval from the guru at '
                            '${vm.instituteName}. You\'ll get access as soon as they approve it.',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 32),
                  if (!rejected)
                    FilledButton.icon(
                      onPressed: _checking ? null : () => _check(vm),
                      icon: _checking
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : const Icon(Icons.refresh),
                      label: const Text('Check again'),
                    ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: vm.signOut,
                    icon: const Icon(Icons.logout),
                    label: const Text('Sign out'),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
