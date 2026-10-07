import 'package:cloud_firestore/cloud_firestore.dart';

/// Helpers so models can read Firestore maps *and* local JSON cache maps.
///
/// Firestore gives `Timestamp`; the Hive cache stores ISO-8601 strings.
DateTime? readDate(Object? value) {
  if (value == null) return null;
  if (value is Timestamp) return value.toDate();
  if (value is DateTime) return value;
  if (value is String) return DateTime.tryParse(value);
  if (value is int) return DateTime.fromMillisecondsSinceEpoch(value);
  return null;
}

String? writeDateIso(DateTime? value) => value?.toIso8601String();

Timestamp? writeTimestamp(DateTime? value) =>
    value == null ? null : Timestamp.fromDate(value);

List<String> readStringList(Object? value) =>
    value is List ? value.map((e) => e.toString()).toList() : const [];

double readDouble(Object? value) =>
    value is num ? value.toDouble() : double.tryParse('$value') ?? 0;

T readEnum<T extends Enum>(List<T> values, Object? raw, T fallback) {
  for (final v in values) {
    if (v.name == raw) return v;
  }
  return fallback;
}
