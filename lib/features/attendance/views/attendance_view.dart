import 'package:flutter/material.dart';
import 'package:flutter_redux/flutter_redux.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/router/routes.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/attendance_record.dart';
import '../../../data/models/attendance_summary.dart';
import '../../../redux/state/app_state.dart';
import '../../../shared/widgets/common_widgets.dart';
import '../../../shared/widgets/form_fields.dart';
import '../../../shared/widgets/user_avatar.dart';
import '../view_models/attendance_view_model.dart';

final _dayLabel = DateFormat('EEE, d MMM yyyy');
final _monthLabel = DateFormat('MMMM yyyy');

bool _sameDay(DateTime? a, DateTime b) =>
    a != null && a.year == b.year && a.month == b.month && a.day == b.day;

/// Staff take attendance for a date (each student Present or Absent) and see
/// the month's percentages. Works offline; Firestore syncs later.
class AttendanceView extends StatefulWidget {
  const AttendanceView({super.key});

  @override
  State<AttendanceView> createState() => _AttendanceViewState();
}

class _AttendanceViewState extends State<AttendanceView> with SingleTickerProviderStateMixin {
  late final TabController _tabs = TabController(length: 2, vsync: this);

  DateTime _date = AttendanceRecord.dayOf(DateTime.now());
  DateTime _month = DateTime(DateTime.now().year, DateTime.now().month);

  /// Taps not saved yet: studentId → present?. Only differences from what is saved.
  final _edits = <String, bool>{};
  String _query = '';

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  bool get _dirty => _edits.isNotEmpty;

  bool _markOf(AttendanceViewModel vm, String id) =>
      _edits[id] ?? _saved(vm)?.marks[id] ?? true; // new dates start as Present

  AttendanceRecord? _saved(AttendanceViewModel vm) =>
      _sameDay(vm.date, _date) ? vm.record : null;

  /// The batch the screen is set to (what the store holds).
  String _batch(AttendanceViewModel vm) => vm.batchId;

  void _set(AttendanceViewModel vm, String id, bool present) {
    final base = _saved(vm)?.marks[id] ?? true;
    setState(() => present == base ? _edits.remove(id) : _edits[id] = present);
  }

  void _setAll(AttendanceViewModel vm, bool present) {
    setState(() {
      _edits.clear();
      for (final s in vm.roster) {
        if ((_saved(vm)?.marks[s.id] ?? true) != present) _edits[s.id] = present;
      }
    });
  }

  Future<bool> _confirmDiscard() async {
    if (!_dirty) return true;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Discard changes?'),
        content: const Text('You have attendance that is not saved yet.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Keep editing')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Discard')),
        ],
      ),
    );
    return ok == true;
  }

  Future<void> _goTo(AttendanceViewModel vm, DateTime day) async {
    final d = AttendanceRecord.dayOf(day);
    if (_sameDay(_date, d) || !await _confirmDiscard()) return;
    setState(() {
      _date = d;
      _edits.clear();
    });
    vm.load(d, _batch(vm));
  }

  Future<void> _pickDate(AttendanceViewModel vm) async {
    final today = AttendanceRecord.dayOf(DateTime.now());
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(today.year - 2),
      lastDate: today,
      initialEntryMode: DatePickerEntryMode.calendarOnly,
    );
    if (picked != null && mounted) _goTo(vm, picked);
  }

  Future<void> _selectBatch(AttendanceViewModel vm, String batchId) async {
    if (batchId == vm.batchId || !await _confirmDiscard()) return;
    setState(() {
      _edits.clear();
      _query = '';
    });
    vm.load(_date, batchId);
  }

  Future<void> _save(AttendanceViewModel vm) async {
    final marks = {for (final s in vm.roster) s.id: _markOf(vm, s.id)};
    final error = await vm.save(_date, marks, _batch(vm));
    if (!mounted) return;
    if (error != null) {
      showSnack(context, error, error: true);
      return;
    }
    setState(_edits.clear);
    showSnack(
      context,
      vm.isOnline
          ? 'Attendance saved for ${_dayLabel.format(_date)}'
          : 'Saved on this phone. It will sync when you are online.',
    );
  }

  void _changeMonth(AttendanceViewModel vm, int delta) {
    final now = DateTime.now();
    final next = DateTime(_month.year, _month.month + delta);
    if (next.isAfter(DateTime(now.year, now.month))) return;
    setState(() => _month = next);
    vm.loadMonth(next);
  }

  @override
  Widget build(BuildContext context) {
    return StoreConnector<AppState, AttendanceViewModel>(
      ignoreChange: (s) => s.auth.user == null,
      converter: AttendanceViewModel.fromStore,
      distinct: true,
      onInit: (store) {
        final vm = AttendanceViewModel.fromStore(store);
        if (!vm.isStaff) return;
        vm.loadStudents();
        vm.loadBatches();
        vm.load(_date, vm.batchId);
        vm.loadMonth(_month);
      },
      onWillChange: (prev, next) {
        if (next.saveError != null && next.saveError != prev?.saveError) {
          showSnack(context, next.saveError!, error: true);
          next.clearSaveError();
        }
      },
      builder: (context, vm) {
        if (!vm.isStaff) {
          return Scaffold(
            appBar: AppBar(title: const Text('Attendance')),
            body: const EmptyState(
              icon: Icons.lock_outline,
              title: 'Only for guru and teachers',
              message: 'Your guru takes attendance for the class.',
            ),
          );
        }
        return Scaffold(
          appBar: AppBar(
            title: const Text('Attendance'),
            actions: [
              IconButton(
                tooltip: 'Batches',
                icon: const Icon(Icons.layers_outlined),
                onPressed: () => context.push(Routes.batches),
              ),
            ],
            bottom: TabBar(controller: _tabs, tabs: const [Tab(text: 'Take'), Tab(text: 'Summary')]),
          ),
          body: TabBarView(
            controller: _tabs,
            children: [_takeTab(context, vm), _summaryTab(context, vm)],
          ),
        );
      },
    );
  }

  // ---------------------------------------------------------------- Take

  Widget _takeTab(BuildContext context, AttendanceViewModel vm) {
    final today = AttendanceRecord.dayOf(DateTime.now());
    final isToday = _sameDay(_date, today);
    final saved = _saved(vm);
    final q = _query.trim().toLowerCase();
    final roster = [
      for (final s in vm.roster)
        if (q.isEmpty || s.name.toLowerCase().contains(q)) s,
    ];
    final present = vm.roster.where((s) => _markOf(vm, s.id)).length;
    final absent = vm.roster.length - present;
    final busy = vm.loading;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
          child: Row(
            children: [
              IconButton(
                tooltip: 'Previous day',
                icon: const Icon(Icons.chevron_left),
                onPressed: () => _goTo(vm, _date.subtract(const Duration(days: 1))),
              ),
              Expanded(
                child: TextButton.icon(
                  onPressed: () => _pickDate(vm),
                  icon: const Icon(Icons.event_outlined),
                  label: Text(isToday ? 'Today · ${_dayLabel.format(_date)}' : _dayLabel.format(_date)),
                ),
              ),
              IconButton(
                tooltip: 'Next day',
                icon: const Icon(Icons.chevron_right),
                onPressed: isToday ? null : () => _goTo(vm, _date.add(const Duration(days: 1))),
              ),
            ],
          ),
        ),
        _BatchPicker(vm: vm, onChanged: (id) => _selectBatch(vm, id)),
        if (busy || vm.studentsLoading) const LinearProgressIndicator(minHeight: 2),
        Expanded(
          child: vm.error != null
              ? ErrorRetry(message: vm.error!, onRetry: () => vm.load(_date, vm.batchId))
              : vm.roster.isEmpty
                  ? EmptyState(
                      icon: Icons.groups_outlined,
                      title: vm.studentsLoading
                          ? 'Loading students…'
                          : vm.batchId == AttendanceRecord.allStudents
                              ? 'No students yet'
                              : 'No students in this batch',
                      message: vm.studentsError ??
                          (vm.studentsLoading
                              ? null
                              : vm.batchId == AttendanceRecord.allStudents
                                  ? 'Add your students, or approve their join requests.'
                                  : 'Choose who is in this batch on the Batches screen.'),
                      action: vm.studentsLoading
                          ? null
                          : vm.batchId == AttendanceRecord.allStudents
                              ? FilledButton.icon(
                                  onPressed: () => context.push(Routes.studentNew),
                                  icon: const Icon(Icons.person_add_alt_1),
                                  label: const Text('Add student'),
                                )
                              : FilledButton.icon(
                                  onPressed: () => context.push(Routes.batches),
                                  icon: const Icon(Icons.layers_outlined),
                                  label: const Text('Open batches'),
                                ),
                    )
                  : ListView(
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                      children: [
                        Wrap(
                          spacing: 8,
                          runSpacing: 4,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            StatusChip(label: 'Present $present', color: AppColors.success),
                            StatusChip(label: 'Absent $absent', color: AppColors.danger),
                            StatusChip(
                              label: _dirty
                                  ? 'Unsaved changes'
                                  : saved != null
                                      ? 'Saved'
                                      : 'Not taken yet',
                              color: _dirty ? AppColors.warning : AppColors.info,
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                onPressed: busy ? null : () => _setAll(vm, true),
                                child: const Text('All present'),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: OutlinedButton(
                                onPressed: busy ? null : () => _setAll(vm, false),
                                child: const Text('All absent'),
                              ),
                            ),
                          ],
                        ),
                        if (vm.roster.length > 8) ...[
                          const SizedBox(height: 8),
                          TextField(
                            onChanged: (v) => setState(() => _query = v),
                            decoration: AppTheme.input('Search student', prefixIcon: const Icon(Icons.search)),
                          ),
                        ],
                        const SizedBox(height: 8),
                        for (final s in roster)
                          _StudentRow(
                            key: ValueKey(s.id),
                            name: s.name,
                            photoUrl: s.photoUrl,
                            present: _markOf(vm, s.id),
                            enabled: !busy,
                            onChanged: (p) => _set(vm, s.id, p),
                          ),
                      ],
                    ),
        ),
        if (vm.roster.isNotEmpty)
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
              child: LoadingButton(
                label: saved == null ? 'Save attendance' : 'Update attendance',
                loading: false,
                onPressed: busy ? null : () => _save(vm),
              ),
            ),
          ),
      ],
    );
  }

  // ------------------------------------------------------------- Summary

  Widget _summaryTab(BuildContext context, AttendanceViewModel vm) {
    final theme = Theme.of(context);
    final summary = vm.summary;
    final now = DateTime.now();
    final isCurrentMonth = _month.year == now.year && _month.month == now.month;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
      children: [
        Row(
          children: [
            IconButton(
              tooltip: 'Previous month',
              icon: const Icon(Icons.chevron_left),
              onPressed: () => _changeMonth(vm, -1),
            ),
            Expanded(
              child: Text(_monthLabel.format(_month), textAlign: TextAlign.center, style: theme.textTheme.titleMedium),
            ),
            IconButton(
              tooltip: 'Next month',
              icon: const Icon(Icons.chevron_right),
              onPressed: isCurrentMonth ? null : () => _changeMonth(vm, 1),
            ),
          ],
        ),
        _BatchPicker(vm: vm, onChanged: (id) => _selectBatch(vm, id)),
        if (vm.monthLoading) const LinearProgressIndicator(minHeight: 2),
        if (vm.monthError != null)
          ErrorRetry(message: vm.monthError!, onRetry: () => vm.loadMonth(_month))
        else if (summary.classesHeld == 0 && !vm.monthLoading)
          const EmptyState(
            icon: Icons.event_busy_outlined,
            title: 'No attendance this month',
            message: 'Take attendance on the Take tab and it will appear here.',
          )
        else ...[
          Row(
            children: [
              Expanded(child: _Stat(label: 'Classes held', value: '${summary.classesHeld}', icon: Icons.event_available_outlined)),
              const SizedBox(width: 12),
              Expanded(
                child: _Stat(
                  label: 'Average attendance',
                  value: '${summary.averagePercent.round()}%',
                  icon: Icons.insights_outlined,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text('Students', style: theme.textTheme.titleMedium),
          const SizedBox(height: 4),
          for (final row in summary.students) _SummaryRow(row: row),
          const SizedBox(height: 16),
          Text('Class days', style: theme.textTheme.titleMedium),
          const SizedBox(height: 4),
          for (final r in vm.batchMonth.reversed)
            Card(
              child: ListTile(
                title: Text(_dayLabel.format(r.date)),
                subtitle: Text(
                  '${r.presentCount} present · ${r.absentCount} absent'
                  '${vm.batchId == AttendanceRecord.allStudents ? ' · ${vm.batchName(r.batchId)}' : ''}',
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () async {
                  if (r.batchId != vm.batchId) await _selectBatch(vm, r.batchId);
                  if (!mounted) return;
                  await _goTo(vm, r.date);
                  if (mounted && _sameDay(_date, r.date)) _tabs.animateTo(0);
                },
              ),
            ),
        ],
      ],
    );
  }
}

/// "All students" plus each batch, as a row of chips.
class _BatchPicker extends StatelessWidget {
  const _BatchPicker({required this.vm, required this.onChanged});

  final AttendanceViewModel vm;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    if (vm.batches.isEmpty) return const SizedBox.shrink();
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Row(
        children: [
          for (final (id, label) in [
            (AttendanceRecord.allStudents, 'All students'),
            for (final b in vm.batches) (b.id, b.name),
          ])
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(
                label: Text(label),
                selected: vm.batchId == id,
                onSelected: (_) => onChanged(id),
              ),
            ),
        ],
      ),
    );
  }
}

class _StudentRow extends StatelessWidget {
  const _StudentRow({
    super.key,
    required this.name,
    required this.photoUrl,
    required this.present,
    required this.enabled,
    required this.onChanged,
  });

  final String name;
  final String? photoUrl;
  final bool present;
  final bool enabled;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: Row(
            children: [
              UserAvatar(name: name, photoUrl: photoUrl, radius: 18),
              const SizedBox(width: 12),
              Expanded(child: Text(name, maxLines: 1, overflow: TextOverflow.ellipsis)),
              ChoiceChip(
                label: const Text('Present'),
                selected: present,
                selectedColor: AppColors.success.withValues(alpha: 0.2),
                onSelected: enabled ? (_) => onChanged(true) : null,
              ),
              const SizedBox(width: 6),
              ChoiceChip(
                label: const Text('Absent'),
                selected: !present,
                selectedColor: AppColors.danger.withValues(alpha: 0.2),
                onSelected: enabled ? (_) => onChanged(false) : null,
              ),
            ],
          ),
        ),
      );
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value, required this.icon});
  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: AppColors.maroon),
              const SizedBox(height: 8),
              Text(value, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w700)),
              Text(label, style: const TextStyle(fontSize: 12)),
            ],
          ),
        ),
      );
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({required this.row});
  final StudentAttendance row;

  Color get _color => row.percent >= 75
      ? AppColors.success
      : row.percent >= 50
          ? AppColors.warning
          : AppColors.danger;

  @override
  Widget build(BuildContext context) {
    final hasClasses = row.total > 0;
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: UserAvatar(name: row.student.name, photoUrl: row.student.photoUrl, radius: 18),
      title: Text(row.student.name),
      subtitle: hasClasses
          ? Padding(
              padding: const EdgeInsets.only(top: 4),
              child: LinearProgressIndicator(
                value: row.percent / 100,
                color: _color,
                backgroundColor: _color.withValues(alpha: 0.15),
                minHeight: 6,
                borderRadius: BorderRadius.circular(3),
              ),
            )
          : const Text('No classes yet'),
      // Fixed width, so every row's bar ends at the same place.
      trailing: SizedBox(
        width: 52,
        child: hasClasses
            ? Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text('${row.percent.round()}%', style: TextStyle(fontWeight: FontWeight.w700, color: _color)),
                  Text('${row.present}/${row.total}', style: Theme.of(context).textTheme.bodySmall),
                ],
              )
            : null,
      ),
    );
  }
}
