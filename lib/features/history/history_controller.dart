import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'history_entry.dart';

class HistoryController with ChangeNotifier {
  static const _kKey = 'history_entries_v1';

  final List<HistoryEntry> _items = [];
  List<HistoryEntry> get items => List.unmodifiable(_items);

  // Very short or generic "preparing/loading" texts are treated as placeholders.
  // Only placeholders are allowed to be overwritten by a later final result.
  bool _looksLikePlaceholder(String t) {
    final s = t.toLowerCase().trim();
    if (s.isEmpty) return true;
    if (s.length < 24) return true;
    return s.contains('hazir') || s.contains('hazır') || s.contains('prepar') || s.contains('loading');
  }

  String _userKey() {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    return uid != null ? '${_kKey}_$uid' : _kKey;
  }

  CollectionReference<Map<String, dynamic>>? _fireCol() {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return null;
    return FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('history');
  }

  Future<void> load() async {
    final sp = await SharedPreferences.getInstance();
    final userKey = _userKey();
    bool fromRemote = false;
    final col = _fireCol();
    if (col != null) {
      try {
        final snap = await col.orderBy('createdAt', descending: true).get();
        final fetched = snap.docs.map((d) => HistoryEntry.fromJson(d.data())).toList();
        _items
          ..clear()
          ..addAll(fetched);
        fromRemote = true;
        // cache locally per user
        final list = _items.map((e) => json.encode(e.toJson())).toList();
        await sp.setStringList(userKey, list);
      } catch (_) {}
    }
    if (!fromRemote) {
      // fallback to local cache
      final list = sp.getStringList(userKey) ?? sp.getStringList(_kKey) ?? [];
      _items
        ..clear()
        ..addAll(list.map((s) => HistoryEntry.fromJson(json.decode(s))));
      _items.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    }
    notifyListeners();
  }

  Future<void> _persist() async {
    final sp = await SharedPreferences.getInstance();
    final list = _items.map((e) => json.encode(e.toJson())).toList();
    await sp.setStringList(_userKey(), list);
  }

  Future<void> add(HistoryEntry e) async {
    _items.insert(0, e);
    await _persist();
    // remote
    try {
      final col = _fireCol();
      if (col != null) {
        await col.doc(e.id).set(e.toJson(), SetOptions(merge: true));
      }
    } catch (_) {}
    notifyListeners();
  }

  Future<void> upsert(HistoryEntry e) async {
    final i = _items.indexWhere((x) => x.id == e.id);
    if (i >= 0) {
      // Do not overwrite finalized readings. Only allow replacement
      // if the existing entry still looks like a placeholder.
      final existing = _items[i];
      if (_isPlaceholder(existing.text)) {
        _items[i] = e;
      } else {
        // Keep existing (immutable) and ignore this update.
      }
    } else {
      _items.insert(0, e);
    }
    await _persist();
    try {
      final col = _fireCol();
      if (col != null) {
        await col.doc(e.id).set(e.toJson(), SetOptions(merge: true));
      }
    } catch (_) {}
    notifyListeners();
  }

  // More robust placeholder detection: normalize Turkish diacritics
  bool _isPlaceholder(String t) {
    final raw = t.toLowerCase().trim();
    if (raw.isEmpty) return true;
    if (raw.length < 24) return true;
    String s = raw
        .replaceAll('ı', 'i')
        .replaceAll('İ', 'i')
        .replaceAll('ş', 's')
        .replaceAll('Ş', 's')
        .replaceAll('ğ', 'g')
        .replaceAll('Ğ', 'g')
        .replaceAll('ü', 'u')
        .replaceAll('Ü', 'u')
        .replaceAll('ö', 'o')
        .replaceAll('Ö', 'o')
        .replaceAll('ç', 'c')
        .replaceAll('Ç', 'c');
    return s.contains('hazir') || s.contains('hazirlan') || s.contains('prepar') || s.contains('loading');
  }

  Future<void> toggleFavorite(String id) async {
    final i = _items.indexWhere((e) => e.id == id);
    if (i >= 0) {
      _items[i] = _items[i].copyWith(favorite: !_items[i].favorite);
      await _persist();
      try {
        final col = _fireCol();
        if (col != null) {
          await col.doc(id).set({'favorite': _items[i].favorite, 'id': id}, SetOptions(merge: true));
        }
      } catch (_) {}
      notifyListeners();
    }
  }

  Future<void> delete(String id) async {
    _items.removeWhere((e) => e.id == id);
    await _persist();
    try { final col = _fireCol(); if (col != null) { await col.doc(id).delete(); } } catch (_) {}
    notifyListeners();
  }

  Future<void> clearAllLocal() async {
    _items.clear();
    final sp = await SharedPreferences.getInstance();
    await sp.remove(_kKey);
    notifyListeners();
  }
}
