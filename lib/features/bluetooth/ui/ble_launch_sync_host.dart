import 'dart:async';

import 'package:blood_pressure_app/core/repository/repo_context.dart';
import 'package:blood_pressure_app/core/widgets/toast.dart';
import 'package:blood_pressure_app/features/bluetooth/backend/bluetooth_backend.dart';
import 'package:blood_pressure_app/features/bluetooth/background/bluetooth_foreground_service.dart';
import 'package:blood_pressure_app/features/bluetooth/logic/ble_launch_sync.dart';
import 'package:blood_pressure_app/features/bluetooth/logic/bluetooth_cubit.dart';
import 'package:blood_pressure_app/features/bluetooth/logic/device_scan_cubit.dart';
import 'package:blood_pressure_app/features/bluetooth/ui/ble_launch_sync_card.dart';
import 'package:blood_pressure_app/features/settings/app_settings.dart';
import 'package:blood_pressure_app/model/bluetooth_input_mode.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_settings_framework/flutter_settings_framework.dart';

/// Tracks where the app is relative to the auto-sync area.
class HomePresenceObserver extends NavigatorObserver with ChangeNotifier {
  bool _onHomeRoute = true;
  bool _onHomeTab = true;
  bool _onSettingsTab = false;
  bool _onMainRoute = true;
  bool _onSettingsRoute = false;
  final Map<Route<dynamic>, bool> _mainRoutes = {};
  final Map<Route<dynamic>, bool> _settingsRoutes = {};

  /// Whether the current top route is the home tab.
  bool get onHome => _onHomeRoute && _onHomeTab;

  /// Whether auto-sync is allowed for the current screen.
  ///
  /// The scan remains active on the app's data screens and while the app is
  /// backgrounded. Settings (including settings subpages) is the deliberate
  /// exception because those pages start their own Bluetooth workflows.
  bool get onMainScreen => _onMainRoute && !_onSettingsRoute && !_onSettingsTab;

  /// Home is only the named root route. Unnamed overlays (settings
  /// subpages, details, dialogs) are not home.
  static bool isHomeRoute(Route<dynamic>? route) {
    final name = route?.settings.name;
    return name == '/' || name == Navigator.defaultRouteName;
  }

  /// Whether [route] belongs to the settings section of the app.
  static bool isSettingsRoute(Route<dynamic>? route) {
    final name = route?.settings.name;
    return name == '/settings' || name?.startsWith('/settings/') == true;
  }

  /// Whether [route] is an app screen where auto-sync may run.
  static bool isMainRoute(Route<dynamic>? route) {
    final name = route?.settings.name;
    return name == null || (name != '/onboarding' && !isSettingsRoute(route));
  }

  /// Shell tabs other than home should not count as the home screen.
  void setHomeTab(bool value) {
    if (_onHomeTab == value) return;
    _onHomeTab = value;
    notifyListeners();
  }

  /// Update both shell-tab flags in one notification.
  void setShellTab({required bool isHome, required bool isSettings}) {
    if (_onHomeTab == isHome && _onSettingsTab == isSettings) return;
    _onHomeTab = isHome;
    _onSettingsTab = isSettings;
    notifyListeners();
  }

  void _recordRoute(Route<dynamic> route, {Route<dynamic>? previousRoute}) {
    final named = route.settings.name;
    final fromPreviousSettings =
        previousRoute != null &&
        (_settingsRoutes[previousRoute] ?? _onSettingsRoute);
    final fromSettingsTab = _onSettingsTab;
    _settingsRoutes[route] = named == null
        ? fromPreviousSettings || fromSettingsTab
        : isSettingsRoute(route);
    _mainRoutes[route] = named == null
        ? (_mainRoutes[previousRoute] ?? _onMainRoute)
        : isMainRoute(route);
  }

  void _apply(Route<dynamic>? route) {
    final nextHome = isHomeRoute(route);
    final nextMain = _mainRoutes[route] ?? isMainRoute(route);
    final nextSettings = _settingsRoutes[route] ?? isSettingsRoute(route);
    if (nextHome == _onHomeRoute &&
        nextMain == _onMainRoute &&
        nextSettings == _onSettingsRoute) {
      return;
    }
    _onHomeRoute = nextHome;
    _onMainRoute = nextMain;
    _onSettingsRoute = nextSettings;
    notifyListeners();
  }

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _recordRoute(route, previousRoute: previousRoute);
    _apply(route);
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _mainRoutes.remove(route);
    _settingsRoutes.remove(route);
    _apply(previousRoute);
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    final oldMain = oldRoute == null ? null : _mainRoutes[oldRoute];
    final oldSettings = oldRoute == null ? null : _settingsRoutes[oldRoute];
    if (oldRoute != null) {
      _mainRoutes.remove(oldRoute);
      _settingsRoutes.remove(oldRoute);
    }
    if (newRoute != null) {
      final named = newRoute.settings.name;
      _mainRoutes[newRoute] = named == null
          ? oldMain ?? _onMainRoute
          : isMainRoute(newRoute);
      _settingsRoutes[newRoute] = named == null
          ? oldSettings ?? _onSettingsRoute
          : isSettingsRoute(newRoute);
    }
    _apply(newRoute);
  }

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _mainRoutes.remove(route);
    _settingsRoutes.remove(route);
    _apply(previousRoute);
  }

  @override
  void dispose() {
    _mainRoutes.clear();
    _settingsRoutes.clear();
    super.dispose();
  }
}

/// Live launch-sync progress and whether the detail popout is open.
class BleLaunchSyncView extends ChangeNotifier {
  BleLaunchSyncProgress _progress = const BleLaunchSyncProgress();
  bool _detailsOpen = false;
  bool _paused = false;

  /// Link shared by the AppBar indicator and its attached detail panel.
  final LayerLink indicatorLink = LayerLink();

  /// Identifies the AppBar indicator so the detail panel can stay on screen
  /// when a trailing control, such as the measurement filter, insets it.
  final GlobalKey indicatorKey = GlobalKey();

  /// Current sync stage.
  BleLaunchSyncProgress get progress => _progress;

  /// Whether the user opened the stage popout.
  bool get detailsOpen => _detailsOpen;

  /// Whether the user paused launch sync for this session.
  bool get paused => _paused;

  /// Stop the in-flight sync without restarting it.
  VoidCallback? onPause;

  /// Start launch sync again after [paused].
  VoidCallback? onResume;

  /// Publish a new progress snapshot.
  void setProgress(BleLaunchSyncProgress value) {
    if (value == _progress) return;
    _progress = value;
    notifyListeners();
  }

  /// Mark launch sync as paused or running.
  void setPaused(bool value) {
    if (value == _paused) return;
    _paused = value;
    notifyListeners();
  }

  /// Show the hidden stage card.
  void openDetails() {
    if (_detailsOpen) return;
    _detailsOpen = true;
    notifyListeners();
  }

  /// Hide the stage card without cancelling the sync.
  void closeDetails() {
    if (!_detailsOpen) return;
    _detailsOpen = false;
    notifyListeners();
  }
}

/// Provides the current launch-sync progress to the home AppBar and overlays.
class BleLaunchSyncScope extends InheritedNotifier<BleLaunchSyncView> {
  /// Expose [notifier] to descendants.
  const BleLaunchSyncScope({
    super.key,
    required BleLaunchSyncView super.notifier,
    required super.child,
  });

  /// Current view model, if a host is present.
  static BleLaunchSyncView? maybeOf(BuildContext context) => context
      .dependOnInheritedWidgetOfExactType<BleLaunchSyncScope>()
      ?.notifier;

  /// Current progress, or an idle snapshot when no host is present.
  static BleLaunchSyncProgress of(BuildContext context) =>
      maybeOf(context)?.progress ?? const BleLaunchSyncProgress();
}

/// Runs [BleLaunchSync] once after the first frame and shows a status card.
class BleLaunchSyncHost extends ConsumerStatefulWidget {
  /// Wrap [child] so a launch sync can overlay the app.
  const BleLaunchSyncHost({
    super.key,
    required this.child,
    this.manager,
    this.bluetoothCubit,
    this.deviceScanCubit,
    this.sync,
    this.createSync,
    this.homePresence,
    this.resultBannerDuration = const Duration(seconds: 6),
  });

  /// App content under the status card.
  final Widget child;

  /// Optional Bluetooth backend for tests.
  final BluetoothManager<DiscoveredEventArgs>? manager;

  /// Optional [BluetoothCubit] factory for tests.
  final BluetoothCubit Function()? bluetoothCubit;

  /// Optional [DeviceScanCubit] factory for tests.
  final DeviceScanCubit Function()? deviceScanCubit;

  /// Optional prebuilt sync, used by tests.
  final BleLaunchSync? sync;

  /// Optional factory used by tests when a cancelled sync should start again.
  final BleLaunchSync Function()? createSync;

  /// When set, sync runs on every main screen except settings.
  final HomePresenceObserver? homePresence;

  /// How long a completed status card stays visible.
  final Duration resultBannerDuration;

  @override
  ConsumerState<BleLaunchSyncHost> createState() => _BleLaunchSyncHostState();
}

class _BleLaunchSyncHostState extends ConsumerState<BleLaunchSyncHost> {
  BleLaunchSync? _sync;
  Future<void>? _foregroundServiceStart;
  final BleLaunchSyncView _view = BleLaunchSyncView();
  bool _paused = false;
  bool _suppressAutoStart = false;

  @override
  void initState() {
    super.initState();
    _view.onPause = _pause;
    _view.onResume = _resume;
    widget.homePresence?.addListener(_onPresence);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_maybeStart());
    });
  }

  bool get _onMainScreen => widget.homePresence?.onMainScreen ?? true;

  bool _launchSyncEnabled(AppSettings settings) =>
      settings.syncBluetoothOnLaunch &&
      settings.bluetoothMeasurementsEnabled &&
      settings.bleInput != BluetoothInputMode.disabled &&
      (settings.bloodPressureEnabled || settings.weightInput);

  void _onPresence() {
    if (_onMainScreen) {
      _suppressAutoStart = false;
      unawaited(_maybeStart());
    } else {
      _leaveMainScreens();
    }
  }

  void _onSettings(AppSettings settings) {
    if (!mounted) return;
    if (_launchSyncEnabled(settings)) {
      _suppressAutoStart = false;
      unawaited(_maybeStart());
      return;
    }
    _stopBecauseDisabled();
  }

  void _leaveMainScreens() {
    _suppressAutoStart = true;
    _sync?.cancel();
    _view.closeDetails();
    unawaited(_stopForegroundService());
  }

  void _stopBecauseDisabled() {
    _paused = false;
    _view.setPaused(false);
    _view.closeDetails();
    _view.setProgress(const BleLaunchSyncProgress());
    _sync?.cancel();
    unawaited(_stopForegroundService());
  }

  void _pause() {
    if (_paused) return;
    _paused = true;
    _view.setPaused(true);
    _sync?.cancel();
    unawaited(_stopForegroundService());
  }

  void _resume() {
    _paused = false;
    _suppressAutoStart = false;
    _view.setPaused(false);
    _sync?.progress.removeListener(_onProgress);
    _sync?.cancel();
    _sync = null;
    BleLaunchSync.allowRetry();
    unawaited(_maybeStart());
  }

  String _backgroundStatus(BleLaunchSyncProgress progress) {
    final name = progress.deviceName?.trim();
    final named = name != null && name.isNotEmpty;
    return switch (progress.phase) {
      BleLaunchSyncPhase.scanning =>
        named
            ? 'lookingForDevice'.tr(namedArgs: {'name': name})
            : 'scanningForDevices'.tr(),
      BleLaunchSyncPhase.connecting =>
        named
            ? 'connectingToDevice'.tr(namedArgs: {'name': name})
            : 'connectingToMeter'.tr(),
      BleLaunchSyncPhase.reading => 'readingStoredMeasurements'.tr(),
      BleLaunchSyncPhase.importing => 'savingNewMeasurements'.tr(),
      BleLaunchSyncPhase.idle || BleLaunchSyncPhase.done => 'syncingMeter'.tr(),
    };
  }

  Future<void> _startForegroundService(String text) async {
    try {
      await BluetoothForegroundService.start(text: text);
    } catch (_) {
      // The service is an optimization for background execution. A platform
      // restriction must not take down the Bluetooth sync itself.
    }
  }

  Future<void> _updateForegroundServiceWhenReady(Future<void> start) async {
    await start;
    if (!mounted || !identical(_foregroundServiceStart, start)) return;
    final progress = _sync?.progress.value;
    if (progress?.isBusy != true) return;
    await BluetoothForegroundService.update(text: _backgroundStatus(progress!));
  }

  Future<void> _stopForegroundService() async {
    final start = _foregroundServiceStart;
    if (start == null) return;
    _foregroundServiceStart = null;
    await start;
    await BluetoothForegroundService.stop();
  }

  Future<void> _finishForegroundService(BleLaunchSyncResult result) async {
    final start = _foregroundServiceStart;
    if (start == null) return;
    _foregroundServiceStart = null;
    await start;
    if (result.status == BleLaunchSyncStatus.imported) {
      await BluetoothForegroundService.finish(
        text: 'importedNewMeasurements'.tr(
          namedArgs: {'count': '${result.count}'},
        ),
      );
      return;
    }
    await BluetoothForegroundService.stop();
  }

  Future<void> _maybeStart() async {
    if (!mounted ||
        !_onMainScreen ||
        _paused ||
        _suppressAutoStart ||
        BleLaunchSync.isHeldByInput) {
      return;
    }
    final settings = ref.read(appSettingsProvider);
    if (!_launchSyncEnabled(settings)) return;
    if (_sync != null) return;

    final sync =
        widget.createSync?.call() ??
        widget.sync ??
        BleLaunchSync(
          controller: ref.read(settingsControllerProvider),
          repo: context.bpRepo,
          weightRepo: context.weightRepo,
          includeBloodPressure: settings.bloodPressureEnabled,
          includeWeight: settings.weightInput,
          blacklistRepo: context.blacklistRepo,
          manager: widget.manager,
          bluetoothCubit: widget.bluetoothCubit,
          deviceScanCubit: widget.deviceScanCubit,
        );
    _sync = sync;
    sync.progress.addListener(_onProgress);
    _onProgress();
    final result = await sync.run();
    await _finishForegroundService(result);
    if (!mounted) return;
    if (result.status == BleLaunchSyncStatus.cancelled) {
      sync.progress.removeListener(_onProgress);
      final name = sync.progress.value.deviceName;
      _sync = null;
      if (!_launchSyncEnabled(ref.read(appSettingsProvider))) {
        _view.closeDetails();
        _view.setProgress(const BleLaunchSyncProgress());
        return;
      }
      _view.setProgress(
        BleLaunchSyncProgress(
          phase: BleLaunchSyncPhase.done,
          deviceName: name,
          result: const BleLaunchSyncResult(
            status: BleLaunchSyncStatus.cancelled,
          ),
        ),
      );
      if (_paused) return;
      _view.closeDetails();
      if (_onMainScreen &&
          !_suppressAutoStart &&
          !BleLaunchSync.isHeldByInput) {
        unawaited(_maybeStart());
      }
      return;
    }
    _view.closeDetails();
    _showResultMessage(result);
  }

  void _showResultMessage(BleLaunchSyncResult result) {
    final message = switch (result.status) {
      BleLaunchSyncStatus.imported => 'importedNewMeasurements'.tr(
        namedArgs: {'count': '${result.count}'},
      ),
      BleLaunchSyncStatus.upToDate => 'noNewMeasurements'.tr(),
      BleLaunchSyncStatus.bluetoothOff => 'bluetoothOffSyncSkipped'.tr(),
      BleLaunchSyncStatus.failed => 'bluetoothSyncFailed'.tr(),
      BleLaunchSyncStatus.notFound => 'meterNotFound'.tr(),
      BleLaunchSyncStatus.skipped || BleLaunchSyncStatus.cancelled => null,
    };
    if (message == null || !mounted) return;
    final duration = widget.resultBannerDuration > Duration.zero
        ? widget.resultBannerDuration
        : const Duration(seconds: 4);
    switch (result.status) {
      case BleLaunchSyncStatus.imported:
        context.showSuccess(message, duration: duration);
      case BleLaunchSyncStatus.upToDate:
        context.showToast(message, duration: duration);
      case BleLaunchSyncStatus.bluetoothOff:
      case BleLaunchSyncStatus.failed:
      case BleLaunchSyncStatus.notFound:
        context.showError(message, duration: duration);
      case BleLaunchSyncStatus.skipped:
      case BleLaunchSyncStatus.cancelled:
        break;
    }
  }

  void _onProgress() {
    final progress = _sync?.progress.value ?? const BleLaunchSyncProgress();
    _view.setProgress(progress);
    if (progress.isBusy) {
      final start = _foregroundServiceStart ??= _startForegroundService(
        _backgroundStatus(progress),
      );
      unawaited(_updateForegroundServiceWhenReady(start));
    }
  }

  @override
  void dispose() {
    widget.homePresence?.removeListener(_onPresence);
    _sync?.progress.removeListener(_onProgress);
    _sync?.cancel();
    unawaited(_stopForegroundService());
    _view.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(appSettingsProvider, (prev, next) => _onSettings(next));
    return BleLaunchSyncScope(notifier: _view, child: widget.child);
  }
}

/// Opens an attached, dimmed detail panel for the compact Bluetooth indicator.
class BleLaunchSyncPopout extends StatelessWidget {
  /// Wrap [child] with a launch-sync overlay.
  const BleLaunchSyncPopout({super.key, this.child});

  /// Content under the overlay.
  final Widget? child;

  @override
  Widget build(BuildContext context) => _BleLaunchSyncOverlayHost(child: child);
}

class _BleLaunchSyncOverlayHost extends StatefulWidget {
  const _BleLaunchSyncOverlayHost({this.child});

  final Widget? child;

  @override
  State<_BleLaunchSyncOverlayHost> createState() =>
      _BleLaunchSyncOverlayHostState();
}

class _BleLaunchSyncOverlayHostState extends State<_BleLaunchSyncOverlayHost>
    with SingleTickerProviderStateMixin {
  BleLaunchSyncView? _view;
  OverlayEntry? _entry;
  late final AnimationController _transition = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 320),
    reverseDuration: const Duration(milliseconds: 220),
  )..addListener(_refreshEntry);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final nextView = BleLaunchSyncScope.maybeOf(context);
    if (identical(nextView, _view)) return;
    _view?.removeListener(_syncOverlay);
    _view = nextView;
    _view?.addListener(_syncOverlay);
    _syncOverlay();
  }

  bool get _shouldShow {
    final view = _view;
    return view != null &&
        view.detailsOpen &&
        (view.paused || view.progress.hasVisibleStatus);
  }

  void _syncOverlay() {
    final view = _view;
    if (view == null) return;
    if (_shouldShow) {
      if (_entry == null) {
        _entry = OverlayEntry(
          builder: (context) =>
              _BleLaunchSyncAttachedPanel(view: view, transition: _transition),
        );
        Overlay.of(context, rootOverlay: true).insert(_entry!);
      }
      _transition.forward();
    } else if (_entry != null) {
      _transition.reverse().then((_) {
        if (mounted && !_shouldShow) _removeEntry();
      });
    }
    _refreshEntry();
  }

  void _refreshEntry() => _entry?.markNeedsBuild();

  void _removeEntry() {
    _entry?.remove();
    _entry?.dispose();
    _entry = null;
  }

  @override
  void dispose() {
    _view?.removeListener(_syncOverlay);
    _removeEntry();
    _transition.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child ?? const SizedBox.shrink();
}

class _BleLaunchSyncAttachedPanel extends StatelessWidget {
  const _BleLaunchSyncAttachedPanel({
    required this.view,
    required this.transition,
  });

  final BleLaunchSyncView view;
  final Animation<double> transition;

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.sizeOf(context).width;
    // AppBar actions sit on the end edge. Anchor the panel there so Arabic
    // (RTL) grows the card inward instead of off the leading side. A trailing
    // filter insets that anchor, so shift the card back inside the screen.
    final direction = Directionality.of(context);
    final topEnd = AlignmentDirectional.topEnd.resolve(direction);
    final bottomEnd = AlignmentDirectional.bottomEnd.resolve(direction);
    final endIsRight = topEnd == Alignment.topRight;
    final placement = _syncPanelPlacement(
      screenWidth: screenWidth,
      anchorEnd: _indicatorAnchorEnd(view.indicatorKey, endIsRight: endIsRight),
      endIsRight: endIsRight,
    );
    return AnimatedBuilder(
      animation: transition,
      builder: (context, _) => Stack(
        fit: StackFit.expand,
        clipBehavior: Clip.none,
        children: [
          ModalBarrier(
            color: Colors.black.withValues(alpha: 0.54 * transition.value),
            dismissible: true,
            onDismiss: view.closeDetails,
            semanticsLabel: MaterialLocalizations.of(
              context,
            ).modalBarrierDismissLabel,
          ),
          Align(
            alignment: topEnd,
            child: CompositedTransformFollower(
              link: view.indicatorLink,
              showWhenUnlinked: false,
              targetAnchor: bottomEnd,
              followerAnchor: topEnd,
              offset: Offset(placement.dx, 12),
              child: Opacity(
                opacity: transition.value,
                child: Transform.scale(
                  alignment: topEnd,
                  scale: 0.9 + transition.value * 0.1,
                  child: SizedBox(
                    width: placement.width,
                    child: BleLaunchSyncCard(
                      progress: view.progress,
                      paused: view.paused,
                      onClosed: view.closeDetails,
                      onPause: view.onPause,
                      onResume: view.onResume,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SyncPanelPlacement {
  const _SyncPanelPlacement({required this.width, required this.dx});

  final double width;
  final double dx;
}

double? _indicatorAnchorEnd(GlobalKey key, {required bool endIsRight}) {
  final target = key.currentContext?.findRenderObject();
  if (target is! RenderBox || !target.hasSize || !target.attached) return null;
  final origin = target.localToGlobal(Offset.zero);
  return endIsRight ? origin.dx + target.size.width : origin.dx;
}

/// Keeps a card anchored to [anchorEnd] inside the screen.
///
/// The measurement filter sits outside the Bluetooth indicator, so a card as
/// wide as the screen overflows the opposite edge. Shift it back in. The card
/// already insets its own contents, so the outer box may sit on the screen edge.
_SyncPanelPlacement _syncPanelPlacement({
  required double screenWidth,
  required double? anchorEnd,
  required bool endIsRight,
}) {
  final full = screenWidth - 24;
  var width = full < 420 ? full : 420.0;
  if (width < 0) width = 0;
  if (anchorEnd == null || screenWidth <= 0) {
    return _SyncPanelPlacement(width: width, dx: 0);
  }

  var start = endIsRight ? anchorEnd - width : anchorEnd;
  var end = start + width;
  if (start < 0) {
    final shift = -start;
    start += shift;
    end += shift;
  }
  if (end > screenWidth) {
    final shift = end - screenWidth;
    start -= shift;
    end -= shift;
  }
  if (start < 0) {
    start = 0;
    width = screenWidth;
    end = screenWidth;
  }
  final aligned = endIsRight ? end : start;
  return _SyncPanelPlacement(width: width, dx: aligned - anchorEnd);
}
