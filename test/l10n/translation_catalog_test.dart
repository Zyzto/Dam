import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('every locale JSON has the same keys as en.json', () {
    final dir = Directory('assets/translations');
    final en = jsonDecode(File('${dir.path}/en.json').readAsStringSync())
        as Map<String, dynamic>;
    final enKeys = en.keys.toSet();
    expect(enKeys.contains('addMeasurement'), isTrue);
    expect(enKeys.contains('searchSettings'), isTrue);
    expect(enKeys.contains('measurementSemantics'), isTrue);
    expect(enKeys.contains('onboardingSkip'), isTrue);
    expect(enKeys.contains('onboardingReplay'), isTrue);
    expect(enKeys.any((k) => k.startsWith('@')), isFalse);

    for (final file in dir.listSync().whereType<File>()) {
      if (!file.path.endsWith('.json')) continue;
      final map = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
      expect(
        map.keys.toSet(),
        enKeys,
        reason: file.uri.pathSegments.last,
      );
      expect(map.values.every((v) => v is String && v.isNotEmpty), isTrue);
    }
  });

  test('app name uses the local script outside Latin languages', () {
    const names = {
      'ar.json': 'الجنان',
      'bg.json': 'Джанан',
      'ru.json': 'Джанан',
      'uk.json': 'Джанан',
      'zh.json': '贾南',
      'zh-Hant.json': '賈南',
      'ta.json': 'ஜனான்',
    };
    for (final entry in names.entries) {
      final locale = _load(entry.key);
      expect(locale['title'], entry.value);
    }
    expect(_load('en.json')['title'], 'Janan');
    expect(_load('de.json')['title'], 'Janan');
  });
}

Map<String, dynamic> _load(String name) =>
    jsonDecode(File('assets/translations/$name').readAsStringSync())
        as Map<String, dynamic>;
