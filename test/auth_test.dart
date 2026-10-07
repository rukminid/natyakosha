import 'package:flutter_test/flutter_test.dart';
import 'package:natyakosha/core/utils/mobile_number.dart';
import 'package:natyakosha/core/validators/app_validators.dart';
import 'package:natyakosha/data/models/app_user.dart';
import 'package:natyakosha/redux/actions/app_actions.dart';
import 'package:natyakosha/redux/reducers/app_reducer.dart';
import 'package:natyakosha/redux/state/app_state.dart';

void main() {
  group('MobileNumber', () {
    test('normalises common formats to 10 digits', () {
      expect(MobileNumber.normalize('98765 43210'), '9876543210');
      expect(MobileNumber.normalize('+91 98765-43210'), '9876543210');
      expect(MobileNumber.normalize('919876543210'), '9876543210');
      expect(MobileNumber.normalize('09876543210'), '9876543210');
    });
    test('rejects invalid numbers', () {
      expect(MobileNumber.normalize('5876543210'), isNull);
      expect(MobileNumber.normalize('98765'), isNull);
      expect(MobileNumber.normalize(null), isNull);
    });
    test('maps to a hidden auth id and E.164', () {
      expect(MobileNumber.authEmail('9876543210'), '919876543210@phone.natyakosha.app');
      expect(MobileNumber.e164('9876543210'), '+919876543210');
    });
  });

  group('AppValidators (sign-up / reset)', () {
    test('new password needs 8+ chars with letters and numbers', () {
      final v = AppValidators.newPassword();
      expect(v(''), isNotNull);
      expect(v('abc123'), isNotNull);
      expect(v('abcdefgh'), isNotNull);
      expect(v('12345678'), isNotNull);
      expect(v('natya2026'), isNull);
    });

    test('re-enter password must match', () {
      var original = 'natya2026';
      final v = AppValidators.confirmPassword(() => original);
      expect(v('natya2026'), isNull);
      expect(v('natya2025'), 'Passwords do not match');
      original = 'changed99';
      expect(v('natya2026'), 'Passwords do not match');
      expect(v(''), isNotNull);
    });

    test('date of birth', () {
      final now = DateTime(2026, 9, 24);
      final v = AppValidators.dob(now: now);
      expect(v(null), isNotNull);
      expect(v(DateTime(2027, 1, 1)), isNotNull); // future
      expect(v(DateTime(2025, 1, 1)), isNotNull); // under 3
      expect(v(DateTime(2014, 5, 10)), isNull);
      expect(v(DateTime(1900, 1, 1)), isNotNull); // over 100
    });

    test('name', () {
      final v = AppValidators.name();
      expect(v(''), isNotNull);
      expect(v('A'), isNotNull);
      expect(v('Ananya Rao'), isNull);
      expect(v('అనన్య'), isNull); // Telugu letters are fine
      expect(v('Ana123'), isNotNull);
    });
  });

  group('AppUser status', () {
    test('missing status (console-created) counts as approved', () {
      final u = AppUser.fromMap('u1', {'name': 'Guru', 'role': 'guru', 'schoolId': 's1'});
      expect(u.isApproved, isTrue);
    });
    test('sign-up profile round-trips through the offline cache', () {
      final u = AppUser(
        id: 'u2',
        name: 'Ananya',
        role: UserRole.student,
        schoolId: 's1',
        status: AccountStatus.pending,
        dob: DateTime(2014, 5, 10),
        gender: Gender.female,
        phone: '+919876543210',
      );
      expect(AppUser.fromJson(u.toJson()), u);
    });
  });

  group('join requests reducer', () {
    const pending = AppUser(
      id: 'p1',
      name: 'Ananya',
      role: UserRole.student,
      schoolId: 's1',
      status: AccountStatus.pending,
    );

    test('loaded then reviewed removes the member', () {
      var s = appReducer(AppState.initial(), const PendingMembersLoadedAction([pending]));
      expect(s.pendingMembers.items, hasLength(1));
      s = appReducer(s, const MemberReviewedAction('p1'));
      expect(s.pendingMembers.items, isEmpty);
    });

    test('pending user signs in as authenticated but not approved', () {
      final s = appReducer(AppState.initial(), const AuthSuccessAction(pending));
      expect(s.auth.status, AuthStatus.authenticated);
      expect(s.auth.user!.isApproved, isFalse);
    });
  });
}
