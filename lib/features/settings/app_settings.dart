import 'dart:convert';

import 'package:blood_pressure_app/features/settings/registry.dart';
import 'package:blood_pressure_app/l10n/app_locales.dart';
import 'package:blood_pressure_app/model/blood_pressure/pressure_unit.dart';
import 'package:blood_pressure_app/model/bluetooth_input_mode.dart';
import 'package:blood_pressure_app/model/bluetooth_measurement_import_mode.dart';
import 'package:blood_pressure_app/model/body_sex.dart';
import 'package:blood_pressure_app/model/horizontal_graph_line.dart';
import 'package:blood_pressure_app/model/known_ble_device.dart';
import 'package:blood_pressure_app/model/range_limits.dart';
import 'package:blood_pressure_app/model/weight_unit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_settings_framework/flutter_settings_framework.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'app_settings.g.dart';

/// Immutable snapshot of user settings for widgets that need many fields.
class AppSettings {
  const AppSettings({
    required this.languageKey,
    required this.accentColor,
    required this.sysColor,
    required this.diaColor,
    required this.pulColor,
    required this.horizontalGraphLines,
    required this.dateFormatString,
    required this.graphLineThickness,
    required this.animationSpeed,
    required this.sysWarn,
    required this.diaWarn,
    required this.rangeLimits,
    required this.lastVersion,
    required this.allowManualTimeInput,
    required this.confirmDeletion,
    required this.themeMode,
    required this.validateInputs,
    required this.allowMissingValues,
    required this.drawRegressionLines,
    required this.startWithAddMeasurementPage,
    required this.autostartBluetoothInput,
    required this.syncBluetoothOnLaunch,
    required this.bluetoothImportMode,
    required this.compactList,
    required this.roundedReminderButton,
    required this.medicationNotificationsEnabled,
    required this.overdueReminderCount,
    required this.overdueReminderIntervalMinutes,
    required this.shiftMissedDoseTimes,
    required this.missedDoseShiftLimitMinutes,
    required this.showAllReminderRings,
    required this.needlePinBarWidth,
    required this.bottomAppBars,
    required this.preferredPressureUnit,
    required this.bleInput,
    required this.bluetoothMeasurementsEnabled,
    required this.bloodPressureEnabled,
    required this.medicineFeatureEnabled,
    required this.weightInput,
    required this.knownBleDev,
    required this.weightUnit,
    required this.bodyHeightCm,
    required this.birthYear,
    required this.bodySex,
    required this.athleteMode,
    required this.trustBLETime,
    required this.showBLETimeTrustDialog,
    required this.interruptGraphAfterNDays,
    required this.useHealthConnect,
    required this.syncWeightMeasurements,
    required this.syncPressureMeasurements,
    required this.syncOnAppStart,
    required this.onboardingCompleted,
  });

  factory AppSettings.fromController(SettingsController controller) {
    final height = controller.get(bodyHeightCmSetting);
    final year = controller.get(birthYearSetting);
    final sexKey = controller.get(bodySexSetting);
    final bleInput = BluetoothInputMode.values.firstWhere(
      (m) => m.name == controller.get(bleInputSetting),
      orElse: () => BluetoothInputMode.disabled,
    );
    return AppSettings(
      languageKey: controller.get(languageSetting),
      accentColor: Color(controller.get(accentColorSetting)),
      sysColor: Color(controller.get(sysColorSetting)),
      diaColor: Color(controller.get(diaColorSetting)),
      pulColor: Color(controller.get(pulColorSetting)),
      horizontalGraphLines: decodeHorizontalGraphLines(
        controller.get(horizontalGraphLinesSetting),
      ),
      dateFormatString: controller.get(dateFormatStringSetting),
      graphLineThickness: controller.get(graphLineThicknessSetting),
      animationSpeed: controller.get(animationSpeedSetting),
      sysWarn: controller.get(sysWarnSetting),
      diaWarn: controller.get(diaWarnSetting),
      rangeLimits: RangeLimits(
        bmiNormalMin: controller.get(bmiNormalMinSetting),
        bmiOverweightMin: controller.get(bmiOverweightMinSetting),
        bmiObeseMin: controller.get(bmiObeseMinSetting),
        sysElevatedMmHg: controller.get(sysElevatedMmHgSetting),
        sysHighMmHg: controller.get(sysHighMmHgSetting),
        diaHighMmHg: controller.get(diaHighMmHgSetting),
      ),
      lastVersion: controller.get(lastVersionSetting),
      allowManualTimeInput: controller.get(allowManualTimeInputSetting),
      confirmDeletion: controller.get(confirmDeletionSetting),
      themeMode: themeModeFromKey(controller.get(themeModeSetting)),
      validateInputs: controller.get(validateInputsSetting),
      allowMissingValues: controller.get(allowMissingValuesSetting),
      drawRegressionLines: controller.get(drawRegressionLinesSetting),
      startWithAddMeasurementPage: controller.get(
        startWithAddMeasurementPageSetting,
      ),
      autostartBluetoothInput: controller.get(autostartBluetoothInputSetting),
      syncBluetoothOnLaunch: controller.get(syncBluetoothOnLaunchSetting),
      bluetoothImportMode: BluetoothMeasurementImportMode.values.firstWhere(
        (m) => m.name == controller.get(bluetoothImportModeSetting),
        orElse: () => BluetoothMeasurementImportMode.disabled,
      ),
      compactList: controller.get(compactListSetting),
      roundedReminderButton: controller.get(roundedReminderButtonSetting),
      medicationNotificationsEnabled: controller.get(
        medicationNotificationsEnabledSetting,
      ),
      overdueReminderCount: controller.get(overdueReminderCountSetting),
      overdueReminderIntervalMinutes: controller.get(
        overdueReminderIntervalSetting,
      ),
      shiftMissedDoseTimes: controller.get(shiftMissedDoseTimesSetting),
      missedDoseShiftLimitMinutes: controller.get(missedDoseShiftLimitSetting),
      showAllReminderRings: controller.get(showAllReminderRingsSetting),
      needlePinBarWidth: controller.get(needlePinBarWidthSetting),
      bottomAppBars: controller.get(bottomAppBarsSetting),
      preferredPressureUnit: PressureUnit.values.firstWhere(
        (u) => u.name == controller.get(preferredPressureUnitSetting),
        orElse: () => PressureUnit.mmHg,
      ),
      bleInput: bleInput,
      bluetoothMeasurementsEnabled: bleInput != BluetoothInputMode.disabled,
      bloodPressureEnabled: controller.get(bloodPressureEnabledSetting),
      medicineFeatureEnabled: controller.get(medicineFeatureEnabledSetting),
      weightInput: controller.get(weightInputSetting),
      knownBleDev: decodeKnownBleDevices(
        controller.get(knownBleDevicesSetting),
      ),
      weightUnit: WeightUnit.values.firstWhere(
        (u) => u.name == controller.get(preferredWeightUnitSetting),
        orElse: () => WeightUnit.kg,
      ),
      bodyHeightCm: height > 0 ? height : null,
      birthYear: year > 0 ? year : null,
      bodySex: sexKey.isEmpty
          ? null
          : BodySex.values.firstWhere(
              (s) => s.name == sexKey,
              orElse: () => BodySex.female,
            ),
      athleteMode: controller.get(athleteModeSetting),
      trustBLETime: controller.get(trustBleTimeSetting),
      showBLETimeTrustDialog: controller.get(showBleTimeTrustDialogSetting),
      interruptGraphAfterNDays: controller.get(interruptGraphAfterNDaysSetting),
      useHealthConnect: controller.get(useHealthConnectSetting),
      syncWeightMeasurements: controller.get(syncWeightMeasurementsSetting),
      syncPressureMeasurements: controller.get(syncPressureMeasurementsSetting),
      syncOnAppStart: controller.get(syncOnAppStartSetting),
      onboardingCompleted: controller.get(onboardingCompletedSetting),
    );
  }

  final String languageKey;
  final Color accentColor;
  final Color sysColor;
  final Color diaColor;
  final Color pulColor;
  final List<HorizontalGraphLine> horizontalGraphLines;
  final String dateFormatString;
  final double graphLineThickness;
  final int animationSpeed;
  final int sysWarn;
  final int diaWarn;

  /// BMI and blood-pressure category cutoffs.
  final RangeLimits rangeLimits;
  final int lastVersion;
  final bool allowManualTimeInput;
  final bool confirmDeletion;
  final ThemeMode themeMode;
  final bool validateInputs;
  final bool allowMissingValues;
  final bool drawRegressionLines;
  final bool startWithAddMeasurementPage;
  final bool autostartBluetoothInput;
  final bool syncBluetoothOnLaunch;
  final BluetoothMeasurementImportMode bluetoothImportMode;
  final bool compactList;
  final bool roundedReminderButton;
  final bool medicationNotificationsEnabled;
  final int overdueReminderCount;
  final int overdueReminderIntervalMinutes;
  final bool shiftMissedDoseTimes;
  final int missedDoseShiftLimitMinutes;
  final bool showAllReminderRings;
  final double needlePinBarWidth;
  final bool bottomAppBars;
  final PressureUnit preferredPressureUnit;
  final BluetoothInputMode bleInput;
  final bool bluetoothMeasurementsEnabled;
  final bool bloodPressureEnabled;
  final bool medicineFeatureEnabled;
  final bool weightInput;
  final List<KnownBleDevice> knownBleDev;
  final WeightUnit weightUnit;
  final double? bodyHeightCm;
  final int? birthYear;
  final BodySex? bodySex;
  final bool athleteMode;
  final bool trustBLETime;
  final bool showBLETimeTrustDialog;
  final int interruptGraphAfterNDays;
  final bool useHealthConnect;
  final bool syncWeightMeasurements;
  final bool syncPressureMeasurements;
  final bool syncOnAppStart;
  final bool onboardingCompleted;

  Locale? get language => localeFromLanguageKey(languageKey);

  bool get hasBodyProfile =>
      bodyHeightCm != null && birthYear != null && bodySex != null;

  int? get bodyAgeYears {
    final year = birthYear;
    if (year == null) return null;
    return DateTime.now().year - year;
  }
}

ThemeMode themeModeFromKey(String key) => switch (key) {
  'dark' => ThemeMode.dark,
  'light' => ThemeMode.light,
  _ => ThemeMode.system,
};

List<HorizontalGraphLine> decodeHorizontalGraphLines(String raw) {
  try {
    final decoded = jsonDecode(raw);
    if (decoded is! List) return [];
    return decoded
        .whereType<Map<Object?, Object?>>()
        .map((e) => HorizontalGraphLine.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  } catch (_) {
    return [];
  }
}

String encodeKnownBleDevicesJson(List<KnownBleDevice> devices) =>
    jsonEncode(devices.map((d) => d.toJson()).toList());

Future<void> persistKnownBleDevices(
  SettingsController controller,
  List<KnownBleDevice> devices,
) => controller.set(knownBleDevicesSetting, encodeKnownBleDevicesJson(devices));

List<KnownBleDevice> decodeKnownBleDevices(String raw) {
  try {
    final decoded = jsonDecode(raw);
    if (decoded is! List) return [];
    return decoded
        .whereType<Map<Object?, Object?>>()
        .map((e) => KnownBleDevice.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  } catch (_) {
    return [];
  }
}

@riverpod
AppSettings appSettings(Ref ref) {
  final settings = ref.watch(settingsProvidersProvider);
  ref.watch(settings.provider(languageSetting));
  ref.watch(settings.provider(accentColorSetting));
  ref.watch(settings.provider(sysColorSetting));
  ref.watch(settings.provider(diaColorSetting));
  ref.watch(settings.provider(pulColorSetting));
  ref.watch(settings.provider(horizontalGraphLinesSetting));
  ref.watch(settings.provider(dateFormatStringSetting));
  ref.watch(settings.provider(graphLineThicknessSetting));
  ref.watch(settings.provider(animationSpeedSetting));
  ref.watch(settings.provider(sysWarnSetting));
  ref.watch(settings.provider(diaWarnSetting));
  ref.watch(settings.provider(bmiNormalMinSetting));
  ref.watch(settings.provider(bmiOverweightMinSetting));
  ref.watch(settings.provider(bmiObeseMinSetting));
  ref.watch(settings.provider(sysElevatedMmHgSetting));
  ref.watch(settings.provider(sysHighMmHgSetting));
  ref.watch(settings.provider(diaHighMmHgSetting));
  ref.watch(settings.provider(lastVersionSetting));
  ref.watch(settings.provider(allowManualTimeInputSetting));
  ref.watch(settings.provider(confirmDeletionSetting));
  ref.watch(settings.provider(themeModeSetting));
  ref.watch(settings.provider(validateInputsSetting));
  ref.watch(settings.provider(allowMissingValuesSetting));
  ref.watch(settings.provider(drawRegressionLinesSetting));
  ref.watch(settings.provider(startWithAddMeasurementPageSetting));
  ref.watch(settings.provider(autostartBluetoothInputSetting));
  ref.watch(settings.provider(syncBluetoothOnLaunchSetting));
  ref.watch(settings.provider(bluetoothImportModeSetting));
  ref.watch(settings.provider(compactListSetting));
  ref.watch(settings.provider(roundedReminderButtonSetting));
  ref.watch(settings.provider(medicationNotificationsEnabledSetting));
  ref.watch(settings.provider(overdueReminderCountSetting));
  ref.watch(settings.provider(overdueReminderIntervalSetting));
  ref.watch(settings.provider(shiftMissedDoseTimesSetting));
  ref.watch(settings.provider(missedDoseShiftLimitSetting));
  ref.watch(settings.provider(showAllReminderRingsSetting));
  ref.watch(settings.provider(needlePinBarWidthSetting));
  ref.watch(settings.provider(bottomAppBarsSetting));
  ref.watch(settings.provider(preferredPressureUnitSetting));
  ref.watch(settings.provider(bleInputSetting));
  ref.watch(settings.provider(bluetoothMeasurementsEnabledSetting));
  ref.watch(settings.provider(bloodPressureEnabledSetting));
  ref.watch(settings.provider(medicineFeatureEnabledSetting));
  ref.watch(settings.provider(weightInputSetting));
  ref.watch(settings.provider(knownBleDevicesSetting));
  ref.watch(settings.provider(preferredWeightUnitSetting));
  ref.watch(settings.provider(bodyHeightCmSetting));
  ref.watch(settings.provider(birthYearSetting));
  ref.watch(settings.provider(bodySexSetting));
  ref.watch(settings.provider(athleteModeSetting));
  ref.watch(settings.provider(trustBleTimeSetting));
  ref.watch(settings.provider(showBleTimeTrustDialogSetting));
  ref.watch(settings.provider(interruptGraphAfterNDaysSetting));
  ref.watch(settings.provider(useHealthConnectSetting));
  ref.watch(settings.provider(syncWeightMeasurementsSetting));
  ref.watch(settings.provider(syncPressureMeasurementsSetting));
  ref.watch(settings.provider(syncOnAppStartSetting));
  ref.watch(settings.provider(onboardingCompletedSetting));
  return AppSettings.fromController(settings.controller);
}

extension AppSettingsRef on WidgetRef {
  AppSettings get appSettings => watch(appSettingsProvider);

  AppSettings readAppSettings() => read(appSettingsProvider);

  Future<void> writeKnownBleDevices(List<KnownBleDevice> devices) =>
      updateSetting(knownBleDevicesSetting, encodeKnownBleDevicesJson(devices));

  Future<void> writeHorizontalGraphLines(List<HorizontalGraphLine> lines) =>
      updateSetting(
        horizontalGraphLinesSetting,
        jsonEncode(lines.map((l) => l.toJson()).toList()),
      );

  Future<void> setThemeMode(ThemeMode mode) =>
      updateSetting(themeModeSetting, switch (mode) {
        ThemeMode.dark => 'dark',
        ThemeMode.light => 'light',
        ThemeMode.system => 'system',
      });

  Future<void> setLanguage(Locale? locale) =>
      updateSetting(languageSetting, languageKeyFromLocale(locale));

  Future<void> setBleInput(BluetoothInputMode mode) async {
    await updateSetting(bleInputSetting, mode.name);
    await updateSetting(
      bluetoothMeasurementsEnabledSetting,
      mode != BluetoothInputMode.disabled,
    );
  }

  Future<void> setBluetoothMeasurementsEnabled(bool enabled) async {
    final mode = read(appSettingsProvider).bleInput;
    await updateSetting(bluetoothMeasurementsEnabledSetting, enabled);
    await setBleInput(
      enabled
          ? mode == BluetoothInputMode.disabled
                ? BluetoothInputMode.newBluetoothInputCrossPlatform
                : mode
          : BluetoothInputMode.disabled,
    );
  }

  Future<void> setBluetoothImportMode(BluetoothMeasurementImportMode mode) =>
      updateSetting(bluetoothImportModeSetting, mode.name);

  Future<void> setPressureUnit(PressureUnit unit) =>
      updateSetting(preferredPressureUnitSetting, unit.name);

  Future<void> setWeightUnit(WeightUnit unit) =>
      updateSetting(preferredWeightUnitSetting, unit.name);

  Future<void> setBodySex(BodySex? sex) =>
      updateSetting(bodySexSetting, sex?.name ?? '');
}

extension AppSettingsContext on BuildContext {
  AppSettings readAppSettings() =>
      ProviderScope.containerOf(this, listen: false).read(appSettingsProvider);

  Future<void> updateSetting<T>(SettingDefinition<T> setting, T value) =>
      ProviderScope.containerOf(
        this,
        listen: false,
      ).read(settingsControllerProvider).set(setting, value);

  Future<void> writeKnownBleDevices(List<KnownBleDevice> devices) =>
      updateSetting(
        knownBleDevicesSetting,
        jsonEncode(devices.map((d) => d.toJson()).toList()),
      );
}
