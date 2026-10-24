import 'package:flutter/material.dart';

import '../platform/web_bridge.dart' as bridge;

/// Current app language. English or Amharic, remembered in the browser.
class LocaleController extends ValueNotifier<Locale> {
  LocaleController._() : super(Locale(_initial()));
  static final LocaleController instance = LocaleController._();

  static String _initial() {
    final saved = bridge.readLocal('astudio.lang');
    return saved == 'am' ? 'am' : 'en';
  }

  bool get isAmharic => value.languageCode == 'am';

  void set(String code) {
    final next = code == 'am' ? 'am' : 'en';
    if (value.languageCode == next) return;
    value = Locale(next);
    bridge.writeLocal('astudio.lang', next);
  }

  void toggle() => set(isAmharic ? 'en' : 'am');
}

const List<Locale> kSupportedLocales = [Locale('en'), Locale('am')];

/// Inline translations: `context.tr('Book now', 'ቀጠሮ ይያዙ')`.
/// Reading the locale through Localizations makes every caller rebuild
/// when the language changes.
extension Tr on BuildContext {
  bool get isAm => Localizations.localeOf(this).languageCode == 'am';
  String tr(String en, String am) => isAm ? am : en;
}
