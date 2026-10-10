import 'dart:async';

import 'package:blood_pressure_app/features/bluetooth/background/bluetooth_foreground_service.dart';
import 'package:blood_pressure_app/features/bluetooth/logic/ble_launch_sync.dart';
import 'package:blood_pressure_app/features/bluetooth/ui/ble_launch_sync_card.dart';
import 'package:blood_pressure_app/features/bluetooth/ui/ble_launch_sync_host.dart';
import 'package:blood_pressure_app/features/home/ble_home_sync_indicator.dart';
import 'package:blood_pressure_app/features/settings/registry.dart';
import 'package:blood_pressure_app/model/bluetooth_input_mode.dart';
import 'package:blood_pressure_app/model/known_ble_device.dart';
import 'package:flutter/material.dart';
import 'package:safaeh/safaeh.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../util.dart';

class _HangingSync extends BleLaunchSync {
  _HangingSync([this.phase = BleLaunchSyncPhase.scanning])
    : super(
        controller: testSettingsController!,
        repo: MockBloodPressureRepository(),
      );

  final BleLaunchSyncPhase phase;
  final Completer<BleLaunchSyncResult> _done = Completer();
  bool cancelled = false;

  @override
  Future<BleLaunchSyncResult> run() {
    progress.value = BleLaunchSyncProgress(phase: phase, deviceName: 'BM59');
    return _done.future;
  }

  @override
  void cancel() {
    cancelled = true;
    if (_done.isCompleted) return;
    const result = BleLaunchSyncResult(status: BleLaunchSyncStatus.cancelled);
    progress.value = const BleLaunchSyncProgress(
      phase: BleLaunchSyncPhase.done,
      result: result,
    );
    _done.complete(result);
  }
}

class _ControllableSync extends BleLaunchSync {
  _ControllableSync()
    : super(
        controller: testSettingsController!,
        repo: MockBloodPressureRepository(),
      );

  final Completer<BleLaunchSyncResult> _done = Completer();

  @override
  Future<BleLaunchSyncResult> run() {
    progress.value = const BleLaunchSyncProgress(
      phase: BleLaunchSyncPhase.scanning,
      deviceName: 'BM59',
    );
    return _done.future;
  }

  void complete(BleLaunchSyncResult result) {
    progress.value = BleLaunchSyncProgress(
      phase: BleLaunchSyncPhase.done,
      deviceName: result.deviceName,
      receivedCount: result.receivedCount,
      result: result,
    );
    _done.complete(result);
  }
}

class _FakeSync extends BleLaunchSync {
  _FakeSync(this.result)
    : super(
        controller: testSettingsController!,
        repo: MockBloodPressureRepository(),
      );

  final BleLaunchSyncResult result;

  @override
  Future<BleLaunchSyncResult> run() async {
    progress.value = BleLaunchSyncProgress(
      phase: BleLaunchSyncPhase.done,
      deviceName: result.deviceName,
      receivedCount: result.receivedCount,
      result: result,
    );
    return result;
  }
}

TestSettingsSeed _enabledSettings() => TestSettingsSeed(
  syncBluetoothOnLaunch: true,
  bleInput: BluetoothInputMode.newBluetoothInputCrossPlatform,
  knownBleDev: const [KnownBleDevice(id: 'aa', name: 'BM59')],
);

void main() {
  setUp(() async {
    BleLaunchSync.resetSession();
    await createTestSettings();
  });

  test('home is only the named root route', () {
    expect(
      HomePresenceObserver.isHomeRoute(
        MaterialPageRoute<void>(
          settings: const RouteSettings(name: '/'),
          builder: (_) => const SizedBox.shrink(),
        ),
      ),
      isTrue,
    );
    expect(
      HomePresenceObserver.isHomeRoute(
        MaterialPageRoute<void>(builder: (_) => const SizedBox.shrink()),
      ),
      isFalse,
    );
    expect(
      HomePresenceObserver.isHomeRoute(
        MaterialPageRoute<void>(
          settings: const RouteSettings(name: '/settings'),
          builder: (_) => const SizedBox.shrink(),
        ),
      ),
      isFalse,
    );
  });

  test('leaving the home tab is not home', () {
    final observer = HomePresenceObserver();
    expect(observer.onHome, isTrue);
    observer.setHomeTab(false);
    expect(observer.onHome, isFalse);
    observer.setHomeTab(true);
    expect(observer.onHome, isTrue);
  });

  testWidgets('does not show a banner when launch sync is off', (tester) async {
    await pumpApp(
      tester,
      await appBase(
        const BleLaunchSyncHost(
          resultBannerDuration: Duration.zero,
          child: Text('home'),
        ),
        settings: TestSettingsSeed(syncBluetoothOnLaunch: false),
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(find.text('home'), findsOneWidget);
    expect(find.byType(BleLaunchSyncCard), findsNothing);
    expect(
      find.byType(SafaehFeedbackSurface, skipOffstage: false),
      findsNothing,
    );
  });

  testWidgets('does not start the foreground service for a skipped sync', (
    tester,
  ) async {
    final starts = <String>[];
    var stops = 0;
    BluetoothForegroundService.startOverrideForTesting =
        ({required text}) async {
          starts.add(text);
        };
    BluetoothForegroundService.stopOverrideForTesting = () async {
      stops++;
    };
    addTearDown(BluetoothForegroundService.resetOverridesForTesting);

    await pumpApp(
      tester,
      await appBase(
        BleLaunchSyncHost(
          resultBannerDuration: Duration.zero,
          sync: _FakeSync(
            const BleLaunchSyncResult(status: BleLaunchSyncStatus.skipped),
          ),
          child: const Text('home'),
        ),
        settings: _enabledSettings(),
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(starts, isEmpty);
    expect(stops, 0);
  });

  testWidgets('keeps stages hidden until the compact indicator is tapped', (
    tester,
  ) async {
    final sync = _HangingSync();
    await pumpApp(
      tester,
      await appBase(
        BleLaunchSyncHost(
          resultBannerDuration: Duration.zero,
          sync: sync,
          child: Scaffold(
            appBar: AppBar(actions: const [BleHomeSyncIndicator()]),
            body: const BleLaunchSyncPopout(child: Text('home')),
          ),
        ),
        settings: _enabledSettings(),
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(find.byType(BleLaunchSyncCard), findsNothing);
    expect(find.byIcon(Icons.sync), findsOneWidget);

    final homeY = tester.getTopLeft(find.text('home')).dy;
    await tester.tap(find.byType(BleHomeSyncIndicator));
    await tester.pump();
    expect(find.byType(BleLaunchSyncCard), findsOneWidget);
    expect(
      tester.getTopLeft(find.byType(BleLaunchSyncCard)).dy,
      greaterThanOrEqualTo(tester.getBottomLeft(find.byType(AppBar)).dy),
    );
    expect(tester.getTopLeft(find.text('home')).dy, homeY);
  });

  testWidgets('shows imported count after a successful sync', (tester) async {
    await pumpApp(
      tester,
      await appBase(
        BleLaunchSyncHost(
          resultBannerDuration: Duration.zero,
          sync: _FakeSync(
            const BleLaunchSyncResult(
              status: BleLaunchSyncStatus.imported,
              count: 3,
              deviceName: 'BM59',
            ),
          ),
          child: const Text('home'),
        ),
        settings: _enabledSettings(),
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(find.byType(BleLaunchSyncCard), findsNothing);
    expect(
      find.byType(SafaehFeedbackSurface, skipOffstage: false),
      findsOneWidget,
    );
    expect(
      find.text('Imported 3 new measurements', skipOffstage: false),
      findsOneWidget,
    );
    expect(find.text('home'), findsOneWidget);
  });

  testWidgets('keeps checking when moving to another main route', (
    tester,
  ) async {
    final sync = _HangingSync();
    final observer = HomePresenceObserver();
    await pumpApp(
      tester,
      await appBase(
        BleLaunchSyncHost(
          resultBannerDuration: Duration.zero,
          homePresence: observer,
          sync: sync,
          child: Scaffold(
            appBar: AppBar(actions: const [BleHomeSyncIndicator()]),
            body: const BleLaunchSyncPopout(child: Text('home')),
          ),
        ),
        settings: _enabledSettings(),
      ),
    );
    await tester.pump();
    await tester.pump();
    expect(find.byIcon(Icons.sync), findsOneWidget);

    observer.didPush(
      MaterialPageRoute<void>(
        settings: const RouteSettings(name: '/add'),
        builder: (_) => const SizedBox.shrink(),
      ),
      null,
    );
    await tester.pump();
    expect(sync.cancelled, isFalse);
    expect(find.byType(BleLaunchSyncCard), findsNothing);
    expect(find.byIcon(Icons.sync), findsOneWidget);
  });

  testWidgets('stops in settings and restarts on a main route', (tester) async {
    final syncs = <_HangingSync>[];
    final observer = HomePresenceObserver();
    final home = MaterialPageRoute<void>(
      settings: const RouteSettings(name: '/'),
      builder: (_) => const SizedBox.shrink(),
    );
    await pumpApp(
      tester,
      await appBase(
        BleLaunchSyncHost(
          resultBannerDuration: Duration.zero,
          homePresence: observer,
          createSync: () {
            final sync = _HangingSync();
            syncs.add(sync);
            return sync;
          },
          child: Scaffold(
            appBar: AppBar(actions: const [BleHomeSyncIndicator()]),
            body: const BleLaunchSyncPopout(child: Text('home')),
          ),
        ),
        settings: _enabledSettings(),
      ),
    );
    await tester.pump();
    await tester.pump();
    expect(syncs, hasLength(1));
    expect(find.byIcon(Icons.sync), findsOneWidget);

    observer.didPush(
      MaterialPageRoute<void>(
        settings: const RouteSettings(name: '/settings'),
        builder: (_) => const SizedBox.shrink(),
      ),
      home,
    );
    await tester.pump();
    expect(syncs.single.cancelled, isTrue);

    observer.didPop(
      MaterialPageRoute<void>(
        settings: const RouteSettings(name: '/settings'),
        builder: (_) => const SizedBox.shrink(),
      ),
      home,
    );
    await tester.pump();
    await tester.pump();
    expect(syncs, hasLength(2));
    expect(find.byIcon(Icons.sync), findsOneWidget);
  });

  testWidgets('shows already up to date when nothing new was imported', (
    tester,
  ) async {
    await pumpApp(
      tester,
      await appBase(
        BleLaunchSyncHost(
          resultBannerDuration: Duration.zero,
          sync: _FakeSync(
            const BleLaunchSyncResult(status: BleLaunchSyncStatus.upToDate),
          ),
          child: const Text('home'),
        ),
        settings: _enabledSettings(),
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(
      find.text('No new measurements', skipOffstage: false),
      findsOneWidget,
    );
    expect(find.byType(BleLaunchSyncCard), findsNothing);
  });

  testWidgets('pause in the popout stops sync until resume', (tester) async {
    final syncs = <_HangingSync>[];
    await pumpApp(
      tester,
      await appBase(
        BleLaunchSyncHost(
          resultBannerDuration: Duration.zero,
          createSync: () {
            final sync = _HangingSync();
            syncs.add(sync);
            return sync;
          },
          child: Scaffold(
            appBar: AppBar(actions: const [BleHomeSyncIndicator()]),
            body: const BleLaunchSyncPopout(child: Text('home')),
          ),
        ),
        settings: _enabledSettings(),
      ),
    );
    await tester.pump();
    await tester.pump();
    expect(syncs, hasLength(1));

    await tester.tap(find.byType(BleHomeSyncIndicator));
    await tester.pump();
    expect(find.byTooltip('Pause'), findsOneWidget);

    await tester.tap(find.byTooltip('Pause'));
    await tester.pump();
    expect(syncs.single.cancelled, isTrue);
    expect(find.text('Meter sync paused'), findsOneWidget);
    expect(find.byTooltip('Resume'), findsOneWidget);
    expect(find.text('Pause'), findsNothing);
    expect(find.text('Resume'), findsNothing);
    expect(find.byIcon(Icons.bluetooth), findsWidgets);
    expect(find.text('0'), findsOneWidget);

    await tester.tap(find.byTooltip('Resume'));
    await tester.pump();
    await tester.pump();
    expect(syncs, hasLength(2));
    expect(syncs.last.cancelled, isFalse);
  });

  testWidgets('resume after meter not found starts scanning again', (
    tester,
  ) async {
    final syncs = <BleLaunchSync>[];
    await pumpApp(
      tester,
      await appBase(
        BleLaunchSyncHost(
          resultBannerDuration: Duration.zero,
          createSync: () {
            if (syncs.isEmpty) {
              final sync = _FakeSync(
                const BleLaunchSyncResult(status: BleLaunchSyncStatus.notFound),
              );
              syncs.add(sync);
              return sync;
            }
            final sync = _HangingSync();
            syncs.add(sync);
            return sync;
          },
          child: Scaffold(
            appBar: AppBar(actions: const [BleHomeSyncIndicator()]),
            body: const BleLaunchSyncPopout(child: Text('home')),
          ),
        ),
        settings: _enabledSettings(),
      ),
    );
    await tester.pump();
    await tester.pump();
    expect(syncs, hasLength(1));

    await tester.tap(find.byType(BleHomeSyncIndicator));
    await tester.pump();
    await tester.pump();
    expect(syncs, hasLength(2));
    expect(find.byIcon(Icons.sync), findsOneWidget);
  });

  testWidgets('unnamed overlays on a main route keep scanning active', (
    tester,
  ) async {
    final syncs = <_HangingSync>[];
    final observer = HomePresenceObserver();
    final home = MaterialPageRoute<void>(
      settings: const RouteSettings(name: '/'),
      builder: (_) => const SizedBox.shrink(),
    );
    await pumpApp(
      tester,
      await appBase(
        BleLaunchSyncHost(
          resultBannerDuration: Duration.zero,
          homePresence: observer,
          createSync: () {
            final sync = _HangingSync();
            syncs.add(sync);
            return sync;
          },
          child: Scaffold(
            appBar: AppBar(actions: const [BleHomeSyncIndicator()]),
            body: const BleLaunchSyncPopout(child: Text('home')),
          ),
        ),
        settings: _enabledSettings(),
      ),
    );
    await tester.pump();
    await tester.pump();
    expect(syncs, hasLength(1));

    observer.didPush(
      MaterialPageRoute<void>(builder: (_) => const SizedBox.shrink()),
      home,
    );
    await tester.pump();
    expect(observer.onHome, isFalse);
    expect(syncs.single.cancelled, isFalse);
    expect(syncs, hasLength(1));
    expect(find.byIcon(Icons.sync), findsOneWidget);
  });

  testWidgets('disabling launch sync mid-scan cancels and does not restart', (
    tester,
  ) async {
    final syncs = <_HangingSync>[];
    await pumpApp(
      tester,
      await appBase(
        BleLaunchSyncHost(
          resultBannerDuration: Duration.zero,
          createSync: () {
            final sync = _HangingSync();
            syncs.add(sync);
            return sync;
          },
          child: Scaffold(
            appBar: AppBar(actions: const [BleHomeSyncIndicator()]),
            body: const BleLaunchSyncPopout(child: Text('home')),
          ),
        ),
        settings: _enabledSettings(),
      ),
    );
    await tester.pump();
    await tester.pump();
    expect(syncs, hasLength(1));
    expect(find.byIcon(Icons.sync), findsOneWidget);

    await testSettingsController!.set(syncBluetoothOnLaunchSetting, false);
    await tester.pump();
    expect(syncs.single.cancelled, isTrue);
    expect(find.byIcon(Icons.sync), findsNothing);
    expect(find.byIcon(Icons.bluetooth), findsNothing);
    expect(find.byType(BleLaunchSyncCard), findsNothing);

    await tester.pump();
    expect(syncs, hasLength(1));
  });

  testWidgets('enabling launch sync on home starts scanning again', (
    tester,
  ) async {
    final syncs = <_HangingSync>[];
    await pumpApp(
      tester,
      await appBase(
        BleLaunchSyncHost(
          resultBannerDuration: Duration.zero,
          createSync: () {
            final sync = _HangingSync();
            syncs.add(sync);
            return sync;
          },
          child: Scaffold(
            appBar: AppBar(actions: const [BleHomeSyncIndicator()]),
            body: const BleLaunchSyncPopout(child: Text('home')),
          ),
        ),
        settings: _enabledSettings(),
      ),
    );
    await tester.pump();
    await tester.pump();
    expect(syncs, hasLength(1));

    await testSettingsController!.set(syncBluetoothOnLaunchSetting, false);
    await tester.pump();
    expect(syncs.single.cancelled, isTrue);

    await testSettingsController!.set(syncBluetoothOnLaunchSetting, true);
    await tester.pump();
    await tester.pump();
    expect(syncs, hasLength(2));
    expect(syncs.last.cancelled, isFalse);
    expect(find.byIcon(Icons.sync), findsOneWidget);
  });

  testWidgets('paused sync does not restart when returning home', (
    tester,
  ) async {
    final syncs = <_HangingSync>[];
    final observer = HomePresenceObserver();
    final home = MaterialPageRoute<void>(
      settings: const RouteSettings(name: '/'),
      builder: (_) => const SizedBox.shrink(),
    );
    await pumpApp(
      tester,
      await appBase(
        BleLaunchSyncHost(
          resultBannerDuration: Duration.zero,
          homePresence: observer,
          createSync: () {
            final sync = _HangingSync();
            syncs.add(sync);
            return sync;
          },
          child: Scaffold(
            appBar: AppBar(actions: const [BleHomeSyncIndicator()]),
            body: const BleLaunchSyncPopout(child: Text('home')),
          ),
        ),
        settings: _enabledSettings(),
      ),
    );
    await tester.pump();
    await tester.pump();

    await tester.tap(find.byType(BleHomeSyncIndicator));
    await tester.pump();
    await tester.tap(find.byTooltip('Pause'));
    await tester.pump();
    expect(syncs, hasLength(1));

    observer.didPush(
      MaterialPageRoute<void>(
        settings: const RouteSettings(name: '/add'),
        builder: (_) => const SizedBox.shrink(),
      ),
      home,
    );
    await tester.pump();
    observer.didPop(
      MaterialPageRoute<void>(
        settings: const RouteSettings(name: '/add'),
        builder: (_) => const SizedBox.shrink(),
      ),
      home,
    );
    await tester.pump();
    await tester.pump();
    expect(syncs, hasLength(1));
    expect(find.byIcon(Icons.bluetooth), findsOneWidget);
    expect(find.text('0'), findsOneWidget);

    expect(find.text('Meter sync paused'), findsOneWidget);
  });

  testWidgets('finish is called with text only when something was imported', (
    tester,
  ) async {
    final finishes = <String?>[];
    var stops = 0;
    BluetoothForegroundService.startOverrideForTesting =
        ({required text}) async {};
    BluetoothForegroundService.stopOverrideForTesting = () async {
      stops++;
    };
    BluetoothForegroundService.finishOverrideForTesting = ({text}) async {
      finishes.add(text);
    };
    addTearDown(BluetoothForegroundService.resetOverridesForTesting);

    final sync = _ControllableSync();
    await pumpApp(
      tester,
      await appBase(
        BleLaunchSyncHost(
          resultBannerDuration: Duration.zero,
          sync: sync,
          child: const Text('home'),
        ),
        settings: _enabledSettings(),
      ),
    );
    await tester.pump();
    await tester.pump();
    sync.complete(
      const BleLaunchSyncResult(
        status: BleLaunchSyncStatus.imported,
        count: 3,
        deviceName: 'BM59',
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(finishes, ['Imported 3 new measurements']);
    expect(stops, 0);
  });

  testWidgets('stops the notification when nothing was imported', (
    tester,
  ) async {
    final finishes = <String?>[];
    var stops = 0;
    BluetoothForegroundService.startOverrideForTesting =
        ({required text}) async {};
    BluetoothForegroundService.stopOverrideForTesting = () async {
      stops++;
    };
    BluetoothForegroundService.finishOverrideForTesting = ({text}) async {
      finishes.add(text);
    };
    addTearDown(BluetoothForegroundService.resetOverridesForTesting);

    final sync = _ControllableSync();
    await pumpApp(
      tester,
      await appBase(
        BleLaunchSyncHost(
          resultBannerDuration: Duration.zero,
          sync: sync,
          child: const Text('home'),
        ),
        settings: _enabledSettings(),
      ),
    );
    await tester.pump();
    await tester.pump();
    sync.complete(
      const BleLaunchSyncResult(status: BleLaunchSyncStatus.upToDate),
    );
    await tester.pump();
    await tester.pump();

    expect(finishes, isEmpty);
    expect(stops, 1);
  });
}
