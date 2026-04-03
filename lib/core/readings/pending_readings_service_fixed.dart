import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../notifications/notifications_service.dart';
import '../../features/history/history_controller.dart';
import '../../features/history/history_entry.dart';
import '../ai/ai_service.dart';
import '../access/ai_generation_guard.dart';
import '../analytics/analytics.dart';
import 'pending_localization.dart';
import '../../features/profile/profile_controller.dart';
import '../ai/local_generator.dart';

class PendingReadingsService {
  static const _kKey = 'pending_readings_v1';
  static const _kSpeedupUsed = 'speedupUsed';

  static Future<List<Map<String, dynamic>>> _load() async {
    final sp = await SharedPreferences.getInstance();
    final list = sp.getStringList(_kKey) ?? [];
    return list.map((e) => json.decode(e) as Map<String, dynamic>).toList();
  }

  static Future<void> _save(List<Map<String, dynamic>> items) async {
    final sp = await SharedPreferences.getInstance();
    final list = items.map((e) => json.encode(e)).toList();
    await sp.setStringList(_kKey, list);
  }

  static Future<String> schedule({
    required String type,
    required DateTime readyAt,
    Map<String, dynamic>? extras,
    String locale = 'tr',
  }) async {
    final id = readyAt.millisecondsSinceEpoch.toString();
    final items = await _load();
    items.removeWhere((e) => e['id'] == id);
    items.add({
      'id': id,
      'type': type,
      'readyAt': readyAt.toIso8601String(),
      'extras': extras ?? {}
    });
    await _save(items);
    final seconds =
        readyAt.difference(DateTime.now()).inSeconds.clamp(1, 86400);
    await PendingI18n.ensure(locale);
    await NotificationsService.scheduleOneShot(
      id: id.hashCode & 0x7FFFFFFF,
      title: 'Falla - ${PendingI18n.titleForType(type, locale)}',
      body: PendingI18n.bodyForType(type, locale),
      secondsFromNow: seconds,
    );
    return id;
  }

  static Future<void> cancel(String id) async {
    final items = await _load();
    items.removeWhere((e) => e['id'] == id);
    await _save(items);
  }

  static Future<Map<String, dynamic>?> getById(String id) async {
    try {
      final items = await _load();
      for (final it in items) {
        if ((it['id'] as String?) == id) return it;
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  static Future<bool> isSpeedupUsed(String id) async {
    try {
      final it = await getById(id);
      final extras = (it?['extras'] as Map?)?.cast<String, dynamic>() ??
          const <String, dynamic>{};
      return extras[_kSpeedupUsed] == true;
    } catch (_) {
      return false;
    }
  }

  static Future<void> markSpeedupUsed(String id) async {
    try {
      final items = await _load();
      for (final it in items) {
        if ((it['id'] as String?) == id) {
          final extras = (it['extras'] as Map?)?.cast<String, dynamic>() ??
              <String, dynamic>{};
          extras[_kSpeedupUsed] = true;
          it['extras'] = extras;
          break;
        }
      }
      await _save(items);
    } catch (_) {}
  }

  static Future<void> updateReadyAt({
    required String id,
    required String type,
    required DateTime readyAt,
    String locale = 'tr',
  }) async {
    final items = await _load();
    for (final it in items) {
      if ((it['id'] as String?) == id) {
        it['readyAt'] = readyAt.toIso8601String();
        break;
      }
    }
    await _save(items);
    final seconds =
        readyAt.difference(DateTime.now()).inSeconds.clamp(1, 86400);
    try {
      await PendingI18n.ensure(locale);
    } catch (_) {}
    try {
      final notifId = id.hashCode & 0x7FFFFFFF;
      await NotificationsService.cancelOneShot(notifId);
      await NotificationsService.scheduleOneShot(
        id: notifId,
        title: 'Falla - ${PendingI18n.titleForType(type, locale)}',
        body: PendingI18n.bodyForType(type, locale),
        secondsFromNow: seconds,
      );
    } catch (_) {}
  }

  // Returns the earliest readyAt for a pending item of given type that is in the future.
  static Future<DateTime?> nextReadyAtForType(String type) async {
    try {
      final items = await _load();
      final now = DateTime.now();
      DateTime? best;
      for (final it in items) {
        final t = it['type'] as String?;
        final raStr = it['readyAt'] as String?;
        if (t == type && raStr != null) {
          final ra = DateTime.tryParse(raStr);
          if (ra != null && ra.isAfter(now)) {
            if (best == null || ra.isBefore(best)) best = ra;
          }
        }
      }
      return best;
    } catch (_) {
      return null;
    }
  }

  // Returns earliest future pending item for a given type (with extras)
  static Future<Map<String, dynamic>?> firstPendingOfType(String type) async {
    try {
      final items = await _load();
      final now = DateTime.now();
      Map<String, dynamic>? bestItem;
      DateTime? bestAt;
      for (final it in items) {
        if ((it['type'] as String?) != type) continue;
        final ra = DateTime.tryParse((it['readyAt'] as String?) ?? '');
        if (ra == null || ra.isBefore(now)) continue;
        if (bestAt == null || ra.isBefore(bestAt)) {
          bestAt = ra;
          bestItem = it.cast<String, dynamic>();
        }
      }
      return bestItem;
    } catch (_) {
      return null;
    }
  }

  static Future<void> checkAndCompleteDue({
    required HistoryController history,
    required ProfileController profile,
    String locale = 'tr',
  }) async {
    // Ensure localized strings are loaded before producing any titles/bodies
    try {
      await PendingI18n.ensure(locale);
    } catch (_) {}
    final items = await _load();
    final now = DateTime.now();
    final remaining = <Map<String, dynamic>>[];
    for (final it in items) {
      try {
        final ready = DateTime.parse(it['readyAt'] as String);
        if (ready.isAfter(now)) {
          remaining.add(it);
          continue;
        }
        final type = (it['type'] as String?) ?? 'coffee';
        final extras = (it['extras'] as Map?)?.cast<String, dynamic>() ??
            <String, dynamic>{};
        final preparedText = (extras['preparedText'] ?? '').toString().trim();
        // Legacy safety: old pending items may not have a permit saved.
        if (preparedText.isEmpty &&
            (extras['permit'] ?? '').toString().trim().isEmpty) {
          try {
            extras['permit'] = await AiGenerationGuard.issuePermit();
          } catch (_) {}
        }
        // Always generate and save when due so result shows both on screen and in history
        String generated;
        if (preparedText.isNotEmpty) {
          generated = preparedText;
        } else {
          try {
            AiService.configure();
            generated = await AiService.generate(
                type: type,
                profile: profile.profile,
                extras: extras,
                locale: locale);
          } on AiGenerationGuardException catch (e) {
            // If the permit was already consumed, assume generation already happened elsewhere (e.g., Result page).
            if (e.reason == 'permit_already_consumed') {
              continue;
            }
            // Missing permit (shouldn't happen) -> keep pending item.
            remaining.add(it);
            continue;
          } catch (_) {
            generated = '';
          }
        }

        if (generated.trim().isEmpty ||
            generated.trim().startsWith('Uretim su anda yapilamiyor')) {
          try {
            generated = LocalAIGenerator.generate(
                type: type,
                profile: profile.profile,
                extras: extras,
                locale: locale);
          } catch (_) {
            generated =
                'Yorum şu an oluşturulamadı; biraz sonra tekrar deneyebilirsin.\n\nBu içerik eğlence amaçlıdır; kesinlik içermez.';
          }
        }

        if (type == 'coffee') {
          generated = AiService.postProcessCoffeeText(generated);
        }
        final entry = HistoryEntry(
          id: it['id'] as String,
          type: type,
          title: PendingI18n.titleForType(type, locale),
          text: generated,
          createdAt: now,
        );
        await history.upsert(entry);
        // telemetry
        await Analytics.log('pending_completed', {'type': type});
      } catch (_) {}
    }
    await _save(remaining);
  }
}
