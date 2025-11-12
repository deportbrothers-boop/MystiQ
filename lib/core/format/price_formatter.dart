import 'package:intl/intl.dart';
import 'package:flutter/widgets.dart';

class PriceFormatter {
  static String format({required double amount, String? currency, Locale? locale}) {
    try {
      final loc = locale ?? const Locale('en');
      final nf = (currency != null && currency.length == 3)
          ? NumberFormat.simpleCurrency(name: currency, locale: _toLocaleTag(loc))
          : NumberFormat.simpleCurrency(locale: _toLocaleTag(loc));
      // If the NumberFormat picked a different currency by default and we passed an unknown 3-letter code,
      // fall back to generic decimal with symbol if available.
      final s = nf.format(amount);
      return s;
    } catch (_) {
      // Fallback generic formatting
      return amount.toStringAsFixed(2);
    }
  }

  // Best-effort currency decision for a given locale
  static String pickCurrencyForLocale(Locale loc, {Iterable<String>? supported}) {
    final cc = (loc.countryCode ?? '').toUpperCase();
    final lc = loc.languageCode.toLowerCase();
    String candidate;
    if (cc == 'TR' || lc == 'tr') {
      candidate = 'TRY';
    } else if (cc == 'US') {
      candidate = 'USD';
    } else if (cc == 'GB' || cc == 'UK') {
      candidate = 'GBP';
    } else if (cc == 'CA') {
      candidate = 'CAD';
    } else if (cc == 'CH') {
      candidate = 'CHF';
    } else if (cc == 'AE') {
      candidate = 'AED';
    } else if (cc == 'SA') {
      candidate = 'SAR';
    } else if ({'DE','FR','ES','IT','NL','IE','AT','PT','BE','GR','FI','LU','LT','LV','EE','SI','SK','CY','MT'}.contains(cc)) {
      candidate = 'EUR';
    } else if (lc == 'es') {
      candidate = 'EUR';
    } else if (lc == 'ar') {
      candidate = 'USD';
    } else {
      candidate = 'USD';
    }
    if (supported != null && supported.isNotEmpty) {
      // Prefer TRY if available for Turkish users
      if ((cc == 'TR' || lc == 'tr') && supported.contains('TRY')) return 'TRY';
      if (!supported.contains(candidate)) {
        return supported.first;
      }
    }
    return candidate;
  }

  static String _toLocaleTag(Locale loc) {
    if (loc.countryCode == null || loc.countryCode!.isEmpty) return loc.languageCode;
    return '${loc.languageCode}_${loc.countryCode}';
  }
}
