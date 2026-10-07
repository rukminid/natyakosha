import 'package:flutter/material.dart';
import 'package:flutter_redux/flutter_redux.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/router/routes.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/attendance_summary.dart';
import '../../../redux/state/app_state.dart';
import '../../../shared/widgets/common_widgets.dart';
import '../view_models/my_attendance_view_model.dart';

final _monthLabel = DateFormat('MMMM yyyy');
final _dayLabel = DateFormat('EEE, d MMM');

/// A student's own attendance, month by month. A parent sees each child.
class MyAttendanceView extends StatefulWidget {
  const MyAttendanceView({super.key});

  @override
  State<MyAttendanceView> createState() => _MyAttendanceViewState();
}

class _MyAttendanceViewState extends State<MyAttendanceView> {
  DateTime _month = DateTime(DateTime.now().year, DateTime.now().month);

  void _change(MyAttendanceViewModel vm, int delta) {
    final now = DateTime.now();
    final next = DateTime(_month.year, _month.month + delta);
    if (next.isAfter(DateTime(now.year, now.month))) return;
    setState(() => _month = next);
    vm.load(next);
  }

  @override
  Widget build(BuildContext context) {
    return StoreConnector<AppState, MyAttendanceViewModel>(
      ignoreChange: (s) => s.auth.user == null,
      converter: MyAttendanceViewModel.fromStore,
      distinct: true,
      onInit: (store) {
        final vm = MyAttendanceViewModel.fromStore(store);
        if (!vm.isStaff) vm.load(_month);
      },
      builder: (context, vm) {
        if (vm.isStaff) {
          // Staff take attendance; they do not have one of their own.
          return Scaffold(
            appBar: AppBar(title: const Text('Attendance')),
            body: EmptyState(
              icon: Icons.how_to_reg_outlined,
              title: 'Take attendance',
              action: FilledButton(onPressed: () => context.go(Routes.attendance), child: const Text('Open attendance')),
            ),
          );
        }
        final now = DateTime.now();
        final isCurrent = _month.year == now.year && _month.month == now.month;
        return Scaffold(
          appBar: AppBar(title: const Text('My attendance')),
          body: RefreshIndicator(
            onRefresh: () => vm.load(_month),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
              children: [
                Row(
                  children: [
                    IconButton(
                      tooltip: 'Previous month',
                      icon: const Icon(Icons.chevron_left),
                      onPressed: () => _change(vm, -1),
                    ),
                    Expanded(
                      child: Text(_monthLabel.format(_month),
                          textAlign: TextAlign.center, style: Theme.of(context).textTheme.titleMedium),
                    ),
                    IconButton(
                      tooltip: 'Next month',
                      icon: const Icon(Icons.chevron_right),
                      onPressed: isCurrent ? null : () => _change(vm, 1),
                    ),
                  ],
                ),
                if (vm.loading) const LinearProgressIndicator(minHeight: 2),
                if (vm.error != null)
                  ErrorRetry(message: vm.error!, onRetry: () => vm.load(_month))
                else if (vm.people.isEmpty)
                  const EmptyState(
                    icon: Icons.child_care_outlined,
                    title: 'No student linked',
                    message: 'Ask your guru to link your child to your account.',
                  )
                else
                  for (final p in vm.people) _PersonCard(name: p.name, data: p.data, loading: vm.loading, showName: vm.people.length > 1),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _PersonCard extends StatelessWidget {
  const _PersonCard({required this.name, required this.data, required this.loading, required this.showName});

  final String name;
  final StudentMonth data;
  final bool loading;
  final bool showName;

  Color get _color => data.percent >= 75
      ? AppColors.success
      : data.percent >= 50
          ? AppColors.warning
          : AppColors.danger;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final byDay = data.byDay;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (showName) Text(name, style: theme.textTheme.titleMedium),
            if (data.total == 0)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Text(loading ? 'Loading…' : 'No classes recorded this month.', style: theme.textTheme.bodyMedium),
              )
            else ...[
              const SizedBox(height: 8),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text('${data.percent.round()}%',
                      style: theme.textTheme.headlineMedium?.copyWith(color: _color, fontWeight: FontWeight.w700)),
                  const SizedBox(width: 12),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Text('${data.present} of ${data.total} classes attended', style: theme.textTheme.bodyMedium),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              LinearProgressIndicator(
                value: data.percent / 100,
                color: _color,
                backgroundColor: _color.withValues(alpha: 0.15),
                minHeight: 8,
                borderRadius: BorderRadius.circular(4),
              ),
              const SizedBox(height: 12),
              for (final e in byDay)
                ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  title: Text(_dayLabel.format(e.key)),
                  trailing: StatusChip(
                    label: e.value ? 'Present' : 'Absent',
                    color: e.value ? AppColors.success : AppColors.danger,
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }
}
