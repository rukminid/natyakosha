/// Login is "mobile number + password".
///
/// Firebase Auth has no built-in phone+password sign-in, so each mobile
/// number maps to a hidden email-style id, e.g.
///   98765 43210  →  919876543210@phone.natyakosha.app
/// The user never sees this. It lets us use Firebase's free email/password
/// auth, and makes each mobile number unique automatically.
class MobileNumber {
  MobileNumber._();

  static const _authDomain = 'phone.natyakosha.app';

  /// The 10-digit national number, or null if [input] isn't a valid
  /// Indian mobile (accepts spaces, dashes, +91, 91 or 0 prefixes).
  static String? normalize(String? input) {
    if (input == null) return null;
    var digits = input.replaceAll(RegExp(r'\D'), '');
    if (digits.length == 12 && digits.startsWith('91')) digits = digits.substring(2);
    if (digits.length == 11 && digits.startsWith('0')) digits = digits.substring(1);
    return RegExp(r'^[6-9]\d{9}$').hasMatch(digits) ? digits : null;
  }

  /// +919876543210
  static String e164(String tenDigits) => '+91$tenDigits';

  /// Hidden Firebase Auth id for this mobile number.
  static String authEmail(String tenDigits) => '91$tenDigits@$_authDomain';

  /// 98765 43210
  static String pretty(String tenDigits) =>
      '${tenDigits.substring(0, 5)} ${tenDigits.substring(5)}';
}
