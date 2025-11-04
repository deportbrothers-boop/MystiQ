import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'user_profile.dart';
import '../../core/i18n/app_localizations.dart';
import 'profile_controller.dart';

class EditProfilePage extends StatefulWidget {
  const EditProfilePage({super.key});
  @override
  State<EditProfilePage> createState() => _EditProfilePageState();
}

class _EditProfilePageState extends State<EditProfilePage> {
  final nameCtrl = TextEditingController();
  DateTime? birth;
  String gender = '';
  String marital = '';
  bool _saving = false;
  String? photoPath;

  @override
  void initState() {
    super.initState();
    final p = context.read<ProfileController>().profile;
    nameCtrl.text = p.name;
    birth = p.birthDate;
    gender = p.gender;
    marital = p.marital;
    photoPath = p.photoPath;
  }

  ImageProvider? _avatarProvider() {
    if (photoPath == null || photoPath!.isEmpty) return null;
    try {
      return FileImage(File(photoPath!));
    } catch (_) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(AppLocalizations.of(context).t('profile.edit.birthdate')),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            if (Navigator.of(context).canPop()) {
              Navigator.of(context).pop();
            } else {
              context.go('/home');
            }
          },
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Center(
            child: Column(
              children: [
                CircleAvatar(
                  radius: 44,
                  backgroundImage: _avatarProvider(),
                  child: _avatarProvider() == null
                      ? const Icon(Icons.person, size: 44)
                      : null,
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    OutlinedButton.icon(
                      icon: const Icon(Icons.photo_library_outlined),
                      label: Text(AppLocalizations.of(context).t('profile.edit.photo.pick')),
                      onPressed: () async {
                        final x = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 85, maxWidth: 2048);
                        if (x != null) {
                          setState(() => photoPath = x.path);
                        }
                      },
                    ),
                    const SizedBox(width: 8),
                    OutlinedButton.icon(
                      icon: const Icon(Icons.photo_camera_outlined),
                      label: Text(AppLocalizations.of(context).t('profile.edit.photo.capture')),
                      onPressed: () async {
                        final x = await ImagePicker().pickImage(source: ImageSource.camera, imageQuality: 85, maxWidth: 2048);
                        if (x != null) {
                          setState(() => photoPath = x.path);
                        }
                      },
                    ),
                    const SizedBox(width: 8),
                    if (photoPath != null && photoPath!.isNotEmpty)
                      TextButton(onPressed: () => setState(() => photoPath = null), child: Text(AppLocalizations.of(context).t('action.remove'))),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: nameCtrl,
            decoration: InputDecoration(labelText: AppLocalizations.of(context).t('profile.edit.name_label')),
          ),
          const SizedBox(height: 12),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(AppLocalizations.of(context).t('profile.edit.birthdate')),
            subtitle: Text(birth != null ? '${birth!.day}.${birth!.month}.${birth!.year}' : AppLocalizations.of(context).t('action.select')),
            onTap: () async {
              final now = DateTime.now();
              final picked = await showDatePicker(
                context: context,
                initialDate: birth ?? DateTime(now.year - 20),
                firstDate: DateTime(1900),
                lastDate: now,
              );
              if (picked != null) setState(() => birth = picked);
            },
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: gender.isEmpty ? null : gender,
            items: [
              DropdownMenuItem(value: 'kadin', child: Text(AppLocalizations.of(context).t('profile.gender.female'))),
              DropdownMenuItem(value: 'erkek', child: Text(AppLocalizations.of(context).t('profile.gender.male'))),
              DropdownMenuItem(value: 'diger', child: Text(AppLocalizations.of(context).t('profile.gender.other'))),
            ],
            onChanged: (v) => setState(() => gender = v ?? ''),
            decoration: InputDecoration(labelText: AppLocalizations.of(context).t('profile.gender.label')),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: marital.isEmpty ? null : marital,
            items: [
              DropdownMenuItem(value: 'bekar', child: Text(AppLocalizations.of(context).t('profile.marital.single'))),
              DropdownMenuItem(value: 'evli', child: Text(AppLocalizations.of(context).t('profile.marital.married'))),
              DropdownMenuItem(value: 'yeni ayrildi', child: Text(AppLocalizations.of(context).t('profile.marital.recently_separated'))),
              DropdownMenuItem(value: 'sevgilisi var', child: Text(AppLocalizations.of(context).t('profile.marital.in_relationship'))),
            ],
            onChanged: (v) => setState(() => marital = v ?? ''),
            decoration: InputDecoration(labelText: AppLocalizations.of(context).t('profile.marital.label')),
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: _saving
                ? null
                : () async {
                    setState(() => _saving = true);
                    final p = UserProfile(
                      name: nameCtrl.text.trim(),
                      birthDate: birth,
                      gender: gender,
                      zodiac: birth != null ? ZodiacUtil.fromDate(birth!) : '',
                      marital: marital,
                      photoPath: photoPath,
                    );
                    await context.read<ProfileController>().save(p);
                    if (!mounted) return;
                    context.go('/home');
                  },
            child: Text(_saving ? AppLocalizations.of(context).t('action.saving') : AppLocalizations.of(context).t('action.save')),
          ),
        ],
      ),
    );
  }
}




