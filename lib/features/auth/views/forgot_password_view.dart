import 'package:flutter/material.dart';
import 'package:flutter_form_builder/flutter_form_builder.dart';
import 'package:flutter_redux/flutter_redux.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/validators/app_validators.dart';
import '../../../redux/state/app_state.dart';
import '../../../shared/widgets/common_widgets.dart';
import '../../../shared/widgets/form_fields.dart';
import '../view_models/forgot_password_view_model.dart';

/// Forgot password: mobile number (pre-filled from the login screen when
/// typed there), new password and re-enter password.
class ForgotPasswordView extends StatefulWidget {
  const ForgotPasswordView({super.key, this.initialMobile});

  final String? initialMobile;

  @override
  State<ForgotPasswordView> createState() => _ForgotPasswordViewState();
}

class _ForgotPasswordViewState extends State<ForgotPasswordView> {
  final _formKey = GlobalKey<FormBuilderState>();
  bool _saving = false;

  Future<void> _submit(ForgotPasswordViewModel vm) async {
    FocusScope.of(context).unfocus();
    final form = _formKey.currentState!;
    if (!form.saveAndValidate()) return;

    setState(() => _saving = true);
    final error = await vm.resetPassword(
      mobile: form.value['mobile'] as String,
      newPassword: form.value['newPassword'] as String,
    );
    if (!mounted) return;
    setState(() => _saving = false);

    if (error != null) {
      showSnack(context, error, error: true);
      return;
    }
    showSnack(context, 'Password updated. Please sign in with your new password.');
    context.pop();
  }

  @override
  Widget build(BuildContext context) {
    return StoreConnector<AppState, ForgotPasswordViewModel>(
      converter: ForgotPasswordViewModel.fromStore,
      distinct: true,
      builder: (context, vm) => PopScope(
        canPop: !_saving,
        child: Scaffold(
          appBar: AppBar(title: const Text('Reset password')),
          body: AutofillGroup(
            child: FormBuilder(
              key: _formKey,
              enabled: !_saving,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  const Icon(Icons.lock_reset, size: 56, color: AppColors.maroon),
                  const SizedBox(height: 12),
                  Text(
                    'Set a new password for your account.',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                  const SizedBox(height: 24),
                  MobileField(initialValue: widget.initialMobile),
                  const SizedBox(height: 16),
                  PasswordField(
                    name: 'newPassword',
                    label: 'New password',
                    helper: 'At least ${AppValidators.minPasswordLength} characters, letters and numbers',
                    validator: AppValidators.newPassword(),
                    isNewPassword: true,
                  ),
                  const SizedBox(height: 16),
                  PasswordField(
                    name: 'confirmPassword',
                    label: 'Re-enter new password',
                    isNewPassword: true,
                    textInputAction: TextInputAction.done,
                    onSubmitted: (_) => _submit(vm),
                    validator: AppValidators.confirmPassword(
                      () => _formKey.currentState?.instantValue['newPassword'] as String?,
                    ),
                  ),
                  const SizedBox(height: 24),
                  LoadingButton(
                    label: vm.isOnline ? 'Update password' : 'Connect to the internet',
                    loading: _saving,
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
