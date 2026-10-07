import 'package:flutter/material.dart';
import 'package:flutter_redux/flutter_redux.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/router/routes.dart';
import '../../../core/theme/app_theme.dart';
import '../../../redux/state/app_state.dart';
import '../../../shared/widgets/user_avatar.dart';
import '../view_models/profile_view_model.dart';

final _dob = DateFormat('d MMM yyyy');

/// Second tab: who I am, with an Edit button and Sign out.
class ProfileView extends StatelessWidget {
  const ProfileView({super.key});

  Future<void> _confirmSignOut(BuildContext context, ProfileViewModel vm) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Sign out?'),
        content: const Text('You will need your mobile number and password to sign in again.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Sign out')),
        ],
      ),
    );
    if (ok == true) vm.signOut();
  }

  @override
  Widget build(BuildContext context) {
    return StoreConnector<AppState, ProfileViewModel>(
      // During sign-out the user becomes null before the redirect.
      ignoreChange: (s) => s.auth.user == null,
      converter: ProfileViewModel.fromStore,
      distinct: true,
      builder: (context, vm) {
        final u = vm.user;
        return Scaffold(
          appBar: AppBar(
            title: const Text('Profile'),
            actions: [
              IconButton(
                tooltip: 'Edit profile',
                icon: const Icon(Icons.edit_outlined),
                onPressed: () => context.push(Routes.editProfile),
              ),
            ],
          ),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
            children: [
              Center(child: UserAvatar(name: u.name, photoUrl: u.photoUrl, radius: 48)),
              const SizedBox(height: 12),
              Center(child: Text(u.name, style: Theme.of(context).textTheme.titleLarge)),
              const SizedBox(height: 4),
              Center(
                child: Text(u.role.label, style: Theme.of(context).textTheme.bodyMedium),
              ),
              const SizedBox(height: 20),
              Card(
                child: Column(
                  children: [
                    _Row(Icons.account_balance_outlined, 'Institute', u.schoolName ?? '—'),
                    _Row(Icons.phone_iphone, 'Mobile', _phone(u.phone)),
                    _Row(Icons.cake_outlined, 'Date of birth', u.dob == null ? '—' : _dob.format(u.dob!)),
                    _Row(Icons.wc_outlined, 'Gender', u.gender?.label ?? '—'),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: () => context.push(Routes.editProfile),
                icon: const Icon(Icons.edit_outlined),
                label: const Text('Edit profile'),
              ),
              const SizedBox(height: 12),
              TextButton.icon(
                onPressed: () => _confirmSignOut(context, vm),
                style: TextButton.styleFrom(foregroundColor: AppColors.danger),
                icon: const Icon(Icons.logout),
                label: const Text('Sign out'),
              ),
            ],
          ),
        );
      },
    );
  }

  /// +919876543210 → +91 98765 43210
  String _phone(String? e164) {
    if (e164 == null || e164.isEmpty) return '—';
    final d = e164.replaceAll(RegExp(r'\D'), '');
    if (d.length == 12 && d.startsWith('91')) return '+91 ${d.substring(2, 7)} ${d.substring(7)}';
    return e164;
  }
}

class _Row extends StatelessWidget {
  const _Row(this.icon, this.label, this.value);
  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => ListTile(
        leading: Icon(icon, color: AppColors.maroon),
        title: Text(label, style: Theme.of(context).textTheme.bodySmall),
        subtitle: Text(value, style: Theme.of(context).textTheme.bodyLarge),
      );
}
