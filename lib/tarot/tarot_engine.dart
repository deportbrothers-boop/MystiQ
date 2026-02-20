import 'dart:convert';

import 'tarot_data_tr.dart';
import 'tarot_models.dart';
import 'tarot_storage.dart';

class TarotEngine {
  TarotEngine({TarotStorage? storage}) : storage = storage ?? TarotStorage();

  final TarotStorage storage;

  Future<List<TarotCard>> pickCards({
    required String userId,
    required DateTime date,
    int count = 1,
    bool stableDaily = true,
  }) async {
    final recentCards = await storage.getRecentCards(userId);
    final seed = _makeSeed(userId, date, stableDaily: stableDaily);
    final rng = SeededRandom(seed);

    return _pickCardsWithRng(
      rng: rng,
      count: _normalizeCount(count),
      date: date,
      recentCards: recentCards,
      includeSameDay: !stableDaily,
    );
  }

  Future<TarotReading> generateReading({
    required String userId,
    required DateTime date,
    required TarotArea area,
    int count = 1,
    bool stableDaily = true,
  }) async {
    final recentCards = await storage.getRecentCards(userId);
    final recentText = await storage.getRecentTextIds(userId);

    final seed = _makeSeed(userId, date, stableDaily: stableDaily);
    final rng = SeededRandom(seed);

    final cards = _pickCardsWithRng(
      rng: rng,
      count: _normalizeCount(count),
      date: date,
      recentCards: recentCards,
      includeSameDay: !stableDaily,
    );

    final textResult = _buildReadingText(
      cards: cards,
      area: area,
      recentText: recentText,
      rng: rng,
    );

    final updatedRecentCards = _mergeRecentCards(recentCards, cards, date);
    await storage.saveRecentCards(userId, updatedRecentCards);
    await storage.saveRecentTextIds(userId, textResult.state);

    return TarotReading(cards: cards, text: textResult.text);
  }

  int _normalizeCount(int count) {
    if (count <= 0) return 1;
    if (count > tarotCardsTr.length) return tarotCardsTr.length;
    return count;
  }

  List<TarotCard> _pickCardsWithRng({
    required SeededRandom rng,
    required int count,
    required DateTime date,
    required List<RecentCardEntry> recentCards,
    required bool includeSameDay,
  }) {
    final recentDays = _recentDaysByCard(
      recentCards,
      date,
      includeSameDay: includeSameDay,
    );

    final available = <TarotCard>[];
    final weights = <double>[];

    for (final card in tarotCardsTr) {
      var weight = 1.0;
      final daysAgo = recentDays[card.id];
      if (daysAgo != null) {
        weight *= _recencyPenalty(daysAgo);
      }
      available.add(card);
      weights.add(weight);
    }

    final picked = <TarotCard>[];
    for (var i = 0; i < count && available.isNotEmpty; i++) {
      final index = _weightedIndex(weights, rng);
      picked.add(available.removeAt(index));
      weights.removeAt(index);
    }

    return picked;
  }

  int _weightedIndex(List<double> weights, SeededRandom rng) {
    var total = 0.0;
    for (final weight in weights) {
      total += weight;
    }

    if (total <= 0) {
      return rng.nextInt(weights.length);
    }

    final target = rng.nextDouble() * total;
    var running = 0.0;

    for (var i = 0; i < weights.length; i++) {
      running += weights[i];
      if (target <= running) {
        return i;
      }
    }

    return weights.length - 1;
  }

  Map<String, int> _recentDaysByCard(
    List<RecentCardEntry> entries,
    DateTime date, {
    required bool includeSameDay,
  }) {
    final normalized = _normalizeDate(date);
    final result = <String, int>{};

    for (final entry in entries) {
      final entryDate = _parseDateKey(entry.date);
      if (entryDate == null) {
        continue;
      }
      final diff = normalized.difference(entryDate).inDays;
      if (diff < 0) {
        continue;
      }
      if (!includeSameDay && diff == 0) {
        continue;
      }
      if (diff > 7) {
        continue;
      }

      final existing = result[entry.cardId];
      if (existing == null || diff < existing) {
        result[entry.cardId] = diff;
      }
    }

    return result;
  }

  double _recencyPenalty(int daysAgo) {
    if (daysAgo <= 0) return 0.05;
    if (daysAgo == 1) return 0.15;
    if (daysAgo == 2) return 0.25;
    if (daysAgo <= 4) return 0.4;
    if (daysAgo <= 6) return 0.6;
    return 0.8;
  }

  _TextBuildResult _buildReadingText({
    required List<TarotCard> cards,
    required TarotArea area,
    required RecentTextState recentText,
    required SeededRandom rng,
  }) {
    final introHistory = List<String>.from(recentText.introIds);
    final closingHistory = List<String>.from(recentText.closingIds);
    final cardHistory = <String, List<String>>{};
    for (final entry in recentText.cardVariantIds.entries) {
      cardHistory[entry.key] = List<String>.from(entry.value);
    }

    final introPick = _pickFromPool(
      pool: tarotIntrosTr,
      idPrefix: 'intro',
      recentIds: introHistory,
      avoidCount: 10,
      rng: rng,
    );
    _updateHistory(introHistory, introPick.id, 10);

    final closingPick = _pickFromPool(
      pool: tarotClosingsTr,
      idPrefix: 'closing',
      recentIds: closingHistory,
      avoidCount: 10,
      rng: rng,
    );
    _updateHistory(closingHistory, closingPick.id, 10);

    final general = _buildGeneralPart(
      cards: cards,
      cardHistory: cardHistory,
      rng: rng,
    );

    final areaPool = tarotAreaLinesTr[area] ?? const [];
    String areaPart = '';
    int? areaIndex;

    if (areaPool.isNotEmpty) {
      areaIndex = rng.nextInt(areaPool.length);
      areaPart = areaPool[areaIndex];
    }

    String text = _joinParts([
      introPick.text,
      general,
      areaPart,
      closingPick.text,
    ]);

    var count = _wordCount(text);

    if (count < 90 && areaPool.length > 1) {
      areaPart = _extendArea(areaPart, areaPool, areaIndex, rng);
      text = _joinParts([
        introPick.text,
        general,
        areaPart,
        closingPick.text,
      ]);
      count = _wordCount(text);
    }

    if (count > 140) {
      final compactGeneral = _buildTagBasedGeneral(cards);
      text = _joinParts([
        introPick.text,
        compactGeneral,
        areaPart,
        closingPick.text,
      ]);
      count = _wordCount(text);

      if (count < 90 && areaPool.length > 1) {
        areaPart = _extendArea(areaPart, areaPool, areaIndex, rng);
        text = _joinParts([
          introPick.text,
          compactGeneral,
          areaPart,
          closingPick.text,
        ]);
      }
    }

    final updatedState = RecentTextState(
      introIds: introHistory,
      closingIds: closingHistory,
      cardVariantIds: cardHistory,
    );

    return _TextBuildResult(text, updatedState);
  }

  String _buildGeneralPart({
    required List<TarotCard> cards,
    required Map<String, List<String>> cardHistory,
    required SeededRandom rng,
  }) {
    final lines = <String>[];

    for (final card in cards) {
      final pool = tarotCardGeneralLinesTr[card.id] ??
          tarotFallbackCardGeneralLinesTr;
      final history = cardHistory[card.id] ?? <String>[];

      final pick = _pickFromPool(
        pool: pool,
        idPrefix: 'card:${card.id}',
        recentIds: history,
        avoidCount: 5,
        rng: rng,
      );

      _updateHistory(history, pick.id, 5);
      cardHistory[card.id] = history;

      lines.add('${card.nameTr} kartı ${pick.text}');
    }

    return lines.join(' ');
  }

  String _buildTagBasedGeneral(List<TarotCard> cards) {
    final lines = <String>[];

    for (final card in cards) {
      final tags = card.tags.take(3).join(', ');
      final tagText = tags.isEmpty
          ? 'ana temayı öne çıkarır.'
          : '$tags temasını öne çıkarır.';
      lines.add('${card.nameTr} kartı $tagText');
    }

    return lines.join(' ');
  }

  _TextPickResult _pickFromPool({
    required List<String> pool,
    required String idPrefix,
    required List<String> recentIds,
    required int avoidCount,
    required SeededRandom rng,
  }) {
    if (pool.isEmpty) {
      return _TextPickResult('$idPrefix:0', '');
    }

    final start = recentIds.length > avoidCount
        ? recentIds.length - avoidCount
        : 0;
    final recentWindow = recentIds.sublist(start);
    final avoid = recentWindow.toSet();

    final candidates = <int>[];
    for (var i = 0; i < pool.length; i++) {
      final id = '$idPrefix:$i';
      if (!avoid.contains(id)) {
        candidates.add(i);
      }
    }

    final choicePool = candidates.isEmpty
        ? List<int>.generate(pool.length, (i) => i)
        : candidates;

    final index = choicePool[rng.nextInt(choicePool.length)];
    return _TextPickResult('$idPrefix:$index', pool[index]);
  }

  void _updateHistory(List<String> list, String id, int max) {
    list.removeWhere((item) => item == id);
    list.add(id);
    if (list.length > max) {
      list.removeRange(0, list.length - max);
    }
  }

  String _extendArea(
    String areaPart,
    List<String> pool,
    int? usedIndex,
    SeededRandom rng,
  ) {
    if (pool.isEmpty) return areaPart;

    var extraIndex = rng.nextInt(pool.length);
    if (usedIndex != null && pool.length > 1) {
      while (extraIndex == usedIndex) {
        extraIndex = rng.nextInt(pool.length);
      }
    }

    final extra = pool[extraIndex];
    if (areaPart.trim().isEmpty) return extra;
    return '$areaPart $extra';
  }

  String _joinParts(List<String> parts) {
    return parts.where((part) => part.trim().isNotEmpty).join(' ');
  }

  int _wordCount(String text) {
    final words = text.trim().split(RegExp(r'\s+'));
    return words.where((word) => word.isNotEmpty).length;
  }

  List<RecentCardEntry> _mergeRecentCards(
    List<RecentCardEntry> current,
    List<TarotCard> cards,
    DateTime date,
  ) {
    final dateKey = _dateKey(date);
    final updated = <RecentCardEntry>[
      ...current,
      for (final card in cards)
        RecentCardEntry(cardId: card.id, date: dateKey),
    ];

    final cutoff = _normalizeDate(date).subtract(const Duration(days: 30));
    return updated.where((entry) {
      final entryDate = _parseDateKey(entry.date);
      if (entryDate == null) return true;
      return !entryDate.isBefore(cutoff);
    }).toList();
  }

  DateTime _normalizeDate(DateTime date) {
    return DateTime(date.year, date.month, date.day);
  }

  String _dateKey(DateTime date) {
    final y = date.year.toString().padLeft(4, '0');
    final m = date.month.toString().padLeft(2, '0');
    final d = date.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  DateTime? _parseDateKey(String value) {
    final parts = value.split('-');
    if (parts.length != 3) return null;
    final y = int.tryParse(parts[0]);
    final m = int.tryParse(parts[1]);
    final d = int.tryParse(parts[2]);
    if (y == null || m == null || d == null) return null;
    return DateTime(y, m, d);
  }

  int _makeSeed(
    String userId,
    DateTime date, {
    required bool stableDaily,
  }) {
    final base = '$userId|${_dateKey(date)}';
    var seed = _fnv1a32(base);

    if (!stableDaily) {
      seed ^= DateTime.now().microsecondsSinceEpoch & 0xFFFFFFFF;
    }

    return seed;
  }

  int _fnv1a32(String input) {
    const int fnvPrime = 0x01000193;
    var hash = 0x811c9dc5;

    for (final byte in utf8.encode(input)) {
      hash ^= byte;
      hash = (hash * fnvPrime) & 0xFFFFFFFF;
    }

    return hash & 0x7FFFFFFF;
  }
}

class SeededRandom {
  int _state;

  SeededRandom(int seed) : _state = seed & 0xFFFFFFFF;

  int _next32() {
    var x = _state;
    x ^= (x << 13) & 0xFFFFFFFF;
    x ^= (x >> 17) & 0xFFFFFFFF;
    x ^= (x << 5) & 0xFFFFFFFF;
    _state = x & 0xFFFFFFFF;
    return _state;
  }

  int nextInt(int max) {
    if (max <= 0) {
      throw ArgumentError.value(max, 'max', 'Must be > 0');
    }
    return (_next32() & 0x7FFFFFFF) % max;
  }

  double nextDouble() {
    return (_next32() & 0x7FFFFFFF) / 0x7FFFFFFF;
  }
}

class _TextPickResult {
  final String id;
  final String text;

  const _TextPickResult(this.id, this.text);
}

class _TextBuildResult {
  final String text;
  final RecentTextState state;

  const _TextBuildResult(this.text, this.state);
}
