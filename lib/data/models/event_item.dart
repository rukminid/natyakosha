import 'package:equatable/equatable.dart';

import 'model_utils.dart';

/// One piece in an event's running order:
/// `schools/{schoolId}/events/{eventId}/items/{itemId}`.
///
/// Example: order 1 · Pushpanjali · Nattai · Adi talam · 6 performers.
class EventItem extends Equatable {
  const EventItem({
    required this.id,
    required this.order,
    required this.songName,
    this.itemType,
    this.raga,
    this.tala,
    this.composer,
    this.durationMinutes,
    this.performerIds = const [],
    this.audioUrl,
  });

  final String id;
  final int order;
  final String songName;

  /// e.g. Pushpanjali, Jatiswaram, Tarangam, Tillana.
  final String? itemType;
  final String? raga;
  final String? tala;
  final String? composer;
  final int? durationMinutes;
  final List<String> performerIds;
  final String? audioUrl;

  EventItem copyWith({
    int? order,
    String? songName,
    String? itemType,
    String? raga,
    String? tala,
    String? composer,
    int? durationMinutes,
    List<String>? performerIds,
    String? audioUrl,
  }) =>
      EventItem(
        id: id,
        order: order ?? this.order,
        songName: songName ?? this.songName,
        itemType: itemType ?? this.itemType,
        raga: raga ?? this.raga,
        tala: tala ?? this.tala,
        composer: composer ?? this.composer,
        durationMinutes: durationMinutes ?? this.durationMinutes,
        performerIds: performerIds ?? this.performerIds,
        audioUrl: audioUrl ?? this.audioUrl,
      );

  factory EventItem.fromMap(String id, Map<String, dynamic> map) => EventItem(
        id: id,
        order: (map['order'] as num?)?.toInt() ?? 0,
        songName: map['songName'] as String? ?? '',
        itemType: map['itemType'] as String?,
        raga: map['raga'] as String?,
        tala: map['tala'] as String?,
        composer: map['composer'] as String?,
        durationMinutes: (map['durationMinutes'] as num?)?.toInt(),
        performerIds: readStringList(map['performerIds']),
        audioUrl: map['audioUrl'] as String?,
      );

  Map<String, dynamic> toMap() => {
        'order': order,
        'songName': songName,
        'itemType': itemType,
        'raga': raga,
        'tala': tala,
        'composer': composer,
        'durationMinutes': durationMinutes,
        'performerIds': performerIds,
        'audioUrl': audioUrl,
      };

  @override
  List<Object?> get props =>
      [id, order, songName, itemType, raga, tala, composer, durationMinutes, performerIds, audioUrl];
}
