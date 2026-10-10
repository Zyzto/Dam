import 'package:blood_pressure_app/features/bluetooth/logic/ble_launch_sync.dart';
import 'package:blood_pressure_app/features/bluetooth/ui/ble_launch_sync_host.dart';
import 'package:blood_pressure_app/features/home/ble_home_sync_indicator.dart';
import 'package:blood_pressure_app/features/measurement_list/measurement_filter_scope.dart';
import 'package:blood_pressure_app/features/measurement_list/measurement_list.dart';
import 'package:blood_pressure_app/features/shell/dashboard_app_bar.dart';
import 'package:blood_pressure_app/model/bluetooth_input_mode.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:safaeh/safaeh.dart';

import '../../util.dart';

const _titles = ['measurements', 'weight', 'statistics', 'settings'];

Future<Widget> _bar(BleLaunchSyncView view, ValueNotifier<double> page) =>
    materialApp(
      BleLaunchSyncScope(
        notifier: view,
        child: MeasurementFilterScope(
          controller: MeasurementFilterController(),
          child: ValueListenableBuilder<double>(
            valueListenable: page,
            builder: (context, value, _) => Scaffold(
              appBar: DashboardAppBar(page: value, titleKeys: _titles),
            ),
          ),
        ),
      ),
      settings: TestSettingsSeed(
        syncBluetoothOnLaunch: true,
        bleInput: BluetoothInputMode.newBluetoothInputCrossPlatform,
        bloodPressureEnabled: true,
        medicineFeatureEnabled: true,
        weightInput: true,
      ),
    );

double _nearestOpacity(WidgetTester tester, Finder target) {
  final opacity = find.ancestor(of: target, matching: find.byType(Opacity));
  expect(opacity, findsWidgets);
  return tester.widget<Opacity>(opacity.first).opacity;
}

void main() {
  testWidgets('keeps the bluetooth button on every main screen', (tester) async {
    final view = BleLaunchSyncView()
      ..setProgress(
        const BleLaunchSyncProgress(phase: BleLaunchSyncPhase.scanning),
      );
    final page = ValueNotifier<double>(0);
    addTearDown(page.dispose);
    await pumpApp(tester, await _bar(view, page));

    final bluetooth = find.byType(BleHomeSyncIndicator);
    final filter = find.byType(
      SafaehAnchoredDropdownChip<MeasurementListFilter>,
    );

    expect(_nearestOpacity(tester, bluetooth), 1);
    expect(_nearestOpacity(tester, filter), 1);

    for (final dataPage in [1.0, 2.0]) {
      page.value = dataPage;
      await tester.pump();
      expect(_nearestOpacity(tester, bluetooth), 1);
      expect(_nearestOpacity(tester, filter), 0);
    }

    page.value = 3;
    await tester.pump();
    expect(_nearestOpacity(tester, bluetooth), 0);

    page.value = 1;
    await tester.pump();
    await tester.tap(bluetooth);
    await tester.pump();
    expect(view.detailsOpen, isTrue);
  });
}
