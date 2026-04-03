import 'package:flutter/material.dart';

class TermsPage extends StatelessWidget {
  const TermsPage({super.key});
  @override
  Widget build(BuildContext context) {
    return const _DocPage(title: 'Kullanım Koşulları', content: _terms);
  }
}

class PrivacyPage extends StatelessWidget {
  const PrivacyPage({super.key});
  @override
  Widget build(BuildContext context) {
    return const _DocPage(title: 'Gizlilik Politikası', content: _privacy);
  }
}

class _DocPage extends StatelessWidget {
  final String title;
  final String content;
  const _DocPage({required this.title, required this.content});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Text(content),
      ),
    );
  }
}

const _terms =
    'Falla, eğlence amaçlıdır ve sağlık/finansal tavsiye içermez. '
    'Uygulamayı kullanarak yerel yasalara uymayı kabul edersiniz. '
    'Bu uygulamada ücretli satın alım yoktur; coin yalnızca reklam izleyerek kazanılır.';

const _privacy = '''
Falla - Gizlilik Politikası

Yürürlük Tarihi: 11 Kasım 2025
Geliştirici / Yayıncı: GG STUDIOS
Uygulama Adı: Falla

1) Genel Bilgilendirme
Falla, kullanıcılara eğlence amaçlı kahve kupasındaki şekillerin sembolik yorumunu sunar. Gelecek tahmini yapılmaz, kesinlik veya garanti içermez. Bu gizlilik politikası; hangi verilerin toplandığını, nasıl kullanıldığını, nasıl korunduğunu ve kullanıcı haklarını açıklar. Uygulamayı kullanarak bu politikayı kabul etmiş olursunuz.

2) Toplanan Bilgiler
a) Otomatik Toplanan Bilgiler
- Cihaz bilgileri (model, işletim sistemi, dil, sürüm)
- IP adresi ve ülke/bölge bilgisi
- Uygulama kullanım istatistikleri (oturum süresi, tıklama, reklam görüntüleme)
- Reklam tanımlayıcıları (Google Advertising ID / Apple IDFA)

b) Kullanıcı Tarafından Sağlanan Bilgiler
- E-posta adresi (iletişim/destek)
- Kullanıcı adı (yorumlarda kişiselleştirme için)
- Fotoğraf (kahve fincanı vb. görsel içerik)

c) Üçüncü Taraf Servisler
- Firebase (Google LLC): Analitik, hata takibi, kimlik doğrulama
- AdMob (Google LLC): Reklam gösterimi ve gelir takibi
- OpenAI API: (varsa) yorum metinlerinin üretilmesi

3) Verilerin Kullanım Amaçları
- Deneyimi geliştirmek ve kişiselleştirmek
- Uygulama performansını izlemek ve hataları düzeltmek
- Reklam süreçlerini ve içerik deneyimini yönetmek
- Yasal yükümlülükleri yerine getirmek
Falla kullanıcı verilerini satmaz, kiralamaz ve izinsiz üçüncü şahıslarla paylaşmaz.

4) Veri Saklama Süresi
- Kullanıcı tarafından yüklenen görseller, işlendiğinde en geç 24 saat içinde silinebilir.
- Hesap bilgileri, hesap silindiğinde kalıcı olarak kaldırılır.
- Analitik ve reklam verileri anonimleştirilmiş şekilde saklanabilir.

5) Çerezler (Cookies)
Uygulama kendi çerezlerini tutmaz; ancak Google/AdMob gibi üçüncü taraf servisler deneyimi geliştirmek için çerez veya benzeri teknolojiler kullanabilir.

6) Üçüncü Taraf Bağlantıları
Uygulama, üçüncü taraf site/uygulamalara bağlantılar içerebilir. Bu hizmetlerin içerik ve gizlilik uygulamalarından Falla sorumlu değildir.

7) Çocukların Gizliliği
Uygulama 13 yaş altı için tasarlanmamıştır. Bu yaş grubuna ait veriler yanlışlıkla toplanırsa derhal silinir.

8) Güvenlik
Veriler; SSL şifreleme, erişim kontrolü ve güvenli sunucu altyapısı ile korunur. Ancak internet üzerinden hiçbir aktarım %100 güvenli olarak garanti edilemez.

9) Kullanıcı Hakları
Kullanıcılar verilerine erişim, düzeltme, silme ve işlenmesine itiraz haklarına sahiptir. Talepler için: mmystiqapp@gmail.com

10) Değişiklikler
Bu politika zaman zaman güncellenebilir. Değişiklikler uygulama içinde duyurulur ve yayımlandığında yürürlüğe girer.

11) İletişim
E-posta: mmystiqapp@gmail.com
Geliştirici: GG STUDIOS
''';
