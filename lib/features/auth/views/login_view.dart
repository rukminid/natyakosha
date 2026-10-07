import 'package:flutter/material.dart';
import 'package:flutter_form_builder/flutter_form_builder.dart';
import 'package:flutter_redux/flutter_redux.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/routes.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/mobile_number.dart';
import '../../../core/validators/app_validators.dart';
import '../../../redux/state/app_state.dart';
import '../../../shared/widgets/common_widgets.dart';
import '../../../shared/widgets/form_fields.dart';
import '../view_models/login_view_model.dart';

/// Sign in with mobile number + password.
class LoginView extends StatefulWidget {
  const LoginView({super.key});

  @override
  State<LoginView> createState() => _LoginViewState();
}

class _LoginViewState extends State<LoginView> {
  final _formKey = GlobalKey<FormBuilderState>();

  void _submit(LoginViewModel vm) {
    FocusScope.of(context).unfocus();
    final form = _formKey.currentState!;
    if (!form.saveAndValidate()) return;
    vm.signIn(form.value['mobile'] as String, form.value['password'] as String);
  }

  void _forgotPassword() {
    // Carry the typed mobile number over, if it is valid.
    final typed = _formKey.currentState?.instantValue['mobile'] as String?;
    final mobile = MobileNumber.normalize(typed);
    context.push(
      mobile == null ? Routes.forgotPassword : '${Routes.forgotPassword}?mobile=$mobile',
    );
  }

  void _showError(LoginViewModel vm) {
    showSnack(context, vm.error!, error: true);
    vm.clearError();
  }

  @override
  Widget build(BuildContext context) {
    return StoreConnector<AppState, LoginViewModel>(
      converter: LoginViewModel.fromStore,
      distinct: true,
      // An error from session restore may already be in the store.
      onInitialBuild: (vm) {
        if (vm.error != null) _showError(vm);
      },
      onWillChange: (prev, next) {
        // Sign-up / forgot password sit on top of this screen and show their own errors.
        final onTop = ModalRoute.of(context)?.isCurrent ?? true;
        if (onTop && next.error != null && next.error != prev?.error) _showError(next);
      },
      builder: (context, vm) => Scaffold(
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: AutofillGroup(
                child: FormBuilder(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Icon(Icons.self_improvement, size: 64, color: AppColors.maroon),
                      const SizedBox(height: 12),
                      Text(
                        'Natyakosha',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                              color: AppColors.maroon,
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                      const SizedBox(height: 4),
                      const Text('Sign in to your dance school', textAlign: TextAlign.center),
                      const SizedBox(height: 32),
                      if (!vm.firebaseReady)
                        const Padding(
                          padding: EdgeInsets.only(bottom: 16),
                          child: Text(
                            'Firebase is not configured yet. Run `flutterfire configure` — see README.',
                            style: TextStyle(color: AppColors.warning),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      const MobileField(),
                      const SizedBox(height: 16),
                      PasswordField(
                        name: 'password',
                        label: 'Password',
                        validator: AppValidators.loginPassword(),
                        textInputAction: TextInputAction.done,
                        onSubmitted: (_) => _submit(vm),
                      ),
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          onPressed: vm.loading ? null : _forgotPassword,
                          child: const Text('Forgot password?'),
                        ),
                      ),
                      const SizedBox(height: 8),
                      LoadingButton(
                        label: vm.isOnline ? 'Sign in' : 'Connect to the internet to sign in',
                        loading: vm.loading,
                        onPressed: vm.isOnline ? () => _submit(vm) : null,
                      ),
                      const SizedBox(height: 24),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Text('New to Natyakosha?'),
                          TextButton(
                            onPressed: vm.loading ? null : () => context.push(Routes.signup),
                            child: const Text('Create an account'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
