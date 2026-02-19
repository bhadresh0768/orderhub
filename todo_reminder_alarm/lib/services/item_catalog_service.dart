import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:hive_flutter/hive_flutter.dart';

class ItemCatalogService {
  ItemCatalogService(this._db);

  final FirebaseFirestore _db;
  static const _boxName = 'item_catalog_cache';
  static const _itemsKey = 'items';

  CollectionReference<Map<String, dynamic>> get _catalog =>
      _db.collection('item_catalog');

  Future<Box<dynamic>> _openBox() => Hive.openBox<dynamic>(_boxName);

  String _normalize(String value) =>
      value.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');

  String _docIdForName(String normalizedName) {
    final id = normalizedName
        .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
        .replaceAll(RegExp(r'^_+|_+$'), '');
    return id.isEmpty ? 'item_${DateTime.now().millisecondsSinceEpoch}' : id;
  }

  Future<List<String>> getCachedItems() async {
    final box = await _openBox();
    final raw = box.get(_itemsKey);
    if (raw is! List) return const [];
    return raw.whereType<String>().toList();
  }

  Future<void> _saveCachedItems(List<String> items) async {
    final cleaned =
        items.map((e) => e.trim()).where((e) => e.isNotEmpty).toSet().toList()
          ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    final box = await _openBox();
    await box.put(_itemsKey, cleaned);
  }

  Future<List<String>> refreshCatalog({int limit = 300}) async {
    final snap = await _catalog.limit(limit).get();
    final names =
        snap.docs
            .map((doc) => doc.data())
            .where((data) => (data['isActive'] as bool?) ?? true)
            .map((data) => (data['name'] as String?)?.trim() ?? '')
            .where((name) => name.isNotEmpty)
            .toSet()
            .toList()
          ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    await _saveCachedItems(names);
    return names;
  }

  Future<List<String>> searchByPrefix(String query, {int limit = 10}) async {
    final normalized = _normalize(query);
    if (normalized.length < 3) return const [];
    final snap = await _catalog
        .orderBy('normalizedName')
        .startAt([normalized])
        .endAt(['$normalized\uf8ff'])
        .limit(limit)
        .get();
    return snap.docs
        .map((doc) => (doc.data()['name'] as String?)?.trim() ?? '')
        .where((name) => name.isNotEmpty)
        .toSet()
        .toList();
  }

  Future<void> upsertItem(String name) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return;
    final normalized = _normalize(trimmed);
    final docId = _docIdForName(normalized);
    await _catalog.doc(docId).set({
      'name': trimmed,
      'normalizedName': normalized,
      'isActive': true,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }
}
