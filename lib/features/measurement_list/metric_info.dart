import 'package:blood_pressure_app/domain/domain.dart';
import 'package:blood_pressure_app/model/blood_pressure/pressure_unit.dart';
import 'package:blood_pressure_app/model/body_sex.dart';
import 'package:blood_pressure_app/model/range_limits.dart';
import 'package:blood_pressure_app/model/weight_unit.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

/// Metric that can open a description and range card.
enum MetricKind {
  /// Scale kilogram reading.
  weight,
  /// Body mass index.
  bmi,
  /// Body-fat percentage.
  bodyFat,
  /// Muscle mass in kilograms.
  muscle,
  /// Bone mass in kilograms.
  bone,
  /// Body-water percentage.
  water,
  /// Lean body mass in kilograms.
  lbm,
  /// Basal metabolic rate.
  bmr,
  /// Systolic pressure.
  sys,
  /// Diastolic pressure.
  dia,
  /// Pulse in bpm.
  pulse,
}

/// Color role for a range band.
enum MetricBandTone {
  /// Typical or preferred.
  typical,
  /// Elevated or low.
  elevated,
  /// High risk.
  high,
}

/// One labeled interval on a metric.
class MetricRangeBand {
  /// Create a range band.
  const MetricRangeBand({
    required this.id,
    required this.label,
    required this.tone,
    required this.interval,
    this.min,
    this.maxExclusive,
  });

  /// Stable id for tests.
  final String id;

  /// Localized band name.
  final String label;

  /// Color role.
  final MetricBandTone tone;

  /// Displayed interval, such as `18.5–24.9`.
  final String interval;

  /// Inclusive lower bound, when the band has one.
  final double? min;

  /// Exclusive upper bound, when the band has one.
  final double? maxExclusive;

  /// Whether [value] falls in this band.
  bool contains(double value) {
    if (min != null && value < min!) return false;
    if (maxExclusive != null && value >= maxExclusive!) return false;
    return true;
  }
}

/// Localized description, ranges, and the band that contains [current].
class MetricInfo {
  /// Create a resolved metric card model.
  const MetricInfo({
    required this.kind,
    required this.title,
    required this.description,
    required this.formattedValue,
    required this.icon,
    required this.current,
    required this.bands,
    this.warnLabel,
    this.note,
    this.barMin,
    this.barMax,
  });

  /// Which metric this describes.
  final MetricKind kind;

  /// Localized title.
  final String title;

  /// Localized explanation.
  final String description;

  /// Current reading as shown on the details row.
  final String formattedValue;

  /// Icon used on the details row.
  final IconData icon;

  /// Numeric current value used for classification.
  final double current;

  /// Ordered bands, when the metric has them.
  final List<MetricRangeBand> bands;

  /// Optional “Warn at …” chip for sys/dia.
  final String? warnLabel;

  /// Optional extra chip when there are no numeric bands.
  final String? note;

  /// Lower bound of the segment bar.
  final double? barMin;

  /// Upper bound of the segment bar.
  final double? barMax;

  /// Whether a segmented range bar can be drawn.
  bool get showBar =>
      bands.length >= 2 && barMin != null && barMax != null && barMax! > barMin!;

  /// Band that contains [current], when any does.
  MetricRangeBand? get currentBand {
    for (final band in bands) {
      if (band.contains(current)) return band;
    }
    return null;
  }

  /// 0–1 position of [current] on the segment bar.
  double get barFraction {
    if (!showBar) return 0;
    return ((current - barMin!) / (barMax! - barMin!)).clamp(0.0, 1.0);
  }

  /// Build localized info for [kind].
  static MetricInfo resolve({
    required MetricKind kind,
    required double current,
    required String formattedValue,
    BodySex? sex,
    double? heightCm,
    double? weightKg,
    WeightUnit weightUnit = WeightUnit.kg,
    PressureUnit pressureUnit = PressureUnit.mmHg,
    int sysWarn = 120,
    int diaWarn = 80,
    RangeLimits limits = RangeLimits.standard,
  }) {
    switch (kind) {
      case MetricKind.weight:
        return _weight(
          current: current,
          formattedValue: formattedValue,
          heightCm: heightCm,
          weightUnit: weightUnit,
          limits: limits,
        );
      case MetricKind.bmi:
        return _bmi(current, formattedValue, limits);
      case MetricKind.bodyFat:
        return _bodyFat(current, formattedValue, sex);
      case MetricKind.muscle:
        return MetricInfo(
          kind: kind,
          title: 'muscleMass'.tr(),
          description: 'metricInfoMuscleDesc'.tr(),
          formattedValue: formattedValue,
          icon: Icons.fitness_center,
          current: current,
          bands: const [],
          note: 'metricHigherIsBetter'.tr(),
        );
      case MetricKind.bone:
        return _bone(current, formattedValue, weightKg);
      case MetricKind.water:
        return _water(current, formattedValue, sex);
      case MetricKind.lbm:
        return MetricInfo(
          kind: kind,
          title: 'leanBodyMass'.tr(),
          description: 'metricInfoLbmDesc'.tr(),
          formattedValue: formattedValue,
          icon: Icons.monitor_weight_outlined,
          current: current,
          bands: const [],
        );
      case MetricKind.bmr:
        return MetricInfo(
          kind: kind,
          title: 'bmr'.tr(),
          description: 'metricInfoBmrDesc'.tr(),
          formattedValue: formattedValue,
          icon: Icons.local_fire_department_outlined,
          current: current,
          bands: const [],
        );
      case MetricKind.sys:
        return _sys(current, formattedValue, pressureUnit, sysWarn, limits);
      case MetricKind.dia:
        return _dia(current, formattedValue, pressureUnit, diaWarn, limits);
      case MetricKind.pulse:
        return _pulse(current, formattedValue);
    }
  }

  static MetricInfo _weight({
    required double current,
    required String formattedValue,
    required double? heightCm,
    required WeightUnit weightUnit,
    required RangeLimits limits,
  }) {
    final bands = <MetricRangeBand>[];
    double? barMin;
    double? barMax;
    if (heightCm != null && heightCm > 0) {
      final cut = limits.valid;
      final heightM = heightCm / 100;
      final unit = weightUnit.displayName;
      double at(double bmi) =>
          weightUnit.extract(Weight.kg(bmi * heightM * heightM));
      final normal = at(cut.bmiNormalMin);
      final overweight = at(cut.bmiOverweightMin);
      final obese = at(cut.bmiObeseMin);
      bands.addAll([
        MetricRangeBand(
          id: 'underweight',
          label: 'metricRangeUnderweight'.tr(),
          tone: MetricBandTone.elevated,
          interval: '< ${_format(normal)} $unit',
          maxExclusive: normal,
        ),
        MetricRangeBand(
          id: 'normal',
          label: 'metricRangeNormal'.tr(),
          tone: MetricBandTone.typical,
          interval: '${_format(normal)}–${_format(overweight - 0.1)} $unit',
          min: normal,
          maxExclusive: overweight,
        ),
        MetricRangeBand(
          id: 'overweight',
          label: 'metricRangeOverweight'.tr(),
          tone: MetricBandTone.elevated,
          interval: '${_format(overweight)}–${_format(obese - 0.1)} $unit',
          min: overweight,
          maxExclusive: obese,
        ),
        MetricRangeBand(
          id: 'obesity',
          label: 'metricRangeObesity'.tr(),
          tone: MetricBandTone.high,
          interval: '≥ ${_format(obese)} $unit',
          min: obese,
        ),
      ]);
      barMin = normal * 0.7;
      barMax = obese * 1.2;
    }
    return MetricInfo(
      kind: MetricKind.weight,
      title: 'weight'.tr(),
      description: 'metricInfoWeightDesc'.tr(),
      formattedValue: formattedValue,
      icon: Icons.scale,
      current: current,
      bands: bands,
      barMin: barMin,
      barMax: barMax,
    );
  }

  static MetricInfo _bmi(
    double current,
    String formattedValue,
    RangeLimits limits,
  ) {
    final cut = limits.valid;
    return MetricInfo(
      kind: MetricKind.bmi,
      title: 'bmi'.tr(),
      description: 'metricInfoBmiDesc'.tr(),
      formattedValue: formattedValue,
      icon: Icons.monitor_heart_outlined,
      current: current,
      barMin: (cut.bmiNormalMin - 6).clamp(8, 20),
      barMax: cut.bmiObeseMin + 10,
      bands: [
        MetricRangeBand(
          id: 'underweight',
          label: 'metricRangeUnderweight'.tr(),
          tone: MetricBandTone.elevated,
          interval: '< ${_format(cut.bmiNormalMin)}',
          maxExclusive: cut.bmiNormalMin,
        ),
        MetricRangeBand(
          id: 'normal',
          label: 'metricRangeNormal'.tr(),
          tone: MetricBandTone.typical,
          interval:
              '${_format(cut.bmiNormalMin)}–${_format(cut.bmiOverweightMin - 0.1)}',
          min: cut.bmiNormalMin,
          maxExclusive: cut.bmiOverweightMin,
        ),
        MetricRangeBand(
          id: 'overweight',
          label: 'metricRangeOverweight'.tr(),
          tone: MetricBandTone.elevated,
          interval:
              '${_format(cut.bmiOverweightMin)}–${_format(cut.bmiObeseMin - 0.1)}',
          min: cut.bmiOverweightMin,
          maxExclusive: cut.bmiObeseMin,
        ),
        MetricRangeBand(
          id: 'obesity',
          label: 'metricRangeObesity'.tr(),
          tone: MetricBandTone.high,
          interval: '≥ ${_format(cut.bmiObeseMin)}',
          min: cut.bmiObeseMin,
        ),
      ],
    );
  }

  static MetricInfo _bodyFat(
    double current,
    String formattedValue,
    BodySex? sex,
  ) {
    final bands = sex == BodySex.male
        ? [
            MetricRangeBand(
              id: 'low',
              label: 'metricRangeLow'.tr(),
              tone: MetricBandTone.elevated,
              interval: '< 10 %',
              maxExclusive: 10,
            ),
            MetricRangeBand(
              id: 'typical',
              label: 'metricRangeTypical'.tr(),
              tone: MetricBandTone.typical,
              interval: '10–20 %',
              min: 10,
              maxExclusive: 20.05,
            ),
            MetricRangeBand(
              id: 'high',
              label: 'metricRangeHigh'.tr(),
              tone: MetricBandTone.high,
              interval: '> 20 %',
              min: 20.05,
            ),
          ]
        : sex == BodySex.female
            ? [
                MetricRangeBand(
                  id: 'low',
                  label: 'metricRangeLow'.tr(),
                  tone: MetricBandTone.elevated,
                  interval: '< 18 %',
                  maxExclusive: 18,
                ),
                MetricRangeBand(
                  id: 'typical',
                  label: 'metricRangeTypical'.tr(),
                  tone: MetricBandTone.typical,
                  interval: '18–28 %',
                  min: 18,
                  maxExclusive: 28.05,
                ),
                MetricRangeBand(
                  id: 'high',
                  label: 'metricRangeHigh'.tr(),
                  tone: MetricBandTone.high,
                  interval: '> 28 %',
                  min: 28.05,
                ),
              ]
            : [
                MetricRangeBand(
                  id: 'low',
                  label: 'metricRangeLow'.tr(),
                  tone: MetricBandTone.elevated,
                  interval: '< 10 %',
                  maxExclusive: 10,
                ),
                MetricRangeBand(
                  id: 'typicalMen',
                  label: 'metricRangeTypicalMen'.tr(),
                  tone: MetricBandTone.typical,
                  interval: '10–20 %',
                  min: 10,
                  maxExclusive: 20.05,
                ),
                MetricRangeBand(
                  id: 'typicalWomen',
                  label: 'metricRangeTypicalWomen'.tr(),
                  tone: MetricBandTone.typical,
                  interval: '18–28 %',
                  min: 18,
                  maxExclusive: 28.05,
                ),
                MetricRangeBand(
                  id: 'high',
                  label: 'metricRangeHigh'.tr(),
                  tone: MetricBandTone.high,
                  interval: '> 28 %',
                  min: 28.05,
                ),
              ];
    return MetricInfo(
      kind: MetricKind.bodyFat,
      title: 'bodyFat'.tr(),
      description: 'metricInfoFatDesc'.tr(),
      formattedValue: formattedValue,
      icon: Icons.pie_chart_outline,
      current: current,
      bands: bands,
      barMin: 2,
      barMax: 45,
    );
  }

  static MetricInfo _bone(
    double currentKg,
    String formattedValue,
    double? weightKg,
  ) {
    final percent = weightKg != null && weightKg > 0
        ? currentKg / weightKg * 100
        : currentKg;
    return MetricInfo(
      kind: MetricKind.bone,
      title: 'boneMass'.tr(),
      description: 'metricInfoBoneDesc'.tr(),
      formattedValue: formattedValue,
      icon: Icons.accessibility,
      current: percent,
      barMin: 1,
      barMax: 8,
      bands: [
        MetricRangeBand(
          id: 'typical',
          label: 'metricRangeTypical'.tr(),
          tone: MetricBandTone.typical,
          interval: '2.5–5 %',
          min: 2.5,
          maxExclusive: 5.05,
        ),
      ],
    );
  }

  static MetricInfo _water(
    double current,
    String formattedValue,
    BodySex? sex,
  ) {
    final bands = sex == BodySex.male
        ? [
            MetricRangeBand(
              id: 'low',
              label: 'metricRangeLow'.tr(),
              tone: MetricBandTone.elevated,
              interval: '< 50 %',
              maxExclusive: 50,
            ),
            MetricRangeBand(
              id: 'typical',
              label: 'metricRangeTypical'.tr(),
              tone: MetricBandTone.typical,
              interval: '50–65 %',
              min: 50,
              maxExclusive: 65.05,
            ),
            MetricRangeBand(
              id: 'high',
              label: 'metricRangeHigh'.tr(),
              tone: MetricBandTone.elevated,
              interval: '> 65 %',
              min: 65.05,
            ),
          ]
        : sex == BodySex.female
            ? [
                MetricRangeBand(
                  id: 'low',
                  label: 'metricRangeLow'.tr(),
                  tone: MetricBandTone.elevated,
                  interval: '< 45 %',
                  maxExclusive: 45,
                ),
                MetricRangeBand(
                  id: 'typical',
                  label: 'metricRangeTypical'.tr(),
                  tone: MetricBandTone.typical,
                  interval: '45–60 %',
                  min: 45,
                  maxExclusive: 60.05,
                ),
                MetricRangeBand(
                  id: 'high',
                  label: 'metricRangeHigh'.tr(),
                  tone: MetricBandTone.elevated,
                  interval: '> 60 %',
                  min: 60.05,
                ),
              ]
            : [
                MetricRangeBand(
                  id: 'typicalMen',
                  label: 'metricRangeTypicalMen'.tr(),
                  tone: MetricBandTone.typical,
                  interval: '50–65 %',
                  min: 50,
                  maxExclusive: 65.05,
                ),
                MetricRangeBand(
                  id: 'typicalWomen',
                  label: 'metricRangeTypicalWomen'.tr(),
                  tone: MetricBandTone.typical,
                  interval: '45–60 %',
                  min: 45,
                  maxExclusive: 60.05,
                ),
              ];
    return MetricInfo(
      kind: MetricKind.water,
      title: 'bodyWater'.tr(),
      description: 'metricInfoWaterDesc'.tr(),
      formattedValue: formattedValue,
      icon: Icons.water_drop_outlined,
      current: current,
      bands: bands,
      barMin: 30,
      barMax: 80,
    );
  }

  static MetricInfo _sys(
    double current,
    String formattedValue,
    PressureUnit unit,
    int sysWarn,
    RangeLimits limits,
  ) {
    final cut = limits.valid;
    final elevated = _pressure(cut.sysElevatedMmHg, unit);
    final high = _pressure(cut.sysHighMmHg, unit);
    final belowHigh = _pressure(cut.sysHighMmHg - 1, unit);
    final barFloor = cut.sysElevatedMmHg - 40;
    final digits = unit == PressureUnit.kPa ? 1 : 0;
    final suffix = unit == PressureUnit.kPa ? ' kPa' : '';
    return MetricInfo(
      kind: MetricKind.sys,
      title: 'sysLong'.tr(),
      description: 'metricInfoSysDesc'.tr(),
      formattedValue: formattedValue,
      icon: Icons.favorite_outline,
      current: current,
      barMin: _pressure(barFloor < 40 ? 40 : barFloor, unit),
      barMax: _pressure(cut.sysHighMmHg + 50, unit),
      warnLabel: 'metricWarnAt'.tr(namedArgs: {'value': _format(_pressure(sysWarn, unit), digits) + suffix}),
      bands: [
        MetricRangeBand(
          id: 'normal',
          label: 'metricRangeNormal'.tr(),
          tone: MetricBandTone.typical,
          interval: '< ${_format(elevated, digits)}$suffix',
          maxExclusive: elevated,
        ),
        MetricRangeBand(
          id: 'elevated',
          label: 'metricRangeElevated'.tr(),
          tone: MetricBandTone.elevated,
          interval: '${_format(elevated, digits)}–${_format(belowHigh, digits)}$suffix',
          min: elevated,
          maxExclusive: high,
        ),
        MetricRangeBand(
          id: 'high',
          label: 'metricRangeHigh'.tr(),
          tone: MetricBandTone.high,
          interval: '≥ ${_format(high, digits)}$suffix',
          min: high,
        ),
      ],
    );
  }

  static MetricInfo _dia(
    double current,
    String formattedValue,
    PressureUnit unit,
    int diaWarn,
    RangeLimits limits,
  ) {
    final cut = limits.valid;
    final high = _pressure(cut.diaHighMmHg, unit);
    final barFloor = cut.diaHighMmHg - 40;
    final digits = unit == PressureUnit.kPa ? 1 : 0;
    final suffix = unit == PressureUnit.kPa ? ' kPa' : '';
    return MetricInfo(
      kind: MetricKind.dia,
      title: 'diaLong'.tr(),
      description: 'metricInfoDiaDesc'.tr(),
      formattedValue: formattedValue,
      icon: Icons.favorite_outline,
      current: current,
      barMin: _pressure(barFloor < 30 ? 30 : barFloor, unit),
      barMax: _pressure(cut.diaHighMmHg + 40, unit),
      warnLabel: 'metricWarnAt'.tr(namedArgs: {
        'value': '${_format(_pressure(diaWarn, unit), digits)}$suffix',
      }),
      bands: [
        MetricRangeBand(
          id: 'normal',
          label: 'metricRangeNormal'.tr(),
          tone: MetricBandTone.typical,
          interval: '< ${_format(high, digits)}$suffix',
          maxExclusive: high,
        ),
        MetricRangeBand(
          id: 'high',
          label: 'metricRangeHigh'.tr(),
          tone: MetricBandTone.high,
          interval: '≥ ${_format(high, digits)}$suffix',
          min: high,
        ),
      ],
    );
  }

  static MetricInfo _pulse(
    double current,
    String formattedValue,
  ) => MetricInfo(
    kind: MetricKind.pulse,
    title: 'pulLong'.tr(),
    description: 'metricInfoPulDesc'.tr(),
    formattedValue: formattedValue,
    icon: Icons.monitor_heart_outlined,
    current: current,
    barMin: 40,
    barMax: 140,
    bands: [
      MetricRangeBand(
        id: 'low',
        label: 'metricRangeLow'.tr(),
        tone: MetricBandTone.elevated,
        interval: '< 60',
        maxExclusive: 60,
      ),
      MetricRangeBand(
        id: 'typical',
        label: 'metricRangeTypical'.tr(),
        tone: MetricBandTone.typical,
        interval: '60–100',
        min: 60,
        maxExclusive: 100.05,
      ),
      MetricRangeBand(
        id: 'high',
        label: 'metricRangeHigh'.tr(),
        tone: MetricBandTone.elevated,
        interval: '> 100',
        min: 100.05,
      ),
    ],
  );

  static double _pressure(int mmHg, PressureUnit unit) => switch (unit) {
    PressureUnit.mmHg => mmHg.toDouble(),
    PressureUnit.kPa => Pressure.mmHg(mmHg).kPa,
  };

  static String _format(double value, [int digits = 1]) {
    final text = value.toStringAsFixed(digits);
    if (!text.contains('.')) return text;
    var trimmed = text;
    while (trimmed.endsWith('0')) {
      trimmed = trimmed.substring(0, trimmed.length - 1);
    }
    if (trimmed.endsWith('.')) {
      trimmed = trimmed.substring(0, trimmed.length - 1);
    }
    return trimmed;
  }
}

/// Color for [tone] on the current theme.
Color metricBandColor(MetricBandTone tone) => switch (tone) {
  MetricBandTone.typical => Colors.green,
  MetricBandTone.elevated => Colors.amber.shade700,
  MetricBandTone.high => Colors.red,
};
