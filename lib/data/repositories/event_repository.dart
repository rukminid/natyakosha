import 'package:cloud_firestore/cloud_firestore.dart';

import '../../core/errors/app_exception.dart';
import '../models/app_user.dart';
import '../models/dance_event.dart';
import '../models/event_fee.dart';
import '../models/event_item.dart';
import '../models/model_utils.dart' show readEnum;
import '../models/payment.dart' show PaymentMode;
import '../services/firestore_paths.dart';
import '../services/storage_service.dart';

/// Events, their running order (items), participant groups and event fees.
class EventRepository {
  EventRepository({FirebaseFirestore? db, StorageService? storage})
      : _db = db ?? FirebaseFirestore.instance,
        _storageOverride = storage;

  final FirebaseFirestore _db;
  final StorageService? _storageOverride;

  // Created on first use so screens that never upload do not need Firebase Storage.
  late final StorageService _storage = _storageOverride ?? StorageService();

  Future<List<DanceEvent>> fetchEvents(String schoolId) async {
    try {
      final snap = await _db
          .collection(FirestorePaths.events(schoolId))
          .orderBy('date', descending: true)
          .limit(100)
          .get();
      return snap.docs.map((d) => DanceEvent.fromMap(d.id, d.data())).toList();
    } catch (e) {
      throw AppException.from(e);
    }
  }

  /// Creates the event, a group for its participants and — if the event has
  /// a fee — one `pending` fee record per participant, all in one batch.
  /// Cloud Functions can then notify each participant (see README).
  Future<String> createEvent({
    required String schoolId,
    required DanceEvent event,
    required List<AppUser> participants,
  }) async {
    try {
      final batch = _db.batch();
      final eventRef = _db.collection(FirestorePaths.events(schoolId)).doc();
      final groupRef = _db.collection(FirestorePaths.groups(schoolId)).doc();

      batch.set(groupRef, {
        'name': event.title,
        'memberIds': participants.map((p) => p.id).toList(),
        'source': 'event',
        'eventId': eventRef.id,
        'createdAt': FieldValue.serverTimestamp(),
      });

      batch.set(eventRef, {
        ...event.toMap(),
        'participantIds': participants.map((p) => p.id).toList(),
        'groupId': groupRef.id,
        'createdAt': FieldValue.serverTimestamp(),
      });

      final fee = event.fee;
      if (fee != null) {
        for (final p in participants) {
          final record = EventFee(
            studentId: p.id,
            studentName: p.name,
            eventId: eventRef.id,
            amount: fee.amount,
            status: EventFeeStatus.pending,
          );
          batch.set(
            _db.collection(FirestorePaths.eventFees(schoolId, eventRef.id)).doc(p.id),
            record.toMap(),
          );
        }
      }

      await batch.commit();
      return eventRef.id;
    } catch (e) {
      throw AppException.from(e);
    }
  }

  /// Edits an event. The group follows the participant list. Fee records are
  /// reconciled against what is already stored (see [reconcileFees]), so it
  /// does not matter what the caller thought the previous participants were.
  Future<void> updateEvent({
    required String schoolId,
    required DanceEvent event,
    required List<AppUser> participants,
  }) async {
    try {
      final batch = _db.batch();
      final eventRef = _db.collection(FirestorePaths.events(schoolId)).doc(event.id);
      final ids = participants.map((p) => p.id).toList();

      batch.update(eventRef, {
        ...event.toMap(),
        'participantIds': ids,
        // The group is never re-pointed from here.
        'groupId': event.groupId,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      final groupId = event.groupId;
      if (groupId != null) {
        batch.set(
          _db.collection(FirestorePaths.groups(schoolId)).doc(groupId),
          {'name': event.title, 'memberIds': ids},
          SetOptions(merge: true),
        );
      }

      final feesRef = _db.collection(FirestorePaths.eventFees(schoolId, event.id));
      final stored = await feesRef.get();
      final plan = reconcileFees(
        eventId: event.id,
        fee: event.fee,
        participants: participants,
        existing: {
          for (final d in stored.docs)
            d.id: readEnum(EventFeeStatus.values, d.data()['status'], EventFeeStatus.pending),
        },
      );
      for (final record in plan.create) {
        batch.set(feesRef.doc(record.studentId), record.toMap());
      }
      for (final id in plan.delete) {
        batch.delete(feesRef.doc(id));
      }

      await batch.commit();
    } catch (e) {
      throw AppException.from(e);
    }
  }

  /// Deletes the event with its running order, fee records and group.
  /// Firestore does not cascade, so each sub-collection is removed here.
  Future<void> deleteEvent({
    required String schoolId,
    required String eventId,
    String? groupId,
  }) async {
    try {
      final batch = _db.batch();
      final items = await _db.collection(FirestorePaths.eventItems(schoolId, eventId)).get();
      final fees = await _db.collection(FirestorePaths.eventFees(schoolId, eventId)).get();
      for (final d in [...items.docs, ...fees.docs]) {
        batch.delete(d.reference);
      }
      if (groupId != null) {
        batch.delete(_db.collection(FirestorePaths.groups(schoolId)).doc(groupId));
      }
      batch.delete(_db.collection(FirestorePaths.events(schoolId)).doc(eventId));
      await batch.commit();
    } catch (e) {
      throw AppException.from(e);
    }
  }

  Future<List<EventItem>> fetchItems(String schoolId, String eventId) async {
    try {
      final snap = await _db
          .collection(FirestorePaths.eventItems(schoolId, eventId))
          .orderBy('order')
          .get();
      return snap.docs.map((d) => EventItem.fromMap(d.id, d.data())).toList();
    } catch (e) {
      throw AppException.from(e);
    }
  }

  /// Saves a new running order after the guru drags songs around.
  Future<void> reorderItems(String schoolId, String eventId, List<EventItem> items) async {
    try {
      final batch = _db.batch();
      for (var i = 0; i < items.length; i++) {
        batch.update(
          _db.collection(FirestorePaths.eventItems(schoolId, eventId)).doc(items[i].id),
          {'order': i + 1},
        );
      }
      await batch.commit();
    } catch (e) {
      throw AppException.from(e);
    }
  }

  /// Adds a song at the end of the running order. Returns the new item id.
  Future<String> addItem(String schoolId, String eventId, EventItem item) async {
    try {
      final col = _db.collection(FirestorePaths.eventItems(schoolId, eventId));
      final last = await col.orderBy('order', descending: true).limit(1).get();
      final next = last.docs.isEmpty
          ? 1
          : ((last.docs.first.data()['order'] as num?)?.toInt() ?? 0) + 1;
      final ref = col.doc();
      await ref.set({
        ...item.toMap(),
        'order': next,
        'createdAt': FieldValue.serverTimestamp(),
      });
      return ref.id;
    } catch (e) {
      throw AppException.from(e);
    }
  }

  /// Edits a song's details and performers. The order is left alone.
  Future<void> updateItem(String schoolId, String eventId, EventItem item) async {
    try {
      final data = item.toMap()..remove('order');
      await _db
          .collection(FirestorePaths.eventItems(schoolId, eventId))
          .doc(item.id)
          .update(data);
    } catch (e) {
      throw AppException.from(e);
    }
  }

  /// Deletes a song and renumbers [remaining] (already without it) 1..n.
  Future<void> deleteItem(
    String schoolId,
    String eventId,
    String itemId,
    List<EventItem> remaining,
  ) async {
    try {
      final col = _db.collection(FirestorePaths.eventItems(schoolId, eventId));
      final batch = _db.batch()..delete(col.doc(itemId));
      for (var i = 0; i < remaining.length; i++) {
        batch.update(col.doc(remaining[i].id), {'order': i + 1});
      }
      await batch.commit();
    } catch (e) {
      throw AppException.from(e);
    }
  }

  /// Removes [dancerIds] from every song's performers, used when dancers are
  /// taken off an event so no ghost performers stay in the running order.
  Future<void> removePerformers(
    String schoolId,
    String eventId,
    Set<String> dancerIds,
  ) async {
    if (dancerIds.isEmpty) return;
    try {
      final items = await fetchItems(schoolId, eventId);
      final col = _db.collection(FirestorePaths.eventItems(schoolId, eventId));
      final batch = _db.batch();
      var changed = false;
      for (final item in items) {
        if (item.performerIds.any(dancerIds.contains)) {
          changed = true;
          batch.update(col.doc(item.id), {
            'performerIds': item.performerIds.where((id) => !dancerIds.contains(id)).toList(),
          });
        }
      }
      if (changed) await batch.commit();
    } catch (e) {
      throw AppException.from(e);
    }
  }

  Future<List<EventFee>> fetchFees(String schoolId, String eventId) async {
    try {
      final snap = await _db.collection(FirestorePaths.eventFees(schoolId, eventId)).get();
      final list = snap.docs.map((d) => EventFee.fromMap(d.id, d.data())).toList()
        ..sort((a, b) => a.studentName.compareTo(b.studentName));
      return list;
    } catch (e) {
      throw AppException.from(e);
    }
  }

  /// Guru ticks a participant as paid / waived / back to pending,
  /// or changes that one student's amount.
  Future<void> updateFee({
    required String schoolId,
    required String eventId,
    required String studentId,
    required String markedBy,
    EventFeeStatus? status,
    double? amount,
    PaymentMode? mode,
    String? note,
  }) async {
    try {
      await _db.collection(FirestorePaths.eventFees(schoolId, eventId)).doc(studentId).update({
        if (status != null) 'status': status.name,
        if (status == EventFeeStatus.paid) 'paidAt': FieldValue.serverTimestamp(),
        if (amount != null) 'amount': amount,
        if (mode != null) 'mode': mode.name,
        if (note != null) 'note': note,
        'markedBy': markedBy,
      });
    } catch (e) {
      throw AppException.from(e);
    }
  }
  /// One student's fee for one event, or null when they have none.
  Future<EventFee?> fetchFee(String schoolId, String eventId, String studentId) async {
    try {
      final doc = await _db.collection(FirestorePaths.eventFees(schoolId, eventId)).doc(studentId).get();
      final data = doc.data();
      return data == null ? null : EventFee.fromMap(doc.id, data);
    } catch (e) {
      throw AppException.from(e);
    }
  }

  /// A participant (or their parent) attaches the UPI screenshot. The fee
  /// moves to `submitted` so it shows up for the guru to check. Only the four
  /// fields the security rules allow are written.
  Future<void> submitFeeProof({
    required String schoolId,
    required String eventId,
    required String studentId,
    required String screenshotPath,
    String? upiTxnId,
    String? note,
    void Function(double progress)? onProgress,
  }) async {
    try {
      final url = await _storage.uploadImage(
        localPath: screenshotPath,
        storagePath: StoragePaths.eventFeeScreenshot(
          schoolId,
          eventId,
          studentId,
          '${DateTime.now().millisecondsSinceEpoch}.jpg',
        ),
        onProgress: onProgress,
      );
      await _db.collection(FirestorePaths.eventFees(schoolId, eventId)).doc(studentId).update({
        'screenshotUrl': url,
        'upiTxnId': (upiTxnId?.isEmpty ?? true) ? null : upiTxnId,
        'note': (note?.isEmpty ?? true) ? null : note,
        'status': EventFeeStatus.submitted.name,
      });
    } catch (e) {
      throw AppException.from(e);
    }
  }
}

/// What to write to an event's fee records after its participants or fee changed.
class FeePlan {
  const FeePlan({required this.create, required this.delete});

  final List<EventFee> create;
  final List<String> delete;
}

/// Works out which fee records to add or drop.
///  - A participant with no record gets a `pending` one (only while the event has a fee).
///  - A `pending` record of someone no longer taking part is deleted; a paid,
///    submitted or waived one is kept as history.
/// Existing records are never changed, so a per-student amount the guru
/// set by hand survives edits to the event.
FeePlan reconcileFees({
  required String eventId,
  required EventFeeConfig? fee,
  required List<AppUser> participants,
  required Map<String, EventFeeStatus> existing,
}) {
  final staying = {for (final p in participants) p.id};
  return FeePlan(
    create: [
      if (fee != null)
        for (final p in participants)
          if (!existing.containsKey(p.id))
            EventFee(
              studentId: p.id,
              studentName: p.name,
              eventId: eventId,
              amount: fee.amount,
              status: EventFeeStatus.pending,
            ),
    ],
    delete: [
      for (final e in existing.entries)
        if (!staying.contains(e.key) && e.value == EventFeeStatus.pending) e.key,
    ],
  );
}
