import 'package:flutter/widgets.dart';

import 'strings_de.dart';
import 'strings_en.dart';
import 'strings_es.dart';
import 'strings_fr.dart';
import 'strings_pl.dart';
import 'strings_uk.dart';

enum AppLanguage { english, ukrainian, polish, german, spanish, french }

extension AppLanguageLabel on AppLanguage {
  Locale get locale => switch (this) {
    AppLanguage.english => const Locale('en'),
    AppLanguage.ukrainian => const Locale('uk'),
    AppLanguage.polish => const Locale('pl'),
    AppLanguage.german => const Locale('de'),
    AppLanguage.spanish => const Locale('es'),
    AppLanguage.french => const Locale('fr'),
  };

  String get label => switch (this) {
    AppLanguage.english => 'English',
    AppLanguage.ukrainian => 'Українська',
    AppLanguage.polish => 'Polski',
    AppLanguage.german => 'Deutsch',
    AppLanguage.spanish => 'Español',
    AppLanguage.french => 'Français',
  };

  String get flag => switch (this) {
    AppLanguage.english => '🇬🇧',
    AppLanguage.ukrainian => '🇺🇦',
    AppLanguage.polish => '🇵🇱',
    AppLanguage.german => '🇩🇪',
    AppLanguage.spanish => '🇪🇸',
    AppLanguage.french => '🇫🇷',
  };
}

class AppStrings {
  const AppStrings(this.language);

  final AppLanguage language;

  static final Set<String> keys = stringsUk.keys.toSet();

  static const _values = <AppLanguage, Map<String, String>>{
    AppLanguage.ukrainian: stringsUk,
    AppLanguage.english: stringsEn,
    AppLanguage.polish: stringsPl,
    AppLanguage.german: stringsDe,
    AppLanguage.spanish: stringsEs,
    AppLanguage.french: stringsFr,
  };

  String call(String key) => _values[language]![key]!;

  String get homeNav => call('navHome');
  String get listsNav => call('navLists');
  String get scheduleNav => call('navSchedule');
  String get answerNav => call('navAnswer');
  String get moreNav => call('navMore');
  String get homeTitle => call('homeTitle');
  String get homeSubtitle => call('homeSubtitle');
  String get quickRules => call('quickRules');
  String get quickSubtitle => call('quickSubtitle');
  String get listsScreenTitle => call('listsTitle');
  String get scheduleTitle => call('scheduleTitle');
  String get answerTitle => call('answerTitle');
  String get moreTitle => call('moreTitle');
  String get whiteListTab => call('whiteTab');
  String get blackListTab => call('blackTab');
  String get countryOperatorsTab => call('countryOperatorsTab');
}
