import 'package:blood_pressure_app/features/bluetooth/logic/ble_launch_sync.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

/// Status card shown while a launch-time meter sync is running or finished.
class BleLaunchSyncCard extends StatelessWidget {
  /// Create a launch-sync status card.
  const BleLaunchSyncCard({
    super.key,
    required this.progress,
    this.paused = false,
    this.onClosed,
    this.onPause,
    this.onResume,
  });

  /// Current sync stage and optional result.
  final BleLaunchSyncProgress progress;

  /// Whether the user paused launch sync.
  final bool paused;

  /// Hides the card without cancelling an in-flight sync.
  final VoidCallback? onClosed;

  /// Stops the in-flight sync until [onResume].
  final VoidCallback? onPause;

  /// Starts launch sync again after [paused].
  final VoidCallback? onResume;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final result = progress.result;
    final busy = progress.isBusy && !paused;
    final showResume = onResume != null && !busy && paused;
    final showSearchAgain = onResume != null
        && !busy
        && !paused
        && result != null;
    return Card(
      margin: const EdgeInsets.only(top: 8),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 8, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(
                  _leadingIcon,
                  color: _leadingColor(theme),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    _title(),
                    style: theme.textTheme.titleMedium,
                  ),
                ),
                if (busy && (progress.phase == BleLaunchSyncPhase.scanning
                    || progress.lookingForMore))
                  _ScanCountdown(until: progress.scanUntil),
                if (busy
                    && progress.phase != BleLaunchSyncPhase.scanning
                    && !progress.lookingForMore)
                  const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                if (showResume)
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    tooltip: 'resumeMeterSync'.tr(),
                    onPressed: onResume,
                    icon: const Icon(Icons.play_arrow),
                  )
                else if (showSearchAgain)
                  IconButton(
                    key: const Key('searchAgainMeter'),
                    visualDensity: VisualDensity.compact,
                    tooltip: 'searchAgainMeter'.tr(),
                    onPressed: onResume,
                    icon: const Icon(Icons.refresh),
                  )
                else if (busy && onPause != null)
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    tooltip: 'pauseMeterSync'.tr(),
                    onPressed: onPause,
                    icon: const Icon(Icons.pause),
                  ),
                if (onClosed != null)
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    onPressed: onClosed,
                    icon: const Icon(Icons.close),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            _StepRow(phase: progress.phase, result: result),
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: busy ? _barValue : (result == null ? 0 : 1),
                minHeight: 4,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              _info(),
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            if (_detail() case final String detail) ...[
              const SizedBox(height: 4),
              Text(
                detail,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  IconData get _leadingIcon {
    if (paused) return Icons.pause_circle_outline;
    final result = progress.result;
    if (result != null) {
      return switch (result.status) {
        BleLaunchSyncStatus.imported ||
        BleLaunchSyncStatus.upToDate => Icons.check_circle_outline,
        BleLaunchSyncStatus.bluetoothOff => Icons.bluetooth_disabled,
        BleLaunchSyncStatus.failed => Icons.error_outline,
        BleLaunchSyncStatus.notFound ||
        BleLaunchSyncStatus.cancelled => Icons.bluetooth_disabled,
        BleLaunchSyncStatus.skipped => Icons.info_outline,
      };
    }
    return switch (progress.phase) {
      BleLaunchSyncPhase.idle ||
      BleLaunchSyncPhase.scanning => Icons.bluetooth_searching,
      BleLaunchSyncPhase.connecting => Icons.bluetooth_connected,
      BleLaunchSyncPhase.reading ||
      BleLaunchSyncPhase.importing => Icons.downloading,
      BleLaunchSyncPhase.done => Icons.check_circle_outline,
    };
  }

  Color _leadingColor(ThemeData theme) {
    final result = progress.result;
    if (result?.status == BleLaunchSyncStatus.failed
        || result?.status == BleLaunchSyncStatus.notFound) {
      return theme.colorScheme.error;
    }
    if (result?.status == BleLaunchSyncStatus.imported
        || result?.status == BleLaunchSyncStatus.upToDate) {
      return theme.colorScheme.primary;
    }
    return theme.colorScheme.primary;
  }

  double get _barValue => switch (progress.phase) {
    BleLaunchSyncPhase.idle => 0,
    BleLaunchSyncPhase.scanning => 0.2,
    BleLaunchSyncPhase.connecting => 0.45,
    BleLaunchSyncPhase.reading => 0.7,
    BleLaunchSyncPhase.importing => 0.9,
    BleLaunchSyncPhase.done => 1,
  };

  String _title() {
    if (paused) return 'meterSyncPaused'.tr();
    final result = progress.result;
    if (result != null) {
      return switch (result.status) {
        BleLaunchSyncStatus.imported =>
          'importedNewMeasurements'.tr(namedArgs: {'count': '${result.count}'}),
        BleLaunchSyncStatus.upToDate => 'noNewMeasurements'.tr(),
        BleLaunchSyncStatus.bluetoothOff => 'bluetoothOffSyncSkipped'.tr(),
        BleLaunchSyncStatus.failed => 'bluetoothSyncFailed'.tr(),
        BleLaunchSyncStatus.notFound ||
        BleLaunchSyncStatus.cancelled => 'meterNotFound'.tr(),
        BleLaunchSyncStatus.skipped => '',
      };
    }
    final name = progress.deviceName?.trim();
    final hasName = name != null && name.isNotEmpty;
    return switch (progress.phase) {
      BleLaunchSyncPhase.idle ||
      BleLaunchSyncPhase.scanning => hasName
          ? 'lookingForDevice'.tr(namedArgs: {'name': name})
          : 'scanningForDevices'.tr(),
      BleLaunchSyncPhase.connecting => hasName
          ? 'foundMeterNamed'.tr(namedArgs: {'name': name})
          : 'connectingToMeter'.tr(),
      BleLaunchSyncPhase.reading => 'readingStoredMeasurements'.tr(),
      BleLaunchSyncPhase.importing => 'savingNewMeasurements'.tr(),
      BleLaunchSyncPhase.done => 'syncingMeter'.tr(),
    };
  }

  String _info() {
    if (paused) return 'meterSyncPausedHint'.tr();
    final name = progress.deviceName?.trim();
    final hasName = name != null && name.isNotEmpty;
    final result = progress.result;
    if (result != null) {
      if (result.status == BleLaunchSyncStatus.imported
          || result.status == BleLaunchSyncStatus.upToDate) {
        if (result.duplicateCount > 0) {
          return 'skippedAlreadySaved'.tr(namedArgs: {'count': '${result.duplicateCount}'});
        }
        if (result.receivedCount > 0) {
          return 'newMeasurements'.tr(namedArgs: {'count': '${result.count}'});
        }
      }
      if (result.status == BleLaunchSyncStatus.notFound) {
        return 'keepMeterNearby'.tr();
      }
      return 'keepMeterNearby'.tr();
    }
    if (progress.lookingForMore) {
      return 'scanningForExtraDevices'.tr();
    }
    return switch (progress.phase) {
      BleLaunchSyncPhase.connecting => hasName
          ? 'connectingToDevice'.tr(namedArgs: {'name': name})
          : 'connectingToMeter'.tr(),
      BleLaunchSyncPhase.reading => 'readingStoredMeasurements'.tr(),
      BleLaunchSyncPhase.importing => 'savingNewMeasurements'.tr(),
      BleLaunchSyncPhase.scanning => 'checkingForOneMinute'.tr(),
      _ => 'keepMeterNearby'.tr(),
    };
  }

  String? _detail() {
    if (paused || progress.result != null) return null;
    if (progress.phase == BleLaunchSyncPhase.reading
        || progress.phase == BleLaunchSyncPhase.connecting) {
      return 'waitForMeterMeasurement'.tr();
    }
    return null;
  }
}

class _ScanCountdown extends StatelessWidget {
  const _ScanCountdown({this.until});

  final DateTime? until;

  @override
  Widget build(BuildContext context) {
    final deadline = until ?? DateTime.now();
    final remaining = deadline.difference(DateTime.now());
    if (remaining <= Duration.zero) {
      return Text(
        'timeLeft'.tr(namedArgs: {'time': '0:00'}),
        style: Theme.of(context).textTheme.labelLarge,
      );
    }
    return TweenAnimationBuilder<int>(
      tween: IntTween(begin: remaining.inSeconds, end: 0),
      duration: remaining,
      builder: (context, seconds, _) {
        final minutes = seconds ~/ 60;
        final rest = (seconds % 60).toString().padLeft(2, '0');
        return Text(
          'timeLeft'.tr(namedArgs: {'time': '$minutes:$rest'}),
          style: Theme.of(context).textTheme.labelLarge,
        );
      },
    );
  }
}

class _StepRow extends StatelessWidget {
  const _StepRow({required this.phase, this.result});

  final BleLaunchSyncPhase phase;
  final BleLaunchSyncResult? result;

  @override
  Widget build(BuildContext context) {
    final current = switch (phase) {
      BleLaunchSyncPhase.idle ||
      BleLaunchSyncPhase.scanning => 0,
      BleLaunchSyncPhase.connecting => 1,
      BleLaunchSyncPhase.reading => 2,
      BleLaunchSyncPhase.importing => 3,
      BleLaunchSyncPhase.done => 4,
    };
    final failed = result?.status == BleLaunchSyncStatus.failed
        || result?.status == BleLaunchSyncStatus.notFound
        || result?.status == BleLaunchSyncStatus.bluetoothOff;
    final steps = <(IconData, String)>[
      (Icons.bluetooth_searching, 'syncStepLook'.tr()),
      (Icons.bluetooth_connected, 'syncStepConnect'.tr()),
      (Icons.downloading, 'syncStepRead'.tr()),
      (Icons.save_alt, 'syncStepSave'.tr()),
    ];
    return Row(
      children: [
        for (final (index, step) in steps.indexed) ...[
          if (index > 0)
            Expanded(
              child: Divider(
                color: current > index
                    ? Theme.of(context).colorScheme.primary
                    : Theme.of(context).colorScheme.outlineVariant,
              ),
            ),
          _StepChip(
            icon: step.$1,
            label: step.$2,
            state: failed && current <= index
                ? _StepStatus.pending
                : current > index
                    ? _StepStatus.done
                    : current == index
                        ? _StepStatus.active
                        : _StepStatus.pending,
          ),
        ],
      ],
    );
  }
}

enum _StepStatus { pending, active, done }

class _StepChip extends StatelessWidget {
  const _StepChip({
    required this.icon,
    required this.label,
    required this.state,
  });

  final IconData icon;
  final String label;
  final _StepStatus state;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = switch (state) {
      _StepStatus.done ||
      _StepStatus.active => theme.colorScheme.primary,
      _StepStatus.pending => theme.colorScheme.onSurfaceVariant,
    };
    return Column(
      children: [
        CircleAvatar(
          radius: 14,
          backgroundColor: state == _StepStatus.active
              ? theme.colorScheme.primaryContainer
              : theme.colorScheme.surfaceContainerHighest,
          child: Icon(
            state == _StepStatus.done ? Icons.check : icon,
            size: 16,
            color: color,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: theme.textTheme.labelSmall?.copyWith(color: color),
        ),
      ],
    );
  }
}
