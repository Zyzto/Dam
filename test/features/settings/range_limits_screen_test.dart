import 'package:blood_pressure_app/features/settings/app_settings.dart';
import 'package:blood_pressure_app/features/settings/range_limits_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../util.dart';

void main() {
  testWidgets('saves a higher obesity cutoff and can reset it', (tester) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await pumpApp(tester, await materialApp(const RangeLimitsScreen()));

    expect(find.text('Normal from'), findsOneWidget);
    expect(find.text('Systolic elevated from'), findsOneWidget);
    expect(find.text('18.5'), findsWidgets);
    expect(find.text('120'), findsOneWidget);

    await tester.tap(find.text('Obesity from'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '32');
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();

    expect(
      AppSettings.fromController(testSettingsController!).rangeLimits.bmiObeseMin,
      32,
    );

    await tester.tap(find.text('Normal from'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '40');
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();

    expect(
      AppSettings.fromController(testSettingsController!).rangeLimits.bmiNormalMin,
      18.5,
    );

    await tester.tap(find.text('Reset to standard'));
    await tester.pumpAndSettle();
    expect(
      AppSettings.fromController(testSettingsController!).rangeLimits.bmiObeseMin,
      30,
    );
  });
}
