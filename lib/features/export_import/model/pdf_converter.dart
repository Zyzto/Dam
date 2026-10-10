import 'dart:math' as math;

import 'package:blood_pressure_app/domain/medication_unit.dart';
import 'package:blood_pressure_app/features/export_import/model/export_preset.dart';
import 'package:blood_pressure_app/features/export_import/model/import_field_type.dart';
import 'package:blood_pressure_app/features/export_import/model/pdf_export_content.dart';
import 'package:blood_pressure_app/features/settings/app_settings.dart';
import 'package:blood_pressure_app/l10n/western_digits.dart';
import 'package:blood_pressure_app/logging.dart';
import 'package:blood_pressure_app/model/blood_pressure/pressure_unit.dart';
import 'package:blood_pressure_app/model/combined_entry.dart';
import 'package:blood_pressure_app/model/storage/export_columns_store.dart';
import 'package:blood_pressure_app/model/storage/export_pdf_settings.dart';
import 'package:blood_pressure_app/model/storage/export_settings.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/services.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

/// Utility class for creating pdf files.
class PdfConverter with Loggable {
  /// Create pdf builder.
  PdfConverter(
    this.pdfSettings,
    this.settings,
    this.availableColumns,
    this.exportSettings, {
    String? locale,
  }) : locale = locale ?? Intl.defaultLocale ?? 'en';

  /// pdf specific settings.
  final PdfExportSettings pdfSettings;

  /// General customised design information that can be applied to the Pdf.
  final AppSettings settings;

  /// Columns manager used for ex- and import.
  final ExportColumnsManager availableColumns;

  final ExportSettings exportSettings;

  /// Locale used for dates and page direction.
  final String locale;

  /// Create a pdf from a record list.
  Future<Uint8List> create(List<CombinedEntry> entries) async {
    await initializeDateFormatting(locale);
    final pdf = pw.Document(creator: 'Janan');
    final content = _content(entries);
    final fonts = await _loadPdfFonts();
    final logo = _logoWithoutMargin(await rootBundle.loadString(_appLogoAsset));
    final theme = fonts.themeFor(locale);
    final isRtl = locale.split(RegExp('[-_]')).first == 'ar';
    final pageDirection = isRtl ? pw.TextDirection.rtl : pw.TextDirection.ltr;
    final cellAlignment = isRtl
        ? pw.Alignment.centerRight
        : pw.Alignment.centerLeft;
    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        theme: theme,
        textDirection: pageDirection,
        build: (pw.Context context) => [
          ..._letterIntro(content, pageDirection, fonts, logo),
          ..._letterTables(content, cellAlignment, pageDirection, fonts),
        ],
        maxPages: 100,
      ),
    );
    return pdf.save();
  }

  /// Strings and cells laid out by [create].
  PdfExportContent _content(List<CombinedEntry> entries) {
    final preset = exportSettings.getPresetById(pdfSettings.activePreset);
    if (preset == null) {
      logSevere('No such preset: ${pdfSettings.activePreset}');
    }
    final columns = availableColumns.resolveColumns(preset?.columns ?? []);
    return PdfExportContent.from(
      entries: entries,
      dateFormatString: settings.dateFormatString,
      locale: locale,
      pressureUnit: settings.preferredPressureUnit,
      weightUnit: settings.weightUnit,
      columns: columns,
    );
  }

  List<pw.Widget> _letterIntro(
    PdfExportContent content,
    pw.TextDirection pageDirection,
    _PdfFonts fonts,
    String logo,
  ) {
    final widgets = <pw.Widget>[];
    final statistics = content.statistics;
    if (pdfSettings.exportTitle) {
      widgets.add(_letterMasthead(pageDirection, statistics.unitLabel, logo));
      widgets.add(
        pw.Padding(
          padding: const pw.EdgeInsets.only(bottom: 3),
          child: pw.Text(
            content.title,
            style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
            textDirection: _textDirectionFor(content.title, pageDirection),
          ),
        ),
      );
    }
    if (!pdfSettings.exportStatistics) return widgets;

    widgets.add(
      pw.Padding(
        padding: const pw.EdgeInsets.only(bottom: 8),
        child: pw.Text(
          statistics.activityLine,
          style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700),
          textDirection: _textDirectionFor(
            statistics.activityLine,
            pageDirection,
          ),
        ),
      ),
    );
    if (!pdfSettings.exportTitle) {
      final unitLabel = pageDirection == pw.TextDirection.rtl
          ? _rtlUnitLabel(statistics.unitLabel)
          : statistics.unitLabel;
      final unitLine = 'pdfExportUnit'.tr(namedArgs: {'unit': unitLabel});
      widgets.add(
        pw.Padding(
          padding: const pw.EdgeInsets.only(bottom: 8),
          child: pw.Text(
            unitLine,
            style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700),
            textDirection: _textDirectionFor(unitLine, pageDirection),
          ),
        ),
      );
    }
    final latest = statistics.latest;
    if (latest != null) widgets.add(_letterLatest(latest, pageDirection));
    if (statistics.highest != null && statistics.lowest != null) {
      widgets.add(_letterTrio(statistics, pageDirection));
    }
    if (content.chartPoints.length > 1) {
      widgets.add(_buildPdfTrendChart(content, pageDirection, fonts));
    }
    final weight = content.weightSeries;
    final reportDays = _reportDays(content);
    final medicineBlocks = <pw.Widget>[];
    for (var i = 0; i < content.medicineSeries.length; i++) {
      final blocks = _letterMedicineBlocks(
        content.medicineSeries[i],
        reportDays,
        pageDirection,
        i,
        squaresPerRow: weight == null ? 36 : 24,
      );
      if (i == 0) {
        medicineBlocks.add(
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              _letterSectionLabel('intakes'.tr(), pageDirection),
              blocks.first,
            ],
          ),
        );
        medicineBlocks.addAll(blocks.skip(1));
      } else {
        medicineBlocks.addAll(blocks);
      }
    }
    if (weight != null && medicineBlocks.isNotEmpty) {
      for (var i = 0; i < medicineBlocks.length; i++) {
        widgets.add(
          _letterPair(
            i == 0 ? _letterWeight(weight, pageDirection) : pw.SizedBox(),
            medicineBlocks[i],
          ),
        );
      }
    } else if (weight != null) {
      widgets.add(_letterWeight(weight, pageDirection));
    } else {
      widgets.addAll(medicineBlocks);
    }
    return widgets;
  }

  pw.Widget _letterPair(pw.Widget weight, pw.Widget medicine) => pw.Padding(
    padding: const pw.EdgeInsets.only(bottom: 2),
    child: pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Expanded(flex: 3, child: medicine),
        pw.SizedBox(width: 16),
        pw.Expanded(flex: 2, child: weight),
      ],
    ),
  );

  pw.Widget _letterMasthead(
    pw.TextDirection pageDirection,
    String unitLabel,
    String logo,
  ) {
    final unit = pageDirection == pw.TextDirection.rtl
        ? _rtlUnitLabel(unitLabel)
        : unitLabel;
    final name = 'title'.tr();
    return pw.Container(
      margin: const pw.EdgeInsets.only(bottom: 8),
      padding: const pw.EdgeInsets.only(bottom: 3),
      decoration: pw.BoxDecoration(
        border: pw.Border(
          bottom: pw.BorderSide(
            color: settings.accentColor.toPdfColor(),
            width: 1.4,
          ),
        ),
      ),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.center,
        children: [
          pw.Expanded(
            child: pw.Align(
              alignment: pageDirection == pw.TextDirection.rtl
                  ? pw.Alignment.centerRight
                  : pw.Alignment.centerLeft,
              child: pw.Text(
                name,
                style: pw.TextStyle(
                  fontSize: 11,
                  fontWeight: pw.FontWeight.bold,
                ),
                textDirection: _textDirectionFor(name, pageDirection),
              ),
            ),
          ),
          pw.SvgImage(svg: logo, width: 18, height: 18),
          pw.Expanded(
            child: pw.Align(
              alignment: pageDirection == pw.TextDirection.rtl
                  ? pw.Alignment.centerLeft
                  : pw.Alignment.centerRight,
              child: pw.Text(
                unit,
                style: const pw.TextStyle(
                  fontSize: 9,
                  color: PdfColors.grey700,
                ),
                textDirection: _textDirectionFor(unit, pageDirection),
              ),
            ),
          ),
        ],
      ),
    );
  }

  pw.Widget _letterLatest(
    PdfExportLatestReading latest,
    pw.TextDirection pageDirection,
  ) {
    final reading = '${latest.sys} / ${latest.dia}';
    final pulse = '${'pulLong'.tr()} ${latest.pul}';
    return pw.Padding(
      padding: const pw.EdgeInsets.only(top: 2, bottom: 8),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.end,
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                '${'dashboardLatest'.tr()} · ${latest.time}',
                style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700),
                textDirection: pageDirection,
              ),
              pw.SizedBox(height: 1),
              pw.Text(
                reading,
                style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold),
                textDirection: pw.TextDirection.ltr,
              ),
              pw.Text(
                pulse,
                style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700),
                textDirection: _textDirectionFor(pulse, pageDirection),
              ),
            ],
          ),
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.end,
            children: [
              if (latest.sysBand != null)
                _letterBand(
                  '${'sysLong'.tr()} ${latest.sysBand}',
                  _bandColor(latest.sysBand!),
                  pageDirection,
                ),
              if (latest.diaBand != null) ...[
                pw.SizedBox(height: 3),
                _letterBand(
                  '${'diaLong'.tr()} ${latest.diaBand}',
                  _bandColor(latest.diaBand!),
                  pageDirection,
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  pw.Widget _letterBand(
    String label,
    PdfColor color,
    pw.TextDirection pageDirection,
  ) => pw.Container(
    padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 2),
    decoration: pw.BoxDecoration(
      color: PdfColors.grey100,
      borderRadius: pw.BorderRadius.circular(8),
    ),
    child: pw.Text(
      label,
      style: pw.TextStyle(fontSize: 8, color: color),
      textDirection: _textDirectionFor(label, pageDirection),
    ),
  );

  pw.Widget _letterTrio(
    PdfExportStatistics statistics,
    pw.TextDirection pageDirection,
  ) {
    final average = statistics.table[1];
    final cells = [
      _letterTrioCell(
        'average'.tr(),
        '${average[1]}/${average[2]}',
        '${'pulLong'.tr()} ${average[3]}',
        pageDirection,
      ),
      _letterTrioCell(
        'maximum'.tr(),
        '${statistics.highest!.sys}/${statistics.highest!.dia}',
        statistics.highest!.time,
        pageDirection,
      ),
      _letterTrioCell(
        'minimum'.tr(),
        '${statistics.lowest!.sys}/${statistics.lowest!.dia}',
        statistics.lowest!.time,
        pageDirection,
      ),
    ];
    final ordered = pageDirection == pw.TextDirection.rtl
        ? cells.reversed.toList()
        : cells;
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 8),
      child: pw.Table(
        border: pw.TableBorder(
          top: const pw.BorderSide(color: PdfColors.grey300, width: 0.4),
          bottom: const pw.BorderSide(color: PdfColors.grey300, width: 0.4),
          verticalInside: const pw.BorderSide(
            color: PdfColors.grey300,
            width: 0.4,
          ),
        ),
        children: [pw.TableRow(children: ordered)],
      ),
    );
  }

  pw.Widget _letterTrioCell(
    String label,
    String value,
    String caption,
    pw.TextDirection pageDirection,
  ) => pw.Padding(
    padding: const pw.EdgeInsets.symmetric(vertical: 6, horizontal: 4),
    child: pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          label,
          style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700),
          textDirection: _textDirectionFor(label, pageDirection),
        ),
        pw.SizedBox(height: 2),
        pw.Text(
          value,
          style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold),
          textDirection: pw.TextDirection.ltr,
        ),
        pw.Text(
          caption,
          style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700),
          textDirection: _textDirectionFor(caption, pageDirection),
        ),
      ],
    ),
  );

  pw.Widget _letterSectionLabel(String label, pw.TextDirection pageDirection) =>
      pw.Padding(
        padding: const pw.EdgeInsets.only(top: 4, bottom: 4),
        child: pw.Text(
          label,
          style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold),
          textDirection: _textDirectionFor(label, pageDirection),
        ),
      );

  pw.Widget _letterWeight(
    PdfWeightSeries series,
    pw.TextDirection pageDirection,
  ) {
    final latest = series.points.last;
    final first = series.points.first;
    final date = WesternDateFormat('d MMM', locale);
    const captionStyle = pw.TextStyle(fontSize: 8, color: PdfColors.grey700);
    final latestCaption =
        '${'dashboardLatest'.tr()} · ${date.format(latest.time)}';
    final columns = <pw.Widget>[
      pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          _weightAmount(
            series.latest,
            fontSize: 18,
            fontWeight: pw.FontWeight.bold,
            pageDirection: pageDirection,
          ),
          pw.SizedBox(height: 2),
          pw.Text(
            latestCaption,
            style: captionStyle,
            textDirection: _textDirectionFor(
              'dashboardLatest'.tr(),
              pageDirection,
            ),
          ),
        ],
      ),
    ];
    if (series.points.length > 1) {
      final since = 'pdfWeightSince'.tr(
        namedArgs: {'date': date.format(first.time)},
      );
      final fromValue = _formatPreferredWeight(first.value);
      columns
        ..add(pw.SizedBox(width: 16))
        ..add(
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              _weightAmount(
                _signedWeightChange(latest.value - first.value),
                fontSize: 18,
                fontWeight: pw.FontWeight.bold,
                pageDirection: pageDirection,
              ),
              pw.SizedBox(height: 2),
              pw.Text(
                since,
                style: captionStyle,
                textDirection: _textDirectionFor(since, pageDirection),
              ),
              _ltrValueLine(
                'pdfWeightFrom'.tr(namedArgs: {'value': fromValue}),
                fromValue,
                pageDirection,
              ),
            ],
          ),
        );
    }
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        _letterSectionLabel('weight'.tr(), pageDirection),
        pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: pageDirection == pw.TextDirection.rtl
              ? columns.reversed.toList()
              : columns,
        ),
        pw.SizedBox(height: 6),
      ],
    );
  }

  pw.Widget _medicineDoseLabel({
    required String? amount,
    required String unit,
    required pw.TextDirection pageDirection,
  }) {
    const style = pw.TextStyle(fontSize: 9);
    final unitText = pw.Text(
      unit,
      style: style,
      textDirection: _textDirectionFor(unit, pageDirection),
    );
    if (amount == null || amount.isEmpty) {
      return pw.Padding(
        padding: const pw.EdgeInsets.only(bottom: 3),
        child: unitText,
      );
    }
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 3),
      child: pw.Row(
        mainAxisSize: pw.MainAxisSize.min,
        crossAxisAlignment: pw.CrossAxisAlignment.end,
        children: [
          pw.Text(
            amount,
            style: style,
            textDirection: pw.TextDirection.ltr,
          ),
          pw.SizedBox(width: 3),
          unitText,
        ],
      ),
    );
  }

  String _formatPreferredWeight(double value) =>
      settings.weightUnit.format(settings.weightUnit.store(value));

  /// Number stays left to right. An Arabic unit such as كغم is drawn on its own
  /// so the letters are not reversed.
  pw.Widget _weightAmount(
    String formatted, {
    required double fontSize,
    pw.FontWeight? fontWeight,
    PdfColor? color,
    required pw.TextDirection pageDirection,
  }) {
    final unit = settings.weightUnit.displayName;
    final style = pw.TextStyle(
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color,
    );
    final splitAt = unit.isEmpty ? -1 : formatted.lastIndexOf(unit);
    if (splitAt <= 0) {
      return pw.Text(
        formatted,
        style: style,
        textDirection: pw.TextDirection.ltr,
      );
    }
    final number = formatted.substring(0, splitAt).trimRight();
    return pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.end,
      children: [
        pw.Text(number, style: style, textDirection: pw.TextDirection.ltr),
        pw.SizedBox(width: 3),
        pw.Text(
          unit,
          style: style,
          textDirection: _textDirectionFor(unit, pageDirection),
        ),
      ],
    );
  }

  /// Keeps a Latin value such as `70.6 kg` from reversing inside an Arabic phrase.
  pw.Widget _ltrValueLine(
    String line,
    String value,
    pw.TextDirection pageDirection,
  ) {
    const style = pw.TextStyle(fontSize: 8, color: PdfColors.grey700);
    final splitAt = value.isEmpty ? -1 : line.indexOf(value);
    if (splitAt < 0) {
      return pw.Text(
        line,
        style: style,
        textDirection: _textDirectionFor(line, pageDirection),
      );
    }
    final before = line.substring(0, splitAt);
    final after = line.substring(splitAt + value.length);
    final parts = <pw.Widget>[
      if (before.isNotEmpty)
        pw.Text(
          before,
          style: style,
          textDirection: _textDirectionFor(before, pageDirection),
        ),
      _weightAmount(
        value,
        fontSize: 8,
        color: PdfColors.grey700,
        pageDirection: pageDirection,
      ),
      if (after.isNotEmpty)
        pw.Text(
          after,
          style: style,
          textDirection: _textDirectionFor(after, pageDirection),
        ),
    ];
    return pw.Row(
      children: pageDirection == pw.TextDirection.rtl
          ? parts.reversed.toList()
          : parts,
    );
  }

  String _signedWeightChange(double delta) {
    final text = _formatPreferredWeight(delta.abs());
    if (delta.abs() < 0.05) return text;
    return delta < 0 ? '−$text' : '+$text';
  }

  List<pw.Widget> _letterMedicineBlocks(
    PdfMedicineSeries series,
    List<DateTime> reportDays,
    pw.TextDirection pageDirection,
    int index, {
    required int squaresPerRow,
  }) {
    final color = series.color == null
        ? _medicinePalette[index % _medicinePalette.length]
        : _pdfColorFromArgb(series.color!);
    final amounts = {for (final dose in series.doses) dose.amount};
    final steady = amounts.length <= 1;
    final takenDays = <DateTime>{
      for (final dose in series.doses) _calendarDay(dose.time),
    };
    final days = reportDays.isEmpty
        ? (takenDays.toList()..sort())
        : reportDays;
    final taken = days.where(takenDays.contains).length;
    final totalLabel = '${days.length}';
    final ofDays = 'pdfMedicineOfDays'.tr(namedArgs: {'total': totalLabel});
    const captionStyle = pw.TextStyle(fontSize: 9);
    final count = pw.Text(
      '$taken',
      style: pw.TextStyle(
        fontSize: 18,
        fontWeight: pw.FontWeight.bold,
        color: color,
      ),
      textDirection: pw.TextDirection.ltr,
    );
    final header = pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.end,
      children: [
        count,
        pw.SizedBox(width: 6),
        pw.Flexible(
          child: pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.end,
            children: [
              ..._pdfRuns(
                ofDays,
                totalLabel,
                captionStyle,
                pageDirection,
              ),
              pw.Text(
                ' · ',
                style: captionStyle,
                textDirection: pw.TextDirection.ltr,
              ),
              pw.Flexible(
                child: pw.Text(
                  series.name,
                  style: captionStyle,
                  textDirection: _textDirectionFor(series.name, pageDirection),
                ),
              ),
              pw.SizedBox(width: 4),
              _medicineDoseLabel(
                amount: steady && series.doses.isNotEmpty
                    ? formatDoseAmount(series.doses.last.amount)
                    : null,
                unit: series.unit,
                pageDirection: pageDirection,
              ),
            ],
          ),
        ),
      ],
    );
    final squareRows = _tallySquareRows(
      days,
      takenDays,
      color,
      squaresPerRow,
    );
    const maxRows = 40;
    final blocks = <pw.Widget>[];
    if (squareRows.isEmpty) {
      blocks.add(
        pw.Padding(
          padding: const pw.EdgeInsets.only(bottom: 6),
          child: header,
        ),
      );
      return blocks;
    }
    for (var start = 0; start < squareRows.length; start += maxRows) {
      final end = math.min(start + maxRows, squareRows.length);
      blocks.add(
        pw.Padding(
          padding: const pw.EdgeInsets.only(bottom: 6),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              if (start == 0) header,
              if (start == 0) pw.SizedBox(height: 4),
              ...squareRows.sublist(start, end),
            ],
          ),
        ),
      );
    }
    return blocks;
  }

  List<pw.Widget> _tallySquareRows(
    List<DateTime> days,
    Set<DateTime> taken,
    PdfColor color,
    int perRow,
  ) {
    final rows = <pw.Widget>[];
    for (var i = 0; i < days.length; i += perRow) {
      final end = math.min(i + perRow, days.length);
      rows.add(
        pw.Padding(
          padding: const pw.EdgeInsets.only(bottom: 2),
          child: pw.Row(
            children: [
              for (final day in days.sublist(i, end))
                pw.Container(
                  width: 7,
                  height: 7,
                  margin: const pw.EdgeInsets.only(right: 2),
                  decoration: pw.BoxDecoration(
                    color: taken.contains(day) ? color : PdfColors.grey300,
                  ),
                ),
            ],
          ),
        ),
      );
    }
    return rows;
  }

  pw.Widget _buildPdfTrendChart(
    PdfExportContent content,
    pw.TextDirection pageDirection,
    _PdfFonts fonts,
  ) {
    final points = content.chartPoints;
    final xTicks = _chartAxisIndexes(points.length);
    final dateFormat = WesternDateFormat(
      points.first.time.year == points.last.time.year ? 'd/M' : 'd/M/yy',
      locale,
    );
    final systolicColor = settings.sysColor.toPdfColor();
    final diastolicColor = settings.diaColor.toPdfColor();
    final datasets = <pw.Dataset>[];
    final systolic = <pw.PointChartValue>[
      for (var i = 0; i < points.length; i++)
        if (points[i].systolic case final value?)
          pw.PointChartValue(i.toDouble(), value),
    ];
    final diastolic = <pw.PointChartValue>[
      for (var i = 0; i < points.length; i++)
        if (points[i].diastolic case final value?)
          pw.PointChartValue(i.toDouble(), value),
    ];
    if (systolic.isNotEmpty) {
      datasets.add(
        pw.LineDataSet(
          data: systolic,
          legend: 'sysLong'.tr(),
          color: systolicColor,
          lineColor: systolicColor,
          lineWidth: 1.8,
          pointSize: 2.2,
          isCurved: true,
        ),
      );
    }
    if (diastolic.isNotEmpty) {
      datasets.add(
        pw.LineDataSet(
          data: diastolic,
          legend: 'diaLong'.tr(),
          color: diastolicColor,
          lineColor: diastolicColor,
          lineWidth: 1.8,
          pointSize: 2.2,
          isCurved: true,
        ),
      );
    }

    return pw.Padding(
      padding: const pw.EdgeInsets.only(top: 4, bottom: 12),
      child: pw.SizedBox(
        height: 150,
        child: pw.Chart(
          grid: pw.CartesianGrid(
            xAxis: pw.FixedAxis<int>(
              xTicks,
              color: PdfColors.blueGrey,
              width: .6,
              buildLabel: (value) => pw.Text(
                dateFormat.format(
                  points[value.round().clamp(0, points.length - 1)].time,
                ),
                style: pw.TextStyle(font: fonts.latin, fontSize: 7),
                textDirection: pw.TextDirection.ltr,
              ),
            ),
            yAxis: pw.FixedAxis<double>(
              _chartPressureAxis(points),
              color: PdfColors.blueGrey,
              width: .6,
              divisions: true,
              divisionsColor: PdfColors.blueGrey100,
              divisionsWidth: .5,
              buildLabel: (value) => pw.Text(
                _chartPressureLabel(
                  value.toDouble(),
                  settings.preferredPressureUnit,
                ),
                style: pw.TextStyle(font: fonts.latin, fontSize: 7),
                textDirection: pw.TextDirection.ltr,
              ),
            ),
          ),
          datasets: datasets,
          bottom: pw.Padding(
            padding: const pw.EdgeInsets.only(top: 5),
            child: pw.ChartLegend(
              direction: pw.Axis.horizontal,
              textStyle: pw.TextStyle(
                font: pageDirection == pw.TextDirection.rtl
                    ? fonts.arabic
                    : fonts.latin,
                fontSize: 8,
              ),
              padding: pw.EdgeInsets.zero,
            ),
          ),
        ),
      ),
    );
  }

  List<pw.Widget> _letterTables(
    PdfExportContent content,
    pw.Alignment cellAlignment,
    pw.TextDirection pageDirection,
    _PdfFonts fonts,
  ) {
    if (!pdfSettings.exportData) return const [];
    if (!pdfSettings.separateWeightMedicineTables) {
      return [
        _buildPdfTable(
          _PdfLogTable.from(content),
          cellAlignment,
          pageDirection,
          fonts,
        ),
      ];
    }
    final widgets = <pw.Widget>[];
    final readings = _projectLog(
      content,
      (type) =>
          type != RowDataFieldType.weightKg &&
          type != RowDataFieldType.intakes,
    );
    if (readings.rows.isNotEmpty) {
      widgets.add(
        _buildPdfTable(readings, cellAlignment, pageDirection, fonts),
      );
    }
    _addMetricTable(
      widgets,
      content,
      label: 'weight'.tr(),
      metric: RowDataFieldType.weightKg,
      include: (type) =>
          type == RowDataFieldType.timestamp ||
          type == RowDataFieldType.weightKg,
      cellAlignment: cellAlignment,
      pageDirection: pageDirection,
      fonts: fonts,
    );
    _addMetricTable(
      widgets,
      content,
      label: 'intakes'.tr(),
      metric: RowDataFieldType.intakes,
      include: (type) =>
          type == RowDataFieldType.timestamp ||
          type == RowDataFieldType.intakes,
      cellAlignment: cellAlignment,
      pageDirection: pageDirection,
      fonts: fonts,
    );
    return widgets;
  }

  void _addMetricTable(
    List<pw.Widget> widgets,
    PdfExportContent content, {
    required String label,
    required RowDataFieldType metric,
    required bool Function(RowDataFieldType? type) include,
    required pw.Alignment cellAlignment,
    required pw.TextDirection pageDirection,
    required _PdfFonts fonts,
  }) {
    final table = _projectLog(content, include);
    if (!table.columnTypes.contains(metric) || table.rows.isEmpty) return;
    widgets
      ..add(pw.SizedBox(height: 12))
      ..add(_letterSectionLabel(label, pageDirection))
      ..add(
        _buildPdfTable(
          table,
          cellAlignment,
          pageDirection,
          fonts,
          lockTimeColumn: true,
        ),
      );
  }

  pw.Widget _buildPdfTable(
    _PdfLogTable table,
    pw.Alignment cellAlignment,
    pw.TextDirection pageDirection,
    _PdfFonts fonts, {
    bool lockTimeColumn = false,
  }) {
    final headerStyle = pw.TextStyle(
      color: PdfColors.black,
      fontSize: pdfSettings.headerFontSize,
      fontWeight: pw.FontWeight.bold,
    );
    final headers = _orderedTableRow(table.headers, pageDirection);
    final rows = [
      for (final row in table.rows) _orderedTableRow(row, pageDirection),
    ];
    final columnTypes = pageDirection == pw.TextDirection.rtl
        ? table.columnTypes.reversed.toList()
        : table.columnTypes;
    return pw.TableHelper.fromTextArray(
      border: null,
      columnWidths: lockTimeColumn
          ? {
              for (var i = 0; i < columnTypes.length; i++)
                i: columnTypes[i] == RowDataFieldType.timestamp
                    ? const pw.FixedColumnWidth(160)
                    : const pw.FlexColumnWidth(),
            }
          : null,
      cellAlignment: cellAlignment,
      headerDecoration: const pw.BoxDecoration(
        border: pw.Border(bottom: pw.BorderSide()),
      ),
      headerHeight: pdfSettings.headerHeight,
      cellHeight: pdfSettings.cellHeight,
      cellAlignments: {
        for (final v in List.generate(table.headers.length, (idx) => idx))
          v: cellAlignment,
      },
      headerStyle: headerStyle,
      cellStyle: pw.TextStyle(fontSize: pdfSettings.cellFontSize),
      headerDirection: pageDirection,
      cellBuilder: (index, cell, _) {
        final text = cell.toString();
        if (index < columnTypes.length &&
            columnTypes[index] == RowDataFieldType.weightKg &&
            text != pdfMissingValue) {
          return _weightAmount(
            text,
            fontSize: pdfSettings.cellFontSize,
            pageDirection: pageDirection,
          );
        }
        if (pageDirection == pw.TextDirection.rtl &&
            index < columnTypes.length &&
            columnTypes[index] == RowDataFieldType.intakes &&
            _arabicText.hasMatch(text)) {
          final parts = splitPdfMedicineIntakeCell(text);
          if (parts != null) {
            return pw.Row(
              mainAxisSize: pw.MainAxisSize.min,
              children: [
                pw.Text(
                  parts.dose,
                  style: pw.TextStyle(
                    fontSize: pdfSettings.cellFontSize,
                    font: fonts.latin,
                  ),
                  textDirection: pw.TextDirection.ltr,
                ),
                pw.Text(
                  parts.medicine,
                  style: pw.TextStyle(
                    fontSize: pdfSettings.cellFontSize,
                    font: fonts.fontFor(parts.medicine) ?? fonts.arabic,
                  ),
                  textDirection: pw.TextDirection.rtl,
                ),
              ],
            );
          }
        }
        return pw.Text(
          text,
          style: pw.TextStyle(
            fontSize: pdfSettings.cellFontSize,
            font: fonts.fontFor(text),
          ),
          textDirection: _textDirectionFor(text, pageDirection),
        );
      },
      headerCellDecoration: pw.BoxDecoration(
        border: pw.Border(
          bottom: pw.BorderSide(
            color: settings.accentColor.toPdfColor(),
            width: 5,
          ),
        ),
      ),
      rowDecoration: const pw.BoxDecoration(
        border: pw.Border(
          bottom: pw.BorderSide(color: PdfColors.blueGrey, width: .5),
        ),
      ),
      headers: [
        for (final text in headers)
          pw.Text(
            text,
            style: headerStyle.copyWith(font: fonts.fontFor(text)),
            textDirection: _textDirectionFor(text, pageDirection),
          ),
      ],
      data: rows,
    );
  }
}

List<int> _chartAxisIndexes(int pointCount) {
  final last = pointCount - 1;
  final tickCount = math.min(pointCount, 5);
  return {
    for (var i = 0; i < tickCount; i++) (i * last / (tickCount - 1)).round(),
  }.toList()..sort();
}

List<double> _chartPressureAxis(List<PdfExportChartPoint> points) => _niceAxis(
  [
    for (final point in points) ...[?point.systolic, ?point.diastolic],
  ],
);

List<double> _niceAxis(List<double> values) {
  if (values.isEmpty) return const [0, 1];
  final minimum = values.reduce((a, b) => a < b ? a : b);
  final maximum = values.reduce((a, b) => a > b ? a : b);
  final span = maximum - minimum;
  final usefulSpan = span == 0 ? math.max(5, maximum.abs() * .08) : span;
  final rawStep = usefulSpan / 4;
  final magnitude = math
      .pow(10, (math.log(rawStep) / math.ln10).floor())
      .toDouble();
  final normalizedStep = rawStep / magnitude;
  final niceStep =
      switch (normalizedStep) {
        <= 1 => 1.0,
        <= 2 => 2.0,
        <= 5 => 5.0,
        _ => 10.0,
      } *
      magnitude;
  final lower = ((minimum - niceStep * .4) / niceStep).floor() * niceStep;
  var upper = ((maximum + niceStep * .4) / niceStep).ceil() * niceStep;
  if (upper <= lower) upper = lower + niceStep;
  final count = ((upper - lower) / niceStep).round();
  return [for (var i = 0; i <= count; i++) lower + niceStep * i];
}

String _chartPressureLabel(double value, PressureUnit unit) =>
    unit == PressureUnit.kPa
    ? value.toStringAsFixed(1)
    : value.round().toString();

PdfColor _bandColor(String label) {
  if (label == 'metricRangeHigh'.tr()) return PdfColors.red700;
  if (label == 'metricRangeElevated'.tr()) return PdfColors.orange800;
  return PdfColors.teal;
}

PdfColor _pdfColorFromArgb(int argb) => PdfColor(
  ((argb >> 16) & 0xFF) / 255,
  ((argb >> 8) & 0xFF) / 255,
  (argb & 0xFF) / 255,
  ((argb >> 24) & 0xFF) / 255,
);

const _appLogoAsset = 'icon.svg';

/// Drops the adaptive-icon margin so the heart fills the header box.
String _logoWithoutMargin(String svg) => svg.replaceFirst(
  'viewBox="0 0 1024 1024"',
  'viewBox="166 280 629 532"',
);

const _medicinePalette = <PdfColor>[
  PdfColors.teal,
  PdfColors.indigo,
  PdfColors.deepOrange,
  PdfColors.purple,
  PdfColors.cyan,
];

/// Split a formatted medicine intake into an Arabic medicine name and an
/// LTR parenthesized dose so bidi mirroring cannot reverse the punctuation.
({String medicine, String dose})? splitPdfMedicineIntakeCell(String text) {
  if (!text.endsWith(')')) return null;
  final open = text.lastIndexOf('(');
  if (open <= 0 || open == text.length - 1) return null;
  return (medicine: text.substring(0, open), dose: text.substring(open));
}

class _PdfLogTable {
  const _PdfLogTable({
    required this.headers,
    required this.columnTypes,
    required this.rows,
    required this.rowDays,
  });

  factory _PdfLogTable.from(PdfExportContent content) => _PdfLogTable(
    headers: content.headers,
    columnTypes: content.columnTypes,
    rows: content.rows,
    rowDays: content.rowDays,
  );

  final List<String> headers;
  final List<RowDataFieldType?> columnTypes;
  final List<List<String>> rows;
  final List<DateTime> rowDays;
}

_PdfLogTable _projectLog(
  PdfExportContent content,
  bool Function(RowDataFieldType? type) includeColumn,
) {
  final indexes = <int>[
    for (var i = 0; i < content.columnTypes.length; i++)
      if (includeColumn(content.columnTypes[i])) i,
  ];
  final types = [for (final i in indexes) content.columnTypes[i]];
  final rows = <List<String>>[];
  final days = <DateTime>[];
  for (var r = 0; r < content.rows.length; r++) {
    final source = content.rows[r];
    final projected = [
      for (final i in indexes)
        if (i < source.length) source[i] else pdfMissingValue,
    ];
    if (_logRowIsBlank(projected, types)) continue;
    rows.add(projected);
    if (r < content.rowDays.length) days.add(content.rowDays[r]);
  }
  return _PdfLogTable(
    headers: [for (final i in indexes) content.headers[i]],
    columnTypes: types,
    rows: rows,
    rowDays: days,
  );
}

bool _logRowIsBlank(List<String> row, List<RowDataFieldType?> types) {
  for (var i = 0; i < row.length; i++) {
    if (i < types.length && types[i] == RowDataFieldType.timestamp) continue;
    if (row[i] != pdfMissingValue && row[i].isNotEmpty) return false;
  }
  return true;
}

/// Splits [line] around [value] so the value stays left to right.
List<pw.Widget> _pdfRuns(
  String line,
  String value,
  pw.TextStyle style,
  pw.TextDirection pageDirection,
) {
  final index = value.isEmpty ? -1 : line.indexOf(value);
  if (index < 0) {
    return [
      pw.Text(
        line,
        style: style,
        textDirection: _textDirectionFor(line, pageDirection),
      ),
    ];
  }
  final before = line.substring(0, index);
  final after = line.substring(index + value.length);
  return [
    if (before.isNotEmpty)
      pw.Text(
        before,
        style: style,
        textDirection: _textDirectionFor(before, pageDirection),
      ),
    pw.Text(value, style: style, textDirection: pw.TextDirection.ltr),
    if (after.isNotEmpty)
      pw.Text(
        after,
        style: style,
        textDirection: _textDirectionFor(after, pageDirection),
      ),
  ];
}

List<String> _orderedTableRow(List<String> row, pw.TextDirection direction) =>
    direction == pw.TextDirection.rtl ? row.reversed.toList() : row;

DateTime _calendarDay(DateTime time) => DateTime(time.year, time.month, time.day);

/// Every day from the first exported reading to the last, including gaps.
List<DateTime> _reportDays(PdfExportContent content) {
  final times = <DateTime>[
    for (final point in content.chartPoints) point.time,
    for (final point in content.weightSeries?.points ?? const <PdfWeightPoint>[])
      point.time,
    for (final series in content.medicineSeries)
      for (final dose in series.doses) dose.time,
    ...content.rowDays,
  ];
  if (times.isEmpty) return const [];
  var start = _calendarDay(times.first);
  var end = start;
  for (final time in times) {
    final day = _calendarDay(time);
    if (day.isBefore(start)) start = day;
    if (day.isAfter(end)) end = day;
  }
  return [
    for (var day = start; !day.isAfter(end); day = day.add(const Duration(days: 1)))
      day,
  ];
}

final _arabicText = RegExp(r'[\u0600-\u06ff\u0750-\u077f\u08a0-\u08ff]');
final _tamilText = RegExp(r'[\u0b80-\u0bff]');
final _chineseText = RegExp(r'[\u3400-\u4dbf\u4e00-\u9fff]');

String _rtlUnitLabel(String value) => switch (value) {
  'mmHg' => 'مم زئبق',
  'kPa' => 'كيلوباسكال',
  _ => value,
};

pw.TextDirection _textDirectionFor(
  String text,
  pw.TextDirection pageDirection,
) {
  if (text.trim().isEmpty) return pageDirection;
  return _arabicText.hasMatch(text)
      ? pw.TextDirection.rtl
      : pw.TextDirection.ltr;
}

extension _PdfCompatability on Color {
  PdfColor toPdfColor() => PdfColor(r, g, b, a);
}

Future<_PdfFonts>? _pdfFonts;

/// Load fonts that cover every locale Janan ships, plus multilingual notes.
Future<_PdfFonts> _loadPdfFonts() => _pdfFonts ??= _readPdfFonts();

Future<_PdfFonts> _readPdfFonts() async => _PdfFonts(
  latin: pw.Font.ttf(
    await rootBundle.load('assets/fonts/NotoSans-Regular.ttf'),
  ),
  latinBold: pw.Font.ttf(
    await rootBundle.load('assets/fonts/NotoSans-Bold.ttf'),
  ),
  arabic: pw.Font.ttf(
    await rootBundle.load('assets/fonts/NotoSansArabic-Regular.ttf'),
  ),
  arabicBold: pw.Font.ttf(
    await rootBundle.load('assets/fonts/NotoSansArabic-Bold.ttf'),
  ),
  tamil: pw.Font.ttf(
    await rootBundle.load('assets/fonts/NotoSansTamil-Regular.ttf'),
  ),
  tamilBold: pw.Font.ttf(
    await rootBundle.load('assets/fonts/NotoSansTamil-Bold.ttf'),
  ),
  chinese: pw.Font.ttf(await rootBundle.load('assets/fonts/NotoSansSC.ttf')),
);

class _PdfFonts {
  const _PdfFonts({
    required this.latin,
    required this.latinBold,
    required this.arabic,
    required this.arabicBold,
    required this.tamil,
    required this.tamilBold,
    required this.chinese,
  });

  final pw.Font latin;
  final pw.Font latinBold;
  final pw.Font arabic;
  final pw.Font arabicBold;
  final pw.Font tamil;
  final pw.Font tamilBold;
  final pw.Font chinese;

  /// Pick a complex-script font as the primary font for user-entered cells.
  /// This preserves shaping even when a note's script differs from the app
  /// locale. A null result inherits the locale-aware theme font.
  pw.Font? fontFor(String text) {
    if (_arabicText.hasMatch(text)) return arabic;
    if (_tamilText.hasMatch(text)) return tamil;
    if (_chineseText.hasMatch(text)) return chinese;
    return null;
  }

  pw.ThemeData themeFor(String locale) {
    final language = locale.split(RegExp('[-_]')).first;
    return switch (language) {
      // Complex scripts must be the primary font. Using them only as a
      // fallback splits the text into separate glyph runs and breaks shaping.
      'ar' => pw.ThemeData.withFont(
        base: arabic,
        bold: arabicBold,
        fontFallback: [latin, tamil, chinese],
      ),
      'ta' => pw.ThemeData.withFont(
        base: tamil,
        bold: tamilBold,
        fontFallback: [latin, arabic, chinese],
      ),
      'zh' => pw.ThemeData.withFont(
        base: chinese,
        bold: chinese,
        fontFallback: [latin, arabic, tamil],
      ),
      _ => pw.ThemeData.withFont(
        base: latin,
        bold: latinBold,
        fontFallback: [arabic, tamil, chinese],
      ),
    };
  }
}
