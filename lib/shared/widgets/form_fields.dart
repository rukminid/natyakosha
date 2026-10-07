import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_form_builder/flutter_form_builder.dart';

import '../../core/theme/app_theme.dart';
import '../../core/validators/app_validators.dart';

/// Mobile number field used by login, sign-up and forgot password.
/// Shows a fixed +91 prefix and accepts 10 digits.
class MobileField extends StatelessWidget {
  const MobileField({super.key, this.name = 'mobile', this.initialValue, this.textInputAction});

  final String name;
  final String? initialValue;
  final TextInputAction? textInputAction;

  @override
  Widget build(BuildContext context) => FormBuilderTextField(
        name: name,
        initialValue: initialValue,
        keyboardType: TextInputType.phone,
        autofillHints: const [AutofillHints.telephoneNumberNational],
        textInputAction: textInputAction ?? TextInputAction.next,
        maxLength: 10,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        decoration: AppTheme.input(
          'Mobile number',
          prefixIcon: const Icon(Icons.phone_iphone),
        ).copyWith(prefixText: '+91  ', counterText: ''),
        validator: AppValidators.indianPhone(),
      );
}

/// Password field with a show/hide eye.
class PasswordField extends StatefulWidget {
  const PasswordField({
    super.key,
    required this.name,
    required this.label,
    required this.validator,
    this.helper,
    this.textInputAction,
    this.onSubmitted,
    this.isNewPassword = false,
  });

  final String name;
  final String label;
  final String? helper;
  final FormFieldValidator<String> validator;
  final TextInputAction? textInputAction;
  final ValueChanged<String?>? onSubmitted;
  final bool isNewPassword;

  @override
  State<PasswordField> createState() => _PasswordFieldState();
}

class _PasswordFieldState extends State<PasswordField> {
  bool _obscure = true;

  @override
  Widget build(BuildContext context) => FormBuilderTextField(
        name: widget.name,
        obscureText: _obscure,
        enableSuggestions: false,
        autocorrect: false,
        autofillHints: [widget.isNewPassword ? AutofillHints.newPassword : AutofillHints.password],
        textInputAction: widget.textInputAction ?? TextInputAction.next,
        onSubmitted: widget.onSubmitted,
        decoration: AppTheme.input(
          widget.label,
          helper: widget.helper,
          prefixIcon: const Icon(Icons.lock_outline),
        ).copyWith(
          suffixIcon: IconButton(
            tooltip: _obscure ? 'Show password' : 'Hide password',
            icon: Icon(_obscure ? Icons.visibility_off : Icons.visibility),
            onPressed: () => setState(() => _obscure = !_obscure),
          ),
        ),
        validator: widget.validator,
      );
}

/// Primary button that shows a spinner while [loading].
class LoadingButton extends StatelessWidget {
  const LoadingButton({super.key, required this.label, required this.loading, this.onPressed});

  final String label;
  final bool loading;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) => FilledButton(
        onPressed: loading ? null : onPressed,
        child: loading
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
              )
            : Text(label),
      );
}
