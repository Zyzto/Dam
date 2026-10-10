import 'package:blood_pressure_app/features/export_import/model/export_preset.dart';
import 'package:blood_pressure_app/features/export_import/model/pdf_export_content.dart';
import 'package:blood_pressure_app/features/statistics/dashboard/dashboard_snapshot.dart';
import 'package:blood_pressure_app/model/blood_pressure/pressure_unit.dart';
import 'package:blood_pressure_app/model/combined_entry.dart';
import 'package:blood_pressure_app/model/storage/export_columns_store.dart';
import 'package:blood_pressure_app/model/weight_unit.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:blood_pressure_app/domain/domain.dart';
import 'package:intl/date_symbol_data_local.dart';

import '../../util.dart';
import 'record_formatter_test.dart';

void main() {
  setUpAll(() {
    loadTestTranslations();
    return initializeDateFormatting('en');
  });

  final columns = ExportColumnsManager().resolveColumns(
    ExportPreset.appPdf.columns,
  );

  PdfExportContent contentOf(
    List<CombinedEntry> entries, {
    PressureUnit unit = PressureUnit.mmHg,
    WeightUnit weightUnit = WeightUnit.kg,
  }) => PdfExportContent.from(
    entries: entries,
    dateFormatString: 'yyyy-MM-dd',
    locale: 'en',
    pressureUnit: unit,
    weightUnit: weightUnit,
    columns: columns,
  );

  test('builds table rows newest first without changing input order', () {
    final early = mockEntry(
      time: DateTime(2024, 1, 1, 8),
      sys: 120,
      dia: 80,
      pul: 70,
      note: 'morning',
    );
    final late = mockEntry(
      time: DateTime(2024, 1, 3, 20),
      sys: 130,
      dia: 85,
      pul: 72,
      note: 'evening',
    );
    final content = contentOf([early, late]);

    expect(content.rows, hasLength(2));
    expect(content.rows.first[1], '130');
    expect(content.rows.last[1], '120');
    expect(content.rows.first[4], 'evening');
    expect(content.rows.last[4], 'morning');
    expect(content.chartPoints.map((point) => point.time), [
      DateTime(2024, 1, 1, 8),
      DateTime(2024, 1, 3, 20),
    ]);
    expect(content.chartPoints.first.systolic, 120);
    expect(content.chartPoints.last.systolic, 130);
    expect(content.statistics.count, 2);
  });

  test("keeps each exported row's calendar day for table striping", () {
    final firstMorning = mockEntry(time: DateTime(2024, 1, 1, 8));
    final firstEvening = mockEntry(time: DateTime(2024, 1, 1, 20));
    final nextDay = mockEntry(time: DateTime(2024, 1, 2, 8));

    final content = contentOf([firstMorning, firstEvening, nextDay]);

    expect(content.rowDays, [
      DateTime(2024, 1, 2),
      DateTime(2024, 1, 1),
      DateTime(2024, 1, 1),
    ]);
  });

  test('sorts arbitrary input before selecting the latest reading', () {
    final newer = mockEntry(
      time: DateTime(2024, 3, 3, 18),
      sys: 140,
      dia: 90,
      pul: 80,
    );
    final older = mockEntry(
      time: DateTime(2024, 3, 1, 8),
      sys: 100,
      dia: 60,
      pul: 60,
    );
    final input = [newer, older];
    final content = contentOf(input);

    expect(input, [newer, older]);
    expect(content.rows.first[1], '140');
    expect(content.rows.last[1], '100');
    expect(content.statistics.latest!.sys, '140');
    expect(content.title, contains('2024-03-01'));
    expect(content.title, contains('2024-03-03'));
  });

  test('shows fractional daily averages instead of rounding down to zero', () {
    final entries = [
      for (var i = 0; i < 8; i++)
        mockEntry(time: DateTime(2024, 1, 1 + i * 4), sys: 120, dia: 80),
    ];
    final content = contentOf(entries);

    expect(content.statistics.measurementsPerDay, closeTo(8 / 28, .0001));
    expect(content.statistics.activityLine, '8 readings · 0.3 per day');
  });

  test('formats pressures in the preferred unit', () {
    final entry = mockEntry(
      time: DateTime(2024, 2, 1),
      sys: 120,
      dia: 80,
      pul: 70,
    );
    final mmHg = contentOf([entry]);
    final kPa = contentOf([entry], unit: PressureUnit.kPa);

    expect(mmHg.rows.single[1], '120');
    expect(mmHg.rows.single[2], '80');
    expect(mmHg.statistics.table[1][1], '120');
    expect(kPa.rows.single[1], isNot('120'));
    expect(
      kPa.rows.single[1],
      formatDashboardPressure(entry.sys, PressureUnit.kPa),
    );
    expect(kPa.statistics.table[1][1], kPa.rows.single[1]);
  });

  test('uses dashboard avg min max and latest reading', () {
    final older = mockEntry(
      time: DateTime(2024, 3, 1, 8),
      sys: 100,
      dia: 60,
      pul: 60,
    );
    final newer = mockEntry(
      time: DateTime(2024, 3, 3, 18),
      sys: 140,
      dia: 90,
      pul: 80,
    );
    final content = contentOf([older, newer]);

    expect(content.statistics.table[1], ['Average', '120', '75', '70']);
    expect(content.statistics.table[2], ['Maximum', '140', '90', '80']);
    expect(content.statistics.table[3], ['Minimum', '100', '60', '60']);
    expect(content.statistics.latest, isNotNull);
    expect(content.statistics.latest!.sys, '140');
    expect(content.statistics.latest!.dia, '90');
    expect(content.statistics.latest!.pul, '80');
    expect(content.statistics.latest!.time, '2024-03-03');
    expect(content.statistics.measurementsPerDay, 1);
  });

  test('renders missing pressure weight and intakes as a dash', () {
    final time = DateTime(2024, 4, 1);
    final entry = CombinedEntry(
      time: time,
      record: BloodPressureRecord(time: time),
      note: Note(time: time),
    );
    final content = contentOf([entry]);

    expect(content.rows.single[1], pdfMissingValue);
    expect(content.rows.single[2], pdfMissingValue);
    expect(content.rows.single[3], pdfMissingValue);
    expect(content.rows.single[4], pdfMissingValue);
    expect(content.rows.single[5], pdfMissingValue);
    expect(content.rows.single[6], pdfMissingValue);
    expect(content.rows.single, isNot(contains('null')));
  });

  test('includes notes weight and intakes in the PDF preset', () {
    final time = DateTime(2024, 5, 1, 9);
    final entry = CombinedEntry(
      time: time,
      record: BloodPressureRecord(
        time: time,
        sys: Pressure.mmHg(118),
        dia: Pressure.mmHg(76),
        pul: 64,
      ),
      note: Note(time: time, note: 'after walk'),
      weight: BodyweightRecord(time: time, weight: Weight.kg(70.5)),
      intake: MedicineIntake(
        time: time,
        medicine: const Medicine(designation: 'Lisinopril'),
        dosis: Weight.mg(10),
      ),
    );
    final content = contentOf([entry]);

    expect(content.headers, hasLength(7));
    expect(content.rows.single[4], 'after walk');
    expect(content.rows.single[5], contains('70.5'));
    expect(content.rows.single[6], contains('Lisinopril'));
    expect(content.rows.single[6], contains('10'));
    expect(content.weightSeries, isNotNull);
    expect(content.weightSeries!.latest, contains('70.5'));
    expect(content.medicineSeries, hasLength(1));
    expect(content.medicineSeries.single.name, 'Lisinopril');
    expect(content.medicineSeries.single.doses, hasLength(1));
    expect(content.medicineSeries.single.latestLabel, contains('10'));
  });

  test('highest and lowest follow the extreme systolic reading', () {
    final low = mockEntry(
      time: DateTime(2024, 6, 1, 8),
      sys: 110,
      dia: 70,
      pul: 60,
    );
    final high = mockEntry(
      time: DateTime(2024, 6, 2, 8),
      sys: 148,
      dia: 92,
      pul: 80,
    );
    final content = contentOf([low, high]);

    expect(content.statistics.highest!.sys, '148');
    expect(content.statistics.highest!.dia, '92');
    expect(content.statistics.highest!.time, contains('2024-06-02'));
    expect(content.statistics.lowest!.sys, '110');
    expect(content.statistics.lowest!.dia, '70');
    expect(content.statistics.latest!.sysBand, 'High');
    expect(content.statistics.latest!.diaBand, 'High');
    expect(
      contentOf([low]).statistics.latest!.sysBand,
      'Normal',
    );
  });

  test('charts weight in the preferred unit and keeps doses once', () {
    final dose = MedicineIntake(
      time: DateTime(2024, 7, 1, 8),
      medicine: const Medicine(designation: 'Amlodipine'),
      dosis: Weight.mg(5),
    );
    final later = MedicineIntake(
      time: DateTime(2024, 7, 2, 8),
      medicine: const Medicine(designation: 'Amlodipine'),
      dosis: Weight.mg(5),
    );
    final morning = CombinedEntry(
      time: DateTime(2024, 7, 1, 8),
      record: BloodPressureRecord(
        time: DateTime(2024, 7, 1, 8),
        sys: Pressure.mmHg(120),
        dia: Pressure.mmHg(80),
      ),
      intake: dose,
      weight: BodyweightRecord(
        time: DateTime(2024, 7, 1, 8),
        weight: Weight.kg(70),
      ),
    );
    final evening = CombinedEntry(
      time: DateTime(2024, 7, 1, 20),
      record: BloodPressureRecord(
        time: DateTime(2024, 7, 1, 20),
        sys: Pressure.mmHg(128),
        dia: Pressure.mmHg(82),
      ),
      dayIntakes: [dose],
      weight: BodyweightRecord(
        time: DateTime(2024, 7, 1, 20),
        weight: Weight.kg(71),
      ),
    );
    final nextDay = CombinedEntry(
      time: DateTime(2024, 7, 2, 8),
      intake: later,
    );
    final content = contentOf(
      [morning, evening, nextDay],
      weightUnit: WeightUnit.lbs,
    );

    expect(content.weightSeries!.points, hasLength(2));
    expect(
      content.weightSeries!.points.first.value,
      closeTo(WeightUnit.lbs.extract(Weight.kg(70)), 0.001),
    );
    expect(content.weightSeries!.points.first.time.isBefore(
      content.weightSeries!.points.last.time,
    ), isTrue);
    expect(content.medicineSeries, hasLength(1));
    expect(content.medicineSeries.single.doses, hasLength(2));
    expect(content.medicineSeries.single.doses.first.time, dose.time);
    expect(content.medicineSeries.single.doses.last.amount, 5);
  });
}
