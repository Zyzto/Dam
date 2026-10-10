import 'package:blood_pressure_app/screens/settings_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_settings_framework/safaeh.dart';
import 'package:flutter_test/flutter_test.dart';

import '../util.dart';

void main() {
  testWidgets('phone settings show the Safaeh page index and search', (
    tester,
  ) async {
    usePhoneTestSurface(tester);

    await pumpApp(tester, await materialApp(const SettingsPage()));
    await tester.pump();

    expect(find.byType(SafaehSettingsPageIndexOverlay), findsOneWidget);
    expect(find.byType(SafaehSettingsSearchButton), findsOneWidget);
    expect(find.text('On this page'), findsOneWidget);

    await tester.tap(find.byType(SafaehSettingsSearchButton));
    await tester.pump();
    expect(
      find.byKey(const ValueKey('safaeh_settings_search_field')),
      findsOneWidget,
    );

    await tester.enterText(
      find.byKey(const ValueKey('safaeh_settings_search_field')),
      'theme',
    );
    await tester.pump();
    expect(find.text('Theme'), findsWidgets);
  });

  testWidgets('wide settings show the Safaeh page index rail', (tester) async {
    tester.view.physicalSize = const Size(1000, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await pumpApp(tester, await materialApp(const SettingsPage()));
    await tester.pump();

    expect(find.byType(SafaehSettingsPageIndex), findsOneWidget);
    expect(find.byType(SafaehSettingsPageIndexOverlay), findsNothing);
  });

  testWidgets('theme and language use Safaeh phone picker sheets', (
    tester,
  ) async {
    usePhoneTestSurface(tester);

    await pumpApp(tester, await materialApp(const SettingsPage()));

    await tester.tap(find.text('Theme').last);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('safaeh_drag_handle')), findsOneWidget);
    expect(find.text('Dark'), findsOneWidget);
    await tester.tap(find.text('Dark'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Language').last);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('safaeh_drag_handle')), findsOneWidget);
    expect(find.text('English'), findsOneWidget);
    await tester.tap(find.text('English'));
    await tester.pumpAndSettle();
  });

  testWidgets('date format uses a Safaeh picker of presets', (tester) async {
    usePhoneTestSurface(tester);

    await pumpApp(tester, await materialApp(const SettingsPage()));

    await tester.tap(find.text('Time format').last);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('safaeh_drag_handle')), findsOneWidget);
    expect(find.byType(SafaehTilePickerBody<String>), findsOneWidget);
    expect(find.text('yyyy-MM-dd HH:mm'), findsOneWidget);
    expect(find.text('dd/MM/yyyy HH:mm'), findsOneWidget);
    expect(find.text('MM/dd/yyyy h:mm a'), findsOneWidget);

    await tester.tap(find.text('dd/MM/yyyy HH:mm'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('safaeh_drag_handle')), findsNothing);
  });

  testWidgets('advanced groups start collapsed', (tester) async {
    usePhoneTestSurface(tester);

    await pumpApp(tester, await materialApp(const SettingsPage()));

    expect(find.text('Advanced'), findsWidgets);
    expect(find.text('Bottom dialog bars'), findsNothing);
    expect(find.text('Animation duration'), findsNothing);
    expect(find.text('Validate inputs'), findsNothing);

    await tester.tap(find.text('Advanced').first);
    await tester.pumpAndSettle();

    expect(find.text('Bottom dialog bars'), findsOneWidget);
    expect(find.text('Animation duration'), findsNothing);
  });

  testWidgets('opening advanced keeps the rows above it still', (tester) async {
    usePhoneTestSurface(tester);

    await pumpApp(tester, await materialApp(const SettingsPage()));

    final advanced = find.text('Advanced').first;
    await Scrollable.ensureVisible(tester.element(advanced), alignment: 0.8);
    await tester.pump();

    final above = find.text('Confirm deletion');
    final before = tester.getTopLeft(above).dy;
    await tester.tapAt(tester.getCenter(advanced));
    for (final elapsed in [16, 50, 100, 200]) {
      await tester.pump(Duration(milliseconds: elapsed));
      expect(
        tester.getTopLeft(above).dy,
        closeTo(before, 4),
        reason: 'Opening Advanced should not visibly move rows above it.',
      );
    }
    expect(tester.getTopLeft(above).dy, closeTo(before, 1));
  });

  testWidgets('theme color uses a flat color list', (tester) async {
    usePhoneTestSurface(tester);

    await pumpApp(tester, await materialApp(const SettingsPage()));

    await tester.tap(find.text('Theme color').last);
    await tester.pumpAndSettle();

    expect(_swatch(0xFFF44336), findsWidgets);
    expect(_swatch(0xFF009688), findsWidgets);
    expect(find.text('Red'), findsNothing);
    expect(find.text('OK'), findsNothing);
    expect(find.text('Cancel'), findsNothing);
  });
}

Finder _swatch(int argb) => find.byWidgetPredicate((widget) {
  if (widget is! AnimatedContainer) return false;
  final decoration = widget.decoration;
  final color = decoration is BoxDecoration ? decoration.color : null;
  return color != null && color.toARGB32() == argb;
});
