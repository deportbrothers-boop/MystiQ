class UserProfile {
  final String name;
  final DateTime? birthDate;
  final String gender; // male/female/other
  final String zodiac; // TR zodiac name
  final String marital; // evli/bekar/yeni ayrıldı/sevgilisi var
  final String? photoPath; // local file path for avatar

  const UserProfile({
    required this.name,
    required this.birthDate,
    required this.gender,
    required this.zodiac,
    required this.marital,
    this.photoPath,
  });

  factory UserProfile.empty() => const UserProfile(
        name: '',
        birthDate: null,
        gender: '',
        zodiac: '',
        marital: '',
        photoPath: null,
      );

  UserProfile copyWith({
    String? name,
    DateTime? birthDate,
    String? gender,
    String? zodiac,
    String? marital,
    String? photoPath,
  }) =>
      UserProfile(
        name: name ?? this.name,
        birthDate: birthDate ?? this.birthDate,
        gender: gender ?? this.gender,
        zodiac: zodiac ?? this.zodiac,
        marital: marital ?? this.marital,
        photoPath: photoPath ?? this.photoPath,
      );

  Map<String, dynamic> toJson() => {
        'name': name,
        'birthDate': birthDate?.toIso8601String(),
        'gender': gender,
        'zodiac': zodiac,
        'marital': marital,
        'photoPath': photoPath,
      };

  factory UserProfile.fromJson(Map<String, dynamic> j) => UserProfile(
        name: j['name'] as String? ?? '',
        birthDate: j['birthDate'] != null ? DateTime.tryParse(j['birthDate'] as String) : null,
        gender: j['gender'] as String? ?? '',
        zodiac: j['zodiac'] as String? ?? '',
        marital: j['marital'] as String? ?? '',
        photoPath: j['photoPath'] as String?,
      );
}

class ZodiacUtil {
  static String fromDate(DateTime d) {
    final m = d.month;
    final day = d.day;
    // Türkçe burç isimleri
    if ((m == 3 && day >= 21) || (m == 4 && day <= 20)) return 'Koç';
    if ((m == 4 && day >= 21) || (m == 5 && day <= 21)) return 'Boğa';
    if ((m == 5 && day >= 22) || (m == 6 && day <= 21)) return 'İkizler';
    if ((m == 6 && day >= 22) || (m == 7 && day <= 22)) return 'Yengeç';
    if ((m == 7 && day >= 23) || (m == 8 && day <= 23)) return 'Aslan';
    if ((m == 8 && day >= 24) || (m == 9 && day <= 23)) return 'Başak';
    if ((m == 9 && day >= 24) || (m == 10 && day <= 23)) return 'Terazi';
    if ((m == 10 && day >= 24) || (m == 11 && day <= 22)) return 'Akrep';
    if ((m == 11 && day >= 23) || (m == 12 && day <= 21)) return 'Yay';
    if ((m == 12 && day >= 22) || (m == 1 && day <= 20)) return 'Oğlak';
    if ((m == 1 && day >= 21) || (m == 2 && day <= 19)) return 'Kova';
    return 'Balık';
  }

  static String element(String zodiac) {
    final fire = ['Koç', 'Aslan', 'Yay'];
    final earth = ['Boğa', 'Başak', 'Oğlak'];
    final air = ['İkizler', 'Terazi', 'Kova'];
    final water = ['Yengeç', 'Akrep', 'Balık'];
    if (fire.contains(zodiac)) return 'Ateş';
    if (earth.contains(zodiac)) return 'Toprak';
    if (air.contains(zodiac)) return 'Hava';
    if (water.contains(zodiac)) return 'Su';
    return '';
  }
}

