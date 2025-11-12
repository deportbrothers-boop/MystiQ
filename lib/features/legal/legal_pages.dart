import 'package:flutter/material.dart';

class TermsPage extends StatelessWidget {
  const TermsPage({super.key});
  @override
  Widget build(BuildContext context) {
    return const _DocPage(title: 'Kullanim Kosullari', content: _terms);
  }
}

class PrivacyPage extends StatelessWidget {
  const PrivacyPage({super.key});
  @override
  Widget build(BuildContext context) {
    return const _DocPage(title: 'Gizlilik Politikasi', content: _privacy);
  }
}

class _DocPage extends StatelessWidget {
  final String title; final String content;
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

const _terms = 'MystiQ, eglence amaclidir ve saglik/finansal tavsiye icermez. Uygulamayi kullanarak yerel yasalara uymayi kabul edersiniz. Premium ve coin urunleri dijital icerik olup iade kosullari magaza politikalarina tabidir.';

const _privacy = '''
MystiQ - Gizlilik Politikasi

Yururluk Tarihi: 11 Kasim 2025
Gelistirici / Yayinci: GG STUDIOS
Uygulama Adi: MystiQ

1) Genel Bilgilendirme
MystiQ, kullanicilara eglence ve kisisel analiz (fal, astroloji, ruya tabiri, el fali, tarot vb.) hizmetleri sunar. Bu gizlilik politikasi; hangi verilerin toplandigini, nasil kullanildigini, nasil korundugunu ve kullanici haklarini aciklar. Uygulamayi kullanarak bu politikayi kabul etmis olursunuz.

2) Toplanan Bilgiler
a) Otomatik Toplanan Bilgiler
- Cihaz bilgileri (model, isletim sistemi, dil, surum)
- IP adresi ve ulke/bolge bilgisi
- Uygulama kullanim istatistikleri (oturum suresi, tiklama, reklam goruntuleme)
- Reklam tanimlayicilari (Google Advertising ID / Apple IDFA)

b) Kullanici Tarafindan Saglanan Bilgiler
- E‑posta adresi (abonelik/iletisim/destek)
- Kullanici adi (fal sonuclarinda kisisellestirme)
- Fotograf (kahve fincani, el fotografi vb. gorsel analiz icin)

c) Ucuncu Taraf Servisler
- Firebase (Google LLC): Analitik, hata takibi, kimlik dogrulama
- AdMob (Google LLC): Reklam gosterimi ve gelir takibi
- OpenAI API: Yapay zeka ile fal metinleri/analizler uretimi
- Google Billing / StoreKit: Uygulama ici satin alma/abonelik yonetimi

3) Verilerin Kullanim Amaclari
- Deneyimi gelistirmek ve kisisellestirmek
- Uygulama performansini izlemek ve hatalari duzeltmek
- Reklam, satin alma ve abonelik sureclerini yonetmek
- Yasal yukumlulukleri yerine getirmek
MystiQ kullanici verilerini satmaz, kiralamaz ve izinsiz ucuncu sahislarla paylasmaz.

4) Veri Saklama Suresi
- Kullanici tarafindan yuklenen gorseller, islendikten sonra en gec 24 saat icinde silinir.
- Hesap bilgileri, hesap silindiginde kalici olarak kaldirilir.
- Analitik ve reklam verileri anonimlestirilmis sekilde saklanir.

5) Cerezler (Cookies)
Uygulama kendi cerezlerini tutmaz; ancak Google/AdMob gibi ucuncu taraf servisler deneyimi gelistirmek icin cerez veya benzeri teknolojiler kullanabilir.

6) Ucuncu Taraf Baglantilari
Uygulama, ucuncu taraf site/uygulamalara baglantilar icerebilir. Bu hizmetlerin icerik ve gizlilik uygulamalarindan MystiQ sorumlu degildir.

7) Cocuklarin Gizliligi
Uygulama 13 yas alti icin tasarlanmamistir. Bu yas grubuna ait veriler yanlislikla toplanirsa derhal silinir.

8) Guvenlik
Veriler; SSL sifreleme, erisim kontrolu ve guvenli sunucu altyapisi ile korunur. Ancak internet uzerinden hicbir aktarim %100 guvenli olarak garanti edilemez.

9) Kullanici Haklari
Kullanicilar verilerine erisim, duzeltme, silme ve islenmesine itiraz haklarina sahiptir. Talepler icin: mmystiqapp@gmail.com

10) Degisiklikler
Bu politika zaman zaman guncellenebilir. Degisiklikler uygulama icinde duyurulur ve yayimlandiginda yururluge girer.

11) Iletisim
E‑posta: mmystiqapp@gmail.com
Gelistirici: GG STUDIOS
''';

