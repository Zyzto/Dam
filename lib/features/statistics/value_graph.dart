import 'dart:math' as math;

import 'package:blood_pressure_app/app.dart';
import 'package:blood_pressure_app/core/widgets/toast.dart';
import 'package:blood_pressure_app/domain/domain.dart';
import 'package:blood_pressure_app/features/settings/app_settings.dart';
import 'package:blood_pressure_app/features/statistics/chart/chart_legend.dart';
import 'package:blood_pressure_app/features/statistics/chart/chart_tooltip.dart';
import 'package:blood_pressure_app/features/statistics/chart/graph_series.dart';
import 'package:blood_pressure_app/features/statistics/chart/medication_dot_painter.dart';
import 'package:blood_pressure_app/features/statistics/chart/time_axis_titles.dart';
import 'package:blood_pressure_app/l10n/western_digits.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

export 'package:blood_pressure_app/features/statistics/chart/graph_series.dart';

/// A graph of [BloodPressureRecord] values.
///
/// Note that this can't follow the users preferred unit as this would not allow
/// to put all data on one graph
class BloodPressureValueGraph extends ConsumerWidget {
  /// Create a new graph of [BloodPressureRecord] values.
  const BloodPressureValueGraph({
    super.key,
    required this.records,
    required this.colors,
    required this.intakes,
  });

  /// Data to draw lines and determine decorations from.
  ///
  /// Must be more than two and sorted.
  final List<BloodPressureRecord> records;

  /// Notes that should render as colored lines if present.
  final List<Note> colors;

  /// Intake dates get painted as tiny colored medicines at the bottom of the
  /// graph.
  final List<MedicineIntake> intakes;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(appSettingsProvider);
    if (records.sysGraph().length < 2 &&
        records.diaGraph().length < 2 &&
        records.pulGraph().length < 2) {
      return Center(child: Text('errNotEnoughDataToGraph'.tr()));
    }
    return _BloodPressureValueChart(
      records: records,
      colors: colors,
      intakes: settings.medicineFeatureEnabled
          ? intakes
          : const <MedicineIntake>[],
    );
  }
}

class _BloodPressureValueChart extends ConsumerStatefulWidget {
  const _BloodPressureValueChart({
    required this.records,
    required this.colors,
    required this.intakes,
  });

  final List<BloodPressureRecord> records;
  final List<Note> colors;
  final List<MedicineIntake> intakes;

  @override
  ConsumerState<_BloodPressureValueChart> createState() =>
      _BloodPressureValueChartState();
}

class _BloodPressureValueChartState
    extends ConsumerState<_BloodPressureValueChart> {
  TransformationController? _transform;
  bool? _lastDisconnected;
  bool _isZoomed = false;

  TransformationController _ensureTransform() =>
      _transform ??= TransformationController()..addListener(_onTransform);

  @override
  void dispose() {
    _transform?.removeListener(_onTransform);
    _transform?.dispose();
    super.dispose();
  }

  void _onTransform() {
    final zoomed = (_transform!.value.getMaxScaleOnAxis() - 1.0).abs() > 0.01;
    if (zoomed == _isZoomed) return;
    _isZoomed = zoomed;
    if (mounted) setState(() {});
  }

  void _syncDisconnectWarning(bool disconnected) {
    if (_lastDisconnected == disconnected) return;
    _lastDisconnected = disconnected;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.dismissAllToasts();
      if (disconnected) {
        context.showToastWithAction(
          'bigGraphSplit'.tr(),
          actionLabel: 'openSettings'.tr(),
          icon: Icons.settings_outlined,
          onAction: () =>
              Navigator.of(context).pushNamed(AppRoute.settingsGraph.path),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final records = widget.records.toList()
      ..sort((a, b) => a.time.compareTo(b.time));
    final settings = ref.watch(appSettingsProvider);
    final locale = context.locale.toString();
    final theme = Theme.of(context);
    final labelStyle = theme.textTheme.bodySmall ?? const TextStyle();
    final axisColor = theme.brightness == Brightness.dark
        ? Colors.white
        : Colors.black;
    final gridColor = theme.brightness == Brightness.dark
        ? Colors.white60
        : Colors.black45;

    final sys = records.sysGraph();
    final dia = records.diaGraph();
    final pul = records.pulGraph();
    final disconnected = isGraphEntirelyDisconnected(
      sys: sys,
      dia: dia,
      pul: pul,
      interruptAfterNDays: settings.interruptGraphAfterNDays,
    );
    if (disconnected != _lastDisconnected) {
      _syncDisconnectWarning(disconnected);
    }

    final times = <DateTime>[
      ...records.map((r) => r.time),
      ...widget.colors.map((n) => n.time),
      ...widget.intakes.map((i) => i.time),
    ]..sort();
    var minX = times.first.millisecondsSinceEpoch.toDouble();
    var maxX = times.last.millisecondsSinceEpoch.toDouble();
    if (minX == maxX) {
      minX -= const Duration(hours: 12).inMilliseconds;
      maxX += const Duration(hours: 12).inMilliseconds;
    }

    var minY = double.infinity;
    var maxY = double.negativeInfinity;
    void consider(double? value) {
      if (value == null) return;
      minY = math.min(minY, value);
      maxY = math.max(maxY, value);
    }

    for (final r in records) {
      consider(r.sys?.mmHg.toDouble());
      consider(r.dia?.mmHg.toDouble());
      consider(r.pul?.toDouble());
    }
    for (final line in settings.horizontalGraphLines) {
      consider(line.height.toDouble());
    }
    if (!minY.isFinite || !maxY.isFinite) {
      minY = 0;
      maxY = 1;
    }
    if (minY == maxY) {
      minY -= 5;
      maxY += 5;
    }
    maxY += (maxY - minY) * 0.20;

    final bars = <LineChartBarData>[];
    var metricBarCount = 0;

    void addMetric(
      Iterable<(DateTime, double)> series,
      Color color, {
      double? warnValue,
    }) {
      for (final segment in splitSeriesByGap(
        series,
        settings.interruptGraphAfterNDays,
      )) {
        bars.add(
          _metricBar(
            segment,
            color: color,
            thickness: settings.graphLineThickness,
            warnValue: warnValue,
          ),
        );
        metricBarCount++;
      }
    }

    addMetric(sys, settings.sysColor, warnValue: settings.sysWarn.toDouble());
    addMetric(dia, settings.diaColor, warnValue: settings.diaWarn.toDouble());
    addMetric(pul, settings.pulColor);

    if (settings.drawRegressionLines) {
      for (final series in [sys.toList(), dia.toList()]) {
        final fit = linearRegression(series);
        if (fit == null) continue;
        bars.add(
          LineChartBarData(
            spots: [
              FlSpot(minX, fit.slope * minX + fit.intercept),
              FlSpot(maxX, fit.slope * maxX + fit.intercept),
            ],
            color: Colors.grey,
            barWidth: 3,
            dotData: const FlDotData(show: false),
          ),
        );
      }
    }

    for (final intake in widget.intakes) {
      final medicineColor = intake.medicine.color == null
          ? theme.colorScheme.onSurface
          : Color(intake.medicine.color!);
      bars.add(
        LineChartBarData(
          spots: [FlSpot(intake.time.millisecondsSinceEpoch.toDouble(), minY)],
          color: Colors.transparent,
          barWidth: 0,
          dotData: FlDotData(
            getDotPainter: (spot, percent, bar, index) => MedicationDotPainter(
              color: medicineColor,
              brightness: theme.brightness,
            ),
          ),
        ),
      );
    }

    final dateFormatter = WesternDateFormat(settings.dateFormatString, locale);

    final startLabel = WesternDateFormat.yMMMd(
      locale,
    ).format(records.first.time);
    final endLabel = WesternDateFormat.yMMMd(locale).format(records.last.time);

    return Semantics(
      label: 'graphSemantics'.tr(
        namedArgs: {
          'name': 'bloodPressure'.tr(),
          'start': startLabel,
          'end': endLabel,
        },
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(40, 4, 8, 10),
            child: Row(
              children: [
                Expanded(
                  child: ChartLegend(
                    items: [
                      ('sysShort'.tr(), settings.sysColor),
                      ('diaShort'.tr(), settings.diaColor),
                      ('pulShort'.tr(), settings.pulColor),
                    ],
                  ),
                ),
                if (_isZoomed)
                  IconButton(
                    tooltip: 'resetZoom'.tr(),
                    visualDensity: VisualDensity.compact,
                    icon: const Icon(Icons.zoom_out_map, size: 20),
                    onPressed: () => _transform!.value = Matrix4.identity(),
                  ),
              ],
            ),
          ),
          Expanded(
            child: LineChart(
              LineChartData(
                minX: minX,
                maxX: maxX,
                minY: minY,
                maxY: maxY,
                clipData: const FlClipData.all(),
                gridData: FlGridData(
                  drawVerticalLine: true,
                  drawHorizontalLine: true,
                  getDrawingHorizontalLine: (_) =>
                      FlLine(color: gridColor, strokeWidth: 1),
                  getDrawingVerticalLine: (_) =>
                      FlLine(color: gridColor, strokeWidth: 1),
                ),
                borderData: FlBorderData(
                  show: true,
                  border: Border(
                    left: BorderSide(color: axisColor),
                    bottom: BorderSide(color: axisColor),
                  ),
                ),
                titlesData: FlTitlesData(
                  topTitles: const AxisTitles(),
                  rightTitles: const AxisTitles(),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 36,
                      maxIncluded: false,
                      getTitlesWidget: (value, meta) => valueAxisTitle(
                        value: value,
                        meta: meta,
                        style: labelStyle,
                      ),
                    ),
                  ),
                  bottomTitles: const AxisTitles(
                    sideTitles: SideTitles(reservedSize: 8),
                  ),
                ),
                extraLinesData: ExtraLinesData(
                  extraLinesOnTop: false,
                  verticalLines: [
                    for (final note in widget.colors.where(
                      (n) => n.color != null,
                    ))
                      VerticalLine(
                        x: note.time.millisecondsSinceEpoch.toDouble(),
                        color: Color(note.color!).withAlpha(102),
                        strokeWidth: settings.needlePinBarWidth,
                      ),
                  ],
                  horizontalLines: [
                    for (final line in settings.horizontalGraphLines)
                      HorizontalLine(
                        y: line.height.toDouble(),
                        color: line.color,
                        strokeWidth: 2,
                        dashArray: const [10, 5],
                      ),
                  ],
                ),
                lineBarsData: bars,
                lineTouchData: LineTouchData(
                  enabled: true,
                  handleBuiltInTouches: true,
                  touchTooltipData: LineTouchTooltipData(
                    fitInsideHorizontally: true,
                    fitInsideVertically: true,
                    maxContentWidth: 180,
                    getTooltipColor: (_) => chartTooltipColor(context),
                    getTooltipItems: (touched) {
                      final metric = touched
                          .where((s) => s.barIndex < metricBarCount)
                          .toList();
                      if (metric.isEmpty) {
                        return List<LineTooltipItem?>.filled(
                          touched.length,
                          null,
                        );
                      }
                      final time = DateTime.fromMillisecondsSinceEpoch(
                        metric.first.x.round(),
                      );
                      final items = <LineTooltipItem?>[];
                      var first = true;
                      for (final spot in touched) {
                        if (spot.barIndex >= metricBarCount) {
                          items.add(null);
                          continue;
                        }
                        if (first) {
                          first = false;
                          items.add(
                            LineTooltipItem(
                              dateFormatter.format(time),
                              chartTooltipTitleStyle(context),
                              textAlign: TextAlign.start,
                              children: [
                                for (final m in metric)
                                  TextSpan(
                                    text: '\n${m.y.round()}',
                                    style: chartTooltipValueStyle(
                                      context,
                                      m.bar.color ??
                                          theme.colorScheme.onSurface,
                                    ),
                                  ),
                              ],
                            ),
                          );
                        } else {
                          items.add(null);
                        }
                      }
                      return items;
                    },
                  ),
                ),
              ),
              key: ValueKey<String>(locale),
              duration: Duration(milliseconds: settings.animationSpeed),
              curve: Curves.slowMiddle,
              transformationConfig: FlTransformationConfig(
                scaleAxis: FlScaleAxis.horizontal,
                minScale: 1,
                maxScale: 8,
                panEnabled: _isZoomed,
                transformationController: _ensureTransform(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  LineChartBarData _metricBar(
    List<(DateTime, double)> segment, {
    required Color color,
    required double thickness,
    double? warnValue,
  }) => LineChartBarData(
    spots: [
      for (final point in segment)
        FlSpot(point.$1.millisecondsSinceEpoch.toDouble(), point.$2),
    ],
    color: color,
    barWidth: thickness,
    isStrokeCapRound: true,
    isStrokeJoinRound: true,
    dotData: FlDotData(show: segment.length < 2),
    belowBarData: warnValue == null
        ? BarAreaData()
        : BarAreaData(
            show: true,
            color: Colors.redAccent.withAlpha(72),
            cutOffY: warnValue,
            applyCutOffY: true,
          ),
  );
}
