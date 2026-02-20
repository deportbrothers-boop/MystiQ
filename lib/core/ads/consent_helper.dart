import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'dart:async';

/// Simple helper for Google UMP consent flow (google_mobile_ads 5.x).
/// Uses callback-based API and never blocks startup.
class AdConsent {
  // Whether to request non-personalized ads (NPA).
  // Heuristic: if consent is still required (not obtained), prefer NPA.
  static bool npa = false;

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

      // Update initial NPA heuristic based on current status
      try {
        final s = await ConsentInformation.instance.getConsentStatus();
        npa = (s == ConsentStatus.required);
      } catch (_) {}

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
          // After showing (or if not required), refresh heuristic once more.
          try {
            final s2 = await ConsentInformation.instance.getConsentStatus();
            npa = (s2 == ConsentStatus.required);
          } catch (_) {}
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
