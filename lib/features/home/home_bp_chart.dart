import 'dart:async';
import 'dart:math' as math;

import 'package:blood_pressure_app/core/settings/storage_providers.dart';
import 'package:blood_pressure_app/data_util/combined_entry_builder.dart';
import 'package:blood_pressure_app/domain/domain.dart';
import 'package:blood_pressure_app/features/home/chart_bucket_calendar.dart';
import 'package:blood_pressure_app/features/home/home_medication_timing_chart.dart';
import 'package:blood_pressure_app/features/measurement_list/metric_info.dart';
import 'package:blood_pressure_app/features/settings/app_settings.dart';
import 'package:blood_pressure_app/features/settings/registry.dart';
import 'package:blood_pressure_app/features/statistics/chart/chart_tooltip.dart';
import 'package:blood_pressure_app/features/statistics/chart/time_axis_titles.dart';
import 'package:blood_pressure_app/features/statistics/dashboard/dashboard_section.dart';
import 'package:blood_pressure_app/l10n/western_digits.dart';
import 'package:blood_pressure_app/model/range_limits.dart';
import 'package:blood_pressure_app/model/storage/interval_store_manager.dart';
import 'package:blood_pressure_app/theme/app_text.dart';
import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_settings_framework/flutter_settings_framework.dart';

/// Charts the user can cycle on the home dashboard.
enum HomeBpChartKind {
  /// Min–max systolic per day (or week / month when the range is long).
  dailyRange,

  /// Share of readings in normal / elevated / high bands.
  classification,

  /// Systolic minus diastolic over time.
  pulsePressure,

  /// Share of recorded medicine doses taken early, on time, or late.
  medicineTiming;

  /// Decode a stored preference, falling back to [dailyRange].
  static HomeBpChartKind parse(String? raw) =>
      values.asNameMap()[raw] ?? HomeBpChartKind.dailyRange;
}

const _inRangeColor = Color(0xFF7FC8BA);
const _elevatedColor = Color(0xFFF9B132);
const _highColor = Color(0xFFF87261);

/// Dashboard card with home blood-pressure and medicine charts.
class HomeBpChart extends StatelessWidget {
  /// Create the home chart card with whichever chart categories are enabled.
  const HomeBpChart({
    super.key,
    this.showBloodPressure = true,
    this.showMedicine = false,
  });

  /// Whether the three blood-pressure charts can be selected.
  final bool showBloodPressure;

  /// Whether the medicine timing chart can be selected.
  final bool showMedicine;

  @override
  Widget build(BuildContext context) => CombinedEntryBuilder(
    rangeType: IntervalStoreManagerLocation.mainPage,
    onData: (context, records, intakes, notes) => _HomeBpChartView(
      records: records,
      showBloodPressure: showBloodPressure,
      showMedicine: showMedicine,
    ),
  );
}

class _HomeBpChartView extends ConsumerStatefulWidget {
  const _HomeBpChartView({
    required this.records,
    required this.showBloodPressure,
    required this.showMedicine,
  });

  final List<BloodPressureRecord> records;
  final bool showBloodPressure;
  final bool showMedicine;

  @override
  ConsumerState<_HomeBpChartView> createState() => _HomeBpChartViewState();
}

class _HomeBpChartViewState extends ConsumerState<_HomeBpChartView>
    with TickerProviderStateMixin {
  static const _swap = Duration(milliseconds: 420);
  static const _tallHeight = 220.0;
  static const _shortHeight = 116.0;

  late final AnimationController _spin;
  late final AnimationController _size;
  late Animation<double> _height;
  late HomeBpChartKind _kind;

  List<HomeBpChartKind> get _availableKinds => [
    if (widget.showBloodPressure) ...[
      HomeBpChartKind.dailyRange,
      HomeBpChartKind.classification,
      HomeBpChartKind.pulsePressure,
    ],
    if (widget.showMedicine) HomeBpChartKind.medicineTiming,
  ];

  double _heightFor(HomeBpChartKind kind) => switch (kind) {
    HomeBpChartKind.classification ||
    HomeBpChartKind.medicineTiming => _shortHeight,
    _ => _tallHeight,
  };

  String _titleOf(HomeBpChartKind kind) => switch (kind) {
    HomeBpChartKind.dailyRange => 'chartDailyRange'.tr(),
    HomeBpChartKind.classification => 'chartClassification'.tr(),
    HomeBpChartKind.pulsePressure => 'pulsePressure'.tr(),
    HomeBpChartKind.medicineTiming => 'homeMedicineTiming'.tr(),
  };

  String _subtitleOf(HomeBpChartKind kind) => switch (kind) {
    HomeBpChartKind.dailyRange => 'chartDailyRangeSubtitle'.tr(),
    HomeBpChartKind.classification => 'chartClassificationSubtitle'.tr(),
    HomeBpChartKind.pulsePressure => 'chartPulsePressureSubtitle'.tr(),
    HomeBpChartKind.medicineTiming => 'homeMedicineTimingSubtitle'.tr(),
  };

  IconData _iconOf(HomeBpChartKind kind) => switch (kind) {
    HomeBpChartKind.dailyRange => Icons.waterfall_chart,
    HomeBpChartKind.classification => Icons.donut_large,
    HomeBpChartKind.pulsePressure => Icons.show_chart,
    HomeBpChartKind.medicineTiming => Icons.medication_outlined,
  };

  HomeBpChartKind _availableKind(String? raw) {
    final selected = HomeBpChartKind.parse(raw);
    final kinds = _availableKinds;
    if (kinds.contains(selected) || kinds.isEmpty) return selected;
    return kinds.first;
  }

  @override
  void initState() {
    super.initState();
    _kind = _availableKind(ref.readSetting<String>(homeBpChartSetting));
    _spin = AnimationController(vsync: this, duration: _swap);
    _size = AnimationController(vsync: this, duration: _swap);
    _height = AlwaysStoppedAnimation(_heightFor(_kind));
  }

  @override
  void didUpdateWidget(covariant _HomeBpChartView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_availableKinds.isNotEmpty && !_availableKinds.contains(_kind)) {
      _spin.stop();
      _size.stop();
      _kind = _availableKinds.first;
      _height = AlwaysStoppedAnimation(_heightFor(_kind));
    }
  }

  @override
  void dispose() {
    _spin.dispose();
    _size.dispose();
    super.dispose();
  }

  void _cycle() {
    final kinds = _availableKinds;
    if (kinds.length < 2) return;
    _spin.forward(from: 0);
    final next = kinds[(kinds.indexOf(_kind) + 1) % kinds.length];
    _height = Tween<double>(
      begin: _height.value,
      end: _heightFor(next),
    ).animate(CurvedAnimation(parent: _size, curve: Curves.easeInOutCubic));
    setState(() => _kind = next);
    _size.forward(from: 0);
    unawaited(ref.updateSetting<String>(homeBpChartSetting, next.name));
  }

  Widget _fadeSlot({
    required String text,
    required TextStyle? style,
    required double height,
  }) => SizedBox(
    height: height,
    width: double.infinity,
    child: AnimatedSwitcher(
      duration: _swap,
      switchInCurve: Curves.easeInOutCubic,
      switchOutCurve: Curves.easeInOutCubic,
      layoutBuilder: (current, previous) => Stack(
        fit: StackFit.expand,
        alignment: AlignmentDirectional.centerStart,
        children: [
          for (final child in previous) IgnorePointer(child: child),
          ?current,
        ],
      ),
      transitionBuilder: (child, animation) =>
          FadeTransition(opacity: animation, child: child),
      child: Align(
        key: ValueKey(text),
        alignment: AlignmentDirectional.centerStart,
        child: Text(
          text,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: style,
        ),
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    Localizations.localeOf(context);
    final limits = ref.watch(appSettingsProvider).rangeLimits;
    final selectedRange = ref.watch(
      currentDateRangeProvider(IntervalStoreManagerLocation.mainPage),
    );
    final period = _chartPeriodForSpan(selectedRange.duration);
    final theme = Theme.of(context);
    final titleStyle = AppText.title(context);
    final subtitleStyle = AppText.subtitle(context);
    final titleHeight = titleStyle.fontSize! * (titleStyle.height ?? 1.25);
    final subtitleHeight =
        subtitleStyle.fontSize! * (subtitleStyle.height ?? 1.3);
    return DashboardSection(
      padding: const EdgeInsetsDirectional.fromSTEB(16, 12, 8, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              AnimatedSwitcher(
                duration: _swap,
                switchInCurve: Curves.easeInOutCubic,
                switchOutCurve: Curves.easeInOutCubic,
                child: Icon(
                  _iconOf(_kind),
                  key: ValueKey(_kind),
                  size: 20,
                  color: theme.colorScheme.primary,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _fadeSlot(
                      text: _titleOf(_kind),
                      style: titleStyle,
                      height: titleHeight,
                    ),
                    _fadeSlot(
                      text: _subtitleOf(_kind),
                      style: subtitleStyle,
                      height: subtitleHeight,
                    ),
                  ],
                ),
              ),
              if (_availableKinds.length > 1)
                IconButton(
                  tooltip: 'chartNext'.tr(),
                  style: IconButton.styleFrom(
                    foregroundColor: theme.colorScheme.primary,
                    minimumSize: const Size(48, 48),
                  ),
                  icon: RotationTransition(
                    turns: CurvedAnimation(
                      parent: _spin,
                      curve: Curves.easeOutCubic,
                    ),
                    child: const Icon(Icons.change_circle, size: 28),
                  ),
                  onPressed: _cycle,
                ),
            ],
          ),
          const SizedBox(height: 12),
          AnimatedBuilder(
            animation: _size,
            builder: (context, child) => SizedBox(
              height: _height.value,
              width: double.infinity,
              child: child,
            ),
            child: ClipRect(
              child: AnimatedSwitcher(
                duration: _swap,
                switchInCurve: Curves.easeInOutCubic,
                switchOutCurve: Curves.easeInOutCubic,
                layoutBuilder: (current, previous) => Stack(
                  fit: StackFit.expand,
                  alignment: Alignment.topCenter,
                  children: [
                    for (final child in previous) IgnorePointer(child: child),
                    ?current,
                  ],
                ),
                transitionBuilder: (child, animation) =>
                    FadeTransition(opacity: animation, child: child),
                child: KeyedSubtree(
                  key: ValueKey(_kind),
                  child: switch (_kind) {
                    HomeBpChartKind.dailyRange => _DailyRangeChart(
                      records: widget.records,
                      range: selectedRange,
                      period: period,
                    ),
                    HomeBpChartKind.classification => Align(
                      alignment: Alignment.topCenter,
                      child: _ClassificationChart(
                        records: widget.records,
                        limits: limits,
                      ),
                    ),
                    HomeBpChartKind.pulsePressure => _PulsePressureChart(
                      records: widget.records,
                      range: selectedRange,
                      period: period,
                    ),
                    HomeBpChartKind.medicineTiming =>
                      const HomeMedicationTimingChartContent(),
                  },
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyChart extends StatelessWidget {
  const _EmptyChart();

  @override
  Widget build(BuildContext context) => Center(
    child: Text(
      'errNotEnoughDataToGraph'.tr(),
      textAlign: TextAlign.center,
      style: AppText.subtitle(context),
    ),
  );
}

enum _RangeBucket { day, week, month }

class _ChartPeriod {
  const _ChartPeriod({required this.dataBucket, required this.axisBucket});

  final _RangeBucket dataBucket;
  final _RangeBucket axisBucket;
}

class _RangeSlot {
  const _RangeSlot(this.start, this.min, this.max, this.avg);

  final DateTime start;
  final double? min;
  final double? max;
  final double? avg;

  bool get hasData => min != null && max != null && avg != null;
}

_ChartPeriod _chartPeriodForSpan(Duration span) {
  final days = span.inDays;
  if (days <= 14) {
    return const _ChartPeriod(
      dataBucket: _RangeBucket.day,
      axisBucket: _RangeBucket.day,
    );
  }
  if (days <= 45) {
    return const _ChartPeriod(
      dataBucket: _RangeBucket.week,
      axisBucket: _RangeBucket.week,
    );
  }
  if (days <= 400) {
    return const _ChartPeriod(
      dataBucket: _RangeBucket.week,
      axisBucket: _RangeBucket.month,
    );
  }
  return const _ChartPeriod(
    dataBucket: _RangeBucket.month,
    axisBucket: _RangeBucket.month,
  );
}

DateTime _bucketStart(DateTime time, _RangeBucket bucket) =>
    chartBucketStart(time, switch (bucket) {
      _RangeBucket.day => ChartCalendarBucket.day,
      _RangeBucket.week => ChartCalendarBucket.week,
      _RangeBucket.month => ChartCalendarBucket.month,
    });

DateTime _nextBucket(DateTime start, _RangeBucket bucket) =>
    nextChartBucket(start, switch (bucket) {
      _RangeBucket.day => ChartCalendarBucket.day,
      _RangeBucket.week => ChartCalendarBucket.week,
      _RangeBucket.month => ChartCalendarBucket.month,
    });

List<DateTime> _bucketStarts(
  DateRange range,
  _RangeBucket bucket, {
  required DateTime firstRecord,
  required DateTime lastRecord,
}) {
  final useRecordBounds = bucket == _RangeBucket.month;
  var cursor = _bucketStart(
    useRecordBounds ? firstRecord : range.start,
    bucket,
  );
  final last = _bucketStart(useRecordBounds ? lastRecord : range.end, bucket);
  final starts = <DateTime>[];
  while (!cursor.isAfter(last)) {
    starts.add(cursor);
    cursor = _nextBucket(cursor, bucket);
  }
  return starts;
}

List<_RangeSlot> _dailyRangeSlots(
  Iterable<BloodPressureRecord> records,
  DateRange range,
  _ChartPeriod period,
) {
  final dated = records.where((r) => r.sys != null || r.dia != null).toList()
    ..sort((a, b) => a.time.compareTo(b.time));
  if (dated.isEmpty) return const [];

  final sysBy = <DateTime, List<double>>{};
  final diaBy = <DateTime, List<double>>{};
  for (final record in dated) {
    final start = _bucketStart(record.time, period.dataBucket);
    final sys = record.sys?.mmHg.toDouble();
    final dia = record.dia?.mmHg.toDouble();
    if (sys != null) sysBy.putIfAbsent(start, () => []).add(sys);
    if (dia != null) diaBy.putIfAbsent(start, () => []).add(dia);
  }

  final starts = _bucketStarts(
    range,
    period.dataBucket,
    firstRecord: dated.first.time,
    lastRecord: dated.last.time,
  );
  final slots = <_RangeSlot>[];
  for (final start in starts) {
    final values = sysBy[start]?.isNotEmpty == true
        ? sysBy[start]!
        : diaBy[start];
    if (values == null || values.isEmpty) {
      slots.add(_RangeSlot(start, null, null, null));
    } else {
      final min = values.reduce(math.min);
      final max = values.reduce(math.max);
      final avg = values.reduce((a, b) => a + b) / values.length;
      slots.add(_RangeSlot(start, min, max, avg));
    }
  }
  return slots;
}

class _DailyRangeChart extends StatelessWidget {
  const _DailyRangeChart({
    required this.records,
    required this.range,
    required this.period,
  });

  final List<BloodPressureRecord> records;
  final DateRange range;
  final _ChartPeriod period;

  @override
  Widget build(BuildContext context) {
    final slots = _dailyRangeSlots(records, range, period);
    if (slots.every((s) => !s.hasData)) return const _EmptyChart();

    final theme = Theme.of(context);
    final locale = context.locale.toString();
    final axisDateFormat = switch (period.axisBucket) {
      _RangeBucket.day => WesternDateFormat('ccc', locale),
      _RangeBucket.week => WesternDateFormat('d/M', locale),
      _RangeBucket.month => WesternDateFormat(
        period.dataBucket == _RangeBucket.week || slots.length <= 12
            ? 'M'
            : 'M/yy',
        locale,
      ),
    };
    String? labelAt(int index, DateTime start) {
      if (period.dataBucket == _RangeBucket.week &&
          period.axisBucket == _RangeBucket.month) {
        final labelDate = index == 0
            ? range.start
            : start.add(const Duration(days: 3));
        final month = labelDate.month;
        final previousMonth = index <= 1
            ? range.start.month
            : slots[index - 1].start.add(const Duration(days: 3)).month;
        if (index != 0 && month == previousMonth) return null;
        return axisDateFormat.format(DateTime(labelDate.year, month));
      }

      final labelEvery = slots.length > 8 ? (slots.length / 6).ceil() : 1;
      final isLabel =
          index == 0 || index == slots.length - 1 || index % labelEvery == 0;
      final nearLastLabel =
          labelEvery > 1 &&
          index != slots.length - 1 &&
          slots.length - 1 - index < 3;
      if (!isLabel || nearLastLabel) return null;
      return axisDateFormat.format(start);
    }

    return CustomPaint(
      painter: _RangeBarPainter(
        slots: slots,
        barColor: theme.colorScheme.primary,
        gridColor: theme.colorScheme.onSurface.withValues(alpha: 0.22),
        labelStyle: AppText.subtitle(
          context,
        ).copyWith(color: theme.colorScheme.onSurface),
        labelAt: labelAt,
        textDirection: Directionality.of(context),
      ),
    );
  }
}

class _RangeBarPainter extends CustomPainter {
  _RangeBarPainter({
    required this.slots,
    required this.barColor,
    required this.gridColor,
    required this.labelStyle,
    required this.labelAt,
    required this.textDirection,
  });

  final List<_RangeSlot> slots;
  final Color barColor;
  final Color gridColor;
  final TextStyle labelStyle;
  final String? Function(int, DateTime) labelAt;
  final TextDirection textDirection;

  @override
  void paint(Canvas canvas, Size size) {
    final filled = slots.where((s) => s.hasData).toList();
    if (filled.isEmpty || size.width <= 0 || size.height <= 0) return;

    var rawMin = filled.map((s) => s.min!).reduce(math.min);
    var rawMax = filled.map((s) => s.max!).reduce(math.max);
    if (rawMin == rawMax) {
      rawMin -= 8;
      rawMax += 8;
    }
    final pad = math.max(8.0, (rawMax - rawMin) * 0.18);
    final minY = ((rawMin - pad) / 10).floor() * 10.0;
    final maxY = ((rawMax + pad) / 10).ceil() * 10.0;
    final span = math.max(10.0, maxY - minY);
    final step = span <= 30
        ? 10.0
        : span <= 80
        ? 20.0
        : 40.0;

    const left = 32.0;
    const top = 16.0;
    const bottom = 22.0;
    final plot = Rect.fromLTWH(
      left,
      top,
      size.width - left,
      size.height - bottom - top,
    );
    if (plot.width <= 0 || plot.height <= 0) return;

    double yOf(double value) => plot.top + (maxY - value) / span * plot.height;

    final gridPaint = Paint()
      ..color = gridColor
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;

    for (var y = minY; y <= maxY + 0.01; y += step) {
      _dashLine(
        canvas,
        Offset(plot.left, yOf(y)),
        Offset(plot.right, yOf(y)),
        gridPaint,
      );
      final label = TextPainter(
        text: TextSpan(text: y.round().toString(), style: labelStyle),
        textDirection: textDirection,
      )..layout();
      label.paint(
        canvas,
        Offset(plot.left - 6 - label.width, yOf(y) - label.height / 2),
      );
    }

    final count = slots.length;
    final cell = plot.width / count;
    final barWidth = (cell * 0.42).clamp(2.0, 22.0);
    final barPaint = Paint()..color = barColor;
    final tickPaint = Paint()
      ..color = Color.alphaBlend(Colors.white.withValues(alpha: 0.88), barColor)
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;

    for (var i = 0; i < count; i++) {
      final slot = slots[i];
      final cx = plot.left + cell * (i + 0.5);
      if (slot.hasData) {
        var top = yOf(slot.max!);
        var bottomY = yOf(slot.min!);
        if ((bottomY - top).abs() < barWidth) {
          final mid = (top + bottomY) / 2;
          top = mid - barWidth / 2;
          bottomY = mid + barWidth / 2;
        }
        final rect = Rect.fromLTRB(
          cx - barWidth / 2,
          top,
          cx + barWidth / 2,
          bottomY,
        );
        canvas.drawRRect(
          RRect.fromRectAndRadius(rect, Radius.circular(barWidth / 2)),
          barPaint,
        );
        final ay = yOf(slot.avg!);
        canvas.drawLine(
          Offset(cx - barWidth / 2 - 1, ay),
          Offset(cx + barWidth / 2 + 1, ay),
          tickPaint,
        );
      }
      final labelText = labelAt(i, slot.start);
      if (labelText != null) {
        final label = TextPainter(
          text: TextSpan(text: labelText, style: labelStyle),
          textDirection: textDirection,
        )..layout();
        final labelLeft = (cx - label.width / 2).clamp(
          plot.left,
          plot.right - label.width,
        );
        label.paint(canvas, Offset(labelLeft, plot.bottom + 6));
      }
    }
  }

  void _dashLine(Canvas canvas, Offset a, Offset b, Paint paint) {
    const dash = 3.0;
    const gap = 5.0;
    final distance = (b - a).distance;
    if (distance == 0) return;
    final dir = (b - a) / distance;
    var d = 0.0;
    while (d < distance) {
      final start = a + dir * d;
      final end = a + dir * math.min(d + dash, distance);
      canvas.drawLine(start, end, paint);
      d += dash + gap;
    }
  }

  @override
  bool shouldRepaint(covariant _RangeBarPainter oldDelegate) =>
      oldDelegate.slots != slots ||
      oldDelegate.barColor != barColor ||
      oldDelegate.gridColor != gridColor ||
      oldDelegate.labelStyle != labelStyle ||
      oldDelegate.textDirection != textDirection ||
      oldDelegate.labelAt != labelAt;
}

int _toneRank(MetricBandTone tone) => switch (tone) {
  MetricBandTone.typical => 0,
  MetricBandTone.elevated => 1,
  MetricBandTone.high => 2,
};

Color _toneColor(MetricBandTone tone) => switch (tone) {
  MetricBandTone.typical => _inRangeColor,
  MetricBandTone.elevated => _elevatedColor,
  MetricBandTone.high => _highColor,
};

String _toneLabel(MetricBandTone tone) => switch (tone) {
  MetricBandTone.typical => 'chartInRange'.tr(),
  MetricBandTone.elevated => 'metricRangeElevated'.tr(),
  MetricBandTone.high => 'metricRangeHigh'.tr(),
};

MetricBandTone _pressureTone(PressureBand band) => switch (band) {
  PressureBand.normal => MetricBandTone.typical,
  PressureBand.elevated => MetricBandTone.elevated,
  PressureBand.high => MetricBandTone.high,
};

MetricBandTone? _classify(BloodPressureRecord record, RangeLimits limits) {
  MetricBandTone? worst;
  void consider(MetricBandTone tone) {
    if (worst == null || _toneRank(tone) > _toneRank(worst!)) {
      worst = tone;
    }
  }

  final sys = record.sys?.mmHg;
  if (sys != null) consider(_pressureTone(limits.systolicBand(sys)));
  final dia = record.dia?.mmHg;
  if (dia != null) consider(_pressureTone(limits.diastolicBand(dia)));
  return worst;
}

class _ClassificationChart extends StatelessWidget {
  const _ClassificationChart({required this.records, required this.limits});

  final List<BloodPressureRecord> records;
  final RangeLimits limits;

  @override
  Widget build(BuildContext context) {
    final counts = <MetricBandTone, int>{
      MetricBandTone.typical: 0,
      MetricBandTone.elevated: 0,
      MetricBandTone.high: 0,
    };
    var total = 0;
    for (final record in records) {
      final tone = _classify(record, limits);
      if (tone == null) continue;
      counts[tone] = counts[tone]! + 1;
      total++;
    }
    if (total == 0) return const _EmptyChart();

    const tones = [
      MetricBandTone.typical,
      MetricBandTone.elevated,
      MetricBandTone.high,
    ];
    final theme = Theme.of(context);
    final present = tones.where((tone) => counts[tone]! > 0).toList();

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: 32,
          width: double.infinity,
          child: CustomPaint(
            painter: _MixBarPainter(
              segments: [
                for (final tone in present)
                  (counts[tone]! / total, _toneColor(tone)),
              ],
            ),
            child: const SizedBox.expand(),
          ),
        ),
        const SizedBox(height: 20),
        Row(
          children: [
            for (final tone in tones)
              Expanded(
                child: _MixLegend(
                  tone: tone,
                  percent: ((counts[tone]! / total) * 100).round(),
                  labelStyle: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurface,
                  ),
                  valueStyle: theme.textTheme.headlineSmall?.copyWith(
                    color: _toneColor(tone),
                    fontWeight: FontWeight.w700,
                    height: 1.15,
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }
}

class _MixBarPainter extends CustomPainter {
  _MixBarPainter({required this.segments});

  final List<(double, Color)> segments;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0 || size.height <= 0 || segments.isEmpty) return;
    final radius = Radius.circular(size.height / 2);
    final track = RRect.fromRectAndRadius(Offset.zero & size, radius);
    canvas.clipRRect(track);
    var x = 0.0;
    for (final segment in segments) {
      final width = size.width * segment.$1;
      canvas.drawRect(
        Rect.fromLTWH(x, 0, width + 0.5, size.height),
        Paint()..color = segment.$2,
      );
      x += width;
    }
  }

  @override
  bool shouldRepaint(covariant _MixBarPainter oldDelegate) =>
      oldDelegate.segments != segments;
}

class _MixLegend extends StatelessWidget {
  const _MixLegend({
    required this.tone,
    required this.percent,
    required this.labelStyle,
    required this.valueStyle,
  });

  final MetricBandTone tone;
  final int percent;
  final TextStyle? labelStyle;
  final TextStyle? valueStyle;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: _toneColor(tone),
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              _toneLabel(tone),
              style: labelStyle,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
      const SizedBox(height: 4),
      Text('$percent%', style: valueStyle),
    ],
  );
}

class _PulsePoint {
  const _PulsePoint(this.start, this.value);

  final DateTime start;
  final double? value;
}

class _PulsePressureChart extends StatelessWidget {
  const _PulsePressureChart({
    required this.records,
    required this.range,
    required this.period,
  });

  final List<BloodPressureRecord> records;
  final DateRange range;
  final _ChartPeriod period;

  @override
  Widget build(BuildContext context) {
    final byBucket = <DateTime, List<double>>{};
    final dated =
        records
            .where((record) => record.sys != null && record.dia != null)
            .toList()
          ..sort((a, b) => a.time.compareTo(b.time));
    if (dated.isEmpty) return const _EmptyChart();
    for (final record in dated) {
      final start = _bucketStart(record.time, period.dataBucket);
      byBucket
          .putIfAbsent(start, () => [])
          .add((record.sys!.mmHg - record.dia!.mmHg).toDouble());
    }
    final points =
        _bucketStarts(
          range,
          period.dataBucket,
          firstRecord: dated.first.time,
          lastRecord: dated.last.time,
        ).map((start) {
          final values = byBucket[start];
          final average = values == null || values.isEmpty
              ? null
              : values.reduce((a, b) => a + b) / values.length;
          return _PulsePoint(start, average);
        }).toList();
    final measured = points.map((point) => point.value).whereType<double>();
    final values = measured.toList();
    if (values.length < 2) return const _EmptyChart();

    final theme = Theme.of(context);
    final locale = context.locale.toString();
    final color = theme.colorScheme.primary;
    final labelStyle = AppText.subtitle(
      context,
    ).copyWith(color: theme.colorScheme.onSurface);
    final gridColor = theme.colorScheme.onSurface.withValues(alpha: 0.28);
    final axisColor = theme.colorScheme.onSurface.withValues(alpha: 0.45);

    var minY = values.reduce(math.min);
    var maxY = values.reduce(math.max);
    if (minY == maxY) {
      minY -= 5;
      maxY += 5;
    }
    final pad = math.max(4.0, (maxY - minY) * 0.2);
    minY = math.max(0, ((minY - pad) / 10).floor() * 10.0);
    maxY = ((maxY + pad) / 10).ceil() * 10.0;
    final yStep = (maxY - minY) <= 30 ? 10.0 : 20.0;

    final axisDateFormat = switch (period.axisBucket) {
      _RangeBucket.day => WesternDateFormat('ccc', locale),
      _RangeBucket.week => WesternDateFormat('d/M', locale),
      _RangeBucket.month => WesternDateFormat(
        period.dataBucket == _RangeBucket.week || points.length <= 12
            ? 'M'
            : 'M/yy',
        locale,
      ),
    };
    final labelEvery =
        period.axisBucket == _RangeBucket.month &&
            (period.dataBucket == _RangeBucket.week || points.length <= 12)
        ? 1
        : points.length > 8
        ? (points.length / 5).ceil()
        : 1;
    final dateFormat = WesternDateFormat.yMMMd(locale);
    final isMonthlyIndex =
        period.dataBucket == _RangeBucket.week &&
        period.axisBucket == _RangeBucket.month;
    DateTime monthDateAt(int index) => index == 0
        ? range.start
        : points[index].start.add(const Duration(days: 3));
    bool isMonthBoundary(int index) =>
        index == 0 || monthDateAt(index).month != monthDateAt(index - 1).month;

    return LineChart(
      LineChartData(
        minX: -0.15,
        maxX: points.length - 0.85,
        minY: minY,
        maxY: maxY,
        clipData: const FlClipData.all(),
        gridData: FlGridData(
          drawVerticalLine: true,
          drawHorizontalLine: true,
          horizontalInterval: yStep,
          verticalInterval: 1,
          getDrawingHorizontalLine: (_) =>
              FlLine(color: gridColor, strokeWidth: 1, dashArray: const [3, 5]),
          getDrawingVerticalLine: (value) {
            if (isMonthlyIndex && !isMonthBoundary(value.round())) {
              return const FlLine(color: Colors.transparent, strokeWidth: 0);
            }
            return FlLine(
              color: gridColor,
              strokeWidth: 1,
              dashArray: const [3, 5],
            );
          },
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
              reservedSize: 32,
              interval: yStep,
              maxIncluded: false,
              getTitlesWidget: (value, meta) =>
                  valueAxisTitle(value: value, meta: meta, style: labelStyle),
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 22,
              interval: 1,
              getTitlesWidget: (value, meta) {
                final index = value.round();
                if (index < 0 || index >= points.length) {
                  return const SizedBox.shrink();
                }
                if ((value - index).abs() > 0.01) {
                  return const SizedBox.shrink();
                }
                final point = points[index];
                if (isMonthlyIndex) {
                  if (!isMonthBoundary(index)) {
                    return const SizedBox.shrink();
                  }
                  final labelDate = monthDateAt(index);
                  final month = labelDate.month;
                  final text = axisDateFormat.format(
                    DateTime(labelDate.year, month),
                  );
                  return SideTitleWidget(
                    meta: meta,
                    fitInside: SideTitleFitInsideData.fromTitleMeta(meta),
                    child: Text(text, style: labelStyle),
                  );
                }
                final isLast = index == points.length - 1;
                final sparseLabels =
                    points.length > 10 &&
                    (period.dataBucket == _RangeBucket.day ||
                        (period.dataBucket == _RangeBucket.month &&
                            points.length > 12));
                final nearLastLabel =
                    sparseLabels && !isLast && points.length - 1 - index < 3;
                if (nearLastLabel ||
                    (index != 0 && !isLast && index % labelEvery != 0)) {
                  return const SizedBox.shrink();
                }
                final text = axisDateFormat.format(point.start);
                return SideTitleWidget(
                  meta: meta,
                  fitInside: SideTitleFitInsideData.fromTitleMeta(meta),
                  child: Text(text, style: labelStyle),
                );
              },
            ),
          ),
        ),
        lineBarsData: [
          LineChartBarData(
            spots: [
              for (var i = 0; i < points.length; i++)
                if (points[i].value == null)
                  FlSpot.nullSpot
                else
                  FlSpot(i.toDouble(), points[i].value!),
            ],
            color: color,
            barWidth: 2.6,
            isCurved: true,
            curveSmoothness: 0.28,
            preventCurveOverShooting: true,
            dotData: const FlDotData(show: false),
            belowBarData: BarAreaData(
              show: true,
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  color.withValues(alpha: 0.38),
                  color.withValues(alpha: 0),
                ],
              ),
            ),
          ),
        ],
        lineTouchData: LineTouchData(
          enabled: true,
          handleBuiltInTouches: true,
          touchTooltipData: LineTouchTooltipData(
            fitInsideHorizontally: true,
            fitInsideVertically: true,
            getTooltipColor: (_) => chartTooltipColor(context),
            getTooltipItems: (touched) {
              if (touched.isEmpty) return const [];
              return [
                for (final spot in touched)
                  LineTooltipItem(
                    '${dateFormat.format(points[spot.x.round()].start)}\n'
                    '${spot.y.round()}',
                    chartTooltipValueStyle(context, color),
                  ),
              ];
            },
          ),
        ),
      ),
      key: ValueKey<String>(locale),
      duration: Duration.zero,
    );
  }
}
