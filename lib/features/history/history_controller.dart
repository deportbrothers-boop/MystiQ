import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'history_entry.dart';

class HistoryController with ChangeNotifier {
  static const _kKey = 'history_entries_v1';

  final List<HistoryEntry> _items = [];
  List<HistoryEntry> get items => List.unmodifiable(_items);

  Future<void> load() async {
    final sp = await SharedPreferences.getInstance();
    final list = sp.getStringList(_kKey) ?? [];
    _items
      ..clear()
      ..addAll(list.map((s) => HistoryEntry.fromJson(json.decode(s))));
    _items.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    notifyListeners();
  }

  Future<void> _persist() async {
    final sp = await SharedPreferences.getInstance();
    final list = _items.map((e) => json.encode(e.toJson())).toList();
    await sp.setStringList(_kKey, list);
  }

  Future<void> add(HistoryEntry e) async {
    _items.insert(0, e);
    await _persist();
    notifyListeners();
  }

  Future<void> upsert(HistoryEntry e) async {
    final i = _items.indexWhere((x) => x.id == e.id);
    if (i >= 0) {
      _items[i] = e;
    } else {
      _items.insert(0, e);
    }
    await _persist();
    notifyListeners();
  }

  Future<void> toggleFavorite(String id) async {
    final i = _items.indexWhere((e) => e.id == id);
    if (i >= 0) {
      _items[i] = _items[i].copyWith(favorite: !_items[i].favorite);
      await _persist();
      notifyListeners();
    }
  }

  Future<void> delete(String id) async {
    _items.removeWhere((e) => e.id == id);
    await _persist();
    notifyListeners();
  }
}
