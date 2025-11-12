import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/i18n/app_localizations.dart';
import '../../core/entitlements/entitlements_controller.dart';
import '../legal/legal_pages.dart';

class SignUpPage extends StatefulWidget {
  const SignUpPage({super.key});
  @override
  State<SignUpPage> createState() => _SignUpPageState();
}

class _SignUpPageState extends State<SignUpPage> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  bool _showPassword = false;
  bool _showConfirm = false;
  bool _accepted = false;
  String? _error;
  bool _busy = false;
  bool _emailInUse = false;

  bool get _validEmail {
    final e = _email.text.trim();
    final re = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
    return re.hasMatch(e);
  }

  bool get _validPassword {
    final p = _password.text;
    final hasLen = p.length >= 8;
    final hasNum = RegExp(r'[0-9]').hasMatch(p);
    final hasLet = RegExp(r'[A-Za-z]').hasMatch(p);
    return hasLen && hasNum && hasLet;
  }

  int get _passwordScore {
    final p = _password.text;
    int score = 0;
    if (p.length >= 8) score++;
    if (RegExp(r'[0-9]').hasMatch(p)) score++;
    if (RegExp(r'[A-Z]').hasMatch(p) && RegExp(r'[a-z]').hasMatch(p)) score++;
    if (RegExp(r'[!@#\$%^&*(),.?":{}|<>_\-]').hasMatch(p)) score++;
    return score;
  }

  Future<void> _checkEmailInUse() async {
    _emailInUse = false;
    if (!_validEmail) { setState((){}); return; }
    try {
      final methods = await FirebaseAuth.instance.fetchSignInMethodsForEmail(_email.text.trim());
      setState(() => _emailInUse = methods.isNotEmpty);
    } catch (_) {
      // ignore
    }
  }

  Future<void> _create() async {
    setState(() => _error = null);
    if (_emailInUse) {
      setState(() => _error = 'Bu e-posta zaten kullanimda.');
      return;
    }
    if (!_validEmail) {
      setState(() => _error = 'Gecerli bir e-posta girin.');
      return;
    }
    if (!_validPassword || _password.text != _confirm.text) {
      setState(() => _error = 'Sifre en az 8 karakter, harf ve rakam icermeli; Sifreler eslesmeli.');
      return;
    }
    if (!_accepted) {
      setState(() => _error = 'Devam etmek icin sartlari kabul edin.');
      return;
    }
    if (_busy) return;
    setState(() { _busy = true; });
    try {
      // Guard: make sure Firebase is initialized (avoid race on cold start)
      try {
        if (Firebase.apps.isEmpty) {
          await Firebase.initializeApp();
        }
      } catch (_) {}
      // Klavyeyi kapat, UI'yi ferahlat
      FocusScope.of(context).unfocus();
      final cred = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: _email.text.trim(),
        password: _password.text,
      );
      final uid = cred.user!.uid;

      // Save basic profile & entitlements in background (do not block navigation)
      try {
        Future.microtask(() async {
          try {
            final users = FirebaseFirestore.instance.collection('users');
            await users.doc(uid).set({
              'email': _email.text.trim(),
              'createdAt': FieldValue.serverTimestamp(),
              'updatedAt': FieldValue.serverTimestamp(),
            }, SetOptions(merge: true));
          } catch (_) {}
          try {
            final ent = context.read<EntitlementsController>();
            await FirebaseFirestore.instance
                .collection('users')
                .doc(uid)
                .collection('meta')
                .doc('entitlements')
                .set({
              'coins': ent.coins,
              'premiumSku': ent.premiumSku,
              'premiumUntil': ent.premiumUntil?.toIso8601String(),
              'firstFreeUsed': ent.firstFreeUsed,
              'updatedAt': FieldValue.serverTimestamp(),
            }, SetOptions(merge: true));
          } catch (_) {}
        });
      } catch (_) {}

      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool('just_signed_up', true);
        await prefs.setBool('remember_me', true); // dogrudan uygulamaya girsin
      } catch (_) {}
      // Yeni hesapla devam: yerel durumlari guncelle ve Profil Duzenle'ye git
      try { if (mounted) await context.read<EntitlementsController>().switchToCurrentUser(); } catch (_) {}
      if (!mounted) return;
      context.replace('/profile/edit');
    } on FirebaseAuthException catch (e) {
      setState(() => _error = e.message ?? 'Kayit basarisiz.');
    } catch (e) {
      setState(() => _error = 'Beklenmeyen bir hata: $e');
    } finally {
      if (mounted) setState(() { _busy = false; });
    }
  }

  void _openLegalSheet() {
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      backgroundColor: const Color(0xFF121018),
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Sozlesmeler', style: TextStyle(fontWeight: FontWeight.w700)),
              const SizedBox(height: 6),
              ListTile(
                leading: const Icon(Icons.description_outlined),
                title: const Text('Kullanim Kosullari'),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.of(context).push(MaterialPageRoute(builder: (_) => TermsPage()));
                },
              ),
              ListTile(
                leading: const Icon(Icons.privacy_tip_outlined),
                title: const Text('Gizlilik'),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.of(context).push(MaterialPageRoute(builder: (_) => PrivacyPage()));
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Kayit Ol')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextField(
              controller: _email,
              decoration: InputDecoration(
                labelText: 'E-posta',
                suffixIcon: _validEmail
                    ? (_emailInUse
                        ? const Icon(Icons.error_outline, color: Colors.redAccent)
                        : const Icon(Icons.check_circle, color: Colors.green))
                    : null,
              ),
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.next,
              onChanged: (_) => _checkEmailInUse(),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _password,
              decoration: InputDecoration(
                labelText: 'Sifre',
                suffixIcon: IconButton(
                  icon: Icon(_showPassword ? Icons.visibility_off : Icons.visibility),
                  onPressed: () => setState(() => _showPassword = !_showPassword),
                ),
              ),
              obscureText: !_showPassword,
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: 6),
            _PasswordStrengthBar(score: _passwordScore),
            const SizedBox(height: 10),
            TextField(
              controller: _confirm,
              decoration: InputDecoration(
                labelText: 'Sifre (tekrar)',
                suffixIcon: IconButton(
                  icon: Icon(_showConfirm ? Icons.visibility_off : Icons.visibility),
                  onPressed: () => setState(() => _showConfirm = !_showConfirm),
                ),
              ),
              obscureText: !_showConfirm,
            ),
            const SizedBox(height: 10),
            Row(children: [
              Checkbox(value: _accepted, onChanged: (v) => setState(() => _accepted = v ?? false)),
              Expanded(
                child: GestureDetector(
                  onTap: _openLegalSheet,
                  child: const Text(
                    'Devam ederek Gizlilik ve Kullanim Kosullari\'ni kabul edersiniz. \n(Detay icin tiklayin)',
                    style: TextStyle(color: Colors.white70, decoration: TextDecoration.underline),
                  ),
                ),
              ),
            ]),
            if (_error != null) ...[
              Text(_error!, style: const TextStyle(color: Colors.redAccent)),
              const SizedBox(height: 8),
            ],
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _busy ? null : _create,
                child: const Text('Kayit Ol'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PasswordStrengthBar extends StatelessWidget {
  final int score; // 0..4
  const _PasswordStrengthBar({required this.score});
  Color _color() {
    switch (score) {
      case 0:
      case 1:
        return Colors.redAccent;
      case 2:
        return Colors.orange;
      case 3:
        return Colors.yellow;
      default:
        return Colors.green;
    }
  }
  String _label() {
    switch (score) {
      case 0:
      case 1:
        return 'Zayif sifre';
      case 2:
        return 'Orta sifre';
      case 3:
        return 'Guclu sifre';
      default:
        return 'Cok guclu';
    }
  }
  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: score / 4.0,
              minHeight: 6,
              backgroundColor: Colors.white10,
              valueColor: AlwaysStoppedAnimation<Color>(_color()),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Text(_label(), style: const TextStyle(color: Colors.white70, fontSize: 12)),
      ],
    );
  }
}
