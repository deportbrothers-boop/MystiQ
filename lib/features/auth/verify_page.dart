import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../../core/i18n/app_localizations.dart';
import '../../core/app_env.dart';
import 'verify_controller.dart';

class VerifyPage extends StatefulWidget {
  const VerifyPage({super.key});
  @override
  State<VerifyPage> createState() => _VerifyPageState();
}

class _VerifyPageState extends State<VerifyPage> {
  final _code = TextEditingController();
  String? _error;

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    final vc = context.watch<VerifyController>();
    final email = vc.email;
    return Scaffold(
      appBar: AppBar(title: Text(loc.t('auth.title'))),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text(email != null ? AppLocalizations.of(context).t('verify.code_sent_email') + ' ' + email : AppLocalizations.of(context).t('verify.code_sent_sms')),
          const SizedBox(height: 8),
          TextField(
            controller: _code,
            keyboardType: TextInputType.number,
            maxLength: 6,
            decoration: InputDecoration(labelText: AppLocalizations.of(context).t('verify.input_label'), prefixIcon: Icon(Icons.verified_user)),
            onChanged: (_) => setState(() => _error = null),
          ),
          if (_error != null) ...[
            Text(_error!, style: const TextStyle(color: Colors.redAccent)),
            const SizedBox(height: 8),
          ],
          ElevatedButton(
            onPressed: () {
              if (vc.verify(_code.text)) {
                // (opsiyonel) doğrulanan e‑postayı profilde saklamak istiyorsanız burada ekleyebilirsiniz.
                context.go('/profile/edit');
              } else {
                setState(() => _error = 'Kod hatalı veya süresi doldu.');
              }
            },
            child: Text(AppLocalizations.of(context).t('action.continue')),
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: vc.canResend()
                ? () {
                    final e = vc.email;
                    if (e != null) vc.send(e);
                    setState(() {});
                  }
                : null,
            child: Text(vc.canResend() ? AppLocalizations.of(context).t('verify.resend') : AppLocalizations.of(context).t('verify.wait')),
          ),
          const Spacer(),
          if (AppEnv.showDevOtp && vc.code != null)
            Text(AppLocalizations.of(context).t('dev.code_prefix') + ' ' + '', textAlign: TextAlign.center, style: const TextStyle(color: Colors.white38)),
        ]),
      ),
    );
  }
}

