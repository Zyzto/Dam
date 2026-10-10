import 'dart:io';

import 'package:blood_pressure_app/core/repository/repo_context.dart';
import 'package:blood_pressure_app/core/widgets/toast.dart';
import 'package:blood_pressure_app/features/health_connect/bp_sync_model.dart';
import 'package:blood_pressure_app/features/health_connect/sync_model.dart';
import 'package:blood_pressure_app/features/health_connect/sync_tile.dart';
import 'package:blood_pressure_app/features/health_connect/weight_sync_model.dart';
import 'package:blood_pressure_app/features/settings/app_settings.dart';
import 'package:blood_pressure_app/features/settings/registry.dart';
import 'package:blood_pressure_app/features/settings/tiles/titled_column.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_settings_framework/flutter_settings_framework.dart';
import 'package:health/health.dart';

class HealthConnectScreen extends ConsumerStatefulWidget {
  const HealthConnectScreen({super.key});

  @override
  ConsumerState<HealthConnectScreen> createState() =>
      _HealthConnectScreenState();
}

class _HealthConnectScreenState extends ConsumerState<HealthConnectScreen> {
  @override
  void initState() {
    super.initState();
    _bootstrap().ignore();
  }

  final _health = Health();

  bool _platformSupport = false;
  bool _hasWeightPermission = false;
  bool _hasBloodPressurePermission = false;

  Future<void> _bootstrap() async {
    await _health.configure();
    await _checkPermissions();
    if (!mounted) return;
    final enabled = ref.read(appSettingsProvider).useHealthConnect;
    if (enabled && _platformSupport && !_hasAllPermissions) {
      final granted = await _requestPermissions();
      if (!granted && mounted) {
        await ref.updateSetting(useHealthConnectSetting, false);
      }
    }
  }

  bool get _hasAllPermissions {
    final settings = ref.read(appSettingsProvider);
    return (!settings.weightInput || _hasWeightPermission) &&
        (!settings.bloodPressureEnabled || _hasBloodPressurePermission);
  }

  Future<void> _checkPermissions() async {
    if (!(Platform.isAndroid || Platform.isIOS)) {
      if (!mounted) return;
      setState(() {
        _platformSupport = false;
        _hasWeightPermission = false;
        _hasBloodPressurePermission = false;
      });
      return;
    }
    try {
      final settings = ref.read(appSettingsProvider);
      final platformSupport = await _health.isHealthConnectAvailable();
      final hasWeightPermission = settings.weightInput
          ? await _health.hasPermissions(
                  [HealthDataType.WEIGHT],
                  permissions: [HealthDataAccess.READ_WRITE],
                ) ??
                false
          : false;
      final hasBloodPressurePermission = settings.bloodPressureEnabled
          ? await _health.hasPermissions(
                  [
                    HealthDataType.BLOOD_PRESSURE_SYSTOLIC,
                    HealthDataType.BLOOD_PRESSURE_DIASTOLIC,
                  ],
                  permissions: [
                    HealthDataAccess.READ_WRITE,
                    HealthDataAccess.READ_WRITE,
                  ],
                ) ??
                false
          : false;
      if (!mounted) return;
      setState(() {
        _platformSupport = platformSupport;
        _hasWeightPermission = hasWeightPermission;
        _hasBloodPressurePermission = hasBloodPressurePermission;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _platformSupport = false;
        _hasWeightPermission = false;
        _hasBloodPressurePermission = false;
      });
    }
  }

  Future<bool> _requestPermissions() async {
    final settings = ref.read(appSettingsProvider);
    final types = <HealthDataType>[
      if (settings.bloodPressureEnabled) ...[
        HealthDataType.BLOOD_PRESSURE_SYSTOLIC,
        HealthDataType.BLOOD_PRESSURE_DIASTOLIC,
      ],
      if (settings.weightInput) HealthDataType.WEIGHT,
    ];
    if (types.isEmpty) return true;
    try {
      final granted = await _health.requestPermissionsIfMissing(types);
      if (!granted && mounted) {
        context.showError('noPermissions'.tr());
      }
      await _checkPermissions();
      return granted;
    } catch (_) {
      if (mounted) {
        context.showError('noPermissions'.tr());
      }
      await _checkPermissions();
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(appSettingsProvider);
    final hasSyncableFeatures =
        settings.bloodPressureEnabled || settings.weightInput;
    return Scaffold(
      appBar: AppBar(title: Text('healthConnect'.tr())),
      body: ListView(
        children: [
          Padding(
            padding: const EdgeInsetsDirectional.only(
              start: 10.0,
              end: 10.0,
              top: 16.0,
              bottom: 10.0,
            ),
            child: Text('healthConnectDesc'.tr()),
          ),
          Padding(
            padding: EdgeInsetsGeometry.symmetric(horizontal: 8.0),
            child: SwitchListTile(
              title: Text('optEnableHealthConnect'.tr()),
              tileColor: Theme.of(context).cardColor,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadiusGeometry.circular(16.0),
              ),
              minVerticalPadding: 22.0,
              value: settings.useHealthConnect,
              onChanged:
                  (Platform.isAndroid || Platform.isIOS) &&
                      (hasSyncableFeatures || settings.useHealthConnect)
                  ? (newValue) async {
                      if (newValue) {
                        if (!hasSyncableFeatures) return;
                        final granted = await _requestPermissions();
                        if (!granted) return;
                        await ref.updateSetting(useHealthConnectSetting, true);
                        return;
                      }
                      await _health.revokePermissions();
                      await ref.updateSetting(useHealthConnectSetting, false);
                      await _checkPermissions();
                    }
                  : null,
              subtitle: _platformSupport
                  ? hasSyncableFeatures
                        ? null
                        : Text('onboardingFeaturesHint'.tr())
                  : Text(
                      'healthConnectPlatformUnsupported'.tr(),
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
            ),
          ),

          if (settings.weightInput &&
              _platformSupport &&
              !_hasWeightPermission &&
              _hasBloodPressurePermission)
            _missingPermissionsBanner('noWeightPermission'.tr()),
          if (settings.bloodPressureEnabled &&
              _platformSupport &&
              _hasWeightPermission &&
              !_hasBloodPressurePermission)
            _missingPermissionsBanner('noBloodPressurePermission'.tr()),
          if (_platformSupport &&
              ((settings.weightInput && !_hasWeightPermission) ||
                  (settings.bloodPressureEnabled &&
                      !_hasBloodPressurePermission)) &&
              (!settings.weightInput || !_hasWeightPermission) &&
              (!settings.bloodPressureEnabled || !_hasBloodPressurePermission))
            _missingPermissionsBanner('noPermissions'.tr()),
          if (settings.bloodPressureEnabled || settings.weightInput)
            SwitchListTile(
              title: Text('syncOnAppStart'.tr()),
              value: settings.syncOnAppStart,
              onChanged: _hasAllPermissions
                  ? (v) {
                      ref.updateSetting(syncOnAppStartSetting, v);
                    }
                  : null,
            ),
          if (settings.weightInput)
            TitledColumn(
              title: Text('weight'.tr()),
              children: [
                SwitchListTile(
                  title: Text('automaticallySyncData'.tr()),
                  value: settings.syncWeightMeasurements,
                  onChanged: _hasWeightPermission
                      ? (v) {
                          ref.updateSetting(syncWeightMeasurementsSetting, v);
                        }
                      : null,
                ),
                SyncTile(
                  disabled: !_hasWeightPermission,
                  mdl: WeightSyncModel(
                    weightRepo: context.weightRepo,
                    health: _health,
                  ),
                ),
              ],
            ),
          if (settings.bloodPressureEnabled)
            TitledColumn(
              title: Text('bloodPressure'.tr()),
              children: [
                SwitchListTile(
                  title: Text('automaticallySyncData'.tr()),
                  value: settings.syncPressureMeasurements,
                  onChanged: _hasBloodPressurePermission
                      ? (v) {
                          ref.updateSetting(syncPressureMeasurementsSetting, v);
                        }
                      : null,
                ),
                SyncTile(
                  disabled: !_hasBloodPressurePermission,
                  mdl: BPSyncModel(bpRepo: context.bpRepo, health: _health),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _missingPermissionsBanner(String reason) => Padding(
    padding: EdgeInsetsGeometry.symmetric(horizontal: 8.0, vertical: 2.0),
    child: Row(
      mainAxisSize: MainAxisSize.max,
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          reason,
          style: TextStyle(color: Theme.of(context).colorScheme.error),
        ),
        TextButton(
          onPressed: _requestPermissions,
          child: Text('btnCheckAgain'.tr()),
        ),
      ],
    ),
  );
}
