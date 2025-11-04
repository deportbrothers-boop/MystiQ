import 'package:flutter/foundation.dart';

/// Build-time/runtime flags for environment-specific behavior.
class AppEnv {
  /// Enable developer-only OTP display in VerifyPage.
  /// Set with: --dart-define=SHOW_DEV_OTP=true
  /// Guarded by !kReleaseMode so it never shows in release builds.
  static const bool _showDevOtpFlag = bool.fromEnvironment('SHOW_DEV_OTP', defaultValue: false);
  static bool get showDevOtp => _showDevOtpFlag && !kReleaseMode;
}

