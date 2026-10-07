import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_form_builder/flutter_form_builder.dart';
import 'package:flutter_redux/flutter_redux.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/validators/app_validators.dart';
import '../../../data/models/app_user.dart';
import '../../../redux/state/app_state.dart';
import '../../../shared/widgets/common_widgets.dart';
import '../../../shared/widgets/form_fields.dart';
import '../view_models/students_view_model.dart';

/// Add a student ([studentId] null) or edit one the guru added.
/// Only the name is required: a student may have no phone or birthday on file.
class StudentFormView extends StatefulWidget {
  const StudentFormView({super.key, this.studentId});

  final String? studentId;

  @override
  State<StudentFormView> createState() => _StudentFormViewState();
}

class _StudentFormViewState extends State<StudentFormView> {
  final _formKey = GlobalKey<FormBuilderState>();
  bool _saving = false;

  /// +919876543210 → 9876543210 for the text box.
  String? _tenDigits(String? e164) {
    final d = e164?.replaceAll(RegExp(r'\D'), '');
    if (d == null || d.isEmpty) return null;
    return d.length == 12 && d.startsWith('91') ? d.substring(2) : d;
  }

  Future<void> _save(StudentsViewModel vm, AppUser? existing) async {
    FocusScope.of(context).unfocus();
    final form = _formKey.currentState!;
    if (!form.saveAndValidate()) return;
    final v = form.value;

    setState(() => _saving = true);
    final name = v['name'] as String;
    final dob = v['dob'] as DateTime?;
    final gender = v['gender'] as Gender?;
    final mobile = v['guardianMobile'] as String?;
    final error = existing == null
        ? await vm.add(name: name, dob: dob, gender: gender, guardianMobile: mobile)
        : await vm.update(existing, name: name, dob: dob, gender: gender, guardianMobile: mobile);
    if (!mounted) return;
    setState(() => _saving = false);
    if (error != null) {
      showSnack(context, error, error: true);
      return;
    }
    showSnack(context, existing == null ? '$name added' : 'Changes saved');
    context.pop();
  }

  @override
  Widget build(BuildContext context) {
    final today = DateTime.now();
    return StoreConnector<AppState, StudentsViewModel>(
      ignoreChange: (s) => s.auth.user == null,
      converter: StudentsViewModel.fromStore,
      distinct: true,
      onInit: (store) {
        // Opening the edit screen directly (a link, or after a restart).
        final vm = StudentsViewModel.fromStore(store);
        if (widget.studentId != null && vm.students.isEmpty) vm.refresh();
      },
      builder: (context, vm) {
        final editing = widget.studentId != null;
        final existing = editing ? vm.studentById(widget.studentId!) : null;
        if (!vm.isStaff || (editing && existing == null)) {
          return Scaffold(
            appBar: AppBar(title: Text(editing ? 'Edit student' : 'Add student')),
            body: EmptyState(
              icon: vm.isStaff ? Icons.person_off_outlined : Icons.lock_outline,
              title: vm.isStaff ? (vm.loading ? 'Loading…' : 'Student not found') : 'Only for guru and teachers',
            ),
          );
        }
        return Scaffold(
          appBar: AppBar(title: Text(editing ? 'Edit student' : 'Add student')),
          body: FormBuilder(
            key: _formKey,
            enabled: !_saving,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
              children: [
                if (!editing)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: Text(
                      'The student does not need the app. They will appear when you take attendance '
                      'and pick dancers for events.',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ),
                FormBuilderTextField(
                  name: 'name',
                  initialValue: existing?.name,
                  textCapitalization: TextCapitalization.words,
                  textInputAction: TextInputAction.next,
                  decoration: AppTheme.input('Student name', prefixIcon: const Icon(Icons.person_outline)),
                  validator: AppValidators.name(),
                ),
                const SizedBox(height: 16),
                FormBuilderDateTimePicker(
                  name: 'dob',
                  initialValue: existing?.dob,
                  inputType: InputType.date,
                  format: DateFormat('d MMM yyyy'),
                  firstDate: DateTime(today.year - 100),
                  lastDate: today,
                  initialDate: DateTime(today.year - 10, today.month, today.day),
                  initialEntryMode: DatePickerEntryMode.calendarOnly,
                  decoration: AppTheme.input(
                    'Date of birth (optional)',
                    prefixIcon: const Icon(Icons.cake_outlined),
                    helper: 'Shown on the birthday board (no year)',
                  ),
                  validator: (d) => d == null ? null : AppValidators.dob()(d),
                ),
                const SizedBox(height: 16),
                FormBuilderDropdown<Gender>(
                  name: 'gender',
                  initialValue: existing?.gender,
                  decoration: AppTheme.input('Gender (optional)', prefixIcon: const Icon(Icons.wc_outlined)),
                  items: [
                    for (final g in Gender.values) DropdownMenuItem(value: g, child: Text(g.label)),
                  ],
                ),
                const SizedBox(height: 16),
                FormBuilderTextField(
                  name: 'guardianMobile',
                  initialValue: _tenDigits(existing?.guardianPhone),
                  keyboardType: TextInputType.phone,
                  maxLength: 10,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: AppTheme.input(
                    'Parent mobile (optional)',
                    prefixIcon: const Icon(Icons.phone_iphone),
                    helper: 'For your reference. It is not a login.',
                  ).copyWith(prefixText: '+91  ', counterText: ''),
                  validator: AppValidators.optionalIndianPhone(),
                ),
                const SizedBox(height: 24),
                if (!vm.isOnline)
                  const Padding(
                    padding: EdgeInsets.only(bottom: 12),
                    child: Text('You are offline. Connect to save.'),
                  ),
                LoadingButton(
                  label: editing ? 'Save changes' : 'Add student',
                  loading: _saving,
                  onPressed: vm.isOnline ? () => _save(vm, existing) : null,
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
