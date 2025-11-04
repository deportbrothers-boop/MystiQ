import 'dart:io';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../../core/i18n/app_localizations.dart';
import '../profile/profile_controller.dart';

class AuthPage extends StatefulWidget {
  const AuthPage({super.key});
  @override
  State<AuthPage> createState() => _AuthPageState();
}

class _AuthPageState extends State<AuthPage> {
  final _email = TextEditingController();
  bool _accepted = false;
  String? _error;
  bool _busy = false;
  String? _photoPath;

  bool get _validEmail {
    final e = _email.text.trim();
    final re = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
    return re.hasMatch(e);
  }

  void _goToProfileEdit() {
    if (_busy) return;
    _busy = true;
    Future.microtask(() {
      if (!mounted) return;
      context.go('/profile/edit');
      _busy = false;
    });
  }

  void _continueEmail() {
    setState(() => _error = null);
    if (!_validEmail) {
      setState(() => _error = AppLocalizations.of(context).t('error.email_invalid'));
      return;
    }
    if (!_accepted) {
      setState(() => _error = AppLocalizations.of(context).t('error.accept_terms'));
      return;
    }
    _goToProfileEdit();
  }

  Future<void> _continuePhone() async {
    setState(() => _error = null);
    if (!_accepted) {
      setState(() => _error = AppLocalizations.of(context).t('error.accept_terms'));
      return;
    }
    _goToProfileEdit();
  }

  Future<void> _pickFromGallery() async {
    final pc = context.read<ProfileController>();
    final x = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 85, maxWidth: 2048);
    if (x != null) {
      setState(() => _photoPath = x.path);
      await pc.save(pc.profile.copyWith(photoPath: _photoPath));
    }
  }

  Future<void> _captureFromCamera() async {
    final pc = context.read<ProfileController>();
    final x = await ImagePicker().pickImage(source: ImageSource.camera, imageQuality: 85, maxWidth: 2048);
    if (x != null) {
      setState(() => _photoPath = x.path);
      await pc.save(pc.profile.copyWith(photoPath: _photoPath));
    }
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    ImageProvider? avatar;
    if (_photoPath != null) {
      try { avatar = FileImage(File(_photoPath!)); } catch (_) {}
    }
    return Scaffold(
      appBar: AppBar(title: Text(loc.t('auth.title'))),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Column(children: [
                  CircleAvatar(
                    radius: 40,
                    backgroundImage: avatar,
                    child: avatar == null ? const Icon(Icons.person, size: 40) : null,
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      OutlinedButton.icon(
                        onPressed: _pickFromGallery,
                        icon: const Icon(Icons.photo_library_outlined),
                        label: Text(AppLocalizations.of(context).t('auth.gallery')),
                      ),
                      const SizedBox(width: 8),
                      OutlinedButton.icon(
                        onPressed: _captureFromCamera,
                        icon: const Icon(Icons.photo_camera_outlined),
                        label: Text(AppLocalizations.of(context).t('auth.camera')),
                      ),
                    ],
                  ),
                ]),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _email,
                keyboardType: TextInputType.emailAddress,
                decoration: InputDecoration(labelText: AppLocalizations.of(context).t('auth.email_label'), prefixIcon: Icon(Icons.email)),
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 12),
              Row(children: [
                Checkbox(value: _accepted, onChanged: (v) => setState(() => _accepted = v ?? false)),
                Expanded(child: Text(loc.t('auth.terms'))),
              ]),
              if (_error != null) ...[
                Text(_error!, style: const TextStyle(color: Colors.redAccent)),
                const SizedBox(height: 8),
              ],
              ElevatedButton(onPressed: _validEmail && _accepted ? _continueEmail : null, child: Text(loc.t('auth.email'))),
              const SizedBox(height: 12),
              OutlinedButton(onPressed: _accepted ? _continuePhone : null, child: Text(AppLocalizations.of(context).t('auth.phone'))),
              const SizedBox(height: 12),
              ElevatedButton(onPressed: _validEmail && _accepted ? _continueEmail : null, child: Text(loc.t('auth.google'))),
              const SizedBox(height: 12),
              ElevatedButton(onPressed: _validEmail && _accepted ? _continueEmail : null, child: Text(loc.t('auth.apple'))),
              const SizedBox(height: 24),
              Center(
                child: TextButton(
                  onPressed: () => context.push('/auth/signup'),
                  child: Text(AppLocalizations.of(context).t('auth.signup.invite') != 'auth.signup.invite' ? AppLocalizations.of(context).t('auth.signup.invite') : 'Hesabın yok mu? Kayıt Ol'),
                ),
              ),
              const SizedBox(height: 12),
              Text(loc.t('auth.terms'), textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodySmall),
            ],
          ),
        ),
      ),
    );
  }
}

