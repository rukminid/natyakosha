import 'package:flutter/material.dart';
import 'package:flutter_form_builder/flutter_form_builder.dart';
import 'package:flutter_redux/flutter_redux.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/validators/app_validators.dart';
import '../../../data/models/app_user.dart';
import '../../../data/models/dance_event.dart';
import '../../../redux/state/app_state.dart';
import '../../../shared/widgets/common_widgets.dart';
import '../../../shared/widgets/form_fields.dart';
import '../../../shared/widgets/user_multi_picker.dart';
import '../view_models/events_view_model.dart';

/// Create ([eventId] null) or edit an event: details, schedule, optional
/// fee and the dancers taking part. Staff only.
class EventFormView extends StatefulWidget {
  const EventFormView({super.key, this.eventId, this.initialDate});

  final String? eventId;

  /// Day pre-filled for a new event (picked on the calendar).
  final DateTime? initialDate;

  @override
  State<EventFormView> createState() => _EventFormViewState();
}

class _EventFormViewState extends State<EventFormView> {
  final _formKey = GlobalKey<FormBuilderState>();
  final _dateFormat = DateFormat('EEE, d MMM yyyy');

  bool _initialised = false;
  bool _hasFee = false;
  bool _saving = false;
  Set<String> _selected = {};

  void _init(DanceEvent? event) {
    if (_initialised) return;
    _initialised = true;
    _selected = {...?event?.participantIds};
    _hasFee = event?.fee != null;
  }

  DateTime _at(DateTime day, DateTime time) =>
      DateTime(day.year, day.month, day.day, time.hour, time.minute);

  Future<void> _pickDancers(EventFormViewModel vm) async {
    final result = await showModalBottomSheet<Set<String>>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => UserMultiPicker(
        title: 'Choose dancers',
        options: [for (final s in vm.students) PickerOption(s.id, s.name)],
        initial: _selected,
        emptyTitle: 'No approved students yet',
        emptyMessage: 'Students appear here once you approve their join request.',
      ),
    );
    if (result != null) setState(() => _selected = result);
  }

  Future<void> _save(EventFormViewModel vm) async {
    FocusScope.of(context).unfocus();
    final form = _formKey.currentState!;
    if (!form.saveAndValidate()) return;
    final v = form.value;

    final day = v['date'] as DateTime;
    final start = _at(day, v['start'] as DateTime);
    final endTime = v['end'] as DateTime?;
    String? clean(Object? s) {
      final t = (s as String?)?.trim() ?? '';
      return t.isEmpty ? null : t;
    }

    final existing = vm.event;
    final event = DanceEvent(
      id: existing?.id ?? '',
      title: (v['title'] as String).trim(),
      date: start,
      endsAt: endTime == null ? null : _at(day, endTime),
      venue: (v['venue'] as String).trim(),
      organiser: clean(v['organiser']),
      description: clean(v['description']),
      groupId: existing?.groupId,
      participantIds: _selected.toList(),
      coverUrl: existing?.coverUrl,
      fee: _hasFee
          ? EventFeeConfig(
              amount: double.parse((v['feeAmount'] as String).trim()),
              dueDate: v['feeDue'] as DateTime,
              description: clean(v['feeDesc']),
              upiId: clean(v['feeUpi']),
            )
          : null,
    );

    // Keep people who are no longer in the student list (so editing never
    // silently drops them); new fee records only need names for new dancers.
    final byId = {for (final s in vm.students) s.id: s};
    final participants = [
      for (final id in _selected)
        byId[id] ??
            AppUser(id: id, name: 'Former member', role: UserRole.student, schoolId: ''),
    ];

    setState(() => _saving = true);
    final error = await vm.save(event, participants);
    if (!mounted) return;
    setState(() => _saving = false);
    if (error != null) {
      showSnack(context, error, error: true);
      return;
    }
    showSnack(context, existing == null ? 'Event created' : 'Event updated');
    context.pop();
  }

  @override
  Widget build(BuildContext context) {
    final today = DateTime.now();
    return StoreConnector<AppState, EventFormViewModel>(
      ignoreChange: (s) => s.auth.user == null,
      converter: (store) => EventFormViewModel.fromStore(store, widget.eventId),
      distinct: true,
      onInit: (store) => EventFormViewModel.fromStore(store, widget.eventId).loadStudents(),
      builder: (context, vm) {
        final editing = widget.eventId != null;
        if (editing && vm.event == null) {
          return Scaffold(
            appBar: AppBar(title: const Text('Edit event')),
            body: const EmptyState(icon: Icons.event_busy, title: 'Event not found'),
          );
        }
        final e = vm.event;
        _init(e);
        final defaultDay = e?.date ?? widget.initialDate ?? today;
        final selectedNames = [
          for (final s in vm.students)
            if (_selected.contains(s.id)) s.name,
        ];

        return Scaffold(
          appBar: AppBar(title: Text(editing ? 'Edit event' : 'New event')),
          body: FormBuilder(
            key: _formKey,
            enabled: !_saving,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
              children: [
                FormBuilderTextField(
                  name: 'title',
                  initialValue: e?.title,
                  textCapitalization: TextCapitalization.words,
                  textInputAction: TextInputAction.next,
                  decoration: AppTheme.input('Event title', prefixIcon: const Icon(Icons.theater_comedy_outlined)),
                  validator: (v) =>
                      AppValidators.required<String>('Title')(v) ?? AppValidators.maxLength(80, 'Title')(v),
                ),
                const SizedBox(height: 16),
                FormBuilderDateTimePicker(
                  name: 'date',
                  initialValue: DateTime(defaultDay.year, defaultDay.month, defaultDay.day),
                  inputType: InputType.date,
                  format: _dateFormat,
                  firstDate: DateTime(2020),
                  lastDate: DateTime(today.year + 5),
                  initialEntryMode: DatePickerEntryMode.calendarOnly,
                  decoration: AppTheme.input('Date', prefixIcon: const Icon(Icons.event_outlined)),
                  validator: AppValidators.required<DateTime>('Date'),
                ),
                const SizedBox(height: 16),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: FormBuilderDateTimePicker(
                        name: 'start',
                        initialValue: e?.date ?? DateTime(today.year, today.month, today.day, 17),
                        inputType: InputType.time,
                        decoration: AppTheme.input('Starts', prefixIcon: const Icon(Icons.schedule)),
                        validator: AppValidators.required<DateTime>('Start time'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FormBuilderDateTimePicker(
                        name: 'end',
                        initialValue: e?.endsAt,
                        inputType: InputType.time,
                        decoration: AppTheme.input('Ends (optional)', prefixIcon: const Icon(Icons.schedule_outlined)),
                        validator: (end) {
                          final start = _formKey.currentState?.fields['start']?.value as DateTime?;
                          if (end == null || start == null) return null;
                          final s = start.hour * 60 + start.minute;
                          final t = end.hour * 60 + end.minute;
                          return t <= s ? 'End must be after start' : null;
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                FormBuilderTextField(
                  name: 'venue',
                  initialValue: e?.venue,
                  textCapitalization: TextCapitalization.words,
                  textInputAction: TextInputAction.next,
                  decoration: AppTheme.input(
                    'Venue',
                    prefixIcon: const Icon(Icons.place_outlined),
                    helper: 'Type the hall and city, e.g. Ravindra Bharathi, Hyderabad',
                  ),
                  validator: (v) =>
                      AppValidators.required<String>('Venue')(v) ?? AppValidators.maxLength(120, 'Venue')(v),
                ),
                const SizedBox(height: 16),
                FormBuilderTextField(
                  name: 'organiser',
                  initialValue: e?.organiser,
                  textCapitalization: TextCapitalization.words,
                  textInputAction: TextInputAction.next,
                  decoration: AppTheme.input('Organiser (optional)', prefixIcon: const Icon(Icons.groups_2_outlined)),
                  validator: AppValidators.maxLength(80, 'Organiser'),
                ),
                const SizedBox(height: 16),
                FormBuilderTextField(
                  name: 'description',
                  initialValue: e?.description,
                  minLines: 2,
                  maxLines: 5,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: AppTheme.input('Notes (optional)', prefixIcon: const Icon(Icons.notes_outlined)),
                  validator: AppValidators.maxLength(500, 'Notes'),
                ),
                const SizedBox(height: 20),

                // ---- Dancers ----
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                'Dancers (${_selected.length})',
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                            ),
                            TextButton.icon(
                              onPressed: vm.studentsLoading || _saving ? null : () => _pickDancers(vm),
                              icon: const Icon(Icons.person_add_alt_1_outlined),
                              label: Text(_selected.isEmpty ? 'Choose' : 'Change'),
                            ),
                          ],
                        ),
                        if (vm.studentsLoading) const LinearProgressIndicator(minHeight: 2),
                        if (vm.studentsError != null && vm.students.isEmpty)
                          Text(vm.studentsError!, style: const TextStyle(color: AppColors.danger))
                        else if (selectedNames.isEmpty && !vm.studentsLoading)
                          const Text('No dancers chosen yet. A group is created for them automatically.')
                        else
                          Wrap(
                            spacing: 8,
                            runSpacing: 4,
                            children: [for (final n in selectedNames) Chip(label: Text(n))],
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 8),

                // ---- Fee ----
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Participation fee'),
                  subtitle: const Text('Costume, travel, hall… charged to each dancer'),
                  value: _hasFee,
                  onChanged: _saving ? null : (v) => setState(() => _hasFee = v),
                ),
                if (_hasFee) ...[
                  FormBuilderTextField(
                    name: 'feeAmount',
                    initialValue: e?.fee == null ? null : e!.fee!.amount.toStringAsFixed(0),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: AppTheme.input('Amount per dancer', prefixIcon: const Icon(Icons.currency_rupee)),
                    validator: AppValidators.amount(),
                  ),
                  const SizedBox(height: 16),
                  FormBuilderDateTimePicker(
                    name: 'feeDue',
                    initialValue: e?.fee?.dueDate ?? defaultDay,
                    inputType: InputType.date,
                    format: _dateFormat,
                    firstDate: DateTime(2020),
                    lastDate: DateTime(today.year + 5),
                    initialEntryMode: DatePickerEntryMode.calendarOnly,
                    decoration: AppTheme.input('Pay by', prefixIcon: const Icon(Icons.event_available_outlined)),
                    validator: AppValidators.required<DateTime>('Due date'),
                  ),
                  const SizedBox(height: 16),
                  FormBuilderTextField(
                    name: 'feeUpi',
                    initialValue: e?.fee?.upiId,
                    autocorrect: false,
                    keyboardType: TextInputType.emailAddress,
                    decoration: AppTheme.input(
                      'UPI id to pay (optional)',
                      prefixIcon: const Icon(Icons.account_balance_wallet_outlined),
                      helper: 'Dancers pay you by UPI and upload the screenshot',
                    ),
                    validator: AppValidators.optionalUpiId(),
                  ),
                  const SizedBox(height: 16),
                  FormBuilderTextField(
                    name: 'feeDesc',
                    initialValue: e?.fee?.description,
                    decoration: AppTheme.input('What is it for? (optional)', prefixIcon: const Icon(Icons.sell_outlined)),
                    validator: AppValidators.maxLength(120, 'Description'),
                  ),
                ],
                const SizedBox(height: 24),
                if (!vm.isOnline)
                  const Padding(
                    padding: EdgeInsets.only(bottom: 12),
                    child: Text('You are offline. Connect to save the event.'),
                  ),
                LoadingButton(
                  label: editing ? 'Save changes' : 'Create event',
                  loading: _saving,
                  onPressed: vm.isOnline ? () => _save(vm) : null,
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
