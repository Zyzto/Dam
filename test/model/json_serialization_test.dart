import 'package:blood_pressure_app/features/export_import/model/column.dart';
import 'package:blood_pressure_app/model/storage/storage.dart';
import 'package:blood_pressure_app/model/storage/types/export_format_setting.dart';
import 'package:blood_pressure_app/model/storage/types/interval_storage_setting.dart';
import 'package:blood_pressure_app/model/storage/types/time_step.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:blood_pressure_app/domain/domain.dart';

void main() {
  group('IntervallStorage', () {
    test('should create json without error', () {
      final intervall = IntervalStorage(stepSize: TimeStep.year);
      final json = intervall.toJson();
      expect(json.length, greaterThan(0));
    });

    test('should load same data from json', () {
      final initialData = IntervalStorage();
      final json = initialData.toJson();
      final recreatedData = IntervalStorage.fromJson(json);

      expect(initialData.stepSize, recreatedData.stepSize);
      expect(initialData.currentRange.start.day,
          recreatedData.currentRange.start.day);
      expect(initialData.currentRange.end.day,
          recreatedData.currentRange.end.day);
    });

    test('should load same data from json in edge cases', () {
      final initialData = IntervalStorage(stepSize: TimeStep.custom, customRange: DateRange(
          start: DateTime.fromMillisecondsSinceEpoch(1234),
          end: DateTime.fromMillisecondsSinceEpoch(5678),
      ),);
      final json = initialData.toJson();
      final recreatedData = IntervalStorage.fromJson(json);

      expect(initialData.stepSize, TimeStep.custom);
      expect(recreatedData.currentRange.start.millisecondsSinceEpoch, 1234);
      expect(recreatedData.currentRange.end.millisecondsSinceEpoch, 5678);
    });

    test('should not crash when parsing incorrect json', () {
      IntervalStorage.fromJson('banana');
      IntervalStorage.fromJson('{"stepSize" = 1}');
      IntervalStorage.fromJson('{"stepSize": 1');
      IntervalStorage.fromJson('{stepSize: 1}');
      IntervalStorage.fromJson('green{stepSize: 1}');
    });

    test('should not crash when parsing invalid values and ignore them', () {
      final v1 = IntervalStorage.fromJson('{"stepSize": true}');
      final v2 = IntervalStorage.fromJson('{"stepSize": "month"}');
      final v3 = IntervalStorage.fromJson('{"start": "month", "end": 10.5}');
      final v4 = IntervalStorage.fromJson('{"start": 18.6, "end": 90.65}');

      expect(v1.stepSize, TimeStep.last7Days);
      expect(v2.stepSize, TimeStep.last7Days);
      expect(v3.stepSize, TimeStep.last7Days);

      // in minutes to avoid failing through performance
      expect(v2.currentRange.duration.inMinutes, v1.currentRange.duration.inMinutes);
      expect(v3.currentRange.duration.inMinutes, v1.currentRange.duration.inMinutes);
      expect(v4.currentRange.duration.inMinutes, v1.currentRange.duration.inMinutes);
    });
  });

  group('ExportSettings', (){
    test('should be able to recreate all values from json', () {
      final initial = ExportSettings(
        exportFormat: ExportFormat.db,
        defaultExportDir: 'lorem ipsum',
        exportAfterEveryEntry: true,
      );
      final fromJson = ExportSettings.fromJson(initial.toJson());

      expect(initial.exportFormat, fromJson.exportFormat);
      expect(initial.defaultExportDir, fromJson.defaultExportDir);
      expect(initial.exportAfterEveryEntry, fromJson.exportAfterEveryEntry);

      expect(initial.toJson(), fromJson.toJson());
    });

    test('should not crash when parsing incorrect json', () {
      ExportSettings.fromJson('banana');
      ExportSettings.fromJson('{"defaultExportDir" = 1}');
      ExportSettings.fromJson('{"defaultExportDir": 1');
      ExportSettings.fromJson('{defaultExportDir: 1}');
      ExportSettings.fromJson('green{exportFormat: 1}');
    });

    test('should not crash when parsing invalid values and ignore them', () {
      final v1 = ExportSettings.fromJson('{"defaultExportDir": ["test"]}');
      final v2 = ExportSettings.fromJson('{"exportFormat": "red"}');
      final v3 = ExportSettings.fromJson('{"exportFormat": "month", "exportAfterEveryEntry": 15}');

      expect(v1.defaultExportDir, ExportSettings().defaultExportDir);
      expect(v2.exportFormat, ExportSettings().exportFormat);
      expect(v3.exportFormat, ExportSettings().exportFormat);
      expect(v3.exportAfterEveryEntry, ExportSettings().exportAfterEveryEntry);
    });
  });

  group('CsvExportSettings', (){
    test('should be able to recreate all values from json', () {
      final initial = CsvExportSettings(
        fieldDelimiter: 'asdfghjklö',
        textDelimiter: 'asdfghjklö2',
        exportHeadline: false,
        activePreset: 'test preset 1',
      );
      final fromJson = CsvExportSettings.fromJson(initial.toJson());

      expect(initial.fieldDelimiter, fromJson.fieldDelimiter);
      expect(initial.textDelimiter, fromJson.textDelimiter);
      expect(initial.exportHeadline, fromJson.exportHeadline);
      expect(initial.activePreset, fromJson.activePreset);

      expect(initial.toJson(), fromJson.toJson());
    });

    test('should not crash when parsing incorrect json', () {
      CsvExportSettings.fromJson('banana');
      CsvExportSettings.fromJson('{"fieldDelimiter" = 1}');
      CsvExportSettings.fromJson('{"fieldDelimiter": 1');
      CsvExportSettings.fromJson('{fieldDelimiter: 1}');
      CsvExportSettings.fromJson('green{fieldDelimiter: 1}');
    });

    test('should not crash when parsing invalid values and ignore them', () {
      final v1 = CsvExportSettings.fromJson('{"fieldDelimiter": ["test"]}');
      final v2 = CsvExportSettings.fromJson('{"exportHeadline": "red"}');
      final v3 = CsvExportSettings.fromJson('{"textDelimiter": "month", "textDelimiter": {"test": 10.5}}');

      expect(v1.fieldDelimiter, CsvExportSettings().fieldDelimiter);
      expect(v2.exportHeadline, CsvExportSettings().exportHeadline);
      expect(v3.textDelimiter, CsvExportSettings().textDelimiter);
      expect(v3.activePreset, CsvExportSettings().activePreset);
    });
  });

  group('PdfExportSettings', (){
    test('should be able to recreate all values from json', () {
      final initial = PdfExportSettings(
        exportTitle: false,
        exportStatistics: false,
        exportData: false,
        separateWeightMedicineTables: false,
        headerHeight: 67.89,
        cellHeight: 67.89,
        headerFontSize: 67.89,
        cellFontSize: 67.89,
      );
      final fromJson = PdfExportSettings.fromJson(initial.toJson());

      expect(initial.exportTitle, fromJson.exportTitle);
      expect(initial.exportStatistics, fromJson.exportStatistics);
      expect(initial.exportData, fromJson.exportData);
      expect(
        initial.separateWeightMedicineTables,
        fromJson.separateWeightMedicineTables,
      );
      expect(initial.headerHeight, fromJson.headerHeight);
      expect(initial.cellHeight, fromJson.cellHeight);
      expect(initial.headerFontSize, fromJson.headerFontSize);
      expect(initial.cellFontSize, fromJson.cellFontSize);

      expect(initial.toJson(), fromJson.toJson());
    });

    test('should not crash when parsing incorrect json', () {
      PdfExportSettings.fromJson('banana');
      PdfExportSettings.fromJson('{"cellFontSize" = 1}');
      PdfExportSettings.fromJson('{"cellFontSize": 1');
      PdfExportSettings.fromJson('{cellFontSize: 1}');
      PdfExportSettings.fromJson('green{fieldDelimiter: 1}');
    });

    test('should not crash when parsing invalid values and ignore them', () {
      final v1 = PdfExportSettings.fromJson('{"cellFontSize": ["test"]}');
      final v2 = PdfExportSettings.fromJson('{"cellFontSize": "red"}');
      final v3 = PdfExportSettings.fromJson('{"headerFontSize": "month", "exportData": 15}');

      expect(v1.cellFontSize, PdfExportSettings().cellFontSize);
      expect(v2.cellFontSize, PdfExportSettings().cellFontSize);
      expect(v3.headerFontSize, PdfExportSettings().headerFontSize);
      expect(v3.exportData, PdfExportSettings().exportData);
    });
  });

  group('ExportColumnsManager', (){
    test('should be able to recreate all values from json', () {
      final initial = ExportColumnsManager();
      final c1 = UserColumn('test', 'test', '\$SYS');
      final c2 = TimeColumn('testB', 'mmm');
      initial.addOrUpdate(c1);
      initial.addOrUpdate(c2);
      final fromJson = ExportColumnsManager.fromJson(initial.toJson());

      expect(initial.toJson(), fromJson.toJson());
    });

    test('should not crash when parsing incorrect json', () {
      ExportColumnsManager.fromJson('banana');
      ExportColumnsManager.fromJson('{"userColumns" = 1}');
      ExportColumnsManager.fromJson('{"userColumns": 1');
      ExportColumnsManager.fromJson('{userColumns: 1}');
      ExportColumnsManager.fromJson('green{userColumns: 1}');
    });

    test('should not crash when parsing invalid values and ignore them', () {
      final v1 = ExportColumnsManager.fromJson('{"userColumns": [1]}');
      final v2 = ExportColumnsManager.fromJson('{"cellFontSize": "red"}');

      expect(v1.userColumns.length, ExportColumnsManager().userColumns.length);
      expect(v2.userColumns.length, ExportColumnsManager().userColumns.length);
    });
  });
}
