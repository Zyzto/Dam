import 'package:blood_pressure_app/model/range_limits.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('defaults match the previous fixed bands', () {
    const limits = RangeLimits.standard;
    expect(limits.bmiBand(17), BmiBand.underweight);
    expect(limits.bmiBand(18.5), BmiBand.normal);
    expect(limits.bmiBand(24.9), BmiBand.normal);
    expect(limits.bmiBand(25), BmiBand.overweight);
    expect(limits.bmiBand(30), BmiBand.obesity);
    expect(limits.systolicBand(119), PressureBand.normal);
    expect(limits.systolicBand(120), PressureBand.elevated);
    expect(limits.systolicBand(130), PressureBand.high);
    expect(limits.diastolicBand(79), PressureBand.normal);
    expect(limits.diastolicBand(80), PressureBand.high);
  });

  test('unordered cutoffs fall back to the standard group', () {
    const limits = RangeLimits(
      bmiNormalMin: 40,
      bmiOverweightMin: 20,
      bmiObeseMin: 30,
      sysElevatedMmHg: 150,
      sysHighMmHg: 140,
      diaHighMmHg: 85,
    );
    expect(limits.bmiBand(22), BmiBand.normal);
    expect(limits.systolicBand(125), PressureBand.elevated);
    expect(limits.diastolicBand(85), PressureBand.high);
  });
}
