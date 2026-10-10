import 'package:blood_pressure_app/domain/domain.dart';
import 'package:blood_pressure_app/features/export_import/model/column.dart';
import 'package:blood_pressure_app/features/export_import/model/import_field_type.dart';
import 'package:blood_pressure_app/features/export_import/model/pdf_export_chart_point.dart';
import 'package:blood_pressure_app/features/statistics/dashboard/dashboard_snapshot.dart';
import 'package:blood_pressure_app/l10n/western_digits.dart';
import 'package:blood_pressure_app/model/blood_pressure/pressure_unit.dart';
import 'package:blood_pressure_app/model/blood_pressure_analyzer.dart';
import 'package:blood_pressure_app/model/combined_entry.dart';
import 'package:blood_pressure_app/model/weight_unit.dart';
import 'package:easy_localization/easy_localization.dart';

export 'package:blood_pressure_app/features/export_import/model/pdf_export_chart_point.dart';

/// Placeholder used in PDF cells when a value is missing.
///
/// ASCII hyphen so the default PDF fonts can draw it.
const pdfMissingValue = '-';

/// Newest blood-pressure reading shown above the PDF table.
class PdfExportLatestReading {
  /// Create a formatted latest-reading line.
  const PdfExportLatestReading({
    required this.time,
    required this.sys,
    required this.dia,
    required this.pul,
    this.sysBand,
    this.diaBand,
  });

  /// Timestamp in the user's date format.
  final String time;

  /// Systolic in the preferred unit, or [pdfMissingValue].
  final String sys;

  /// Diastolic in the preferred unit, or [pdfMissingValue].
  final String dia;

  /// Pulse in bpm, or [pdfMissingValue].
  final String pul;

  /// Systolic range name, such as Normal, when a systolic value exists.
  final String? sysBand;

  /// Diastolic range name, when a diastolic value exists.
  final String? diaBand;
}

/// Summary statistics for the exported range.
class PdfExportStatistics {
  /// Create the stats block model.
  const PdfExportStatistics({
    required this.count,
    required this.measurementsPerDay,
    required this.unitLabel,
    required this.activityLine,
    required this.latest,
    required this.table,
    this.highest,
    this.lowest,
  });

  /// Blood-pressure records in the exported range.
  final int count;

  /// Average measurements per day, when the analyzer can compute it.
  final double? measurementsPerDay;

  /// Localized preferred pressure unit.
  final String unitLabel;

  /// Count / per-day sentence matching the dashboard.
  final String activityLine;

  /// Newest blood-pressure row, when one exists.
  final PdfExportLatestReading? latest;

  /// Reading with the highest systolic, when one exists.
  final PdfExportLatestReading? highest;

  /// Reading with the lowest systolic, when one exists.
  final PdfExportLatestReading? lowest;

  /// Header plus average / maximum / minimum rows.
  final List<List<String>> table;
}

/// Testable strings and table cells for a PDF export.
class PdfExportContent {
  /// Create content that the PDF converter can lay out.
  const PdfExportContent({
    required this.title,
    required this.statistics,
    required this.headers,
    required this.rows,
    this.chartPoints = const [],
    this.columnTypes = const [],
    this.rowDays = const [],
    this.weightSeries,
    this.medicineSeries = const [],
  });

  /// Build PDF strings from already-filtered [entries].
  factory PdfExportContent.from({
    required List<CombinedEntry> entries,
    required String dateFormatString,
    String? locale,
    required PressureUnit pressureUnit,
    required WeightUnit weightUnit,
    required List<ExportColumn> columns,
  }) {
    final newestFirst = List<CombinedEntry>.of(entries)
      ..sort((a, b) => b.time.compareTo(a.time));
    final snapshot = DashboardSnapshot.from(entriesNewestFirst: newestFirst);
    final analyzer = snapshot.period;
    final dateFormatter = WesternDateFormat(
      dateFormatString,
      locale ?? Intl.defaultLocale ?? 'en',
    );

    return PdfExportContent(
      title: _title(newestFirst, analyzer, dateFormatter),
      statistics: _statistics(
        snapshot,
        newestFirst,
        pressureUnit,
        dateFormatter,
      ),
      weightSeries: _weightSeries(newestFirst, weightUnit),
      medicineSeries: _medicineSeries(newestFirst),
      headers: columns.map((column) => column.userTitle()).toList(),
      columnTypes: columns.map((column) => column.restoreAbleType).toList(),
      chartPoints: [
        for (final entry in newestFirst.reversed)
          if (entry.sys != null || entry.dia != null)
            PdfExportChartPoint(
              time: entry.time,
              systolic: pressureInUnit(entry.sys, pressureUnit),
              diastolic: pressureInUnit(entry.dia, pressureUnit),
            ),
      ],
      rowDays: [
        for (final entry in newestFirst)
          DateTime(entry.time.year, entry.time.month, entry.time.day),
      ],
      rows: [
        for (final entry in newestFirst)
          [
            for (final column in columns)
              _cell(entry, column, pressureUnit, weightUnit),
          ],
      ],
    );
  }

  /// Date-range headline, or a no-data message.
  final String title;

  /// Stats shown above the table.
  final PdfExportStatistics statistics;

  /// Localized column titles.
  final List<String> headers;

  /// One row per exported entry, newest first.
  final List<List<String>> rows;

  /// Pressure trend points, oldest first for natural time-axis progression.
  final List<PdfExportChartPoint> chartPoints;

  /// Data type for each logical export column, used for script-aware layout.
  final List<RowDataFieldType?> columnTypes;

  /// Calendar day for each row, newest first, used to group the log by day.
  final List<DateTime> rowDays;

  /// Weight chart data, when the export contains a body weight.
  final PdfWeightSeries? weightSeries;

  /// One series per medicine, name order.
  final List<PdfMedicineSeries> medicineSeries;
}

String _title(
  List<CombinedEntry> entries,
  BloodPressureAnalyzer analyzer,
  DateFormat dateFormatter,
) {
  final start =
      analyzer.firstDay ?? (entries.isEmpty ? null : entries.first.time);
  final end = analyzer.lastDay ?? (entries.isEmpty ? null : entries.last.time);
  if (start == null || end == null) return 'errNoData'.tr();
  return 'pdfDocumentTitle'.tr(
    namedArgs: {
      'start': dateFormatter.format(start),
      'end': dateFormatter.format(end),
    },
  );
}

PdfExportStatistics _statistics(
  DashboardSnapshot snapshot,
  List<CombinedEntry> newestFirst,
  PressureUnit pressureUnit,
  DateFormat dateFormatter,
) {
  final period = snapshot.period;
  final measurementsPerDay = _averageMeasurementsPerDay(period);
  final activityLine = measurementsPerDay == null
      ? 'dashboardActivityCount'.tr(
          namedArgs: {'count': snapshot.count.toString()},
        )
      : 'dashboardActivityLine'.tr(
          namedArgs: {
            'count': snapshot.count.toString(),
            'perDay': formatDashboardNumber(measurementsPerDay, digits: 1),
          },
        );
  final latestEntry = snapshot.latest;
  return PdfExportStatistics(
    count: snapshot.count,
    measurementsPerDay: measurementsPerDay,
    unitLabel: _pressureUnitLabel(pressureUnit),
    activityLine: activityLine,
    latest: latestEntry == null
        ? null
        : PdfExportLatestReading(
            time: dateFormatter.format(latestEntry.time),
            sys: _pdfPressure(latestEntry.sys, pressureUnit),
            dia: _pdfPressure(latestEntry.dia, pressureUnit),
            pul: _pdfNumber(latestEntry.pul?.toDouble()),
            sysBand: _systolicBand(latestEntry.sys),
            diaBand: _diastolicBand(latestEntry.dia),
          ),
    highest: _extremeReading(
      newestFirst,
      pressureUnit,
      dateFormatter,
      highest: true,
    ),
    lowest: _extremeReading(
      newestFirst,
      pressureUnit,
      dateFormatter,
      highest: false,
    ),
    table: [
      ['', 'sysLong'.tr(), 'diaLong'.tr(), 'pulLong'.tr()],
      [
        'average'.tr(),
        _pdfPressure(period.avgSys, pressureUnit),
        _pdfPressure(period.avgDia, pressureUnit),
        _pdfNumber(period.avgPul?.toDouble()),
      ],
      [
        'maximum'.tr(),
        _pdfPressure(period.maxSys, pressureUnit),
        _pdfPressure(period.maxDia, pressureUnit),
        _pdfNumber(period.maxPul?.toDouble()),
      ],
      [
        'minimum'.tr(),
        _pdfPressure(period.minSys, pressureUnit),
        _pdfPressure(period.minDia, pressureUnit),
        _pdfNumber(period.minPul?.toDouble()),
      ],
    ],
  );
}

PdfExportLatestReading? _extremeReading(
  List<CombinedEntry> newestFirst,
  PressureUnit pressureUnit,
  DateFormat dateFormatter, {
  required bool highest,
}) {
  CombinedEntry? match;
  for (final entry in newestFirst) {
    final sys = entry.sys;
    if (sys == null) continue;
    final current = match?.sys;
    if (current == null ||
        (highest ? sys.mmHg > current.mmHg : sys.mmHg < current.mmHg)) {
      match = entry;
    }
  }
  if (match == null) return null;
  return PdfExportLatestReading(
    time: dateFormatter.format(match.time),
    sys: _pdfPressure(match.sys, pressureUnit),
    dia: _pdfPressure(match.dia, pressureUnit),
    pul: _pdfNumber(match.pul?.toDouble()),
  );
}

String? _systolicBand(Pressure? pressure) {
  if (pressure == null) return null;
  final value = pressure.mmHg;
  if (value < 120) return 'metricRangeNormal'.tr();
  if (value < 130) return 'metricRangeElevated'.tr();
  return 'metricRangeHigh'.tr();
}

String? _diastolicBand(Pressure? pressure) {
  if (pressure == null) return null;
  return pressure.mmHg < 80
      ? 'metricRangeNormal'.tr()
      : 'metricRangeHigh'.tr();
}

PdfWeightSeries? _weightSeries(
  List<CombinedEntry> newestFirst,
  WeightUnit weightUnit,
) {
  final byTime = <DateTime, Weight>{};
  for (final entry in newestFirst) {
    final weight = entry.weight?.weight;
    if (weight == null) continue;
    byTime[entry.time] = weight;
  }
  if (byTime.isEmpty) return null;
  final times = byTime.keys.toList()..sort();
  final points = [
    for (final time in times)
      PdfWeightPoint(time: time, value: weightUnit.extract(byTime[time]!)),
  ];
  final mean = points.map((point) => point.value).reduce((a, b) => a + b) /
      points.length;
  return PdfWeightSeries(
    points: points,
    latest: weightUnit.format(byTime[times.last]!),
    average: weightUnit.format(weightUnit.store(mean)),
  );
}

List<PdfMedicineSeries> _medicineSeries(List<CombinedEntry> entries) {
  final seen = <String>{};
  final grouped = <String, List<PdfMedicineDose>>{};
  final names = <String, String>{};
  final units = <String, String>{};
  final colors = <String, int?>{};
  for (final entry in entries) {
    for (final intake in entry.allIntakes) {
      final name = intake.medicine.designation.trim();
      if (name.isEmpty) continue;
      final unit = intake.medicine.unit.localizedSymbol;
      final amount = intake.dosis.mg;
      final identity =
          '${intake.time.millisecondsSinceEpoch}|$name|$amount|$unit';
      if (!seen.add(identity)) continue;
      final key = '$name|$unit';
      names[key] = name;
      units[key] = unit;
      colors.putIfAbsent(key, () => intake.medicine.color);
      grouped.putIfAbsent(key, () => []).add(
        PdfMedicineDose(time: intake.time, amount: amount),
      );
    }
  }
  final keys = grouped.keys.toList()..sort();
  return [
    for (final key in keys)
      _medicineSeriesOf(
        name: names[key]!,
        unitSymbol: units[key]!,
        color: colors[key],
        doses: grouped[key]!,
      ),
  ];
}

PdfMedicineSeries _medicineSeriesOf({
  required String name,
  required String unitSymbol,
  required int? color,
  required List<PdfMedicineDose> doses,
}) {
  doses.sort((a, b) => a.time.compareTo(b.time));
  final unit = MedicationUnit.values.firstWhere(
    (candidate) =>
        candidate.localizedSymbol == unitSymbol ||
        candidate.symbol == unitSymbol,
    orElse: () => MedicationUnit.mg,
  );
  return PdfMedicineSeries(
    name: name,
    unit: unitSymbol,
    color: color,
    latestLabel: formatMedicationDose(doses.last.amount, unit),
    doses: doses,
  );
}

double? _averageMeasurementsPerDay(BloodPressureAnalyzer analyzer) {
  if (analyzer.count <= 1) return null;
  final firstDay = analyzer.firstDay;
  final lastDay = analyzer.lastDay;
  if (firstDay == null || lastDay == null) return null;
  final elapsedDays = lastDay.difference(firstDay).inDays;
  if (elapsedDays <= 0) return analyzer.count.toDouble();
  return analyzer.count / elapsedDays;
}

String _cell(
  CombinedEntry entry,
  ExportColumn column,
  PressureUnit pressureUnit,
  WeightUnit weightUnit,
) {
  switch (column.restoreAbleType) {
    case RowDataFieldType.sys:
      return _pdfPressure(entry.sys, pressureUnit);
    case RowDataFieldType.dia:
      return _pdfPressure(entry.dia, pressureUnit);
    case RowDataFieldType.pul:
      return _pdfNumber(entry.pul?.toDouble());
    case RowDataFieldType.weightKg:
      final weight = entry.weight?.weight;
      return weight == null ? pdfMissingValue : weightUnit.format(weight);
    case RowDataFieldType.intakes:
      if (entry.intake == null) return pdfMissingValue;
      return column.encode(entry);
    case RowDataFieldType.timestamp:
    case RowDataFieldType.notes:
    case RowDataFieldType.color:
    case null:
      final encoded = column.encode(entry);
      if (encoded.isEmpty || encoded == 'null') return pdfMissingValue;
      return encoded;
  }
}

String _pdfPressure(Pressure? pressure, PressureUnit unit) {
  final text = formatDashboardPressure(pressure, unit);
  return text == '—' ? pdfMissingValue : text;
}

String _pdfNumber(double? value) {
  final text = formatDashboardNumber(value, digits: 0);
  return text == '—' ? pdfMissingValue : text;
}

String _pressureUnitLabel(PressureUnit unit) => switch (unit) {
  PressureUnit.mmHg => 'pressureUnitMmHg'.tr(),
  PressureUnit.kPa => 'pressureUnitKPa'.tr(),
};
