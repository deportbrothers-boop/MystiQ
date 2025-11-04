import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/ai/ai_service.dart';
import '../profile/profile_controller.dart';
import '../../core/i18n/app_localizations.dart';

class LiveChatPage extends StatefulWidget {
  const LiveChatPage({super.key});
  @override
  State<LiveChatPage> createState() => _LiveChatPageState();
}

class _LiveChatPageState extends State<LiveChatPage> {
  final List<_Msg> msgs = [];
  final ctrl = TextEditingController();
  bool typing = false;
  StreamSubscription<String>? _sub;
  // Personalization (hidden controls; uses profile defaults)
  String _tone = 'friendly'; // friendly | spiritual | humorous
  String _length = 'medium'; // short | medium | long

  @override
  void initState() {
    super.initState();
    final pc = context.read<ProfileController>();
    _tone = pc.chatTone;
    _length = pc.chatLength;
  }

  Future<void> _send() async {
    final t = ctrl.text.trim();
    if (t.isEmpty) return;
    setState(() {
      msgs.add(_Msg(true, t));
      ctrl.clear();
      typing = true;
    });
    final profile = context.read<ProfileController>().profile;
    final locale = Localizations.localeOf(context).languageCode;
    final historyPayload = msgs
        .map((m) => {
              'role': m.me ? 'user' : 'assistant',
              'text': m.text,
            })
        .toList();

    final assistantIndex = msgs.length;
    setState(() => msgs.add(_Msg(false, '')));
    _sub?.cancel();
    final loc = AppLocalizations.of(context);
    final i18n = {
      'live.tips_header': loc.t('live.tips_header'),
      'live.tip.0': loc.t('live.tip.0'),
      'live.tip.1': loc.t('live.tip.1'),
      'live.tip.2': loc.t('live.tip.2'),
      'live.opener.spiritual': loc.t('live.opener.spiritual'),
      'live.opener.humorous': loc.t('live.opener.humorous'),
      'live.opener.default': loc.t('live.opener.default'),
      'live.follow_up': loc.t('live.follow_up'),
      'live.disclaimer': loc.t('live.disclaimer'),
      'live.astro_note': loc.t('live.astro_note'),
    };
    _sub = AiService.streamLiveChat(
      profile: profile,
      history: historyPayload,
      text: t,
      locale: locale,
      options: {'tone': _tone, 'length': _length, 'i18n': i18n},
    ).listen((chunk) {
      if (!mounted) return;
      setState(() {
        msgs[assistantIndex].text += chunk;
        typing = false;
      });
    }, onError: (_) {
      if (!mounted) return;
      setState(() {
        msgs[assistantIndex].text = AppLocalizations.of(context).t('live.welcome');
        typing = false;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    if (msgs.isEmpty) msgs.add(_Msg(false, loc.t('live.welcome')));
    return Scaffold(
      appBar: AppBar(title: Text(loc.t('live.title'))),
      body: Column(
        children: [
          // Chips and quick suggestions removed
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: msgs.length + (typing ? 1 : 0),
              itemBuilder: (_, i) {
                if (typing && i == msgs.length) {
                  return _Bubble(isMe: false, text: loc.t('live.typing'));
                }
                final m = msgs[i];
                return _Bubble(isMe: m.me, text: m.text);
              },
            ),
          ),
          SafeArea(
            child: Row(
              children: [
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: TextField(
                      controller: ctrl,
                      decoration: InputDecoration(
                        hintText: loc.t('live.input_hint'),
                        border: const OutlineInputBorder(),
                      ),
                      onSubmitted: (_) => _send(),
                    ),
                  ),
                ),
                IconButton(onPressed: _send, icon: const Icon(Icons.send))
              ],
            ),
          )
        ],
      ),
    );
  }
}

class _Msg {
  final bool me;
  String text;
  _Msg(this.me, this.text);
}

class _Bubble extends StatelessWidget {
  final bool isMe;
  final String text;
  const _Bubble({required this.isMe, required this.text});
  @override
  Widget build(BuildContext context) {
    final color = isMe ? Colors.amber : Colors.white12;
    final align = isMe ? Alignment.centerRight : Alignment.centerLeft;
    return Align(
      alignment: align,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(text),
      ),
    );
  }
}
