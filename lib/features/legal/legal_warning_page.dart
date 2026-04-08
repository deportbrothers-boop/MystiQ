import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/i18n/app_localizations.dart';

const kLegalWarningAcceptedKey = 'legal_warning_accepted_v1';

class LegalWarningPage extends StatefulWidget {
  final String nextRoute;

  const LegalWarningPage({
    super.key,
    this.nextRoute = '/auth',
  });

  @override
  State<LegalWarningPage> createState() => _LegalWarningPageState();
}

class _LegalWarningPageState extends State<LegalWarningPage> {
  bool _accepted = false;
  bool _saving = false;

  String get _safeNextRoute =>
      widget.nextRoute.startsWith('/') ? widget.nextRoute : '/auth';

  Future<void> _continue() async {
    if (!_accepted || _saving) return;
    setState(() => _saving = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(kLegalWarningAcceptedKey, true);
      if (!mounted) return;
      context.go(_safeNextRoute);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    final title = loc.t('legal.warning.title') != 'legal.warning.title'
        ? loc.t('legal.warning.title')
        : 'Yasal Uyarı';
    final body = loc.t('legal.warning.body') != 'legal.warning.body'
        ? loc.t('legal.warning.body')
        : 'Bu uygulama tamamen eğlence amaçlıdır.\n'
            'Sunulan yorumlar kesinlik içermez ve\n'
            'hiçbir şekilde profesyonel tavsiye\n'
            'niteliği taşımaz. Kullanıcı, içeriklerin\n'
            'eğlence amaçlı olduğunu kabul eder.';
    final acceptLabel = loc.t('legal.warning.accept') != 'legal.warning.accept'
        ? loc.t('legal.warning.accept')
        : 'Okudum, onaylıyorum';
    final continueLabel =
        loc.t('legal.warning.continue') != 'legal.warning.continue'
            ? loc.t('legal.warning.continue')
            : 'Devam';

    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: const Color(0xFF0D0D2B),
        body: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: Colors.white12),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: Theme.of(context).textTheme.headlineSmall,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          body,
                          style:
                              Theme.of(context).textTheme.bodyLarge?.copyWith(
                                    color: Colors.white70,
                                    height: 1.5,
                                  ),
                        ),
                        const SizedBox(height: 20),
                        CheckboxListTile(
                          value: _accepted,
                          onChanged: (value) =>
                              setState(() => _accepted = value ?? false),
                          contentPadding: EdgeInsets.zero,
                          controlAffinity: ListTileControlAffinity.leading,
                          title: Text(acceptLabel),
                        ),
                        const SizedBox(height: 8),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed:
                                (_accepted && !_saving) ? _continue : null,
                            child: _saving
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : Text(continueLabel),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
