import 'package:blood_pressure_app/features/bluetooth/logic/ble_launch_sync.dart';
import 'package:blood_pressure_app/features/bluetooth/ui/ble_launch_sync_host.dart';
import 'package:blood_pressure_app/features/settings/app_settings.dart';
import 'package:blood_pressure_app/model/bluetooth_input_mode.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Compact AppBar control for a launch-time meter sync.
///
/// Each stage has its own icon. After sync finishes the Bluetooth icon stays
/// with a result color instead of disappearing. A tap opens the status card,
/// except after the one-minute search ends without a meter: that tap starts
/// the search again.
class BleHomeSyncIndicator extends ConsumerWidget {
  /// Create a home AppBar sync indicator.
  const BleHomeSyncIndicator({super.key});

  /// Width reserved in the app bar, including the gap before a trailing action.
  static const double slotWidth = 64;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(appSettingsProvider);
    if (!settings.syncBluetoothOnLaunch ||
        !settings.bluetoothMeasurementsEnabled ||
        settings.bleInput == BluetoothInputMode.disabled ||
        (!settings.bloodPressureEnabled && !settings.weightInput)) {
      return const SizedBox.shrink();
    }

    final view = BleLaunchSyncScope.maybeOf(context);
    if (view == null) return const SizedBox.shrink();
    final progress = view.progress;
    if (!progress.hasVisibleStatus && !view.paused) {
      return const SizedBox.shrink();
    }

    final theme = Theme.of(context);
    final muted =
        theme.appBarTheme.foregroundColor ?? theme.colorScheme.onSurface;
    final stopped =
        view.paused || progress.result?.status == BleLaunchSyncStatus.cancelled;
    final style = stopped
        ? _StageStyle(
            icon: Icons.bluetooth,
            color: muted,
            motion: _IconMotion.still,
            reserveCount: true,
            count: 0,
          )
        : _styleFor(progress, muted, theme);
    final tooltip = view.paused ? 'meterSyncPaused'.tr() : _tooltip(progress);
    return Padding(
      padding: const EdgeInsetsDirectional.only(end: 8),
      child: Semantics(
        liveRegion: true,
        label: tooltip,
        child: Tooltip(
          message: tooltip,
          child: CompositedTransformTarget(
            key: view.indicatorKey,
            link: view.indicatorLink,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minWidth: 56, minHeight: 56),
              child: InkWell(
                onTap: () => _onIndicatorTap(view, progress),
                borderRadius: BorderRadius.circular(16),
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 6,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _StageIcon(
                          icon: style.icon,
                          color: style.color,
                          motion: style.motion,
                        ),
                        if (style.reserveCount)
                          _CountSlot(
                            count: style.count,
                            color: style.color,
                            textStyle: theme.textTheme.labelLarge,
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  static _StageStyle _styleFor(
    BleLaunchSyncProgress progress,
    Color muted,
    ThemeData theme,
  ) {
    final count = _deviceCount(progress);
    if (progress.phase == BleLaunchSyncPhase.done || progress.result != null) {
      return _StageStyle(
        icon: Icons.bluetooth,
        color: _resultColor(progress.result, theme, muted),
        motion: _IconMotion.still,
        reserveCount: true,
        count: count,
      );
    }
    return switch (progress.phase) {
      BleLaunchSyncPhase.scanning => _StageStyle(
        icon: Icons.sync,
        color: muted,
        motion: _IconMotion.rotate,
        reserveCount: true,
        count: 0,
      ),
      BleLaunchSyncPhase.connecting => _StageStyle(
        icon: Icons.bluetooth,
        color: Colors.blue,
        motion: _IconMotion.still,
        reserveCount: true,
        count: count,
      ),
      BleLaunchSyncPhase.reading => _StageStyle(
        icon: Icons.bluetooth,
        color: Colors.orange,
        motion: _IconMotion.colorPulse,
        reserveCount: true,
        count: count,
      ),
      BleLaunchSyncPhase.importing => _StageStyle(
        icon: Icons.save_alt,
        color: Colors.orange,
        motion: _IconMotion.colorPulse,
        reserveCount: true,
        count: count,
      ),
      BleLaunchSyncPhase.idle || BleLaunchSyncPhase.done => _StageStyle(
        icon: Icons.bluetooth,
        color: muted,
        motion: _IconMotion.still,
        reserveCount: true,
        count: count,
      ),
    };
  }

  static int _deviceCount(BleLaunchSyncProgress progress) {
    if (progress.deviceCount > 0) return progress.deviceCount;
    return switch (progress.phase) {
      BleLaunchSyncPhase.connecting ||
      BleLaunchSyncPhase.reading ||
      BleLaunchSyncPhase.importing => 1,
      BleLaunchSyncPhase.done => switch (progress.result?.status) {
        BleLaunchSyncStatus.imported ||
        BleLaunchSyncStatus.upToDate ||
        BleLaunchSyncStatus.failed => 1,
        _ => 0,
      },
      BleLaunchSyncPhase.idle || BleLaunchSyncPhase.scanning => 0,
    };
  }

  static Color _resultColor(
    BleLaunchSyncResult? result,
    ThemeData theme,
    Color muted,
  ) => switch (result?.status) {
    BleLaunchSyncStatus.imported => Colors.green,
    BleLaunchSyncStatus.upToDate => Colors.white70,
    BleLaunchSyncStatus.failed ||
    BleLaunchSyncStatus.bluetoothOff => theme.colorScheme.error,
    BleLaunchSyncStatus.notFound || BleLaunchSyncStatus.cancelled => muted,
    BleLaunchSyncStatus.skipped || null => Colors.white70,
  };

  static String _tooltip(BleLaunchSyncProgress progress) {
    final result = progress.result;
    if (result != null) {
      return switch (result.status) {
        BleLaunchSyncStatus.imported => 'importedNewMeasurements'.tr(
          namedArgs: {'count': '${result.count}'},
        ),
        BleLaunchSyncStatus.upToDate => 'noNewMeasurements'.tr(),
        BleLaunchSyncStatus.bluetoothOff => 'bluetoothOffSyncSkipped'.tr(),
        BleLaunchSyncStatus.failed => 'bluetoothSyncFailed'.tr(),
        BleLaunchSyncStatus.notFound => 'meterNotFound'.tr(),
        BleLaunchSyncStatus.cancelled ||
        BleLaunchSyncStatus.skipped => 'meterNotFound'.tr(),
      };
    }
    final name = progress.deviceName?.trim();
    final hasName = name != null && name.isNotEmpty;
    return switch (progress.phase) {
      BleLaunchSyncPhase.scanning =>
        hasName
            ? 'lookingForDevice'.tr(namedArgs: {'name': name})
            : 'scanningForDevices'.tr(),
      BleLaunchSyncPhase.connecting =>
        hasName
            ? 'foundMeterNamed'.tr(namedArgs: {'name': name})
            : 'connectingToMeter'.tr(),
      BleLaunchSyncPhase.reading => 'readingStoredMeasurements'.tr(),
      BleLaunchSyncPhase.importing => 'savingNewMeasurements'.tr(),
      BleLaunchSyncPhase.idle || BleLaunchSyncPhase.done => 'syncingMeter'.tr(),
    };
  }
}

/// After the one-minute search finds nothing, a tap runs it again.
/// Otherwise the tap opens the status card.
void _onIndicatorTap(BleLaunchSyncView view, BleLaunchSyncProgress progress) {
  final retryAfterTimeout =
      view.onResume != null &&
      !view.paused &&
      !progress.isBusy &&
      progress.result?.status == BleLaunchSyncStatus.notFound;
  if (retryAfterTimeout) {
    view.onResume!();
    return;
  }
  view.openDetails();
}

class _StageStyle {
  const _StageStyle({
    required this.icon,
    required this.color,
    required this.motion,
    this.reserveCount = false,
    this.count,
  });

  final IconData icon;
  final Color color;
  final _IconMotion motion;
  final bool reserveCount;
  final int? count;
}

class _CountSlot extends StatelessWidget {
  const _CountSlot({
    required this.count,
    required this.color,
    required this.textStyle,
  });

  final int? count;
  final Color color;
  final TextStyle? textStyle;

  static const double _digitWidth = 14;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsetsDirectional.only(start: 4),
    child: SizedBox(
      width: _digitWidth,
      child: count == null
          ? null
          : Text(
              '$count',
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.clip,
              style: textStyle?.copyWith(color: color),
            ),
    ),
  );
}

enum _IconMotion { rotate, still, colorPulse }

class _StageIcon extends StatefulWidget {
  const _StageIcon({
    required this.icon,
    required this.color,
    required this.motion,
  });

  final IconData icon;
  final Color color;
  final _IconMotion motion;

  @override
  State<_StageIcon> createState() => _StageIconState();
}

class _StageIconState extends State<_StageIcon>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: _durationFor(widget.motion),
  );

  @override
  void initState() {
    super.initState();
    _syncMotion();
  }

  @override
  void didUpdateWidget(_StageIcon oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.motion != widget.motion) {
      _controller.duration = _durationFor(widget.motion);
      _syncMotion();
    }
  }

  Duration _durationFor(_IconMotion motion) => motion == _IconMotion.rotate
      ? const Duration(seconds: 1)
      : const Duration(milliseconds: 900);

  void _syncMotion() {
    switch (widget.motion) {
      case _IconMotion.rotate:
        _controller.repeat();
      case _IconMotion.still:
        _controller
          ..stop()
          ..value = 0;
      case _IconMotion.colorPulse:
        _controller.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final icon = Icon(widget.icon, size: 22, color: widget.color);
    return switch (widget.motion) {
      _IconMotion.still => icon,
      _IconMotion.rotate => RotationTransition(turns: _controller, child: icon),
      _IconMotion.colorPulse => AnimatedBuilder(
        animation: _controller,
        builder: (context, _) => Icon(
          widget.icon,
          size: 22,
          color: Color.lerp(
            Colors.orange.shade200,
            Colors.orange.shade800,
            _controller.value,
          ),
        ),
      ),
    };
  }
}
