import 'dart:math';
import 'package:flutter/foundation.dart';
import '../../core/auth/otp_sender.dart';

class VerifyController with ChangeNotifier {
  String? _email;
  String? _code; // 6-digit
  DateTime? _sentAt;

  String? get email => _email;
  DateTime? get sentAt => _sentAt;
  String? get code => _code; // for development hint

  Future<void> send(String email) async {
    _email = email;
    _code = _generateCode();
    _sentAt = DateTime.now();
    // Try backend email send if configured; ignore result for now
    // (UI yine de VerifyPage'e yönlendirilir.)
    await OtpSender.sendEmail(email: email, code: _code!);
    notifyListeners();
  }

  Future<void> sendSms(String phone) async {
    _email = null;
    _code = _generateCode();
    _sentAt = DateTime.now();
    await OtpSender.sendSms(phone: phone, code: _code!);
    notifyListeners();
  }

  bool canResend({Duration cooldown = const Duration(seconds: 30)}) {
    if (_sentAt == null) return true;
    return DateTime.now().difference(_sentAt!) >= cooldown;
  }

  void clear() {
    _email = null;
    _code = null;
    _sentAt = null;
    notifyListeners();
  }

  bool verify(String input, {Duration validFor = const Duration(minutes: 10)}) {
    if (_code == null || _sentAt == null) return false;
    if (DateTime.now().difference(_sentAt!) > validFor) return false;
    return input.trim() == _code;
  }

  String _generateCode() {
    final r = Random.secure();
    final n = 100000 + r.nextInt(900000);
    return n.toString();
  }
}
