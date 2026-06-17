import 'dart:convert';
import 'dart:io';

import 'package:cairn/l10n/app_localizations.dart';
import 'package:cairn/src/onboarding/setup_guide_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ARB parity', () {
    Set<String> messageKeys(String path) {
      final json = jsonDecode(File(path).readAsStringSync());
      final map = json as Map<String, dynamic>;
      // Drop @@locale and the @-prefixed metadata entries; keep real messages.
      return map.keys.where((k) => !k.startsWith('@')).toSet();
    }

    test('German defines exactly the same keys as the English template', () {
      final en = messageKeys('lib/l10n/app_en.arb');
      final de = messageKeys('lib/l10n/app_de.arb');
      expect(
        de,
        equals(en),
        reason:
            'German missing: ${en.difference(de)}; '
            'German extra: ${de.difference(en)}',
      );
    });
  });

  group('locale rendering', () {
    Widget app(Locale locale) => MaterialApp(
      locale: locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: const SetupGuidePage(),
    );

    testWidgets('renders English content under en', (tester) async {
      await tester.pumpWidget(app(const Locale('en')));
      await tester.pumpAndSettle();
      expect(find.text('Set up on Android'), findsOneWidget);
    });

    testWidgets('renders German content under de', (tester) async {
      await tester.pumpWidget(app(const Locale('de')));
      await tester.pumpAndSettle();
      expect(find.text('Einrichtung für Android'), findsOneWidget);
      // The setup-guide app-bar title is localised too.
      expect(find.text('So holst du deine Daten rein'), findsOneWidget);
    });
  });
}
