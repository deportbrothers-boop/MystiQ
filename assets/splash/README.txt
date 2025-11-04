Place splash assets here:

- brand.png  (Full-screen illustration shown in SplashPage)
  - PNG, sRGB. Provide high-DPI variants so it stays sharp:
    - 1.0x: assets/splash/brand.png            → ~720x1520 (min)
    - 2.0x: assets/splash/2.0x/brand.png       → ~1440x3040 (recommended)
    - 3.0x: assets/splash/3.0x/brand.png       → ~2160x4320 (best on modern phones)
  - Keep the composition center-focused. Avoid text near the edges.

- logo.png   (OS native splash logo via flutter_native_splash)
  - PNG, transparent, sRGB. Provide square logo without background:
    - 1.0x: assets/splash/logo.png             → 1024x1024
    - 2.0x: assets/splash/2.0x/logo.png        → 2048x2048
    - 3.0x: assets/splash/3.0x/logo.png        → 3072x3072 (optional)
  - Keep artwork within the inner safe circle (Android 12 icon mask).

Notes
- Flutter will auto-pick the closest match (1.0x/2.0x/3.0x) at runtime.
- If you only ship a small 1.0x image (e.g., 1024px tall), it will be
  upscaled on high-DPI devices and look blurry.

After adding/replacing files, run:

  dart run flutter_native_splash:create
  flutter clean
  flutter pub get
  flutter run

