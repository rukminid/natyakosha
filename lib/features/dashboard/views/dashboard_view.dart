import 'package:flutter/material.dart';
import 'package:flutter_redux/flutter_redux.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/router/routes.dart';
import '../../../core/theme/app_theme.dart';
import '../../../redux/state/app_state.dart';
import '../view_models/dashboard_view_model.dart';

final _rupees = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);
final _date = DateFormat('EEE, d MMM');

class DashboardView extends StatelessWidget {
  const DashboardView({super.key});

  @override
  Widget build(BuildContext context) {
    return StoreConnector<AppState, DashboardViewModel>(
      // Guard: during sign-out the user becomes null before the redirect.
      ignoreChange: (s) => s.auth.user == null,
      converter: DashboardViewModel.fromStore,
      distinct: true,
      onInit: (store) => DashboardViewModel.fromStore(store).refresh(),
      builder: (context, vm) => Scaffold(
        appBar: AppBar(
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Namaskaram, ${vm.user.name.split(' ').first}'),
              Text(vm.user.role.label, style: Theme.of(context).textTheme.bodySmall),
            ],
          ),
        ),
        body: RefreshIndicator(
          onRefresh: vm.refresh,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
            children: [
              if (vm.loading) const LinearProgressIndicator(minHeight: 2),
              const SizedBox(height: 8),
              vm.isStaff ? _GuruSummary(vm: vm) : _StudentSummary(vm: vm),
              if (vm.isStaff && vm.joinRequests > 0) ...[
                const SizedBox(height: 12),
                Card(
                  color: AppColors.gold.withValues(alpha: 0.15),
                  child: ListTile(
                    leading: const Icon(Icons.person_add_alt_1, color: AppColors.maroon),
                    title: Text(
                      vm.joinRequests == 1
                          ? '1 person wants to join'
                          : '${vm.joinRequests} people want to join',
                    ),
                    subtitle: const Text('Review join requests'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => context.push(Routes.approvals),
                  ),
                ),
              ],
              const SizedBox(height: 20),
              const _SectionTitle('Quick actions'),
              _QuickActions(isStaff: vm.isStaff),
              const SizedBox(height: 20),
              _SectionTitle('Upcoming events', onMore: () => context.go(Routes.events)),
              if (vm.upcomingEvents.isEmpty)
                const _Muted('No upcoming events yet.')
              else
                for (final e in vm.upcomingEvents)
                  Card(
                    child: ListTile(
                      onTap: () => context.push(Routes.eventDetail(e.id)),
                      leading: const Icon(Icons.theater_comedy, color: AppColors.maroon),
                      title: Text(e.title),
                      subtitle: Text('${_date.format(e.date)} · ${e.venue}'),
                      trailing: Text('${e.totalParticipants} dancers'),
                    ),
                  ),
              const SizedBox(height: 20),
              _SectionTitle('Announcements', onMore: () => context.push(Routes.announcements)),
              if (vm.announcements.isEmpty)
                const _Muted('No announcements.')
              else
                for (final a in vm.announcements)
                  Card(
                    child: ListTile(
                      leading: Icon(
                        a.pinned ? Icons.push_pin : Icons.campaign_outlined,
                        color: AppColors.gold,
                      ),
                      title: Text(a.title),
                      subtitle: Text(a.body, maxLines: 2, overflow: TextOverflow.ellipsis),
                    ),
                  ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GuruSummary extends StatelessWidget {
  const _GuruSummary({required this.vm});
  final DashboardViewModel vm;

  @override
  Widget build(BuildContext context) => Row(
        children: [
          Expanded(
            child: _StatTile(
              label: 'Collected this month',
              value: _rupees.format(vm.collectedThisMonth),
              icon: Icons.account_balance_wallet_outlined,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _StatTile(
              label: 'Screenshots to verify',
              value: '${vm.awaitingReview}',
              icon: Icons.fact_check_outlined,
              highlight: vm.awaitingReview > 0,
              onTap: () => context.push(Routes.payments),
            ),
          ),
        ],
      );
}

class _StudentSummary extends StatelessWidget {
  const _StudentSummary({required this.vm});
  final DashboardViewModel vm;

  @override
  Widget build(BuildContext context) => _StatTile(
        label: vm.myOpenPayments.isEmpty ? 'All fees up to date' : 'Payments needing attention',
        value: vm.myOpenPayments.isEmpty ? '✓' : '${vm.myOpenPayments.length}',
        icon: Icons.receipt_long_outlined,
        highlight: vm.myOpenPayments.isNotEmpty,
        onTap: () => context.push(Routes.payments),
      );
}

class _StatTile extends StatelessWidget {
  const _StatTile({
    required this.label,
    required this.value,
    required this.icon,
    this.highlight = false,
    this.onTap,
  });

  final String label;
  final String value;
  final IconData icon;
  final bool highlight;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final fg = highlight ? AppColors.ivory : AppColors.ink;
    return Material(
      color: highlight ? AppColors.maroon : Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: highlight ? AppColors.gold : AppColors.maroon),
              const SizedBox(height: 12),
              Text(value, style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700, color: fg)),
              const SizedBox(height: 4),
              Text(label, style: TextStyle(fontSize: 12, color: fg)),
            ],
          ),
        ),
      ),
    );
  }
}

class _QuickActions extends StatelessWidget {
  const _QuickActions({required this.isStaff});
  final bool isStaff;

  @override
  Widget build(BuildContext context) {
    final actions = <(IconData, String, String)>[
      if (isStaff) (Icons.how_to_reg_outlined, 'Attendance', Routes.attendance),
      if (!isStaff) (Icons.how_to_reg_outlined, 'Attendance', Routes.myAttendance),
      if (isStaff) (Icons.layers_outlined, 'Batches', Routes.batches),
      if (isStaff) (Icons.groups_outlined, 'Students', Routes.students),
      if (isStaff) (Icons.person_add_alt_1_outlined, 'Join requests', Routes.approvals),
      (Icons.payments_outlined, isStaff ? 'Verify fees' : 'My fees', Routes.payments),
      (Icons.theater_comedy_outlined, 'Events', Routes.events),
      (Icons.request_quote_outlined, 'Event fees', Routes.eventFees),
      (Icons.photo_library_outlined, 'Gallery', Routes.gallery),
      (Icons.campaign_outlined, 'Notices', Routes.announcements),
      (Icons.menu_book_outlined, 'Theory', Routes.theory),
    ];
    return GridView.count(
      crossAxisCount: 4,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 8,
      crossAxisSpacing: 8,
      childAspectRatio: 0.85,
      children: [
        for (final (icon, label, route) in actions)
          InkWell(
            borderRadius: BorderRadius.circular(12),
            // Events is a bottom-bar tab, so switch to it instead of stacking a copy.
            onTap: () => route == Routes.events ? context.go(route) : context.push(route),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircleAvatar(
                  radius: 24,
                  backgroundColor: AppColors.maroon.withValues(alpha: 0.08),
                  child: Icon(icon, color: AppColors.maroon),
                ),
                const SizedBox(height: 6),
                Text(label, style: const TextStyle(fontSize: 12), textAlign: TextAlign.center),
              ],
            ),
          ),
      ],
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text, {this.onMore});
  final String text;
  final VoidCallback? onMore;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Row(
          children: [
            Expanded(child: Text(text, style: Theme.of(context).textTheme.titleMedium)),
            if (onMore != null) TextButton(onPressed: onMore, child: const Text('See all')),
          ],
        ),
      );
}

class _Muted extends StatelessWidget {
  const _Muted(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Text(text, style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.grey)),
      );
}
