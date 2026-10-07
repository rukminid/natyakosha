import 'package:flutter_test/flutter_test.dart';
import 'package:natyakosha/data/models/app_user.dart';
import 'package:natyakosha/data/models/dance_event.dart';
import 'package:natyakosha/data/models/event_fee.dart';
import 'package:natyakosha/data/repositories/event_repository.dart';
import 'package:natyakosha/redux/actions/app_actions.dart';
import 'package:natyakosha/redux/reducers/app_reducer.dart';
import 'package:natyakosha/redux/selectors/selectors.dart';
import 'package:natyakosha/redux/state/app_state.dart';

DanceEvent _event(String id, DateTime date, {DateTime? endsAt}) =>
    DanceEvent(id: id, title: 'Event $id', date: date, endsAt: endsAt, venue: 'Hall');

void main() {
  feePlanTests();
  group('DanceEvent', () {
    test('isOn matches the calendar day regardless of time', () {
      final e = _event('1', DateTime(2026, 10, 12, 17, 30));
      expect(e.isOn(DateTime(2026, 10, 12)), isTrue);
      expect(e.isOn(DateTime(2026, 10, 12, 23, 59)), isTrue);
      expect(e.isOn(DateTime(2026, 10, 13)), isFalse);
    });

    test('endsAt survives a toMap / fromMap round trip', () {
      final e = _event('1', DateTime(2026, 10, 12, 17), endsAt: DateTime(2026, 10, 12, 19, 30));
      final back = DanceEvent.fromMap('1', e.toMap());
      expect(back.date, e.date);
      expect(back.endsAt, e.endsAt);
    });

    test('an event with no end time reads back as null', () {
      final back = DanceEvent.fromMap('1', _event('1', DateTime(2026, 10, 12)).toMap());
      expect(back.endsAt, isNull);
    });
  });

  group('selectors', () {
    final events = [
      _event('late', DateTime(2026, 10, 12, 18)),
      _event('early', DateTime(2026, 10, 12, 9)),
      _event('other', DateTime(2026, 10, 14, 9)),
    ];

    test('eventsOnDay returns that day only, earliest first', () {
      final day = eventsOnDay(events, DateTime(2026, 10, 12));
      expect(day.map((e) => e.id), ['early', 'late']);
    });

    test('eventsOnDay is empty for a free day', () {
      expect(eventsOnDay(events, DateTime(2026, 10, 13)), isEmpty);
    });

    test('eventById finds a loaded event and returns null otherwise', () {
      final s = appReducer(AppState.initial(), EventsLoadedAction(events));
      expect(eventById(s, 'early')?.id, 'early');
      expect(eventById(s, 'missing'), isNull);
    });
  });

  group('students slice', () {
    const ananya = AppUser(id: 's1', name: 'Ananya', role: UserRole.student, schoolId: 'sc');

    test('loading then loaded fills the list', () {
      var s = appReducer(AppState.initial(), const StudentsRequestAction());
      expect(s.students.loading, isTrue);
      s = appReducer(s, const StudentsLoadedAction([ananya]));
      expect(s.students.loading, isFalse);
      expect(s.students.items, [ananya]);
    });

    test('a failure keeps the error message', () {
      final s = appReducer(AppState.initial(), const StudentsFailureAction('nope'));
      expect(s.students.error, 'nope');
    });

    test('signing out clears the students', () {
      var s = appReducer(AppState.initial(), const StudentsLoadedAction([ananya]));
      s = appReducer(s, const SignedOutAction());
      expect(s.students.items, isEmpty);
    });
  });

  group('AppUser.copyWith (profile edit)', () {
    test('changes only the edited fields', () {
      const u = AppUser(id: 'u', name: 'Old', role: UserRole.guru, schoolId: 'sc');
      final edited = u.copyWith(name: 'New', gender: Gender.female);
      expect(edited.name, 'New');
      expect(edited.gender, Gender.female);
      expect(edited.role, UserRole.guru);
      expect(edited.schoolId, 'sc');
    });
  });
}

void feePlanTests() {
  group('reconcileFees', () {
    AppUser u(String id) => AppUser(id: id, name: 'N$id', role: UserRole.student, schoolId: 'sc');
    final fee = EventFeeConfig(amount: 500, dueDate: DateTime(2026, 11, 1));

    test('new dancers get a pending record, existing ones are untouched', () {
      final plan = reconcileFees(
        eventId: 'e1',
        fee: fee,
        participants: [u('a'), u('b')],
        existing: {'a': EventFeeStatus.paid},
      );
      expect(plan.create.map((f) => f.studentId), ['b']);
      expect(plan.create.single.status, EventFeeStatus.pending);
      expect(plan.create.single.amount, 500);
      expect(plan.delete, isEmpty);
    });

    test('removed dancers lose a pending record but keep paid, submitted and waived ones', () {
      final plan = reconcileFees(
        eventId: 'e1',
        fee: fee,
        participants: [u('a')],
        existing: {
          'a': EventFeeStatus.pending,
          'b': EventFeeStatus.pending,
          'c': EventFeeStatus.paid,
          'd': EventFeeStatus.submitted,
          'e': EventFeeStatus.waived,
        },
      );
      expect(plan.delete, ['b']);
      expect(plan.create, isEmpty);
    });

    test('adding a fee to an event that had none creates records for everyone', () {
      final plan = reconcileFees(eventId: 'e1', fee: fee, participants: [u('a'), u('b')], existing: {});
      expect(plan.create, hasLength(2));
    });

    test('an event with no fee creates nothing', () {
      final plan = reconcileFees(eventId: 'e1', fee: null, participants: [u('a')], existing: {});
      expect(plan.create, isEmpty);
    });
  });
}
