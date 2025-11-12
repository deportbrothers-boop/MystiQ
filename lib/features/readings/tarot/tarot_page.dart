// import 'dart:math' as math; // unused
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/access/access_gate.dart';
import '../../../core/access/sku_costs.dart';
import '../../../core/analytics/analytics.dart';
import '../../../common/ui/responsive.dart';
import '../../../core/ads/rewarded_helper.dart';
import '../../../common/widgets/sharp_image.dart';
import 'package:provider/provider.dart';
import '../../../core/entitlements/entitlements_controller.dart';
import '../../../core/i18n/app_localizations.dart';
import '../../../core/readings/pending_readings_service_fixed.dart';
import 'tarot_deck_fixed.dart';
import '../../history/history_controller.dart';
import '../../history/history_entry.dart';

class TarotPage extends StatefulWidget {
  const TarotPage({super.key});

  @override
  State<TarotPage> createState() => _TarotPageState();
}

class _TarotPageState extends State<TarotPage> {
  final Set<int> selected = <int>{};
  final List<int?> _slots = [null, null, null]; // Past, Present, Future
  final ScrollController _gridCtrl = ScrollController();
  final GlobalKey _gridKey = GlobalKey();
  late final List<int> _deckOrder;
  String _topic = 'general';
  String _style = 'practical'; // 'practical' | 'spiritual' | 'analytical'

  @override
  void initState() {
    super.initState();
    // Shuffle deck order so user cannot memorize positions
    _deckOrder = List.generate(TarotDeck.count, (i) => i);
    _deckOrder.shuffle();
    // If a pending tarot exists, redirect directly to Result
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      try {
        final item = await PendingReadingsService.firstPendingOfType('tarot');
        if (!mounted || item == null) return;
        final readyAt = DateTime.tryParse((item['readyAt'] as String?) ?? '');
        if (readyAt == null) return;
        final extras = (item['extras'] as Map?)?.cast<String, dynamic>() ?? <String, dynamic>{};
        final names = (extras['cards'] as List?)?.map((e) => '$e').toList() ?? const <String>[];
        final idxs = (extras['cardIndices'] as List?)?.map((e) => int.tryParse('$e') ?? -1).where((e) => e >= 0).toList() ?? const <int>[];
        final reversed = (extras['reversed'] as List?)?.map((e) => e == true).toList() ?? const <bool>[];
        context.push('/reading/result/tarot', extra: {
          'cards': names,
          'cardIndices': idxs,
          'reversed': reversed,
          'etaSeconds': readyAt.difference(DateTime.now()).inSeconds.clamp(0, 86400),
          'readyAt': readyAt.toIso8601String(),
          'generateAtReady': true,
          // streaming/local flags removed
        });
      } catch (_) {}
    });
  }

  Widget _buildBottomCtas() {
    final loc = AppLocalizations.of(context);
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Column(
          children: [
            Text("${loc.t('tarot.selected_prefix')} ${selected.length}/3"),
            const SizedBox(height: 8),
            Row(
              children: [
                OutlinedButton.icon(
                  onPressed: selected.length < 3 ? null : () async {
                    await Analytics.log('reading_started', {'type': 'tarot_ad'});
                    final ok = await RewardedAds.show(context: context);
                    if (!context.mounted) return;
                    if (!ok) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(
                          AppLocalizations.of(context).t('tarot.fast.ad_failed') != 'tarot.fast.ad_failed'
                              ? AppLocalizations.of(context).t('tarot.fast.ad_failed')
                              : 'Reklam gösterilemedi. Tekrar deneyin.',
                        )),
                      );
                      return;
                    }
                    try { await RewardedAds.recordOne(); } catch (_) {}
                    final idxs = _slots.whereType<int>().toList();
                    final names = idxs.map(TarotDeck.nameForIndex).toList();
                    final nowMs = DateTime.now().millisecondsSinceEpoch;
                    final reversed = List<bool>.generate(idxs.length, (k) => ((nowMs + k + idxs[k]) % 2) == 0);
                    final eta = const Duration(minutes: 8);
                    final readyAt = DateTime.now().add(eta);
                    String? scheduledId;
                    try {
                      final extras = <String, dynamic>{
                        'cards': names,
                        'cardIndices': idxs,
                        'reversed': reversed,
                        'topic': _topic,
                        'style': _style,
                        'adBoost': true,
                      };
                      final locale = Localizations.localeOf(context).languageCode;
                      scheduledId = await PendingReadingsService.schedule(
                        type: 'tarot',
                        readyAt: readyAt,
                        extras: extras,
                        locale: locale,
                      );
                      try {
                        final hc = context.read<HistoryController>();
                        await hc.upsert(HistoryEntry(
                          id: scheduledId!,
                          type: 'tarot',
                          title: AppLocalizations.of(context).t('tarot.title'),
                          text: AppLocalizations.of(context).t('reading.preparing'),
                          createdAt: DateTime.now(),
                        ));
                      } catch (_) {}
                    } catch (_) {}
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(
                        AppLocalizations.of(context).t('tarot.fast.thanks') != 'tarot.fast.thanks'
                            ? AppLocalizations.of(context).t('tarot.fast.thanks')
                            : 'Teşekkürler! Falın 8 dk içinde hazır olacak.',
                      )),
                    );
                    context.push('/reading/result/tarot', extra: {
                      'cards': names,
                      'cardIndices': idxs,
                      'reversed': reversed,
                      'sessionId': DateTime.now().millisecondsSinceEpoch,
                      'etaSeconds': eta.inSeconds,
                      'readyAt': readyAt.toIso8601String(),
                      'generateAtReady': true,
                      if (scheduledId != null) 'pendingId': scheduledId,
                      'topic': _topic,
                      'style': _style,
                      // streaming/local flags removed
                    });
                  },
                  icon: const Icon(Icons.play_circle_outline, size: 18),
                  label: Text(
                    AppLocalizations.of(context).t('tarot.entry.watch_and_read') != 'tarot.entry.watch_and_read'
                        ? AppLocalizations.of(context).t('tarot.entry.watch_and_read')
                        : 'Reklam izle (8 dk)',
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton(
                    onPressed: selected.length < 3 ? null : () async {
                      await Analytics.log('reading_started', {'type': 'tarot'});
                      final ent = context.read<EntitlementsController>();
                      final confirmed = await showModalBottomSheet<bool>(
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
                                Text(AppLocalizations.of(context).t('coins.confirm.title') != 'coins.confirm.title'
                                    ? AppLocalizations.of(context).t('coins.confirm.title')
                                    : 'Coin harcanacak'),
                                const SizedBox(height: 8),
                                Text(AppLocalizations.of(context).t('coins.confirm.body') != 'coins.confirm.body'
                                    ? AppLocalizations.of(context).t('coins.confirm.body')
                                    : 'Bu tarot falı için ${SkuCosts.tarotDeep} coin harcanacak. Bakiyeniz: ${ent.coins}'),
                                const SizedBox(height: 12),
                                Row(children: [
                                  Expanded(
                                    child: OutlinedButton(
                                      onPressed: () => Navigator.pop(context, false),
                                      child: Text(AppLocalizations.of(context).t('action.cancel')),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: ElevatedButton(
                                      onPressed: () => Navigator.pop(context, true),
                                      child: Text(AppLocalizations.of(context).t('coins.confirm.spend') != 'coins.confirm.spend'
                                          ? AppLocalizations.of(context).t('coins.confirm.spend')
                                          : 'Harca (${SkuCosts.tarotDeep})'),
                                    ),
                                  ),
                                ])
                              ],
                            ),
                          ),
                        ),
                      );
                      if (!context.mounted) return;
                      if (confirmed != true) return;
                      final ok = await AccessGate.ensureCoinsOnlyOrPaywall(
                        context,
                        coinCost: SkuCosts.tarotDeep,
                      );
                      if (!ok) return;
                      if (!context.mounted) return;
                      final idxs = _slots.whereType<int>().toList();
                      final names = idxs.map(TarotDeck.nameForIndex).toList();
                      final nowMs = DateTime.now().millisecondsSinceEpoch;
                      final reversed = List<bool>.generate(idxs.length, (k) => ((nowMs + k + idxs[k]) % 2) == 0);

                      // Coins flow: no waiting, generate immediately (no placeholder in History)
                      if (!context.mounted) return;
                      context.push('/reading/result/tarot', extra: {
                        'cards': names,
                        'cardIndices': idxs,
                        'reversed': reversed,
                        'topic': _topic,
                        'style': _style,
                        // streaming/local flags removed
                      });
                    },
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(loc.t('tarot.cta')),
                        const SizedBox(width: 8),
                        const Icon(Icons.monetization_on_outlined, size: 16),
                        const SizedBox(width: 2),
                        Text('${SkuCosts.tarotDeep}'),
                        const SizedBox(width: 6),
                        Tooltip(
                          message: (AppLocalizations.of(context).t('coins.reason.tarot') != 'coins.reason.tarot')
                              ? AppLocalizations.of(context).t('coins.reason.tarot')
                              : 'AI isleme maliyetleri nedeniyle coin gereklidir.',
                          child: const Icon(Icons.info_outline, size: 16),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _placeIntoSlot(int index, {int? slot}) {
    for (var i = 0; i < _slots.length; i++) {
      if (_slots[i] == index) _slots[i] = null;
    }
    if (slot != null) {
      _slots[slot] = index;
    } else {
      for (var i = 0; i < _slots.length; i++) {
        if (_slots[i] == null) {
          _slots[i] = index;
          break;
        }
      }
    }
    selected..clear()..addAll(_slots.whereType<int>());
    setState(() {});
  }

  void _clearSlot(int i) {
    if (_slots[i] == null) return;
    _slots[i] = null;
    selected..clear()..addAll(_slots.whereType<int>());
    setState(() {});
  }

  @override
  void dispose() {
    _gridCtrl.dispose();
    super.dispose();
  }

  void _resetDeck() {
    selected.clear();
    for (var i = 0; i < _slots.length; i++) {
      _slots[i] = null;
    }
    _deckOrder.shuffle();
    if (_gridCtrl.hasClients) {
      _gridCtrl.jumpTo(_gridCtrl.position.minScrollExtent);
    }
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final s = R.scale(context);
    final double cardW = 72.0 * s;
    final double cardH = 112.0 * s;
    final double slotW = 100.0 * s;
    final double slotH = 156.0 * s;

    final loc = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(loc.t('tarot.title')),
        actions: [
          IconButton(onPressed: _resetDeck, tooltip: loc.t('common.reset'), icon: const Icon(Icons.refresh)),
        ],
      ),
      body: Column(
        children: [
          // Top: title + 3 slots; no fixed height => grid starts immediately after the helper text
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(loc.t('tarot.select_cards'), style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: ['general','love','work','money','health'].map((k) {
                    String label;
                    switch (k) {
                      case 'love': label = AppLocalizations.of(context).t('coffee.topic.love') != 'coffee.topic.love' ? AppLocalizations.of(context).t('coffee.topic.love') : 'Aşk'; break;
                      case 'work': label = AppLocalizations.of(context).t('coffee.topic.work') != 'coffee.topic.work' ? AppLocalizations.of(context).t('coffee.topic.work') : 'İş'; break;
                      case 'money': label = AppLocalizations.of(context).t('coffee.topic.money') != 'coffee.topic.money' ? AppLocalizations.of(context).t('coffee.topic.money') : 'Para'; break;
                      case 'health': label = AppLocalizations.of(context).t('coffee.topic.health') != 'coffee.topic.health' ? AppLocalizations.of(context).t('coffee.topic.health') : 'Sağlık'; break;
                      default: label = AppLocalizations.of(context).t('coffee.topic.general') != 'coffee.topic.general' ? AppLocalizations.of(context).t('coffee.topic.general') : 'Genel';
                    }
                    return ChoiceChip(
                      selected: _topic == k,
                      label: Text(label),
                      onSelected: (_) => setState(() => _topic = k),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 8),
                const SizedBox.shrink(),
                const SizedBox(height: 12),
                Row(
                  children: List.generate(3, (i) {
                    final idx = _slots[i];
                    return Expanded(
                      child: Padding(
                        padding: EdgeInsets.only(right: i < 2 ? 12 : 0),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            DragTarget<int>(
                              onWillAcceptWithDetails: (details) => true,
                              onAcceptWithDetails: (details) => _placeIntoSlot(details.data, slot: i),
                              builder: (context, cand, rej) {
                                return SizedBox(
                                  width: slotW,
                                  height: slotH,
                                  child: GestureDetector(
                                    onTap: () => _clearSlot(i),
                                    child: _SlotCard(index: idx),
                                  ),
                                );
                              },
                            ),
                            const SizedBox(height: 8),
                            Text(i == 0 ? loc.t('tarot.slot.past') : i == 1 ? loc.t('tarot.slot.present') : loc.t('tarot.slot.future')),
                          ],
                        ),
                      ),
                    );
                  }),
                ),
                const SizedBox(height: 12),
                Text(loc.t('tarot.hint.select_or_drag'), style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
          ),

          // Deck grid fills remaining space
          Expanded(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 20 * s),
              child: GridView.builder(
                key: _gridKey,
                controller: _gridCtrl,
                padding: EdgeInsets.zero,
                physics: const BouncingScrollPhysics(),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 6,
                  crossAxisSpacing: 16 * s,
                  mainAxisSpacing: 14 * s,
                  childAspectRatio: cardW / cardH,
                ),
                itemCount: _deckOrder.length,
                itemBuilder: (context, i) {
                  final cardIndex = _deckOrder[i];
                  final isSel = selected.contains(cardIndex);
                  return LongPressDraggable<int>(
                    data: cardIndex,
                    feedback: SizedBox(width: cardW, height: cardH, child: _TarotCard(index: cardIndex, selected: true)),
                    childWhenDragging: const SizedBox.shrink(),
                    onDragUpdate: (details) {
                      // Auto-scroll grid when dragging near top/bottom edges
                      final box = _gridKey.currentContext?.findRenderObject() as RenderBox?;
                      if (box == null || !_gridCtrl.hasClients) return;
                      final local = box.globalToLocal(details.globalPosition);
                      final height = box.size.height;
                      const edge = 48.0; // px threshold
                      const delta = 18.0; // scroll per update
                      if (local.dy < edge) {
                        final t = (_gridCtrl.offset - delta).clamp(_gridCtrl.position.minScrollExtent, _gridCtrl.position.maxScrollExtent);
                        _gridCtrl.jumpTo(t);
                      } else if (local.dy > height - edge) {
                        final t = (_gridCtrl.offset + delta).clamp(_gridCtrl.position.minScrollExtent, _gridCtrl.position.maxScrollExtent);
                        _gridCtrl.jumpTo(t);
                      }
                    },
                    onDragEnd: (d) {
                      if (!d.wasAccepted && !isSel && selected.length < 3) _placeIntoSlot(cardIndex);
                    },
                    child: GestureDetector(
                      onTap: () {
                        if (!isSel && selected.length < 3) _placeIntoSlot(cardIndex);
                      },
                      child: _TarotCard(index: cardIndex, selected: isSel),
                    ),
                  );
                },
              ),
            ),
          ),

          // Bottom action
          _buildBottomCtas(),
          /*
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Column(
                children: [
                  Text("${loc.t('tarot.selected_prefix')} ${selected.length}/3"),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      OutlinedButton.icon(
                        onPressed: selected.length < 3
                            ? null
                            : () async {
                                await Analytics.log('reading_started', {'type': 'tarot_ad'});
                                final ok = await RewardedAds.show(context: context);
                                if (!context.mounted) return;
                                if (!ok) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        AppLocalizations.of(context).t('tarot.fast.ad_failed') != 'tarot.fast.ad_failed'
                                            ? AppLocalizations.of(context).t('tarot.fast.ad_failed')
                                            : 'Reklam gösterilemedi. Tekrar deneyin.',
                                      ),
                                    ),
                                  );
                                  return;
                                }
                                try { await RewardedAds.recordOne(); } catch (_) {}
                                final idxs = _slots.whereType<int>().toList();
                                final names = idxs.map(TarotDeck.nameForIndex).toList();
                                final nowMs = DateTime.now().millisecondsSinceEpoch;
                                final reversed = List<bool>.generate(idxs.length, (k) => ((nowMs + k + idxs[k]) % 2) == 0);
                                final eta = const Duration(minutes: 8);
                                final readyAt = DateTime.now().add(eta);
                                String? scheduledId;
                                try {
                                  final extras = <String, dynamic>{
                                    'cards': names,
                                    'cardIndices': idxs,
                                    'reversed': reversed,
                                    'topic': _topic,
                                    'style': _style,
                                    'adBoost': true,
                                  };
                                  final locale = Localizations.localeOf(context).languageCode;
                                  scheduledId = await PendingReadingsService.schedule(
                                    type: 'tarot',
                                    readyAt: readyAt,
                                    extras: extras,
                                    locale: locale,
                                  );
                                  try {
                                    final hc = context.read<HistoryController>();
                                    await hc.upsert(HistoryEntry(
                                      id: scheduledId!,
                                      type: 'tarot',
                                      title: AppLocalizations.of(context).t('tarot.title'),
                                      text: AppLocalizations.of(context).t('reading.preparing'),
                                      createdAt: DateTime.now(),
                                    ));
                                  } catch (_) {}
                                } catch (_) {}
                                if (!context.mounted) return;
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      AppLocalizations.of(context).t('tarot.fast.thanks') != 'tarot.fast.thanks'
                                          ? AppLocalizations.of(context).t('tarot.fast.thanks')
                                          : 'Teşekkürler! Falın 8 dk içinde hazır olacak.',
                                    ),
                                  ),
                                );
                                context.push('/reading/result/tarot', extra: {
                                  'cards': names,
                                  'cardIndices': idxs,
                                  'reversed': reversed,
                                  'sessionId': DateTime.now().millisecondsSinceEpoch,
                                  'etaSeconds': eta.inSeconds,
                                  'readyAt': readyAt.toIso8601String(),
                                  'generateAtReady': true,
                                  if (scheduledId != null) 'pendingId': scheduledId,
                                  'topic': _topic,
                                  'style': _style,
                                  // streaming/local flags removed
                                });
                              },
                        icon: const Icon(Icons.play_circle_outline, size: 18),
                        label: Text(
                          AppLocalizations.of(context).t('tarot.entry.watch_and_read') != 'tarot.entry.watch_and_read'
                              ? AppLocalizations.of(context).t('tarot.entry.watch_and_read')
                              : 'Reklam izle (8 dk)',
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: ElevatedButton(
                    onPressed: selected.length < 3
                        ? null
                        : () async {
                            await Analytics.log('reading_started', {'type': 'tarot'});
                            final ent = context.read<EntitlementsController>();

                            // 1) Confirm coin spending to the user
                            final confirmed = await showModalBottomSheet<bool>(
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
                                      Text(AppLocalizations.of(context).t('coins.confirm.title') != 'coins.confirm.title'
                                          ? AppLocalizations.of(context).t('coins.confirm.title')
                                          : 'Coin harcanacak'),
                                      const SizedBox(height: 8),
                                      Text(AppLocalizations.of(context).t('coins.confirm.body') != 'coins.confirm.body'
                                          ? AppLocalizations.of(context).t('coins.confirm.body')
                                          : 'Bu tarot falı için ${SkuCosts.tarotDeep} coin harcanacak. Bakiyeniz: ${ent.coins}'),
                                      const SizedBox(height: 12),
                                      Row(children: [
                                        Expanded(
                                          child: OutlinedButton(
                                            onPressed: () => Navigator.pop(context, false),
                                            child: Text(AppLocalizations.of(context).t('action.cancel')),
                                          ),
                                        ),
                                        const SizedBox(width: 10),
                                        Expanded(
                                          child: ElevatedButton(
                                            onPressed: () => Navigator.pop(context, true),
                                            child: Text(AppLocalizations.of(context).t('coins.confirm.spend') != 'coins.confirm.spend'
                                                ? AppLocalizations.of(context).t('coins.confirm.spend')
                                                : 'Harca (${SkuCosts.tarotDeep})'),
                                          ),
                                        ),
                                      ])
                                    ],
                                  ),
                                ),
                              ),
                            );
                            if (!context.mounted) return;
                            if (confirmed != true) return;

                            // 2) Enforce coin-only access
                            final ok = await AccessGate.ensureCoinsOnlyOrPaywall(
                              context,
                              coinCost: SkuCosts.tarotDeep,
                            );
                            if (!ok) return;
                            if (!context.mounted) return;

                            // 3) Offer rewarded ad to reduce ETA 10 -> 5 minutes
                            Duration eta = Duration.zero;
                            bool adUsed = false;
                            if (eta > Duration.zero) {
                            try {
                              final choice = await showModalBottomSheet<String>(
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
                                        Text(
                                          AppLocalizations.of(context).t('tarot.fast.offer.title') != 'tarot.fast.offer.title'
                                              ? AppLocalizations.of(context).t('tarot.fast.offer.title')
                                              : 'Daha hızlı sonuç ister misiniz?',
                                          style: const TextStyle(fontWeight: FontWeight.w700),
                                        ),
                                        const SizedBox(height: 6),
                                        Text(
                                          AppLocalizations.of(context).t('tarot.fast.offer.body') != 'tarot.fast.offer.body'
                                              ? AppLocalizations.of(context).t('tarot.fast.offer.body')
                                              : 'Reklam izlerseniz tarot falınız 10 dk yerine 5 dk içinde hazır olur.',
                                        ),
                                        const SizedBox(height: 14),
                                        Row(children: [
                                          Expanded(
                                            child: ElevatedButton.icon(
                                              icon: const Icon(Icons.rocket_launch, size: 18),
                                              onPressed: () => Navigator.pop(context, 'ad'),
                                              label: Text(
                                                AppLocalizations.of(context).t('tarot.fast.watch_ad') != 'tarot.fast.watch_ad'
                                                    ? AppLocalizations.of(context).t('tarot.fast.watch_ad')
                                                    : 'Reklam izle (5 dk)'
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 10),
                                          Expanded(
                                            child: OutlinedButton(
                                              onPressed: () => Navigator.pop(context, 'normal'),
                                              child: Text(
                                                AppLocalizations.of(context).t('tarot.fast.normal') != 'tarot.fast.normal'
                                                    ? AppLocalizations.of(context).t('tarot.fast.normal')
                                                    : 'Normal (10 dk)'
                                              ),
                                            ),
                                          ),
                                        ])
                                      ],
                                    ),
                                  ),
                                ),
                              );
                              if (!context.mounted) return;
                              if (choice == 'ad') {
                                final ok = await RewardedAds.show(context: context);
                                if (!context.mounted) return;
                                if (ok) {
                                  adUsed = true;
                                  eta = const Duration(minutes: 8);
                                  try { await RewardedAds.recordOne(); } catch (_) {}
                                  if (mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(content: Text(
                                        AppLocalizations.of(context).t('tarot.fast.thanks') != 'tarot.fast.thanks'
                                            ? AppLocalizations.of(context).t('tarot.fast.thanks')
                                            : 'Teşekkürler! Falın 5 dk içinde hazır olacak.'
                                      )),
                                    );
                                  }
                                } else {
                                  if (mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(content: Text(
                                        AppLocalizations.of(context).t('tarot.fast.ad_failed') != 'tarot.fast.ad_failed'
                                            ? AppLocalizations.of(context).t('tarot.fast.ad_failed')
                                            : 'Reklam gösterilemedi. Normal hızda devam ediliyor (10 dk).'
                                      )),
                                    );
                                  }
                                }
                              }
                            } catch (_) {}

                            }
                            // 4) If coins path (eta == 0), navigate immediately; else schedule background completion
                            final idxs = _slots.whereType<int>().toList();
                            final names = idxs.map(TarotDeck.nameForIndex).toList();
                            final nowMs = DateTime.now().millisecondsSinceEpoch;
                            final reversed = List<bool>.generate(idxs.length, (k) => ((nowMs + k + idxs[k]) % 2) == 0);
                            if (eta == Duration.zero) {
                              if (context.mounted) {
                                context.push('/reading/result/tarot', extra: {
                                  'cards': names,
                                  'cardIndices': idxs,
                                  'reversed': reversed,
                                  'topic': _topic,
                                  'style': _style,
                                  // allow streaming for coin path (immediate)
                                });
                              }
                              return;
                            }
                            final readyAt = DateTime.now().add(eta);
                            String? scheduledId;
                            try {
                              final extras = <String, dynamic>{
                                'cards': names,
                                'cardIndices': idxs,
                                'reversed': reversed,
                                'topic': _topic,
                                'style': _style,
                                'notifyOnly': true,
                                if (adUsed) 'adBoost': true,
                              };
                              final locale = Localizations.localeOf(context).languageCode;
                              scheduledId = await PendingReadingsService.schedule(
                                type: 'tarot',
                                readyAt: readyAt,
                                extras: extras,
                                locale: locale,
                              );
                              try {
                                final hc = context.read<HistoryController>();
                                await hc.upsert(HistoryEntry(
                                  id: scheduledId!,
                                  type: 'tarot',
                                  title: AppLocalizations.of(context).t('tarot.title'),
                                  text: AppLocalizations.of(context).t('reading.preparing'),
                                  createdAt: DateTime.now(),
                                ));
                              } catch (_) {}
                            } catch (_) {}
                            if (context.mounted) {
                              context.push('/reading/result/tarot', extra: {
                                'cards': names,
                                'cardIndices': idxs,
                                'reversed': reversed,
                                'sessionId': DateTime.now().millisecondsSinceEpoch,
                                'etaSeconds': eta.inSeconds,
                                'readyAt': readyAt.toIso8601String(),
                                'generateAtReady': true,
                                if (scheduledId != null) 'pendingId': scheduledId,
                                'topic': _topic,
                                'style': _style,
                                // streaming/local flags removed
                              });
                            }
                          },
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(loc.t('tarot.cta')),
                        const SizedBox(width: 8),
                        const Icon(Icons.monetization_on_outlined, size: 16),
                        const SizedBox(width: 2),
                        Text('${SkuCosts.tarotDeep}'),
                        const SizedBox(width: 6),
                        Tooltip(
                          message: (AppLocalizations.of(context).t('coins.reason.tarot') != 'coins.reason.tarot')
                              ? AppLocalizations.of(context).t('coins.reason.tarot')
                              : 'AI isleme maliyetleri nedeniyle coin gereklidir.',
                          child: const Icon(Icons.info_outline, size: 16),
                         )
                       ],
                     ),
                   ),
                   ],
                  ),
                ],
              ),
            ),
          ),
          */
        ],
      ),
    );
  }
}

class _TarotCard extends StatelessWidget {
  static const String backAsset = 'assets/images/back.png';
  final int index;
  final bool selected;
  const _TarotCard({required this.index, required this.selected});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        boxShadow: selected
            ? [BoxShadow(color: Colors.amberAccent.withValues(alpha: 0.22), blurRadius: 10, spreadRadius: 0.5)]
            : const <BoxShadow>[],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: SharpAssetFallback(
          backAsset,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stack) => Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF131018), Color(0xFF1C1430)],
              ),
            ),
            alignment: Alignment.center,
            child: Icon(Icons.auto_awesome, color: Colors.amber.shade200),
          ),
        ),
      ),
    );
  }
}

class _SlotCard extends StatelessWidget {
  final int? index;
  const _SlotCard({this.index});

  @override
  Widget build(BuildContext context) {
    const r = 10.0;
    if (index == null) {
      return Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(r),
          color: const Color(0xFF0F0D15),
        ),
        child: const Center(child: Icon(Icons.add, color: Colors.white30)),
      );
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(r),
      child: SharpAssetFallback(
        _TarotCard.backAsset,
        fit: BoxFit.cover,
        errorBuilder: (c, e, s) => Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(r),
            color: const Color(0xFF0F0D15),
          ),
          child: const Center(child: Icon(Icons.image_not_supported, color: Colors.white30)),
        ),
      ),
    );
  }
}









