class HistoryEntry {
  final String id;
  final String type; // coffee | tarot | palm | astro
  final String title;
  final String text;
  final DateTime createdAt;
  final bool favorite;

  HistoryEntry({
    required this.id,
    required this.type,
    required this.title,
    required this.text,
    required this.createdAt,
    this.favorite = false,
  });

  HistoryEntry copyWith({bool? favorite}) => HistoryEntry(
        id: id,
        type: type,
        title: title,
        text: text,
        createdAt: createdAt,
        favorite: favorite ?? this.favorite,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'type': type,
        'title': title,
        'text': text,
        'createdAt': createdAt.toIso8601String(),
        'favorite': favorite,
      };

  factory HistoryEntry.fromJson(Map<String, dynamic> j) => HistoryEntry(
        id: j['id'] as String,
        type: j['type'] as String,
        title: j['title'] as String,
        text: j['text'] as String,
        createdAt: DateTime.parse(j['createdAt'] as String),
        favorite: (j['favorite'] as bool?) ?? false,
      );
}

