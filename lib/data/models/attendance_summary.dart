import 'package:equatable/equatable.dart';

import 'app_user.dart';

/// One student's attendance over a month.
class StudentAttendance extends Equatable {
  const StudentAttendance({required this.student, required this.present, required this.total});

  final AppUser student;

  /// Days marked Present.
  final int present;

  /// Class days the student was on the roster (Present or Absent).
  final int total;

  int get absent => total - present;

  /// 0–100. Zero when the student had no class day yet.
  double get percent => total == 0 ? 0 : present * 100 / total;

  @override
  List<Object?> get props => [student, present, total];
}

/// A month at a glance: class days held and each student's percentage.
class AttendanceSummary extends Equatable {
  const AttendanceSummary({required this.classesHeld, required this.students});

  final int classesHeld;
  final List<StudentAttendance> students;

  /// Mean percentage of the students who had at least one class day.
  double get averagePercent {
    final counted = students.where((s) => s.total > 0).toList();
    if (counted.isEmpty) return 0;
    return counted.fold(0.0, (sum, s) => sum + s.percent) / counted.length;
  }

  @override
  List<Object?> get props => [classesHeld, students];
}

/// One class day for one student, as that student (or their parent) sees it:
/// `schools/{schoolId}/studentAttendance/{studentId}/days/{yyyy-MM-dd_batchId}`.
/// Written by staff alongside the class record so students never read
/// the whole class sheet.
class StudentDay extends Equatable {
  const StudentDay({required this.date, required this.present, required this.batchId});

  final DateTime date;
  final bool present;
  final String batchId;

  @override
  List<Object?> get props => [date, present, batchId];
}

/// A student's month: counts and the days behind them.
class StudentMonth extends Equatable {
  const StudentMonth({required this.days});

  final List<StudentDay> days;

  /// Days marked Present. A day counts once even if several batches met.
  int get present => _perDay.values.where((p) => p).length;

  /// Class days the student was on a roster.
  int get total => _perDay.length;
  int get absent => total - present;
  double get percent => total == 0 ? 0 : present * 100 / total;

  Map<DateTime, bool> get _perDay {
    final out = <DateTime, bool>{};
    for (final d in days) {
      final day = DateTime(d.date.year, d.date.month, d.date.day);
      out[day] = (out[day] ?? false) || d.present;
    }
    return out;
  }

  /// One entry per day, newest first (Present if any batch that day had them present).
  List<MapEntry<DateTime, bool>> get byDay => _perDay.entries.toList()..sort((a, b) => b.key.compareTo(a.key));

  @override
  List<Object?> get props => [days];
}
