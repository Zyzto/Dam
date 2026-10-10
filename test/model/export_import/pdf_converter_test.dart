import 'dart:async';

import 'package:blood_pressure_app/features/export_import/model/pdf_converter.dart';
import 'package:blood_pressure_app/features/settings/app_settings.dart';
import 'package:blood_pressure_app/model/storage/storage.dart';
import 'package:flutter/widgets.dart' show Locale;
import 'package:flutter_test/flutter_test.dart';

import '../../util.dart';
import 'csv_converter_test.dart';
import 'record_formatter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    await createTestSettings();
  });

  test('creates an Arabic PDF with a chart and translated summary', () async {
    loadTestTranslations(const Locale('ar'));
    final converter = PdfConverter(
      PdfExportSettings(),
      AppSettings.fromController(testSettingsController!),
      ExportColumnsManager(),
      ExportSettings(),
      locale: 'ar',
    );
    final pdf = await converter.create([
      mockEntry(
        time: DateTime(2024, 1, 1, 8),
        sys: 120,
        dia: 80,
        pul: 70,
        note: 'قراءة الصباح',
      ),
      mockEntry(
        time: DateTime(2024, 1, 3, 20),
        sys: 135,
        dia: 85,
        pul: 74,
        note: 'قراءة المساء',
      ),
    ]);
    expect(pdf.take(5), orderedEquals('%PDF-'.codeUnits));
    expect(pdf.length, greaterThan(1000));
  });
  test('generated data length should be consistent', () async {
    final converter = PdfConverter(
      PdfExportSettings(),
      AppSettings.fromController(testSettingsController!),
      ExportColumnsManager(),
      ExportSettings(),
    );
    final pdf = await converter.create(createRecords());
    final converter2 = PdfConverter(
      PdfExportSettings(),
      AppSettings.fromController(testSettingsController!),
      ExportColumnsManager(),
      ExportSettings(),
    );
    final pdf2 = await converter2.create(createRecords());
    expect(pdf.length, pdf2.length);
  });

  test('separate weight and medicine tables are the default', () async {
    final pdfSettings = PdfExportSettings();
    expect(pdfSettings.separateWeightMedicineTables, isTrue);
    final converter = PdfConverter(
      pdfSettings,
      AppSettings.fromController(testSettingsController!),
      ExportColumnsManager(),
      ExportSettings(),
    );
    final split = await converter.create(createRecords());
    pdfSettings.separateWeightMedicineTables = false;
    final mixed = await converter.create(createRecords());
    expect(split.length, isNot(mixed.length));
  });

  test('generated data should change on settings change', () async {
    final pdfSettings = PdfExportSettings(
      exportData: true,
      exportStatistics: true,
      exportTitle: true,
    );

    final converter = PdfConverter(
      pdfSettings,
      AppSettings.fromController(testSettingsController!),
      ExportColumnsManager(),
      ExportSettings(),
    );
    final pdf1 = await converter.create(createRecords());

    pdfSettings.exportData = false;
    final pdf2 = await converter.create(createRecords());
    expect(pdf1.length, isNot(pdf2.length));
    expect(pdf1.length, greaterThan(pdf2.length));

    pdfSettings.exportStatistics = false;
    final pdf3 = await converter.create(createRecords());
    expect(pdf3.length, isNot(pdf2.length));
    expect(pdf3.length, isNot(pdf1.length));
    expect(pdf2.length, greaterThan(pdf3.length));

    pdfSettings.exportTitle = false;
    pdfSettings.exportData = true;
    final pdf4 = await converter.create(createRecords());
    expect(pdf4.length, isNot(pdf1.length));
    expect(pdf1.length, greaterThan(pdf4.length));
  });

  test('renders multilingual notes without missing-font diagnostics', () async {
    final converter = PdfConverter(
      PdfExportSettings(),
      AppSettings.fromController(testSettingsController!),
      ExportColumnsManager(),
      ExportSettings(),
    );
    final diagnostics = <String>[];

    final pdf = await runZoned(
      () => converter.create([mockEntry(note: 'العربية தமிழ் 中文')]),
      zoneSpecification: ZoneSpecification(
        print: (self, parent, zone, message) => diagnostics.add(message),
      ),
    );

    expect(pdf.take(5), orderedEquals('%PDF-'.codeUnits));
    expect(
      diagnostics,
      isNot(
        anyElement(
          anyOf(
            contains('has no Unicode support'),
            contains('Unable to find a font'),
          ),
        ),
      ),
    );
  });

  test('keeps Arabic medicine dose parentheses in logical order', () {
    final parts = splitPdfMedicineIntakeCell('دواء(10.0)');

    expect(parts?.medicine, 'دواء');
    expect(parts?.dose, '(10.0)');
  });
}
