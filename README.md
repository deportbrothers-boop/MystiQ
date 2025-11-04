MystiQ (Flutter)
=================

Bu depo, MystiQ uygulamasının Flutter iskeletini içerir.

Kurulum
- Flutter 3.x yükleyin ve `flutter doctor` ile doğrulayın.
- `flutter pub get`
- Geliştirme: `flutter run`

Yapı
- `lib/main.dart`: Giriş noktası, tema ve yönlendirme.
- `lib/app_router.dart`: Rotalar.
- `lib/theme/app_theme.dart`: Karanlık tema + altın aksan.
- `lib/features/*`: Özellik bazlı klasörleme (splash, onboarding, auth, home, premium, readings, profile, history).
- `assets/config/products.json`: Ürün SKU kataloğu (abonelik, tek seferlik ve coin paketleri).

Notlar
- Paywall, Firebase olmadan da çalışır: Ürünler `assets/config/products.json` dosyasından yüklenir ve satın alma simülasyonu SharedPreferences ile kalıcı hale getirilir.
- Gerçek mağaza entegrasyonu eklendi: Mağazaya uygun ise Store fiyatları ve gerçek satın alma akışı kullanılır, aksi halde mock moduna düşer.
- Firebase entegrasyonu için `Firebase.initializeApp()` ve platform konfigürasyonları ayrıca eklenecektir.

Reklamlar
- Test Banner AdMob eklendi (HomeShell altına). Test birimleri kullanılır.
- Prod için gerçek `adUnitId` değerlerini `AdService.bannerAdUnitId` içinde değiştirin.

Geçmiş ve Favoriler
- Fal sonucu otomatik olarak yerelde kaydedilir (SharedPreferences). İlk fal ücretsiz.
- Geçmiş ekranından kayıtları görüntüleme, favorileme ve silme yapılabilir. Kayıt detayı, sonuç sayfası ile açılır ve paylaşılabilir.

Fotoğraf/İzinler
- El/Kahve modülleri `image_picker` kullanır. Platform izinleri:
  - iOS: `Info.plist` içine `NSPhotoLibraryUsageDescription` ve `NSCameraUsageDescription` açıklamalarını ekleyin.
  - Android: `compileSdk` 34+, `android:exported` ayarları; `image_picker` çalışma zamanı izinlerini yönetir.

Yeni Modüller
- Astroloji sayfası (günlük yorum) → `/reading/astro`
- Rüya Tabiri (metin gir → yorum) → `/reading/dream`
- Kahve/El: fotoğraf yükleme ve sahte AI tarama animasyonu

OpenAI/AI Kullanımı
- Cloud Functions içinde `aiGenerate` HTTP endpointi eklendi. Prod için Functions ortam değişkenine `OPENAI_API_KEY` atayın ve endpoint URL’sini `assets/config/ai.json` dosyasındaki `serverUrl` alanına yazın.
- Alternatif: Uygulamayı geliştirirken `--dart-define=OPENAI_API_KEY=sk-...` ile çalıştırırsanız istemci doğrudan OpenAI’ye istek atar (sadece geliştirme için). Anahtarları uygulama içine gömmeyin.
- Uygulamada çağıran katman: `lib/core/ai/ai_service.dart`. Sunucu → OpenAI → yerel üretici sırasıyla dener.

Varlık Optimizasyonu (WebP)
- PNG/JPG görselleri WebP formatına dönüştürmek için araç eklendi: `tools/convert_to_webp.ps1`.
- Gereksinim: `cwebp` (Google WebP utilities) PATH’te olmalı.
- Kullanım (PowerShell):
  - Kuru çalıştırma: `./tools/convert_to_webp.ps1 -DryRun`
  - Dönüştür: `./tools/convert_to_webp.ps1` (kalite varsayılan 85)
- Script, dosyaların yanına `.webp` üretir; isterseniz ilgili `Image.asset` yollarını `.webp` uzantısına çevirerek kullanabilirsiniz.
