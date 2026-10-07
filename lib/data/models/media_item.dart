import 'package:equatable/equatable.dart';

import 'model_utils.dart';

enum MediaType { photo, video, audio }

/// `schools/{schoolId}/media/{mediaId}` — a photo, video or audio clip,
/// linked to an event and optionally to one item (song) in it.
class MediaItem extends Equatable {
  const MediaItem({
    required this.id,
    required this.eventId,
    required this.type,
    required this.url,
    required this.uploadedBy,
    this.itemId,
    this.caption,
    this.thumbnailUrl,
    this.createdAt,
  });

  final String id;
  final String eventId;
  final String? itemId;
  final MediaType type;
  final String url;
  final String? thumbnailUrl;
  final String? caption;
  final String uploadedBy;
  final DateTime? createdAt;

  factory MediaItem.fromMap(String id, Map<String, dynamic> map) => MediaItem(
        id: id,
        eventId: map['eventId'] as String? ?? '',
        itemId: map['itemId'] as String?,
        type: readEnum(MediaType.values, map['type'], MediaType.photo),
        url: map['url'] as String? ?? '',
        thumbnailUrl: map['thumbnailUrl'] as String?,
        caption: map['caption'] as String?,
        uploadedBy: map['uploadedBy'] as String? ?? '',
        createdAt: readDate(map['createdAt']),
      );

  Map<String, dynamic> toMap() => {
        'eventId': eventId,
        'itemId': itemId,
        'type': type.name,
        'url': url,
        'thumbnailUrl': thumbnailUrl,
        'caption': caption,
        'uploadedBy': uploadedBy,
        'createdAt': writeTimestamp(createdAt),
      };

  @override
  List<Object?> get props =>
      [id, eventId, itemId, type, url, thumbnailUrl, caption, uploadedBy, createdAt];
}
