import 'app_user.dart';

/// Everything the sign-up form collects.
class SignupData {
  const SignupData({
    required this.role,
    required this.name,
    required this.dob,
    required this.gender,
    required this.mobile,
    required this.password,
    this.instituteId,
    this.instituteName,
    this.newInstituteName,
    this.newInstituteCity,
  }) : assert(
          instituteId != null || newInstituteName != null,
          'Pick an institute or register a new one',
        );

  /// Only guru or student can self-register.
  final UserRole role;
  final String name;
  final DateTime dob;
  final Gender gender;

  /// 10-digit national number (already normalised).
  final String mobile;
  final String password;

  /// Existing institute picked from the dropdown…
  final String? instituteId;
  final String? instituteName;

  /// …or a brand-new institute (gurus only).
  final String? newInstituteName;
  final String? newInstituteCity;

  bool get registersNewInstitute => instituteId == null;
}
