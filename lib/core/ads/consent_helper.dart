import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'dart:async';

/// Simple helper for Google UMP consent flow (google_mobile_ads 5.x).
/// Uses callback-based API and never blocks startup.
class AdConsent {
  static Future<void> requestIfRequired() async {
    try {
      final params = ConsentRequestParameters();

      // requestConsentInfoUpdate is callback-based in 5.x; wrap with Completer.
      final done = Completer<void>();
      ConsentInformation.instance.requestConsentInfoUpdate(
        params,
        () => done.complete(),
        (formError) => done.complete(),
      );
      await done.future; // continue regardless of success/failure

      final available = await ConsentInformation.instance.isConsentFormAvailable();
      if (!available) return;

      ConsentForm.loadConsentForm(
        (ConsentForm form) async {
          final status = await ConsentInformation.instance.getConsentStatus();
          if (status == ConsentStatus.required) {
            form.show((formError) {
              // Ignore dismissal/error; app continues normally.
            });
          }
        },
        (formError) {
          // Ignore load error.
        },
      );
    } catch (_) {
      // Ignore any failures; consent flow should not crash the app.
    }
  }
}