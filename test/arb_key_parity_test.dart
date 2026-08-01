import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('every translation ARB matches the English message contract', () {
    final english = _readArb('en');
    final expectedKeys = english.keys.where((key) => key != '@@locale').toSet();

    for (final locale in const ['es', 'fr', 'de', 'pt', 'ja', 'uk']) {
      final translated = _readArb(locale);
      expect(
        translated.keys.where((key) => key != '@@locale').toSet(),
        expectedKeys,
        reason: 'ARB key mismatch for $locale',
      );
      expect(translated['@@locale'], locale);

      for (final key in expectedKeys.where((key) => key.startsWith('@'))) {
        expect(
          _placeholders(translated[key]),
          _placeholders(english[key]),
          reason: 'Placeholder mismatch for $key in $locale',
        );
      }
    }
  });
}

Map<String, Object?> _readArb(String locale) {
  final file = File('lib/l10n/app_$locale.arb');
  return Map<String, Object?>.from(jsonDecode(file.readAsStringSync()) as Map);
}

Map<String, Object?> _placeholders(Object? metadata) {
  if (metadata is! Map || metadata['placeholders'] is! Map) {
    return const {};
  }
  return Map<String, Object?>.from(metadata['placeholders'] as Map);
}
