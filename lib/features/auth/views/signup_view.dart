import 'package:flutter/material.dart';
import 'package:flutter_form_builder/flutter_form_builder.dart';
import 'package:flutter_redux/flutter_redux.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/mobile_number.dart';
import '../../../core/validators/app_validators.dart';
import '../../../data/models/app_user.dart';
import '../../../data/models/institute.dart';
import '../../../data/models/signup_data.dart';
import '../../../redux/state/app_state.dart';
import '../../../shared/widgets/common_widgets.dart';
import '../../../shared/widgets/form_fields.dart';
import '../view_models/signup_view_model.dart';

/// Dropdown value meaning "my institute isn't listed — register it" (gurus only).
const _newInstitute = '__new__';

/// Sign up: Guru or Student, name, DOB, gender, institute, mobile, password.
class SignupView extends StatefulWidget {
  const SignupView({super.key});

  @override
  State<SignupView> createState() => _SignupViewState();
}

class _SignupViewState extends State<SignupView> {
  final _formKey = GlobalKey<FormBuilderState>();

  // Local UI state that changes which fields are shown.
  UserRole _role = UserRole.student;
  String? _instituteId;

  bool get _registeringNew => _instituteId == _newInstitute;

  void _onRoleChanged(UserRole role) {
    setState(() => _role = role);
    // Students can't register a new institute.
    if (role != UserRole.guru && _registeringNew) {
      _formKey.currentState?.fields['institute']?.didChange(null);
      setState(() => _instituteId = null);
    }
  }

  void _submit(SignupViewModel vm) {
    FocusScope.of(context).unfocus();
    final form = _formKey.currentState!;
    if (!form.saveAndValidate()) return;
    final v = form.value;

    // The dropdown is replaced by an error tile when institutes fail to load,
    // so the field can be absent even though validation passed.
    final instituteId = v['institute'] as String?;
    if (instituteId == null) {
      showSnack(context, 'Please select an institute (reload the list if it failed to load).', error: true);
      return;
    }
    Institute? picked;
    for (final i in vm.institutes) {
      if (i.id == instituteId) picked = i;
    }

    vm.signUp(SignupData(
      role: v['role'] as UserRole,
      name: v['name'] as String,
      dob: v['dob'] as DateTime,
      gender: v['gender'] as Gender,
      mobile: MobileNumber.normalize(v['mobile'] as String)!,
      password: v['password'] as String,
      instituteId: _registeringNew ? null : instituteId,
      instituteName: picked?.displayName,
      newInstituteName: _registeringNew ? v['newInstituteName'] as String : null,
      newInstituteCity: _registeringNew ? v['newInstituteCity'] as String? : null,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final today = DateTime.now();
    return StoreConnector<AppState, SignupViewModel>(
      converter: SignupViewModel.fromStore,
      distinct: true,
      onInit: (store) => SignupViewModel.fromStore(store).loadInstitutes(),
      onWillChange: (prev, next) {
        final onTop = ModalRoute.of(context)?.isCurrent ?? true;
        if (onTop && next.error != null && next.error != prev?.error) {
          showSnack(context, next.error!, error: true);
          next.clearError();
        }
      },
      builder: (context, vm) => PopScope(
        canPop: !vm.submitting,
        child: Scaffold(
          appBar: AppBar(title: const Text('Create account')),
          body: AutofillGroup(
            child: FormBuilder(
              key: _formKey,
              enabled: !vm.submitting,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                children: [
                  // ---- Guru or Student ----
                  FormBuilderField<UserRole>(
                    name: 'role',
                    initialValue: _role,
                    validator: AppValidators.required<UserRole>('Role'),
                    builder: (field) => Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('I am a', style: Theme.of(context).textTheme.titleSmall),
                        const SizedBox(height: 8),
                        SegmentedButton<UserRole>(
                          segments: const [
                            ButtonSegment(
                              value: UserRole.student,
                              label: Text('Student'),
                              icon: Icon(Icons.school_outlined),
                            ),
                            ButtonSegment(
                              value: UserRole.guru,
                              label: Text('Guru'),
                              icon: Icon(Icons.self_improvement),
                            ),
                          ],
                          selected: {field.value ?? UserRole.student},
                          onSelectionChanged: vm.submitting
                              ? null
                              : (s) {
                                  field.didChange(s.first);
                                  _onRoleChanged(s.first);
                                },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // ---- Personal details ----
                  FormBuilderTextField(
                    name: 'name',
                    textCapitalization: TextCapitalization.words,
                    autofillHints: const [AutofillHints.name],
                    textInputAction: TextInputAction.next,
                    decoration: AppTheme.input('Full name', prefixIcon: const Icon(Icons.person_outline)),
                    validator: AppValidators.name(),
                  ),
                  const SizedBox(height: 16),
                  FormBuilderDateTimePicker(
                    name: 'dob',
                    inputType: InputType.date,
                    format: DateFormat('d MMM yyyy'),
                    firstDate: DateTime(today.year - 100),
                    lastDate: today,
                    initialDate: DateTime(today.year - 12, today.month, today.day),
                    initialEntryMode: DatePickerEntryMode.calendarOnly,
                    decoration: AppTheme.input(
                      'Date of birth',
                      prefixIcon: const Icon(Icons.cake_outlined),
                    ),
                    validator: AppValidators.dob(),
                  ),
                  const SizedBox(height: 16),
                  FormBuilderDropdown<Gender>(
                    name: 'gender',
                    decoration: AppTheme.input('Gender', prefixIcon: const Icon(Icons.wc_outlined)),
                    validator: AppValidators.required<Gender>('Gender'),
                    items: [
                      for (final g in Gender.values) DropdownMenuItem(value: g, child: Text(g.label)),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // ---- Institute ----
                  _InstituteDropdown(
                    vm: vm,
                    allowNew: _role == UserRole.guru,
                    onChanged: (id) => setState(() => _instituteId = id),
                  ),
                  if (_registeringNew) ...[
                    const SizedBox(height: 16),
                    FormBuilderTextField(
                      name: 'newInstituteName',
                      textCapitalization: TextCapitalization.words,
                      decoration: AppTheme.input(
                        'New institute name',
                        prefixIcon: const Icon(Icons.account_balance_outlined),
                        helper: 'You will be its guru and can approve students who join.',
                      ),
                      validator: (v) {
                        final t = v?.trim() ?? '';
                        if (t.length < 3) return 'Enter the institute name';
                        final exists = vm.institutes.any((i) => i.name.toLowerCase() == t.toLowerCase());
                        return exists ? 'Already listed — pick it from the list above' : null;
                      },
                    ),
                    const SizedBox(height: 16),
                    FormBuilderTextField(
                      name: 'newInstituteCity',
                      textCapitalization: TextCapitalization.words,
                      decoration: AppTheme.input('City', prefixIcon: const Icon(Icons.location_city_outlined)),
                      validator: AppValidators.required<String>('City'),
                    ),
                  ],
                  const SizedBox(height: 16),

                  // ---- Login details ----
                  const MobileField(),
                  const SizedBox(height: 16),
                  PasswordField(
                    name: 'password',
                    label: 'Set password',
                    helper: 'At least ${AppValidators.minPasswordLength} characters, letters and numbers',
                    validator: AppValidators.newPassword(),
                    isNewPassword: true,
                  ),
                  const SizedBox(height: 16),
                  PasswordField(
                    name: 'confirmPassword',
                    label: 'Re-enter password',
                    isNewPassword: true,
                    textInputAction: TextInputAction.done,
                    validator: AppValidators.confirmPassword(
                      () => _formKey.currentState?.instantValue['password'] as String?,
                    ),
                  ),
                  const SizedBox(height: 24),
                  if (!_registeringNew)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Text(
                        'Your guru will approve your account before you can see the school.',
                        style: Theme.of(context).textTheme.bodySmall,
                        textAlign: TextAlign.center,
                      ),
                    ),
                  LoadingButton(
                    label: vm.isOnline ? 'Create account' : 'Connect to the internet to sign up',
                    loading: vm.submitting,
                    onPressed: vm.isOnline ? () => _submit(vm) : null,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _InstituteDropdown extends StatelessWidget {
  const _InstituteDropdown({required this.vm, required this.allowNew, required this.onChanged});

  final SignupViewModel vm;
  final bool allowNew;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    if (vm.institutesError != null && vm.institutes.isEmpty) {
      return ListTile(
        contentPadding: EdgeInsets.zero,
        leading: const Icon(Icons.error_outline, color: AppColors.danger),
        title: const Text('Could not load institutes'),
        subtitle: Text(vm.institutesError!),
        trailing: TextButton(onPressed: vm.loadInstitutes, child: const Text('Retry')),
      );
    }
    return FormBuilderDropdown<String>(
      name: 'institute',
      isExpanded: true,
      decoration: AppTheme.input(
        vm.institutesLoading ? 'Loading institutes…' : 'Institute',
        prefixIcon: const Icon(Icons.account_balance_outlined),
        helper: !allowNew && vm.institutes.isEmpty && !vm.institutesLoading
            ? 'No institutes yet. Ask your guru to sign up first.'
            : null,
      ),
      validator: AppValidators.required<String>('Institute'),
      onChanged: onChanged,
      items: [
        for (final i in vm.institutes)
          DropdownMenuItem(
            value: i.id,
            child: Text(i.displayName, overflow: TextOverflow.ellipsis),
          ),
        if (allowNew)
          const DropdownMenuItem(
            value: _newInstitute,
            child: Text(
              '+ My institute isn\'t listed — register it',
              style: TextStyle(color: AppColors.maroon, fontWeight: FontWeight.w600),
            ),
          ),
      ],
    );
  }
}
