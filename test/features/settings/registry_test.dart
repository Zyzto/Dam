import 'package:blood_pressure_app/features/settings/registry.dart';
import 'package:blood_pressure_app/screens/settings_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_settings_framework/flutter_settings_framework.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('catalog orders cards by everyday use with Advanced rows last', () {
    final registry = createAppSettingsRegistry();
    expect(registry.getSortedSections().map((s) => s.key), [
      'general',
      'style',
      'blood_pressure',
      'weight',
      'medications',
      'bluetooth',
      'data',
      'about',
      'graph',
    ]);
    expect(styleSection.titleKey, 'appearance');
    expect(bluetoothSection.titleKey, 'devices');
    for (final section in registry.getSortedSections()) {
      expect(section.initiallyExpanded, isTrue, reason: section.key);
    }

    List<String> main(String section) => registry
        .getVisibleSettingsInSection(section)
        .where((s) => s.subSection == null || s.subSection!.isEmpty)
        .map((s) => s.key)
        .toList();
    List<String> advanced(String section) => registry
        .getVisibleSettingsInSection(section)
        .where((s) => s.subSection == 'advanced')
        .map((s) => s.key)
        .toList();

    expect(main('general'), [
      'language',
      'date_format_string',
      'allow_manual_time_input',
      'confirm_deletion',
    ]);
    expect(advanced('general'), ['bottom_app_bars']);
    expect(main('style'), ['theme_mode', 'accent_color', 'compact_list']);
    expect(advanced('style'), ['animation_speed']);
    expect(main('blood_pressure'), [
      'blood_pressure_enabled',
      'preferred_pressure_unit',
      'start_with_add_measurement_page',
      'graph_settings',
      'bp_range_limits',
    ]);
    expect(advanced('blood_pressure'), [
      'validate_inputs',
      'allow_missing_values',
    ]);
    expect(main('weight'), [
      'weight_input',
      'preferred_weight_unit',
      'body_profile',
      'weight_range_limits',
    ]);
    expect(main('medications'), [
      'medicine_feature_enabled',
      'medications',
      'medication_notifications_enabled',
      'overdue_reminder_count',
      'overdue_reminder_interval_minutes',
      'shift_missed_dose_times',
      'missed_dose_shift_limit_minutes',
      'show_all_reminder_rings',
      'rounded_reminder_button',
    ]);
    expect(main('bluetooth'), [
      'bluetooth_measurements_enabled',
      'ble_input',
      'bluetooth_devices',
    ]);
    expect(main('data'), [
      'health_connect_screen',
      'export_import',
      'export_settings',
      'import_settings',
      'delete_data',
    ]);
    expect(main('about'), [
      'version',
      'source_code',
      'licenses',
      'replay_onboarding',
      'logs_viewer',
      'debug_data_server',
    ]);
    for (final section in [
      'weight',
      'medications',
      'bluetooth',
      'data',
      'about',
    ]) {
      expect(advanced(section), isEmpty, reason: section);
    }
    expect(onboardingCompletedSetting.visible, isFalse);
    expect(registry.getVisibleSettingsInSection('graph'), isEmpty);
    expect(useHealthConnectSetting.visible, isFalse);
    expect(autostartBluetoothInputSetting.visible, isFalse);
  });

  test('visibleCatalogChildren keeps one Health Connect row', () {
    final registry = createAppSettingsRegistry();
    final anchors = SettingAnchorRegistry();
    final children = [
      SettingAnchor(
        registry: anchors,
        settingKey: useHealthConnectSetting.key,
        child: const SizedBox(),
      ),
      SettingAnchor(
        registry: anchors,
        settingKey: healthConnectAction.key,
        child: const SizedBox(),
      ),
      SettingAnchor(
        registry: anchors,
        settingKey: syncPressureMeasurementsSetting.key,
        child: const SizedBox(),
      ),
    ];

    final visible = visibleCatalogChildren(registry, children);
    expect(visible, hasLength(1));
    expect(
      (visible.single as SettingAnchor).settingKey,
      healthConnectAction.key,
    );
  });

  test('date format presets include the default pattern', () {
    expect(
      dateFormatStringOptions,
      contains(dateFormatStringSetting.defaultValue),
    );
  });

  test('color settings use the shared flat palette', () {
    expect(appColorOptions, hasLength(18));
    expect(accentColorSetting.colorOptions, same(appColorOptions));
    expect(accentColorSetting.allowCustom, isFalse);
    expect(sysColorSetting.colorOptions, same(appColorOptions));
    expect(diaColorSetting.colorOptions, same(appColorOptions));
    expect(pulColorSetting.colorOptions, same(appColorOptions));
  });
}
