import 'package:equatable/equatable.dart';

import 'model_utils.dart';

/// `schools/{schoolId}/attendance/{yyyy-MM-dd}_{batchId}` — one doc per class day.
///
/// Every student on the roster gets an explicit yes/no in [marks]
/// (`true` = present, `false` = absent), so a student who joins later is
/// never counted absent for days before they joined.
class AttendanceRecord extends Equatable {
  const AttendanceRecord({
    required this.id,
    required this.batchId,
    required this.date,
    required this.marks,
    required this.markedBy,
    this.updatedAt,
  });

  /// Attendance is taken for the whole school until batches exist.
  static const allStudents = 'all';

  final String id;
  final String batchId;

  /// The class day (time of day is ignored).
  final DateTime date;

  /// studentId → present?
  final Map<String, bool> marks;
  final String markedBy;
  final DateTime? updatedAt;

  List<String> get presentIds => [for (final e in marks.entries) if (e.value) e.key];
  List<String> get absentIds => [for (final e in marks.entries) if (!e.value) e.key];
  int get presentCount => marks.values.where((p) => p).length;
  int get absentCount => marks.length - presentCount;

  /// Null when the student was not on the roster that day.
  bool? isPresent(String studentId) => marks[studentId];

  static DateTime dayOf(DateTime d) => DateTime(d.year, d.month, d.day);

  static String docId(DateTime date, [String batchId = allStudents]) {
    final d = '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
    return '${d}_$batchId';
  }

  factory AttendanceRecord.fromMap(String id, Map<String, dynamic> map) {
    final raw = map['marks'];
    final marks = <String, bool>{};
    if (raw is Map) {
      raw.forEach((k, v) => marks['$k'] = v == true);
    } else {
      // Older records only listed who was present.
      for (final id in readStringList(map['presentIds'])) {
        marks[id] = true;
      }
    }
    return AttendanceRecord(
      id: id,
      batchId: map['batchId'] as String? ?? allStudents,
      date: dayOf(readDate(map['date']) ?? DateTime.now()),
      marks: marks,
      markedBy: map['markedBy'] as String? ?? '',
      updatedAt: readDate(map['updatedAt']),
    );
  }

  Map<String, dynamic> toMap() => {
        'batchId': batchId,
        'date': writeTimestamp(date),
        'marks': marks,
        'markedBy': markedBy,
      };

  @override
  List<Object?> get props => [id, batchId, date, marks, markedBy, updatedAt];
}
