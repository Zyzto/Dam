/// One blood-pressure point used by the PDF trend chart, ordered oldest first.
class PdfExportChartPoint {
  /// Create a point in the preferred pressure unit.
  const PdfExportChartPoint({
    required this.time,
    required this.systolic,
    required this.diastolic,
  });

  /// Reading timestamp.
  final DateTime time;

  /// Systolic in the selected pressure unit, when present.
  final double? systolic;

  /// Diastolic in the selected pressure unit, when present.
  final double? diastolic;
}

/// One body-weight point for the PDF weight chart, oldest first.
class PdfWeightPoint {
  /// Create a point in the preferred weight unit.
  const PdfWeightPoint({required this.time, required this.value});

  /// Measurement timestamp.
  final DateTime time;

  /// Weight in the preferred unit.
  final double value;
}

/// Body-weight series shown under the blood-pressure summary.
class PdfWeightSeries {
  /// Create the weight block.
  const PdfWeightSeries({
    required this.points,
    required this.latest,
    required this.average,
  });

  /// Points oldest first. Empty when the export has no weight.
  final List<PdfWeightPoint> points;

  /// Newest weight, formatted with its unit.
  final String latest;

  /// Mean weight, formatted with its unit.
  final String average;
}

/// One dose on a medicine chart.
class PdfMedicineDose {
  /// Create a dose point.
  const PdfMedicineDose({required this.time, required this.amount});

  /// When the dose was taken.
  final DateTime time;

  /// Amount in the medicine's own unit, as entered.
  final double amount;
}

/// Doses of one medicine, for a chart or a single line.
class PdfMedicineSeries {
  /// Create a per-medicine series.
  const PdfMedicineSeries({
    required this.name,
    required this.unit,
    required this.latestLabel,
    required this.doses,
    this.color,
  });

  /// Medicine name.
  final String name;

  /// Unit symbol, such as `mg` or `tab`.
  final String unit;

  /// Newest dose, such as `5 mg`.
  final String latestLabel;

  /// Doses oldest first.
  final List<PdfMedicineDose> doses;

  /// ARGB medicine color, when one was chosen.
  final int? color;
}
