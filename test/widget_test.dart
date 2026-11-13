import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:call_guard/main.dart';
import 'package:call_guard/l10n/app_strings.dart';

void main() {
  testWidgets('renders the Call Guard protection prototype', (tester) async {
    await tester.pumpWidget(const CallGuardApp());

    expect(find.text('Захист викликів'), findsOneWidget);
    expect(find.text('Захист активний'), findsOneWidget);
    expect(find.text('Швидкі правила'), findsOneWidget);
    expect(find.byType(ShieldPhoneLogo), findsNWidgets(2));
  });

  test('every supported language has a complete UI dictionary', () {
    for (final language in AppLanguage.values) {
      final strings = AppStrings(language);
      for (final key in AppStrings.keys) {
        expect(
          strings.call(key),
          isNotEmpty,
          reason: '${language.label}: $key',
        );
      }
    }
  });

  testWidgets('lets the user switch to the dark UI theme', (tester) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(const CallGuardApp());
    expect(
      tester.widget<MaterialApp>(find.byType(MaterialApp)).themeMode,
      ThemeMode.system,
    );

    await tester.tap(find.byTooltip('Профіль, мова та тема'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Темна'));
    await tester.pumpAndSettle();

    expect(
      tester.widget<MaterialApp>(find.byType(MaterialApp)).themeMode,
      ThemeMode.dark,
    );
    expect(
      Theme.of(tester.element(find.text('Тема оформлення'))).brightness,
      Brightness.dark,
    );
  });

  testWidgets('changes the app language and shows country operators', (
    tester,
  ) async {
    await tester.pumpWidget(const CallGuardApp());
    await tester.tap(find.byTooltip('Профіль, мова та тема'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('🇬🇧  English'));
    await tester.pumpAndSettle();
    tester.state<NavigatorState>(find.byType(Navigator).first).pop();
    await tester.pumpAndSettle();

    expect(find.text('Call protection'), findsOneWidget);
    expect(find.text('Protection is active'), findsOneWidget);
    expect(find.text('Home'), findsOneWidget);

    await tester.tap(find.byTooltip('Lists & filters'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Countries & operators'));
    await tester.pumpAndSettle();
    expect(find.text('Ukraine'), findsOneWidget);
  });

  testWidgets('expands countries to reveal their mobile operators', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(const CallGuardApp());
    await tester.tap(find.byTooltip('Списки та фільтри'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Країни та оператори'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Україна'));
    await tester.pumpAndSettle();

    expect(find.text('Київстар'), findsOneWidget);
    expect(find.text('Vodafone UA'), findsOneWidget);
    expect(find.text('+380 67'), findsOneWidget);
  });

  testWidgets('country FAB offers country and operator additions', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(const CallGuardApp());
    await tester.tap(find.byTooltip('Списки та фільтри'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Країни та оператори'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Додати країну або оператора'));
    await tester.pumpAndSettle();

    expect(find.text('Додати країну'), findsOneWidget);
    expect(find.text('Додати оператора'), findsOneWidget);
    await tester.tap(find.text('Додати оператора'));
    await tester.pumpAndSettle();
    expect(find.text('Мережеві префікси (NDC)'), findsOneWidget);
  });
}
