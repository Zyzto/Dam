/// User cutoffs for BMI categories and blood-pressure bands.
///
/// Defaults match the ranges the app already used: WHO BMI splits at 18.5,
/// 25, and 30, systolic bands at 120 and 130 mmHg, and diastolic high at
/// 80 mmHg. A value that lands on a cutoff belongs to the higher band.
class RangeLimits {
  /// Create cutoffs. Out-of-order values are kept as entered; classification
  /// uses [valid], which falls back to the defaults for that group.
  const RangeLimits({
    this.bmiNormalMin = defaultBmiNormalMin,
    this.bmiOverweightMin = defaultBmiOverweightMin,
    this.bmiObeseMin = defaultBmiObeseMin,
    this.sysElevatedMmHg = defaultSysElevatedMmHg,
    this.sysHighMmHg = defaultSysHighMmHg,
    this.diaHighMmHg = defaultDiaHighMmHg,
  });

  /// BMI at which a reading leaves underweight.
  static const defaultBmiNormalMin = 18.5;

  /// BMI at which a reading becomes overweight.
  static const defaultBmiOverweightMin = 25.0;

  /// BMI at which a reading becomes obese.
  static const defaultBmiObeseMin = 30.0;

  /// Systolic mmHg at which a reading leaves normal.
  static const defaultSysElevatedMmHg = 120;

  /// Systolic mmHg at which a reading becomes high.
  static const defaultSysHighMmHg = 130;

  /// Diastolic mmHg at which a reading becomes high.
  static const defaultDiaHighMmHg = 80;

  /// Standard WHO and simplified blood-pressure cutoffs.
  static const standard = RangeLimits();

  /// Inclusive start of the normal BMI band.
  final double bmiNormalMin;

  /// Inclusive start of the overweight BMI band.
  final double bmiOverweightMin;

  /// Inclusive start of the obese BMI band.
  final double bmiObeseMin;

  /// Inclusive start of elevated systolic, in mmHg.
  final int sysElevatedMmHg;

  /// Inclusive start of high systolic, in mmHg.
  final int sysHighMmHg;

  /// Inclusive start of high diastolic, in mmHg.
  final int diaHighMmHg;

  /// Whether the BMI cutoffs rise and stay inside a usable span.
  bool get bmiOrdered =>
      bmiNormalMin >= 10 &&
      bmiNormalMin < bmiOverweightMin &&
      bmiOverweightMin < bmiObeseMin &&
      bmiObeseMin <= 70;

  /// Whether the systolic cutoffs rise and stay inside a usable span.
  bool get sysOrdered =>
      sysElevatedMmHg >= 70 &&
      sysElevatedMmHg < sysHighMmHg &&
      sysHighMmHg <= 250;

  /// Whether the diastolic cutoff stays inside a usable span.
  bool get diaOrdered => diaHighMmHg >= 40 && diaHighMmHg <= 150;

  /// These cutoffs with any unordered group replaced by [standard].
  RangeLimits get valid => RangeLimits(
    bmiNormalMin: bmiOrdered ? bmiNormalMin : defaultBmiNormalMin,
    bmiOverweightMin: bmiOrdered ? bmiOverweightMin : defaultBmiOverweightMin,
    bmiObeseMin: bmiOrdered ? bmiObeseMin : defaultBmiObeseMin,
    sysElevatedMmHg: sysOrdered ? sysElevatedMmHg : defaultSysElevatedMmHg,
    sysHighMmHg: sysOrdered ? sysHighMmHg : defaultSysHighMmHg,
    diaHighMmHg: diaOrdered ? diaHighMmHg : defaultDiaHighMmHg,
  );

  /// Copy with the provided cutoffs replaced.
  RangeLimits copyWith({
    double? bmiNormalMin,
    double? bmiOverweightMin,
    double? bmiObeseMin,
    int? sysElevatedMmHg,
    int? sysHighMmHg,
    int? diaHighMmHg,
  }) => RangeLimits(
    bmiNormalMin: bmiNormalMin ?? this.bmiNormalMin,
    bmiOverweightMin: bmiOverweightMin ?? this.bmiOverweightMin,
    bmiObeseMin: bmiObeseMin ?? this.bmiObeseMin,
    sysElevatedMmHg: sysElevatedMmHg ?? this.sysElevatedMmHg,
    sysHighMmHg: sysHighMmHg ?? this.sysHighMmHg,
    diaHighMmHg: diaHighMmHg ?? this.diaHighMmHg,
  );

  /// BMI category for [bmi].
  BmiBand bmiBand(double bmi) {
    final limits = valid;
    if (bmi < limits.bmiNormalMin) return BmiBand.underweight;
    if (bmi < limits.bmiOverweightMin) return BmiBand.normal;
    if (bmi < limits.bmiObeseMin) return BmiBand.overweight;
    return BmiBand.obesity;
  }

  /// Systolic category for a reading in mmHg.
  PressureBand systolicBand(num mmHg) {
    final limits = valid;
    if (mmHg < limits.sysElevatedMmHg) return PressureBand.normal;
    if (mmHg < limits.sysHighMmHg) return PressureBand.elevated;
    return PressureBand.high;
  }

  /// Diastolic category for a reading in mmHg.
  PressureBand diastolicBand(num mmHg) => mmHg < valid.diaHighMmHg
      ? PressureBand.normal
      : PressureBand.high;
}

/// Body-mass categories controlled by [RangeLimits].
enum BmiBand {
  /// Below the normal cutoff.
  underweight,

  /// From the normal cutoff up to overweight.
  normal,

  /// From the overweight cutoff up to obesity.
  overweight,

  /// At or above the obesity cutoff.
  obesity,
}

/// Blood-pressure categories controlled by [RangeLimits].
enum PressureBand {
  /// Below the first cutoff.
  normal,

  /// From the elevated cutoff up to high. Systolic only.
  elevated,

  /// At or above the high cutoff.
  high,
}
