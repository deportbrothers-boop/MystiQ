import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:provider/provider.dart';
import '../../core/entitlements/entitlements_controller.dart';
import '../../features/history/history_controller.dart';
import '../../features/profile/profile_controller.dart';
import '../../core/i18n/app_localizations.dart';

class SignInPage extends StatefulWidget {
  const SignInPage({super.key});
  @override
  State<SignInPage> createState() => _SignInPageState();
}

class _SignInPageState extends State<SignInPage> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _showPassword = false;
  bool _remember = false;
  bool _busy = false;
  String? _error;

  bool get _validEmail {
    final e = _email.text.trim();
    final re = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
    return re.hasMatch(e);
  }

  bool get _validPassword => _password.text.length >= 6; // Firebase minimum 6

  Future<void> _signIn() async {
    setState(() => _error = null);
    if (!_validEmail) { setState(() => _error = 'Gecerli bir e-posta girin.'); return; }
    if (!_validPassword) { setState(() => _error = 'Sifre en az 6 karakter olmali.'); return; }
    if (_busy) return;
    _busy = true;
    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: _email.text.trim(),
        password: _password.text,
      );
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('remember_me', _remember);
      // E-posta dogrulama zorunlu degil: ek kontrol yapmiyoruz
      // Hesap degisti ise yerel cache'leri temizleme; her kullanicinin local cache'i ayridir
      try {
        final currentUid = FirebaseAuth.instance.currentUser?.uid;
        final lastUid = (await SharedPreferences.getInstance()).getString('ent_last_uid');
        final changed = (currentUid != null && currentUid != lastUid);
        if (mounted) {
          await context.read<EntitlementsController>().switchToCurrentUser();
          // History/Profile controllerleri, hesap degisse de kendi user-key'li cache'lerini kullanacak
          await context.read<HistoryController>().load();
          await context.read<ProfileController>().load();
        }
      } catch (_) {}
      if (!mounted) return;
      // Ilk kayittan sonra profil duzenlemeye git
      try {
        final just = (await SharedPreferences.getInstance()).getBool('just_signed_up') ?? false;
        if (just) {
          await (await SharedPreferences.getInstance()).setBool('just_signed_up', false);
          context.go('/profile/edit');
          return;
        }
      } catch (_) {}
      context.go('/home');
    } on FirebaseAuthException catch (e) {
      setState(() => _error = e.message ?? 'Giris basarisiz.');
    } catch (e) {
      setState(() => _error = 'Beklenmeyen hata: $e');
    } finally {
      _busy = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Giris Yap')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextField(
              controller: _email,
              decoration: const InputDecoration(labelText: 'E-posta', prefixIcon: Icon(Icons.email_outlined)),
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.next,
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _password,
              decoration: InputDecoration(
                labelText: 'Sifre',
                prefixIcon: const Icon(Icons.lock_outline),
                suffixIcon: IconButton(
                  icon: Icon(_showPassword ? Icons.visibility_off : Icons.visibility),
                  onPressed: () => setState(() => _showPassword = !_showPassword),
                ),
              ),
              obscureText: !_showPassword,
              onSubmitted: (_) => _signIn(),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Checkbox(value: _remember, onChanged: (v) => setState(() => _remember = v ?? false)),
                const Text('Beni hatirla'),
                const Spacer(),
                TextButton(
                  onPressed: () async {
                    if (!_validEmail) {
                      setState(() => _error = 'Sifre sifirlama icin gecerli e-posta girin.');
                      return;
                    }
                    try {
                      await FirebaseAuth.instance.sendPasswordResetEmail(email: _email.text.trim());
                      if (!mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Sifre sifirlama e-postasi gonderildi.')));
                    } catch (e) {
                      setState(() => _error = 'Sifre sifirlama basarisiz: $e');
                    }
                  },
                  child: Text(loc.t('auth.forgot') != 'auth.forgot' ? loc.t('auth.forgot') : 'Sifreyi unuttun mu?'),
                ),
              ],
            ),
            if (_error != null) ...[
              const SizedBox(height: 6),
              Text(_error!, style: const TextStyle(color: Colors.redAccent)),
            ],
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: (_validEmail && _validPassword && !_busy) ? _signIn : null,
                child: const Text('Giris Yap'),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text('Hesabin yok mu? '),
                TextButton(onPressed: () => context.push('/auth/signup'), child: const Text('Kayit Ol')),
              ],
            )
          ],
        ),
      ),
    );
  }
}
