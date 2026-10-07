import 'package:equatable/equatable.dart';

import 'model_utils.dart';

/// `schools/{schoolId}/announcements/{id}`.
class Announcement extends Equatable {
  const Announcement({
    required this.id,
    required this.title,
    required this.body,
    required this.createdAt,
    this.pinned = false,
    this.authorName,
  });

  final String id;
  final String title;
  final String body;
  final bool pinned;
  final String? authorName;
  final DateTime createdAt;

  factory Announcement.fromMap(String id, Map<String, dynamic> map) => Announcement(
        id: id,
        title: map['title'] as String? ?? '',
        body: map['body'] as String? ?? '',
        pinned: map['pinned'] as bool? ?? false,
        authorName: map['authorName'] as String?,
        createdAt: readDate(map['createdAt']) ?? DateTime.now(),
      );

  Map<String, dynamic> toMap() => {
        'title': title,
        'body': body,
        'pinned': pinned,
        'authorName': authorName,
        'createdAt': writeTimestamp(createdAt),
      };

  /// JSON for the offline cache (dates as ISO strings, id included).
  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'body': body,
        'pinned': pinned,
        'authorName': authorName,
        'createdAt': writeDateIso(createdAt),
      };

  factory Announcement.fromJson(Map<String, dynamic> json) =>
      Announcement.fromMap(json['id'] as String, json);

  @override
  List<Object?> get props => [id, title, body, pinned, authorName, createdAt];
}
