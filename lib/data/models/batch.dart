import 'package:equatable/equatable.dart';

/// `schools/{schoolId}/batches/{batchId}` — a class group, e.g. "Beginners – Sat 5pm".
class Batch extends Equatable {
  const Batch({
    required this.id,
    required this.name,
    this.level,
    this.timing,
    this.monthlyFee,
  });

  final String id;
  final String name;
  final String? level;
  final String? timing;
  final double? monthlyFee;

  factory Batch.fromMap(String id, Map<String, dynamic> map) => Batch(
        id: id,
        name: map['name'] as String? ?? '',
        level: map['level'] as String?,
        timing: map['timing'] as String?,
        monthlyFee: (map['monthlyFee'] as num?)?.toDouble(),
      );

  Map<String, dynamic> toMap() => {
        'name': name,
        'level': level,
        'timing': timing,
        'monthlyFee': monthlyFee,
      };

  @override
  List<Object?> get props => [id, name, level, timing, monthlyFee];
}
