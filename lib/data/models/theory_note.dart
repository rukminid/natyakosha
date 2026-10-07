import 'package:equatable/equatable.dart';

import 'model_utils.dart';

/// Levels a note can be tagged with.
const theoryLevels = ['Beginner', 'Intermediate', 'Advanced', 'Exam prep'];

/// Topics offered as one-tap suggestions in the note form.
const defaultTheoryTopics = ['Hastas', 'Adavus', 'Talas', 'Ragas', 'Abhinaya', 'History', 'Natya Shastra'];

/// `schools/{schoolId}/theory/{noteId}` — mudras, adavus, talas, Natya Shastra…
class TheoryNote extends Equatable {
  const TheoryNote({
    required this.id,
    required this.topic,
    required this.title,
    required this.body,
    this.level,
    this.imageUrls = const [],
    this.updatedAt,
  });

  final String id;

  /// Grouping, e.g. "Hastas", "Adavus", "Talas", "History".
  final String topic;
  final String title;

  /// Markdown or plain text.
  final String body;

  /// e.g. Beginner / Intermediate / Advanced / Exam prep.
  final String? level;
  final List<String> imageUrls;
  final DateTime? updatedAt;

  factory TheoryNote.fromMap(String id, Map<String, dynamic> map) => TheoryNote(
        id: id,
        topic: map['topic'] as String? ?? '',
        title: map['title'] as String? ?? '',
        body: map['body'] as String? ?? '',
        level: map['level'] as String?,
        imageUrls: readStringList(map['imageUrls']),
        updatedAt: readDate(map['updatedAt']),
      );

  Map<String, dynamic> toMap() => {
        'topic': topic,
        'title': title,
        'body': body,
        'level': level,
        'imageUrls': imageUrls,
        'updatedAt': writeTimestamp(updatedAt),
      };

  TheoryNote copyWith({
    String? topic,
    String? title,
    String? body,
    String? level,
    bool clearLevel = false,
    List<String>? imageUrls,
    DateTime? updatedAt,
  }) =>
      TheoryNote(
        id: id,
        topic: topic ?? this.topic,
        title: title ?? this.title,
        body: body ?? this.body,
        level: clearLevel ? null : (level ?? this.level),
        imageUrls: imageUrls ?? this.imageUrls,
        updatedAt: updatedAt ?? this.updatedAt,
      );

  /// JSON for the offline cache (dates as ISO strings, id included).
  Map<String, dynamic> toJson() => {
        'id': id,
        'topic': topic,
        'title': title,
        'body': body,
        'level': level,
        'imageUrls': imageUrls,
        'updatedAt': writeDateIso(updatedAt),
      };

  factory TheoryNote.fromJson(Map<String, dynamic> json) =>
      TheoryNote.fromMap(json['id'] as String, json);

  @override
  List<Object?> get props => [id, topic, title, body, level, imageUrls, updatedAt];
}
