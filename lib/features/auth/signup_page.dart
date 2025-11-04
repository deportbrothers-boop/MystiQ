import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/i18n/app_localizations.dart';
import '../../core/entitlements/entitlements_controller.dart';

class SignUpPage extends StatefulWidget {
  const SignUpPage({super.key});
  @override
  State<SignUpPage> createState() => _SignUpPageState();
}

class _SignUpPageState extends State<SignUpPage> {
  final _username = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  bool _showPassword = false;
  bool _accepted = false;
  String? _error;
  bool _busy = false;

  bool get _validEmail {
    final e = _email.text.trim();
    final re = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
    return re.hasMatch(e);
  }

  bool get _validUsername {
    final u = _username.text.trim();
    return u.length >= 3 && RegExp(r'^[a-zA-Z0-9_.-]+$').hasMatch(u);
  }

  bool get _validPassword {
    final p = _password.text;
    final hasLen = p.length >= 8;
    final hasNum = RegExp(r'[0-9]').hasMatch(p);
    final hasLet = RegExp(r'[A-Za-z]').hasMatch(p);
    return hasLen && hasNum && hasLet;
  }

  Future<bool> _reserveUsername(String username, String uid) async {
    final key = username.toLowerCase();
    final ref = FirebaseFirestore.instance.collection('usernames').doc(key);
    final snap = await ref.get();
    if (snap.exists) {
      final data = snap.data();
      if (data != null && data['uid'] == uid) return true;
      return false;
    }
    await ref.set({'uid': uid, 'createdAt': FieldValue.serverTimestamp()});
    return true;
  }

  Future<void> _create() async {
    setState(() => _error = null);
    if (!_validUsername) {
      setState(() => _error = 'Geçerli bir kullanıcı adı girin (en az 3, sadece harf/rakam/._-)');
      return;
    }
    if (!_validEmail) {
      setState(() => _error = 'Geçerli bir e-posta girin.');
      return;
    }
    if (!_validPassword || _password.text != _confirm.text) {
      setState(() => _error = 'Şifre en az 8 karakter, harf ve rakam içermeli; şifreler eşleşmeli.');
      return;
    }
    if (!_accepted) {
      setState(() => _error = 'Devam etmek için şartları kabul edin.');
      return;
    }
    if (_busy) return;
    _busy = true;
    try {
      final cred = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: _email.text.trim(),
        password: _password.text,
      );
      final uid = cred.user!.uid;
      // Reserve username (rudimentary uniqueness)
      final ok = await _reserveUsername(_username.text.trim(), uid);
      if (!ok) {
        setState(() => _error = 'Kullanıcı adı kullanılıyor.');
        await cred.user!.delete();
        return;
      }
      // Save profile
      final users = FirebaseFirestore.instance.collection('users');
      await users.doc(uid).set({
        'username': _username.text.trim(),
        'email': _email.text.trim(),
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      // Sync entitlements remotely to avoid loss
      try {
        final ent = context.read<EntitlementsController>();
        await FirebaseFirestore.instance.collection('users').doc(uid).collection('meta').doc('entitlements').set({
          'coins': ent.coins,
          'premiumSku': ent.premiumSku,
          'premiumUntil': ent.premiumUntil?.toIso8601String(),
          'firstFreeUsed': ent.firstFreeUsed,
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      } catch (_) {}

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Hesap oluşturuldu.')),
      );
      Navigator.of(context).pop();
    } on FirebaseAuthException catch (e) {
      setState(() => _error = e.message ?? 'Kayıt başarısız.');
    } catch (e) {
      setState(() => _error = 'Beklenmeyen bir hata: $e');
    } finally {
      _busy = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text('Kayıt Ol')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextField(
              controller: _username,
              decoration: const InputDecoration(labelText: 'Kullanıcı adı'),
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _email,
              decoration: const InputDecoration(labelText: 'E-posta'),
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _password,
              decoration: InputDecoration(
                labelText: 'Şifre',
                suffixIcon: IconButton(
                  icon: Icon(_showPassword ? Icons.visibility_off : Icons.visibility),
                  onPressed: () => setState(() => _showPassword = !_showPassword),
                ),
              ),
              obscureText: !_showPassword,
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _confirm,
              decoration: const InputDecoration(labelText: 'Şifre (tekrar)'),
              obscureText: true,
            ),
            const SizedBox(height: 10),
            Row(children: [
              Checkbox(value: _accepted, onChanged: (v) => setState(() => _accepted = v ?? false)),
              Expanded(child: Text(loc.t('auth.terms'))),
            ]),
            if (_error != null) ...[
              Text(_error!, style: const TextStyle(color: Colors.redAccent)),
              const SizedBox(height: 8),
            ],
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _busy ? null : _create,
                child: const Text('Kayıt Ol'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

