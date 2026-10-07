import 'package:flutter/widgets.dart';
import 'package:form_builder_validators/form_builder_validators.dart';

import '../utils/mobile_number.dart';

/// Yup-style reusable validators for every form in the app.
///
/// Every rule passes an explicit `errorText`, so messages are consistent
/// and do not depend on localization being loaded.
class AppValidators {
  AppValidators._();

  static const minPasswordLength = 8;

  static FormFieldValidator<T> required<T>([String label = 'This field']) =>
      FormBuilderValidators.required<T>(errorText: '$label is required');

  static FormFieldValidator<String> email() => FormBuilderValidators.compose([
        FormBuilderValidators.required(errorText: 'Email is required'),
        FormBuilderValidators.email(errorText: 'Enter a valid email address'),
      ]);

  /// Full name: 2–60 characters, letters, spaces, dots, apostrophes.
  static FormFieldValidator<String> name() => (value) {
        final v = value?.trim() ?? '';
        if (v.isEmpty) return 'Name is required';
        if (v.length < 2) return 'Name is too short';
        if (v.length > 60) return 'Name must be under 60 characters';
        if (!RegExp(r"^[\p{L}\p{M} .'-]+$", unicode: true).hasMatch(v)) {
          return 'Use letters only';
        }
        return null;
      };

  /// Sign-in password: just required (older accounts may be shorter).
  static FormFieldValidator<String> loginPassword() =>
      FormBuilderValidators.required(errorText: 'Password is required');

  /// New password (sign-up / reset): at least 8 chars with a letter and a number.
  static FormFieldValidator<String> newPassword() => (value) {
        final v = value ?? '';
        if (v.isEmpty) return 'Password is required';
        if (v.length < minPasswordLength) return 'Use at least $minPasswordLength characters';
        if (!RegExp(r'[A-Za-z]').hasMatch(v) || !RegExp(r'\d').hasMatch(v)) {
          return 'Use letters and numbers';
        }
        return null;
      };

  /// "Re-enter password" must match [original] (read at validation time).
  static FormFieldValidator<String> confirmPassword(String? Function() original) => (value) {
        if (value == null || value.isEmpty) return 'Please re-enter the password';
        return value == original() ? null : 'Passwords do not match';
      };

  /// Indian mobile number: 10 digits starting 6-9, optional +91 / 0 prefix.
  static FormFieldValidator<String> indianPhone() => (value) {
        if (value == null || value.trim().isEmpty) return 'Mobile number is required';
        return MobileNumber.normalize(value) == null
            ? 'Enter a valid 10-digit mobile number'
            : null;
      };

  /// Mobile number that may be left empty; if filled it must be valid.
  static FormFieldValidator<String> optionalIndianPhone() => (value) {
        if (value == null || value.trim().isEmpty) return null;
        return MobileNumber.normalize(value) == null ? 'Enter a valid 10-digit mobile number' : null;
      };

  /// Date of birth: required, in the past, age between [minAge] and 100.
  static FormFieldValidator<DateTime> dob({int minAge = 3, DateTime? now}) => (value) {
        if (value == null) return 'Date of birth is required';
        final today = now ?? DateTime.now();
        if (value.isAfter(today)) return 'Date of birth cannot be in the future';
        var age = today.year - value.year;
        if (today.month < value.month || (today.month == value.month && today.day < value.day)) {
          age--;
        }
        if (age < minAge) return 'Must be at least $minAge years old';
        if (age > 100) return 'Please check the year';
        return null;
      };

  /// Rupee amount: required, numeric, greater than zero, max 2 decimals.
  static FormFieldValidator<String> amount({double max = 1000000}) => (value) {
        if (value == null || value.trim().isEmpty) return 'Amount is required';
        if (!RegExp(r'^\d+(\.\d{1,2})?$').hasMatch(value.trim())) {
          return 'Enter a valid amount';
        }
        final n = double.parse(value.trim());
        if (n <= 0) return 'Amount must be more than ₹0';
        if (n > max) return 'Amount looks too large';
        return null;
      };

  /// UPI transaction reference (UTR) is 12 digits. Optional field:
  /// empty is allowed, but if filled it must be valid.
  static FormFieldValidator<String> optionalUpiTxnId() => (value) {
        if (value == null || value.trim().isEmpty) return null;
        return RegExp(r'^\d{12}$').hasMatch(value.trim())
            ? null
            : 'UPI reference is the 12-digit number in your payment app';
      };

  /// UPI id such as `guru@okhdfcbank`. Optional: empty is allowed.
  static FormFieldValidator<String> optionalUpiId() => (value) {
        final v = value?.trim() ?? '';
        if (v.isEmpty) return null;
        return RegExp(r'^[A-Za-z0-9.\-_]{2,}@[A-Za-z]{2,}$').hasMatch(v)
            ? null
            : 'Enter a valid UPI id, like name@bank';
      };

  static FormFieldValidator<String> maxLength(int max, [String label = 'This field']) =>
      FormBuilderValidators.maxLength(
        max,
        errorText: '$label must be under $max characters',
        checkNullOrEmpty: false,
      );
}
