import '../../data/models/app_user.dart';
import '../../data/models/attendance_record.dart';
import '../../data/models/attendance_summary.dart';
import '../../data/models/dance_event.dart';
import '../../data/models/event_fee.dart';
import '../../data/models/event_item.dart';
import '../../data/models/media_item.dart';
import '../../data/models/member.dart';
import '../../data/models/theory_note.dart';
import '../../data/models/payment.dart';
import '../state/app_state.dart';

/// Derived data, computed from state (like reselect selectors).

AppUser? currentUser(AppState s) => s.auth.user;

bool isStaff(AppState s) => s.auth.user?.role.isStaff ?? false;

List<Payment> paymentsAwaitingReview(AppState s) =>
    s.payments.items.where((p) => p.status == PaymentStatus.submitted).toList();

List<Payment> paymentsByStatus(AppState s, PaymentStatus? status) => status == null
    ? s.payments.items
    : s.payments.items.where((p) => p.status == status).toList();

double collectedThisMonth(AppState s, {DateTime? now}) {
  final n = now ?? DateTime.now();
  final month = '${n.year}-${n.month.toString().padLeft(2, '0')}';
  return s.payments.items
      .where((p) => p.month == month && p.status == PaymentStatus.verified)
      .fold(0.0, (sum, p) => sum + p.amount);
}

List<DanceEvent> upcomingEvents(AppState s) =>
    s.events.items.where((e) => e.isUpcoming).toList()..sort((a, b) => a.date.compareTo(b.date));

/// Events happening on the calendar day [day], earliest first.
List<DanceEvent> eventsOnDay(List<DanceEvent> events, DateTime day) =>
    events.where((e) => e.isOn(day)).toList()..sort((a, b) => a.date.compareTo(b.date));

/// Looks an event up by id, or null when it was deleted / not loaded.
DanceEvent? eventById(AppState s, String id) {
  for (final e in s.events.items) {
    if (e.id == id) return e;
  }
  return null;
}

/// An event's running order, by `order`.
List<EventItem> itemsForEvent(AppState s, String eventId) =>
    [...(s.eventItems[eventId]?.items ?? const <EventItem>[])]
      ..sort((a, b) => a.order.compareTo(b.order));

/// Events that charge a fee, soonest due date first.
List<DanceEvent> eventsWithFee(AppState s) =>
    s.events.items.where((e) => e.fee != null).toList()
      ..sort((a, b) => a.fee!.dueDate.compareTo(b.fee!.dueDate));

/// Fee records loaded for one event, by student name.
List<EventFee> feesForEvent(AppState s, String eventId) =>
    [...(s.eventFees[eventId]?.items ?? const <EventFee>[])]
      ..sort((a, b) => a.studentName.compareTo(b.studentName));

/// Totals for one event's fees. Waived fees count towards neither side.
class FeeSummary {
  const FeeSummary({
    required this.expected,
    required this.collected,
    required this.pendingCount,
    required this.submittedCount,
    required this.settledCount,
    required this.total,
  });

  final double expected;
  final double collected;
  final int pendingCount;
  final int submittedCount;
  final int settledCount;
  final int total;

  double get outstanding => expected - collected;
  double get progress => expected <= 0 ? 0 : (collected / expected).clamp(0, 1).toDouble();
}

FeeSummary summariseFees(List<EventFee> fees) {
  var expected = 0.0, collected = 0.0;
  var pending = 0, submitted = 0, settled = 0;
  for (final f in fees) {
    if (f.status != EventFeeStatus.waived) expected += f.amount;
    switch (f.status) {
      case EventFeeStatus.paid:
        collected += f.amount;
        settled++;
      case EventFeeStatus.waived:
        settled++;
      case EventFeeStatus.submitted:
        submitted++;
      case EventFeeStatus.pending:
        pending++;
    }
  }
  return FeeSummary(
    expected: expected,
    collected: collected,
    pendingCount: pending,
    submittedCount: submitted,
    settledCount: settled,
    total: fees.length,
  );
}

/// Gallery media, optionally narrowed to one [type] and/or one [eventId].
/// Order is kept (the repository returns newest first).
List<MediaItem> filterMedia(List<MediaItem> all, {MediaType? type, String? eventId}) => [
      for (final m in all)
        if ((type == null || m.type == type) && (eventId == null || m.eventId == eventId)) m,
    ];

/// Theory notes matching [query] (title, topic or body, ignoring case),
/// narrowed to one [topic] and/or [level]. Order is kept.
List<TheoryNote> filterTheory(List<TheoryNote> all, {String query = '', String? topic, String? level}) {
  final q = query.trim().toLowerCase();
  return [
    for (final n in all)
      if ((topic == null || n.topic == topic) &&
          (level == null || n.level == level) &&
          (q.isEmpty ||
              n.title.toLowerCase().contains(q) ||
              n.topic.toLowerCase().contains(q) ||
              n.body.toLowerCase().contains(q)))
        n,
  ];
}

/// Distinct topics in use, by name.
List<String> theoryTopics(List<TheoryNote> all) =>
    {for (final n in all) n.topic}.toList()..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));

/// Looks a note up by id, or null.
TheoryNote? theoryById(AppState s, String id) {
  for (final n in s.theory.items) {
    if (n.id == id) return n;
  }
  return null;
}

/// Members whose birthday is on [day], by name.
List<Member> birthdaysOn(List<Member> members, DateTime day) =>
    members.where((m) => m.hasBirthdayOn(day)).toList()..sort((a, b) => a.name.compareTo(b.name));

/// The birthday board for one month: soonest day first, then by name.
List<Member> birthdaysInMonth(List<Member> members, int year, int month) {
  final inMonth = members.where((m) => m.birthdayIn(year)?.month == month).toList();
  inMonth.sort((a, b) {
    final byDay = a.birthdayIn(year)!.day.compareTo(b.birthdayIn(year)!.day);
    return byDay != 0 ? byDay : a.name.compareTo(b.name);
  });
  return inMonth;
}

/// Month summary: for each student, present days out of the class days they
/// were on the roster. A student who joined mid-month is not counted absent
/// for earlier days, because they have no mark on those days. A day on which
/// several batches met counts once for a student (Present if any says so),
/// and "classes held" counts distinct days.
AttendanceSummary monthlySummary(List<AttendanceRecord> records, List<AppUser> students) {
  final days = {for (final r in records) AttendanceRecord.dayOf(r.date)};
  final rows = <StudentAttendance>[
    for (final st in students) _studentRow(records, st),
  ];
  return AttendanceSummary(classesHeld: days.length, students: rows);
}

StudentAttendance _studentRow(List<AttendanceRecord> records, AppUser st) {
  final perDay = <DateTime, bool>{};
  for (final r in records) {
    final mark = r.marks[st.id];
    if (mark == null) continue;
    final day = AttendanceRecord.dayOf(r.date);
    perDay[day] = (perDay[day] ?? false) || mark;
  }
  return StudentAttendance(
    student: st,
    present: perDay.values.where((p) => p).length,
    total: perDay.length,
  );
}

/// Students of [batchId], or everyone when it is [AttendanceRecord.allStudents].
List<AppUser> rosterForBatch(List<AppUser> students, String batchId) => batchId == AttendanceRecord.allStudents
    ? students
    : [for (final s in students) if (s.batchId == batchId) s];

/// Class records of [batchId], or all of them for [AttendanceRecord.allStudents].
List<AttendanceRecord> recordsForBatch(List<AttendanceRecord> records, String batchId) =>
    batchId == AttendanceRecord.allStudents ? records : [for (final r in records) if (r.batchId == batchId) r];
