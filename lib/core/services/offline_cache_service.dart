import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../features/materials/models/material_model.dart';

/// Lets students mark a material's text content "available offline" — a
/// simple SharedPreferences-backed JSON cache (text-only content is small
/// enough that this doesn't need a real embedded database like sqflite).
/// PDFs/videos still need a connection; only `content` (notes) is cached.
class OfflineCacheService {
  OfflineCacheService._();
  static final OfflineCacheService instance = OfflineCacheService._();

  static const _prefsKey = 'offline_materials_v1';

  Map<int, MaterialModel>? _cache;

  Future<Map<int, MaterialModel>> _load() async {
    if (_cache != null) return _cache!;
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_prefsKey);
    if (raw == null) {
      _cache = {};
      return _cache!;
    }
    final list = (jsonDecode(raw) as List)
        .map((e) => MaterialModel.fromMap(e as Map<String, dynamic>))
        .toList();
    _cache = {for (final m in list) m.id: m};
    return _cache!;
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    final list = _cache!.values.map((m) => m.toMap()).toList();
    await prefs.setString(_prefsKey, jsonEncode(list));
  }

  Future<bool> isCached(int materialId) async {
    final cache = await _load();
    return cache.containsKey(materialId);
  }

  Future<void> cache(MaterialModel material) async {
    final cache = await _load();
    cache[material.id] = material;
    await _persist();
  }

  Future<void> remove(int materialId) async {
    final cache = await _load();
    cache.remove(materialId);
    await _persist();
  }

  Future<List<MaterialModel>> cachedForSubject(int subjectId) async {
    final cache = await _load();
    return cache.values.where((m) => m.subjectId == subjectId).toList();
  }

  Future<List<MaterialModel>> allCached() async {
    final cache = await _load();
    return cache.values.toList();
  }

  Future<int> cachedCount() async {
    final cache = await _load();
    return cache.length;
  }
}
