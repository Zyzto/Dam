import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('medicine reminder notifications are translated in every locale', () {
    final english = _load('en.json');

    for (final file
        in Directory('assets/translations').listSync().whereType<File>().where(
          (file) => file.path.endsWith('.json'),
        )) {
      final locale =
          jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
      expect(locale['reminderDoseMovedFrom'], contains('{time}'));
      if (file.path.endsWith('/en.json')) continue;
      for (final key in _notificationKeys) {
        expect(locale[key], isA<String>());
        expect(
          locale[key],
          isNot(english[key]),
          reason: '${file.uri.pathSegments.last} $key',
        );
      }
    }
  });
}

const _notificationKeys = [
  'reminderNotificationTitle',
  'reminderNotificationChannelName',
  'reminderNotificationChannelDescription',
  'reminderTimingBeforeFood',
  'reminderTimingWithFood',
  'reminderTimingAfterFood',
  'reminderTimingOnWaking',
  'reminderTimingBeforeSleep',
  'reminderNotificationsDisabled',
];

Map<String, dynamic> _load(String name) =>
    jsonDecode(File('assets/translations/$name').readAsStringSync())
        as Map<String, dynamic>;
