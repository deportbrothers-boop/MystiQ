import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'tarot_models.dart';

class TarotStorage {
  static const String _recentCardsKey = 'tarot_recent_cards';
  static const String _recentTextsKey = 'tarot_recent_texts';

  String _key(String base, String userId) => '$base:$userId';

  Future<List<RecentCardEntry>> getRecentCards(String userId) async {
    final sp = await SharedPreferences.getInstance();
    final raw = sp.getString(_key(_recentCardsKey, userId));
    if (raw == null || raw.isEmpty) return [];

    try {
      final decoded = jsonDecode(raw) as List;
      return decoded
          .whereType<Map>()
          .map((e) => RecentCardEntry.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> saveRecentCards(
    String userId,
    List<RecentCardEntry> entries,
  ) async {
    final sp = await SharedPreferences.getInstance();
    final raw = jsonEncode(entries.map((e) => e.toJson()).toList());
    await sp.setString(_key(_recentCardsKey, userId), raw);
  }

  Future<RecentTextState> getRecentTextIds(String userId) async {
    final sp = await SharedPreferences.getInstance();
    final raw = sp.getString(_key(_recentTextsKey, userId));
    if (raw == null || raw.isEmpty) return RecentTextState.empty();

    try {
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      return RecentTextState.fromJson(decoded);
    } catch (_) {
      return RecentTextState.empty();
    }
  }

  Future<void> saveRecentTextIds(String userId, RecentTextState state) async {
    final sp = await SharedPreferences.getInstance();
    final raw = jsonEncode(state.toJson());
    await sp.setString(_key(_recentTextsKey, userId), raw);
  }

  // Firestore opsiyonu: Yerel yerine bulut depolama gerektiğinde çağırın.
  Future<List<RecentCardEntry>> getRecentCardsFromFirestore(
    String userId,
    FirebaseFirestore firestore,
  ) async {
    final doc = await firestore.collection('tarot_state').doc(userId).get();
    final data = doc.data();
    final raw = data?['recentCards'] as String?;
    if (raw == null || raw.isEmpty) return [];

    try {
      final decoded = jsonDecode(raw) as List;
      return decoded
          .whereType<Map>()
          .map((e) => RecentCardEntry.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> saveRecentCardsToFirestore(
    String userId,
    List<RecentCardEntry> entries,
    FirebaseFirestore firestore,
  ) async {
    final raw = jsonEncode(entries.map((e) => e.toJson()).toList());
    await firestore.collection('tarot_state').doc(userId).set(
      {'recentCards': raw},
      SetOptions(merge: true),
    );
  }

  Future<RecentTextState> getRecentTextIdsFromFirestore(
    String userId,
    FirebaseFirestore firestore,
  ) async {
    final doc = await firestore.collection('tarot_state').doc(userId).get();
    final data = doc.data();
    final raw = data?['recentTexts'] as String?;
    if (raw == null || raw.isEmpty) return RecentTextState.empty();

    try {
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      return RecentTextState.fromJson(decoded);
    } catch (_) {
      return RecentTextState.empty();
    }
  }

  Future<void> saveRecentTextIdsToFirestore(
    String userId,
    RecentTextState state,
    FirebaseFirestore firestore,
  ) async {
    final raw = jsonEncode(state.toJson());
    await firestore.collection('tarot_state').doc(userId).set(
      {'recentTexts': raw},
      SetOptions(merge: true),
    );
  }
}
