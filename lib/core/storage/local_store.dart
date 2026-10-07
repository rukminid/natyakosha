import 'dart:convert';

import 'package:hive_ce_flutter/hive_flutter.dart';

import 'storage_keys.dart';

/// Local store (Realm / WatermelonDB equivalent) backed by Hive.
///
/// Values are stored as JSON strings so no type adapters or code
/// generation are needed. Use it to cache data for offline reading:
/// the signed-in user's profile, announcements, theory notes.
class LocalStore {
  LocalStore._(this._box);

  final Box<String> _box;

  static Future<LocalStore> create() async {
    await Hive.initFlutter();
    final box = await Hive.openBox<String>(StorageKeys.cacheBox);
    return LocalStore._(box);
  }

  Future<void> putJson(String key, Object? value) =>
      _box.put(key, jsonEncode(value));

  Map<String, dynamic>? getMap(String key) {
    final raw = _box.get(key);
    if (raw == null) return null;
    return jsonDecode(raw) as Map<String, dynamic>;
  }

  List<Map<String, dynamic>> getList(String key) {
    final raw = _box.get(key);
    if (raw == null) return const [];
    return (jsonDecode(raw) as List<dynamic>).cast<Map<String, dynamic>>();
  }

  Future<void> remove(String key) => _box.delete(key);
  Future<void> clear() => _box.clear();
}
