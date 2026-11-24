import 'package:flutter_test/flutter_test.dart';

import 'package:call_guard/data/world_countries.dart';
import 'package:call_guard/l10n/app_strings.dart';

void main() {
  test('catalog contains the 195 sovereign E.164 countries', () {
    expect(worldCountries, hasLength(195));
    expect(
      worldCountries.map((country) => country.isoCode).toSet(),
      hasLength(195),
    );
    expect(
      worldCountries.map((country) => country.isoCode),
      everyElement(matches(RegExp(r'^[A-Z]{2}$'))),
    );
  });

  test('every country has a complete six-language name and code', () {
    for (final country in worldCountries) {
      expect(
        country.dialCode,
        matches(RegExp(r'^\+\d+$')),
        reason: '${country.isoCode} has an invalid calling code',
      );
      expect(country.localizedNames.keys.toSet(), {
        'uk',
        'en',
        'pl',
        'de',
        'es',
        'fr',
      }, reason: '${country.isoCode} is missing a localization');
      for (final name in country.localizedNames.values) {
        expect(name.trim(), isNotEmpty);
      }
      expect(country.flag, hasLength(4));
    }
  });

  test('search matches names in every language and calling codes', () {
    WorldCountry byIso(String iso) =>
        worldCountries.singleWhere((country) => country.isoCode == iso);

    final ukraine = byIso('UA');
    for (final query in ['Україна', 'Ukraine', 'Ukraina', 'Ucrania']) {
      expect(ukraine.matches(query), isTrue, reason: query);
    }
    expect(ukraine.matches('+380'), isTrue);
    expect(ukraine.matches('380'), isTrue);
    expect(ukraine.matches('UA'), isTrue);

    expect(byIso('CZ').matches('+420'), isTrue);
    expect(byIso('CZ').matches('420'), isTrue);
    expect(byIso('TR').matches('+90'), isTrue);

    final italy = byIso('IT');
    expect(italy.matches('+39'), isTrue);
    expect(italy.matches('39'), isTrue);
    expect(byIso('VA').matches('+39'), isTrue);

    final matches39 = worldCountries.where((country) => country.matches('39'));
    expect(
      matches39.map((country) => country.isoCode),
      containsAll(<String>['IT', 'VA']),
    );
  });

  test('shared +1, +7 and +39 rows expose discriminating area codes', () {
    WorldCountry byIso(String iso) =>
        worldCountries.singleWhere((country) => country.isoCode == iso);

    expect(byIso('US').dialCode, '+1');
    expect(byIso('CA').dialCode, '+1');
    expect(byIso('US').areaCodes, contains('212'));
    expect(byIso('CA').areaCodes, contains('416'));
    expect(byIso('US').areaCodes, isNot(contains('416')));
    expect(byIso('CA').areaCodes, isNot(contains('212')));

    expect(byIso('KZ').areaCodes, isNotEmpty);
    expect(byIso('VA').areaCodes, contains('06698'));
  });

  test('names are available for every UI language', () {
    for (final language in AppLanguage.values) {
      final names = worldCountries.map((country) => country.nameFor(language));
      expect(names, everyElement(isNotEmpty));
      expect(names, everyElement(isNot('')));
    }
    final ukrainian = worldCountries
        .map((country) => country.nameFor(AppLanguage.ukrainian))
        .toList();
    expect(ukrainian, contains('Україна'));
    expect(
      worldCountries.map((country) => country.nameFor(AppLanguage.english)),
      contains('Czechia'),
    );
  });
}
