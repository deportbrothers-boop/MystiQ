import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;
import 'package:http/http.dart' as http;

class _AuthConfig {
  final String emailProxyUrl;
  final String smsProxyUrl;
  const _AuthConfig({required this.emailProxyUrl, required this.smsProxyUrl});
  static Future<_AuthConfig> load() async {
    try {
      final txt = await rootBundle.loadString('assets/config/auth.json');
      final j = json.decode(txt) as Map<String, dynamic>;
      return _AuthConfig(
        emailProxyUrl: (j['emailProxyUrl'] ?? '') as String,
        smsProxyUrl: (j['smsProxyUrl'] ?? '') as String,
      );
    } catch (_) {
      return const _AuthConfig(emailProxyUrl: '', smsProxyUrl: '');
    }
  }
}

class OtpSender {
  static Future<bool> sendEmail({required String email, required String code}) async {
    final cfg = await _AuthConfig.load();
    if (cfg.emailProxyUrl.isEmpty) return false;
    try {
      final r = await http.post(Uri.parse(cfg.emailProxyUrl),
          headers: {'content-type': 'application/json'},
          body: json.encode({'email': email, 'code': code}));
      return r.statusCode >= 200 && r.statusCode < 300;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> sendSms({required String phone, required String code}) async {
    final cfg = await _AuthConfig.load();
    if (cfg.smsProxyUrl.isEmpty) return false;
    try {
      final r = await http.post(Uri.parse(cfg.smsProxyUrl),
          headers: {'content-type': 'application/json'},
          body: json.encode({'phone': phone, 'code': code}));
      return r.statusCode >= 200 && r.statusCode < 300;
    } catch (_) {
      return false;
    }
  }
}

