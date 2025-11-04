class TarotDeck {
  // Total cards used in grid. 22 Major Arcana + 2 sample Minors.
  static const int count = 24;

  static const List<String> majorArcanaTr = [
    'Deli',
    'Büyücü',
    'Başrahibe',
    'İmparatoriçe',
    'İmparator',
    'Başrahip',
    'Aşıklar',
    'Savaş Arabası',
    'Güç',
    'Ermiş',
    'Kader Çarkı',
    'Adalet',
    'Asılan Adam',
    'Ölüm',
    'Denge',
    'Şeytan',
    'Kule',
    'Yıldız',
    'Ay',
    'Güneş',
    'Yargı',
    'Dünya',
  ];

  static const List<String> suits = ['Değnek', 'Kupa', 'Kılıç', 'Tılsım'];
  static const List<String> ranks = [
    'As', 'İki', 'Üç', 'Dört', 'Beş', 'Altı', 'Yedi', 'Sekiz', 'Dokuz', 'On', 'Prens', 'Şövalye', 'Kraliçe', 'Kral'
  ];

  static String nameForIndex(int index) {
    if (index < 22) return majorArcanaTr[index];
    final i = index - 22;
    final suit = suits[(i ~/ 14) % suits.length];
    final rank = ranks[i % 14];
    return '$suit $rank';
  }

  static String frontAsset(int index) => 'assets/images/tarot/fronts/$index.png';
}

