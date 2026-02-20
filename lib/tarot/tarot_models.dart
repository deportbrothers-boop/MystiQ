enum TarotArea { love, money, career, mood }

class TarotCard {
  final String id;
  final String nameTr;
  final String nameEn;
  final List<String> tags;

  const TarotCard({
    required this.id,
    required this.nameTr,
    required this.nameEn,
    required this.tags,
  });
}

class TarotReading {
  final List<TarotCard> cards;
  final String text;

  const TarotReading({
    required this.cards,
    required this.text,
  });
}

class RecentCardEntry {
  final String cardId;
  final String date; // YYYY-MM-DD

  const RecentCardEntry({
    required this.cardId,
    required this.date,
  });

  Map<String, dynamic> toJson() => {
        'cardId': cardId,
        'date': date,
      };

  factory RecentCardEntry.fromJson(Map<String, dynamic> json) {
    return RecentCardEntry(
      cardId: (json['cardId'] ?? '') as String,
      date: (json['date'] ?? '') as String,
    );
  }
}

class RecentTextState {
  final List<String> introIds;
  final List<String> closingIds;
  final Map<String, List<String>> cardVariantIds;

  const RecentTextState({
    required this.introIds,
    required this.closingIds,
    required this.cardVariantIds,
  });

  factory RecentTextState.empty() => const RecentTextState(
        introIds: [],
        closingIds: [],
        cardVariantIds: {},
      );

  Map<String, dynamic> toJson() => {
        'intro': introIds,
        'closing': closingIds,
        'card': cardVariantIds,
      };

  factory RecentTextState.fromJson(Map<String, dynamic> json) {
    final intro = (json['intro'] as List?)?.cast<String>() ?? const [];
    final closing = (json['closing'] as List?)?.cast<String>() ?? const [];
    final rawCard = json['card'] as Map<String, dynamic>?;

    final card = <String, List<String>>{};
    if (rawCard != null) {
      for (final entry in rawCard.entries) {
        final list = (entry.value as List?)?.cast<String>() ?? const [];
        card[entry.key] = List<String>.from(list);
      }
    }

    return RecentTextState(
      introIds: List<String>.from(intro),
      closingIds: List<String>.from(closing),
      cardVariantIds: card,
    );
  }
}
