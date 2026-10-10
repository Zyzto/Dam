import 'package:blood_pressure_app/features/bluetooth/logic/ble_launch_sync.dart';
import 'package:blood_pressure_app/features/bluetooth/ui/ble_launch_sync_card.dart';
import 'package:blood_pressure_app/features/bluetooth/ui/ble_launch_sync_host.dart';
import 'package:blood_pressure_app/features/home/ble_home_sync_indicator.dart';
import 'package:blood_pressure_app/model/bluetooth_input_mode.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../util.dart';

TestSettingsSeed _enabledSettings() => TestSettingsSeed(
  syncBluetoothOnLaunch: true,
  bleInput: BluetoothInputMode.newBluetoothInputCrossPlatform,
);

Future<Widget> _indicator(
  BleLaunchSyncView view, {
  TestSettingsSeed? settings,
  Locale locale = const Locale('en'),
  Widget? trailing,
}) => materialApp(
  BleLaunchSyncScope(
    notifier: view,
    child: Scaffold(
      appBar: AppBar(
        actions: [
          const BleHomeSyncIndicator(),
          ?trailing,
        ],
      ),
      body: const BleLaunchSyncPopout(),
    ),
  ),
  settings: settings ?? _enabledSettings(),
  locale: locale,
);

void _expectPanelOnScreen(WidgetTester tester) {
  final card = tester.getRect(find.byType(BleLaunchSyncCard));
  final screen = Offset.zero & tester.view.physicalSize / tester.view.devicePixelRatio;
  expect(card.left, greaterThanOrEqualTo(0), reason: 'card $card screen $screen');
  expect(card.right, lessThanOrEqualTo(screen.width), reason: 'card $card screen $screen');
  expect(card.top, greaterThanOrEqualTo(0));
  expect(card.bottom, lessThanOrEqualTo(screen.height));
}

/// The filter sits outside the indicator, on the screen's end edge.
/// The card must stay on screen and still cover that indicator.
void _expectPanelBesideFilter(WidgetTester tester) {
  final card = tester.getRect(find.byType(BleLaunchSyncCard));
  final indicator = tester.getRect(find.byType(BleHomeSyncIndicator));
  final filter = tester.getRect(find.byIcon(Icons.filter_list));
  final rtl = Directionality.of(
        tester.element(find.byType(BleHomeSyncIndicator)),
      ) ==
      TextDirection.rtl;
  _expectPanelOnScreen(tester);
  expect(
    rtl ? filter.right <= indicator.left + 1 : filter.left >= indicator.right - 1,
    isTrue,
    reason: 'rtl=$rtl filter $filter indicator $indicator',
  );
  expect(card.left, lessThanOrEqualTo(indicator.left), reason: 'card $card indicator $indicator');
  expect(card.right, greaterThanOrEqualTo(indicator.right), reason: 'card $card indicator $indicator');
}

void main() {
  testWidgets('hides when launch sync is turned off', (tester) async {
    final view = BleLaunchSyncView()
      ..setProgress(const BleLaunchSyncProgress(
        phase: BleLaunchSyncPhase.scanning,
        deviceName: 'BM59',
      ));
    await pumpApp(tester, await materialApp(
      BleLaunchSyncScope(
        notifier: view,
        child: Scaffold(
          appBar: AppBar(actions: const [BleHomeSyncIndicator()]),
        ),
      ),
      settings: TestSettingsSeed(
        syncBluetoothOnLaunch: false,
        bleInput: BluetoothInputMode.newBluetoothInputCrossPlatform,
      ),
    ));

    expect(find.byIcon(Icons.sync), findsNothing);
    expect(find.byIcon(Icons.bluetooth), findsNothing);
  });

  testWidgets('hides when no meter search is running', (tester) async {
    await pumpApp(tester, await materialApp(Scaffold(
      appBar: AppBar(actions: const [BleHomeSyncIndicator()]),
    )));
    expect(find.byIcon(Icons.sync), findsNothing);
    expect(find.byIcon(Icons.bluetooth), findsNothing);
  });

  testWidgets('shows a grey bluetooth 0 after the user pauses sync', (tester) async {
    final view = BleLaunchSyncView()
      ..setPaused(true)
      ..setProgress(const BleLaunchSyncProgress(
        phase: BleLaunchSyncPhase.done,
        deviceName: 'BM59',
        result: BleLaunchSyncResult(status: BleLaunchSyncStatus.cancelled),
      ));
    await pumpApp(tester, await _indicator(view));

    final icon = tester.widget<Icon>(find.byIcon(Icons.bluetooth));
    expect(icon.color, ThemeData().colorScheme.onSurface);
    expect(find.text('0'), findsOneWidget);
    expect(find.byIcon(Icons.pause), findsNothing);
    expect(find.byIcon(Icons.sync), findsNothing);
    await tester.tap(find.byType(BleHomeSyncIndicator));
    await tester.pump();
    expect(view.detailsOpen, isTrue);
    expect(find.text('Meter sync paused'), findsOneWidget);
  });

  testWidgets('shows a grey bluetooth 0 after sync is cancelled', (tester) async {
    final view = BleLaunchSyncView()
      ..setProgress(const BleLaunchSyncProgress(
        phase: BleLaunchSyncPhase.done,
        result: BleLaunchSyncResult(status: BleLaunchSyncStatus.cancelled),
      ));
    await pumpApp(tester, await _indicator(view));

    final icon = tester.widget<Icon>(find.byIcon(Icons.bluetooth));
    expect(icon.color, ThemeData().colorScheme.onSurface);
    expect(find.text('0'), findsOneWidget);
  });

  testWidgets('hides when launch sync was skipped', (tester) async {
    final view = BleLaunchSyncView()
      ..setProgress(const BleLaunchSyncProgress(
        phase: BleLaunchSyncPhase.done,
        result: BleLaunchSyncResult(status: BleLaunchSyncStatus.skipped),
      ));
    await pumpApp(tester, await _indicator(view));
    expect(find.byIcon(Icons.bluetooth), findsNothing);
  });

  testWidgets('shows a rotating refresh icon while scanning', (tester) async {
    final view = BleLaunchSyncView()
      ..setProgress(const BleLaunchSyncProgress(
        phase: BleLaunchSyncPhase.scanning,
        deviceName: 'BM59',
      ));
    await pumpApp(tester, await _indicator(view));

    expect(find.byIcon(Icons.sync), findsOneWidget);
    expect(find.byIcon(Icons.bluetooth), findsNothing);
    expect(find.text('0'), findsOneWidget);
    expect(find.text('Looking for BM59…'), findsNothing);
  });

  testWidgets('shows a blue bluetooth icon while connecting', (tester) async {
    final view = BleLaunchSyncView()
      ..setProgress(const BleLaunchSyncProgress(
        phase: BleLaunchSyncPhase.connecting,
        deviceName: 'BM59',
      ));
    await pumpApp(tester, await _indicator(view));

    final icon = tester.widget<Icon>(find.byIcon(Icons.bluetooth));
    expect(icon.color, Colors.blue);
    expect(find.byIcon(Icons.downloading), findsNothing);
    expect(find.byIcon(Icons.save_alt), findsNothing);
    expect(find.text('1'), findsOneWidget);
    expect(view.detailsOpen, isFalse);

    await tester.tap(find.byType(BleHomeSyncIndicator));
    await tester.pump();
    expect(view.detailsOpen, isTrue);
  });

  testWidgets('keeps bluetooth icons aligned when the count is reserved', (tester) async {
    final view = BleLaunchSyncView()
      ..setProgress(const BleLaunchSyncProgress(
        phase: BleLaunchSyncPhase.connecting,
        deviceName: 'BM59',
      ));
    await pumpApp(tester, await _indicator(view));
    final connectingX = tester.getTopLeft(find.byIcon(Icons.bluetooth)).dx;

    view.setProgress(const BleLaunchSyncProgress(
      phase: BleLaunchSyncPhase.done,
      result: BleLaunchSyncResult(status: BleLaunchSyncStatus.upToDate),
    ));
    await tester.pump();
    expect(tester.getTopLeft(find.byIcon(Icons.bluetooth)).dx, connectingX);
  });

  testWidgets('shows a bluetooth icon while reading', (tester) async {
    final view = BleLaunchSyncView()
      ..setProgress(const BleLaunchSyncProgress(
        phase: BleLaunchSyncPhase.reading,
        deviceName: 'BM59',
        deviceCount: 2,
      ));
    await pumpApp(tester, await _indicator(view));

    expect(find.byIcon(Icons.bluetooth), findsOneWidget);
    expect(find.byIcon(Icons.downloading), findsNothing);
    expect(find.text('2'), findsOneWidget);
  });

  testWidgets('keeps a green bluetooth icon after importing', (tester) async {
    final view = BleLaunchSyncView()
      ..setProgress(const BleLaunchSyncProgress(
        phase: BleLaunchSyncPhase.done,
        result: BleLaunchSyncResult(
          status: BleLaunchSyncStatus.imported,
          count: 3,
        ),
      ));
    await pumpApp(tester, await _indicator(view));

    final icon = tester.widget<Icon>(find.byIcon(Icons.bluetooth));
    expect(icon.color, Colors.green);
    expect(view.detailsOpen, isFalse);

    await tester.tap(find.byType(BleHomeSyncIndicator));
    await tester.pump();
    expect(view.detailsOpen, isTrue);
    expect(find.byType(BleLaunchSyncCard), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 320));
    _expectPanelOnScreen(tester);
    await tester.pump(const Duration(milliseconds: 320));
    final card = tester.getRect(find.byType(BleLaunchSyncCard));
    final screen =
        Offset.zero & tester.view.physicalSize / tester.view.devicePixelRatio;
    expect(card.left, greaterThanOrEqualTo(0), reason: 'card $card screen $screen');
    expect(
      card.right,
      lessThanOrEqualTo(screen.width),
      reason: 'card $card screen $screen',
    );
    expect(
      card.width,
      greaterThanOrEqualTo(screen.width - 24),
      reason: 'card $card screen $screen',
    );
  });

  testWidgets('keeps the sync panel on screen in Arabic', (tester) async {
    final view = BleLaunchSyncView()
      ..setProgress(const BleLaunchSyncProgress(
        phase: BleLaunchSyncPhase.scanning,
      ));
    await pumpApp(
      tester,
      await _indicator(view, locale: const Locale('ar')),
    );

    await tester.tap(find.byType(BleHomeSyncIndicator));
    await tester.pump(const Duration(milliseconds: 320));

    expect(find.byType(BleLaunchSyncCard), findsOneWidget);
    _expectPanelOnScreen(tester);
  });

  for (final locale in const [Locale('en'), Locale('ar')]) {
    testWidgets(
      'keeps the sync panel on screen beside a trailing filter (${locale.languageCode})',
      (tester) async {
        usePhoneTestSurface(tester);
        final view = BleLaunchSyncView()
          ..setProgress(const BleLaunchSyncProgress(
            phase: BleLaunchSyncPhase.scanning,
          ));
        await pumpApp(
          tester,
          await _indicator(
            view,
            locale: locale,
            trailing: IconButton(
              onPressed: () {},
              icon: const Icon(Icons.filter_list),
            ),
          ),
        );

        await tester.tap(find.byType(BleHomeSyncIndicator));
        await tester.pump(const Duration(milliseconds: 320));

        expect(find.byType(BleLaunchSyncCard), findsOneWidget);
        _expectPanelBesideFilter(tester);
      },
    );
  }

  testWidgets('keeps a grey-white bluetooth icon when nothing new was imported', (tester) async {
    final view = BleLaunchSyncView()
      ..setProgress(const BleLaunchSyncProgress(
        phase: BleLaunchSyncPhase.done,
        result: BleLaunchSyncResult(status: BleLaunchSyncStatus.upToDate),
      ));
    await pumpApp(tester, await _indicator(view));

    final icon = tester.widget<Icon>(find.byIcon(Icons.bluetooth));
    expect(icon.color, Colors.white70);
  });

  testWidgets('starts another scan when tapped after the meter was not found', (
    tester,
  ) async {
    var resumed = false;
    final view = BleLaunchSyncView()
      ..setProgress(
        const BleLaunchSyncProgress(
          phase: BleLaunchSyncPhase.done,
          result: BleLaunchSyncResult(status: BleLaunchSyncStatus.notFound),
        ),
      );
    view.onResume = () {
      resumed = true;
    };
    await pumpApp(tester, await _indicator(view));

    await tester.tap(find.byType(BleHomeSyncIndicator));
    await tester.pump();

    expect(resumed, isTrue);
    expect(view.detailsOpen, isFalse);
  });

  testWidgets('shows 0 when no meter was found', (tester) async {
    final view = BleLaunchSyncView()
      ..setProgress(const BleLaunchSyncProgress(
        phase: BleLaunchSyncPhase.done,
        result: BleLaunchSyncResult(status: BleLaunchSyncStatus.notFound),
      ));
    await pumpApp(tester, await _indicator(view));

    expect(find.byIcon(Icons.bluetooth), findsOneWidget);
    expect(find.text('0'), findsOneWidget);
    final icon = tester.widget<Icon>(find.byIcon(Icons.bluetooth));
    expect(icon.color, ThemeData().colorScheme.onSurface);
  });

  testWidgets('keeps a red bluetooth icon after a failure', (tester) async {
    final view = BleLaunchSyncView()
      ..setProgress(const BleLaunchSyncProgress(
        phase: BleLaunchSyncPhase.done,
        result: BleLaunchSyncResult(status: BleLaunchSyncStatus.failed),
      ));
    await pumpApp(tester, await _indicator(view));

    final icon = tester.widget<Icon>(find.byIcon(Icons.bluetooth));
    expect(icon.color, ThemeData().colorScheme.error);
  });
}
