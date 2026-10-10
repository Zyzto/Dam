import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('all shipped locales translate PDF summary strings', () {
    final english = _load('en.json');
    final englishUnit = english['pdfExportUnit'];
    final englishLatest = english['pdfLatestReading'];

    for (final file
        in Directory('assets/translations').listSync().whereType<File>().where(
          (file) => file.path.endsWith('.json'),
        )) {
      final locale =
          jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
      for (final key in _pdfKeys) {
        expect(locale, containsPair(key, isNotNull));
      }
      expect(locale, containsPair('pdfExportUnit', isNotNull));
      expect(locale, containsPair('pdfLatestReading', isNotNull));
      expect(locale['pdfExportUnit'], contains('{unit}'));
      expect(locale['pdfMedicineOfDays'], contains('{total}'));
      expect(locale['pdfWeightSince'], contains('{date}'));
      expect(locale['pdfWeightFrom'], contains('{value}'));
      expect(
        locale['pdfLatestReading'],
        allOf(
          contains('{sys}'),
          contains('{dia}'),
          contains('{pul}'),
          contains('{time}'),
        ),
      );

      if (file.path.endsWith('/en.json')) continue;
      expect(locale['pdfExportUnit'], isNot(englishUnit));
      expect(locale['pdfLatestReading'], isNot(englishLatest));
    }
  });
}

const _pdfKeys = [
  'pdfDocumentTitle',
  'dashboardActivityCount',
  'dashboardActivityLine',
  'pressureUnitMmHg',
  'pressureUnitKPa',
  'sysLong',
  'diaLong',
  'pulLong',
  'average',
  'maximum',
  'minimum',
  'notes',
  'weight',
  'intakes',
  'time',
  'pdfExportUnit',
  'pdfLatestReading',
  'pdfMedicineOfDays',
  'pdfWeightSince',
  'pdfWeightFrom',
  'dashboardAverages',
  'errNoData',
];

Map<String, dynamic> _load(String name) =>
    jsonDecode(File('assets/translations/$name').readAsStringSync())
        as Map<String, dynamic>;
