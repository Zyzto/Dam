import 'package:blood_pressure_app/l10n/app_locales.dart';
import 'package:blood_pressure_app/model/range_limits.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_settings_framework/flutter_settings_framework.dart';
import 'package:material_symbols_icons/symbols.dart';

const generalSection = SettingSection(
  key: 'general',
  titleKey: 'generalSettingsSection',
  icon: Icons.tune,
  order: 0,
  initiallyExpanded: true,
);

const styleSection = SettingSection(
  key: 'style',
  titleKey: 'appearance',
  icon: Icons.color_lens_outlined,
  order: 1,
  initiallyExpanded: true,
);

const bloodPressureSection = SettingSection(
  key: 'blood_pressure',
  titleKey: 'bloodPressure',
  icon: Symbols.heart_plus,
  order: 2,
  initiallyExpanded: true,
);

const weightSection = SettingSection(
  key: 'weight',
  titleKey: 'weight',
  icon: Icons.scale,
  order: 3,
  initiallyExpanded: true,
);

const medicationsSection = SettingSection(
  key: 'medications',
  titleKey: 'medications',
  icon: Icons.medication_outlined,
  order: 4,
  initiallyExpanded: true,
);

const bluetoothSection = SettingSection(
  key: 'bluetooth',
  titleKey: 'devices',
  icon: Icons.bluetooth,
  order: 5,
  initiallyExpanded: true,
);

const dataSection = SettingSection(
  key: 'data',
  titleKey: 'data',
  icon: Icons.storage_outlined,
  order: 6,
  initiallyExpanded: true,
);

const aboutSection = SettingSection(
  key: 'about',
  titleKey: 'aboutWarnValuesScreen',
  icon: Icons.info_outline,
  order: 7,
  initiallyExpanded: true,
);

const graphSection = SettingSection(
  key: 'graph',
  titleKey: 'graphSettings',
  icon: Icons.trending_down_outlined,
  order: 8,
  initiallyExpanded: true,
);

const languageSetting = EnumSetting(
  'language',
  defaultValue: 'system',
  titleKey: 'language',
  options: languageSettingOptions,
  icon: Icons.language,
  section: 'general',
  order: 0,
  searchTerms: {
    'en': ['locale', 'language', 'arabic'],
    'ar': ['لغة', 'عربي', 'الإنجليزية'],
  },
);

const themeModeSetting = EnumSetting(
  'theme_mode',
  defaultValue: 'system',
  titleKey: 'theme',
  options: ['system', 'light', 'dark'],
  optionLabels: {'system': 'system', 'light': 'light', 'dark': 'dark'},
  icon: Icons.brightness_4,
  section: 'style',
  order: 0,
  searchTerms: {
    'en': ['theme', 'dark', 'light', 'mode'],
    'ar': ['المظهر', 'السمة', 'داكن', 'فاتح'],
  },
);

/// Curated material colors used by every concrete color setting.
///
/// Keeping this list explicit makes the picker a compact, flat palette rather
/// than Edadat's expandable material shade browser. The values include the
/// defaults for the accent and graph colors so existing settings remain
/// visibly selected.
const appColorOptions = <int>[
  0xFFF44336, // red
  0xFFE91E63, // pink
  0xFF9C27B0, // purple
  0xFF673AB7, // deep purple
  0xFF3F51B5, // indigo
  0xFF2196F3, // blue
  0xFF00BCD4, // cyan
  0xFF009688, // teal
  0xFF4CAF50, // green
  0xFF8BC34A, // light green
  0xFFCDDC39, // lime
  0xFFFFEB3B, // yellow
  0xFFFFC107, // amber
  0xFFFF9800, // orange
  0xFFFF5722, // deep orange
  0xFF795548, // brown
  0xFF9E9E9E, // grey
  0xFF607D8B, // blue grey
];

const accentColorSetting = ColorSetting(
  'accent_color',
  defaultValue: 0xFF009688,
  titleKey: 'accentColor',
  icon: Icons.palette_outlined,
  section: 'style',
  order: 1,
  colorOptions: appColorOptions,
  allowCustom: false,
);

const graphSettingsAction = ActionSetting(
  'graph_settings',
  titleKey: 'graphSettings',
  icon: Icons.trending_down_outlined,
  section: 'blood_pressure',
  order: 3,
);

const dateFormatStringOptions = [
  'yyyy-MM-dd HH:mm',
  'dd-MM-yyyy HH:mm',
  'dd/MM/yyyy HH:mm',
  'MM/dd/yyyy HH:mm',
  'dd.MM.yyyy HH:mm',
  'yyyy/MM/dd HH:mm',
  'MMM d, yyyy HH:mm',
  'd MMM yyyy HH:mm',
  'yyyy-MM-dd h:mm a',
  'dd/MM/yyyy h:mm a',
  'MM/dd/yyyy h:mm a',
];

const dateFormatStringSetting = StringSetting(
  'date_format_string',
  defaultValue: 'yyyy-MM-dd HH:mm',
  titleKey: 'enterTimeFormatScreen',
  icon: Icons.schedule,
  section: 'general',
  order: 1,
  searchTerms: {
    'en': ['date', 'time', 'format', 'clock'],
    'ar': ['تاريخ', 'وقت', 'تنسيق'],
  },
);

const animationSpeedSetting = IntSetting(
  'animation_speed',
  defaultValue: 150,
  titleKey: 'animationSpeed',
  icon: Icons.speed,
  section: 'style',
  subSection: 'advanced',
  order: 0,
  min: 0,
  max: 1000,
  step: 50,
);

const sysColorSetting = ColorSetting(
  'sys_color',
  defaultValue: 0xFF009688,
  titleKey: 'sysColor',
  section: 'graph',
  order: 0,
  visible: false,
  dependsOn: 'blood_pressure_enabled',
  enabledWhen: true,
  colorOptions: appColorOptions,
  allowCustom: false,
);

const diaColorSetting = ColorSetting(
  'dia_color',
  defaultValue: 0xFF4CAF50,
  titleKey: 'diaColor',
  section: 'graph',
  order: 1,
  visible: false,
  dependsOn: 'blood_pressure_enabled',
  enabledWhen: true,
  colorOptions: appColorOptions,
  allowCustom: false,
);

const pulColorSetting = ColorSetting(
  'pul_color',
  defaultValue: 0xFFF44336,
  titleKey: 'pulColor',
  section: 'graph',
  order: 2,
  visible: false,
  dependsOn: 'blood_pressure_enabled',
  enabledWhen: true,
  colorOptions: appColorOptions,
  allowCustom: false,
);

const graphLineThicknessSetting = DoubleSetting(
  'graph_line_thickness',
  defaultValue: 3,
  titleKey: 'graphLineThickness',
  section: 'graph',
  order: 3,
  dependsOn: 'blood_pressure_enabled',
  enabledWhen: true,
  min: 1,
  max: 10,
  step: 0.5,
  visible: false,
);

const needlePinBarWidthSetting = DoubleSetting(
  'needle_pin_bar_width',
  defaultValue: 5,
  titleKey: 'needlePinBarWidth',
  subtitleKey: 'needlePinBarWidthDesc',
  section: 'graph',
  order: 4,
  dependsOn: 'blood_pressure_enabled',
  enabledWhen: true,
  min: 1,
  max: 20,
  step: 1,
  visible: false,
);

const sysWarnSetting = IntSetting(
  'sys_warn',
  defaultValue: 120,
  titleKey: 'sysWarn',
  section: 'graph',
  order: 5,
  dependsOn: 'blood_pressure_enabled',
  enabledWhen: true,
  min: 0,
  max: 300,
  visible: false,
);

const diaWarnSetting = IntSetting(
  'dia_warn',
  defaultValue: 80,
  titleKey: 'diaWarn',
  section: 'graph',
  order: 6,
  dependsOn: 'blood_pressure_enabled',
  enabledWhen: true,
  min: 0,
  max: 200,
  visible: false,
);

const drawRegressionLinesSetting = BoolSetting(
  'draw_regression_lines',
  defaultValue: false,
  titleKey: 'drawRegressionLines',
  subtitleKey: 'drawRegressionLinesDesc',
  icon: Icons.show_chart,
  section: 'graph',
  order: 7,
  visible: false,
  dependsOn: 'blood_pressure_enabled',
  enabledWhen: true,
);

const interruptGraphAfterNDaysSetting = IntSetting(
  'interrupt_graph_after_n_days',
  defaultValue: 10,
  titleKey: 'maxDataInterval',
  subtitleKey: 'maxDataIntervalDesc',
  section: 'graph',
  order: 8,
  min: 0,
  max: 365,
  visible: false,
  dependsOn: 'blood_pressure_enabled',
  enabledWhen: true,
);

const homeBpChartSetting = EnumSetting(
  'home_bp_chart',
  defaultValue: 'dailyRange',
  titleKey: 'chartDailyRange',
  options: ['dailyRange', 'classification', 'pulsePressure', 'medicineTiming'],
  useRawLabels: true,
  visible: false,
  dependsOn: 'blood_pressure_enabled',
  enabledWhen: true,
);

const graphMarkingsAction = ActionSetting(
  'graph_markings',
  titleKey: 'customGraphMarkings',
  icon: Icons.horizontal_rule,
  section: 'graph',
  order: 9,
  visible: false,
);

const horizontalGraphLinesSetting = StringSetting(
  'horizontal_graph_lines',
  defaultValue: '[]',
  titleKey: 'horizontalLines',
  section: 'graph',
  visible: false,
  dependsOn: 'blood_pressure_enabled',
  enabledWhen: true,
);

const startWithAddMeasurementPageSetting = BoolSetting(
  'start_with_add_measurement_page',
  defaultValue: false,
  titleKey: 'startWithAddMeasurementPage',
  subtitleKey: 'startWithAddMeasurementPageDescription',
  icon: Icons.electric_bolt_outlined,
  section: 'blood_pressure',
  order: 2,
  dependsOn: 'blood_pressure_enabled',
  enabledWhen: true,
);

const allowManualTimeInputSetting = BoolSetting(
  'allow_manual_time_input',
  defaultValue: true,
  titleKey: 'allowManualTimeInput',
  icon: Icons.schedule,
  section: 'general',
  order: 2,
);

const validateInputsSetting = BoolSetting(
  'validate_inputs',
  defaultValue: true,
  titleKey: 'validateInputs',
  icon: Icons.task_alt,
  section: 'blood_pressure',
  subSection: 'advanced',
  order: 0,
  dependsOn: 'blood_pressure_enabled',
  enabledWhen: true,
);

const allowMissingValuesSetting = BoolSetting(
  'allow_missing_values',
  defaultValue: false,
  titleKey: 'allowMissingValues',
  icon: Icons.rule,
  section: 'blood_pressure',
  subSection: 'advanced',
  order: 1,
  dependsOn: 'blood_pressure_enabled',
  enabledWhen: true,
);

const confirmDeletionSetting = BoolSetting(
  'confirm_deletion',
  defaultValue: true,
  titleKey: 'confirmDeletion',
  icon: Icons.delete_forever,
  section: 'general',
  order: 3,
);

const compactListSetting = BoolSetting(
  'compact_list',
  defaultValue: false,
  titleKey: 'compactList',
  icon: Icons.view_agenda_outlined,
  section: 'style',
  order: 2,
);

const roundedReminderButtonSetting = BoolSetting(
  'rounded_reminder_button',
  defaultValue: true,
  titleKey: 'useRoundedSquareReminderButton',
  icon: Icons.rounded_corner,
  section: 'medications',
  order: 8,
);

const preferredPressureUnitSetting = EnumSetting(
  'preferred_pressure_unit',
  defaultValue: 'mmHg',
  titleKey: 'preferredPressureUnit',
  options: ['mmHg', 'kPa'],
  useRawLabels: true,
  icon: Icons.speed,
  section: 'blood_pressure',
  order: 1,
  dependsOn: 'blood_pressure_enabled',
  enabledWhen: true,
);

const preferredWeightUnitSetting = EnumSetting(
  'preferred_weight_unit',
  defaultValue: 'kg',
  titleKey: 'preferredWeightUnit',
  options: ['kg', 'lbs', 'st'],
  useRawLabels: true,
  icon: Icons.scale,
  section: 'weight',
  order: 1,
  dependsOn: 'weight_input',
  enabledWhen: true,
);

const autostartBluetoothInputSetting = BoolSetting(
  'autostart_bluetooth_input',
  defaultValue: false,
  titleKey: 'autostartBluetoothInput',
  subtitleKey: 'autostartBluetoothInputDescription',
  icon: Icons.bluetooth,
  section: 'bluetooth',
  order: 2,
  visible: false,
  dependsOn: 'bluetooth_measurements_enabled',
  enabledWhen: true,
);

const syncBluetoothOnLaunchSetting = BoolSetting(
  'sync_bluetooth_on_launch',
  defaultValue: true,
  titleKey: 'syncBluetoothOnLaunch',
  subtitleKey: 'syncBluetoothOnLaunchDescription',
  icon: Icons.sync,
  section: 'bluetooth',
  order: 3,
  visible: false,
  dependsOn: 'bluetooth_measurements_enabled',
  enabledWhen: true,
);

const bluetoothImportModeSetting = EnumSetting(
  'bluetooth_import_mode',
  defaultValue: 'disabled',
  titleKey: 'bluetoothImportMode',
  subtitleKey: 'bluetoothImportModeDescription',
  options: ['disabled', 'last', 'all'],
  optionLabels: {
    'disabled': 'bluetoothImportModeDisabled',
    'last': 'bluetoothImportModeLast',
    'all': 'bluetoothImportModeAll',
  },
  icon: Icons.download,
  section: 'bluetooth',
  order: 4,
  visible: false,
  dependsOn: 'bluetooth_measurements_enabled',
  enabledWhen: true,
);

const trustBleTimeSetting = BoolSetting(
  'trust_ble_time',
  defaultValue: true,
  titleKey: 'trustBLETime',
  icon: Icons.lock_clock_outlined,
  section: 'bluetooth',
  order: 5,
  visible: false,
  dependsOn: 'bluetooth_measurements_enabled',
  enabledWhen: true,
);

const showBleTimeTrustDialogSetting = BoolSetting(
  'show_ble_time_trust_dialog',
  defaultValue: true,
  titleKey: 'trustBLETime',
  visible: false,
);

const lastVersionSetting = IntSetting(
  'last_version',
  defaultValue: 0,
  titleKey: 'version',
  visible: false,
);

const bottomAppBarsSetting = BoolSetting(
  'bottom_app_bars',
  defaultValue: false,
  titleKey: 'bottomAppBars',
  icon: Icons.vertical_align_bottom,
  section: 'general',
  subSection: 'advanced',
  order: 0,
);

const weightInputSetting = BoolSetting(
  'weight_input',
  defaultValue: false,
  titleKey: 'activateWeightFeatures',
  icon: Icons.scale,
  section: 'weight',
  order: 0,
);

const bloodPressureEnabledSetting = BoolSetting(
  'blood_pressure_enabled',
  defaultValue: true,
  titleKey: 'bloodPressure',
  icon: Symbols.heart_plus,
  section: 'blood_pressure',
  order: 0,
);

const medicineFeatureEnabledSetting = BoolSetting(
  'medicine_feature_enabled',
  defaultValue: true,
  titleKey: 'medications',
  icon: Icons.medication_outlined,
  section: 'medications',
  order: 0,
);

const bluetoothMeasurementsEnabledSetting = BoolSetting(
  'bluetooth_measurements_enabled',
  defaultValue: false,
  titleKey: 'bluetoothMeasurements',
  icon: Icons.bluetooth,
  section: 'bluetooth',
  order: 0,
);

const bleInputSetting = EnumSetting(
  'ble_input',
  defaultValue: 'disabled',
  titleKey: 'bluetoothInput',
  subtitleKey: 'bluetoothInputDesc',
  options: ['disabled', 'oldBluetoothInput', 'newBluetoothInputCrossPlatform'],
  optionLabels: {
    'disabled': 'disabled',
    'oldBluetoothInput': 'legacyBluetoothInput',
    'newBluetoothInputCrossPlatform': 'stableBluetoothInput',
  },
  icon: Icons.bluetooth,
  section: 'bluetooth',
  order: 1,
  dependsOn: 'bluetooth_measurements_enabled',
  enabledWhen: true,
);

const athleteModeSetting = BoolSetting(
  'athlete_mode',
  defaultValue: false,
  titleKey: 'athleteMode',
  subtitleKey: 'athleteModeDesc',
  visible: false,
);

const bodyHeightCmSetting = DoubleSetting(
  'body_height_cm',
  defaultValue: 0,
  titleKey: 'bodyHeightCm',
  visible: false,
);

const birthYearSetting = IntSetting(
  'birth_year',
  defaultValue: 0,
  titleKey: 'birthYear',
  visible: false,
);

const bodySexSetting = EnumSetting(
  'body_sex',
  defaultValue: '',
  titleKey: 'bodySex',
  options: ['', 'female', 'male'],
  visible: false,
);

const knownBleDevicesSetting = StringSetting(
  'known_ble_devices',
  defaultValue: '[]',
  titleKey: 'bluetoothDevices',
  visible: false,
);

const bodyProfileAction = ActionSetting(
  'body_profile',
  titleKey: 'bodyProfile',
  subtitleKey: 'bodyProfileIncomplete',
  icon: Icons.accessibility_new,
  section: 'weight',
  order: 2,
);

const weightRangeLimitsAction = ActionSetting(
  'weight_range_limits',
  titleKey: 'weightRangeLimits',
  subtitleKey: 'weightRangeLimitsDesc',
  icon: Icons.straighten,
  section: 'weight',
  order: 3,
  searchTerms: {
    'en': [
      'bmi',
      'obese',
      'obesity',
      'overweight',
      'underweight',
      'normal',
      'limit',
      'range',
    ],
    'ar': ['سمنة', 'وزن', 'طبيعي', 'مؤشر', 'حد'],
  },
);

const bpRangeLimitsAction = ActionSetting(
  'bp_range_limits',
  titleKey: 'bpRangeLimits',
  subtitleKey: 'bpRangeLimitsDesc',
  icon: Icons.favorite_border,
  section: 'blood_pressure',
  order: 4,
  searchTerms: {
    'en': [
      'blood pressure',
      'systolic',
      'diastolic',
      'normal',
      'elevated',
      'high',
      'limit',
      'range',
    ],
    'ar': ['ضغط', 'انقباضي', 'انبساطي', 'طبيعي', 'حد'],
  },
);

const bmiNormalMinSetting = DoubleSetting(
  'bmi_normal_min',
  defaultValue: RangeLimits.defaultBmiNormalMin,
  titleKey: 'rangeLimitNormalFrom',
  visible: false,
);

const bmiOverweightMinSetting = DoubleSetting(
  'bmi_overweight_min',
  defaultValue: RangeLimits.defaultBmiOverweightMin,
  titleKey: 'rangeLimitOverweightFrom',
  visible: false,
);

const bmiObeseMinSetting = DoubleSetting(
  'bmi_obese_min',
  defaultValue: RangeLimits.defaultBmiObeseMin,
  titleKey: 'rangeLimitObesityFrom',
  visible: false,
);

const sysElevatedMmHgSetting = IntSetting(
  'sys_elevated_mmhg',
  defaultValue: RangeLimits.defaultSysElevatedMmHg,
  titleKey: 'rangeLimitSysElevated',
  visible: false,
);

const sysHighMmHgSetting = IntSetting(
  'sys_high_mmhg',
  defaultValue: RangeLimits.defaultSysHighMmHg,
  titleKey: 'rangeLimitSysHigh',
  visible: false,
);

const diaHighMmHgSetting = IntSetting(
  'dia_high_mmhg',
  defaultValue: RangeLimits.defaultDiaHighMmHg,
  titleKey: 'rangeLimitDiaHigh',
  visible: false,
);

const medicationsAction = ActionSetting(
  'medications',
  titleKey: 'manageMedications',
  icon: Icons.medication,
  section: 'medications',
  order: 1,
);

const medicationNotificationsEnabledSetting = BoolSetting(
  'medication_notifications_enabled',
  defaultValue: true,
  titleKey: 'medicationNotifications',
  subtitleKey: 'medicationNotificationsDesc',
  icon: Icons.notifications_outlined,
  section: 'medications',
  order: 2,
  dependsOn: 'medicine_feature_enabled',
  enabledWhen: true,
  searchTerms: {
    'en': ['notification', 'alert', 'reminder', 'disable'],
    'ar': ['تنبيه', 'إشعار', 'تذكير'],
  },
);

const overdueReminderCountSetting = IntSetting(
  'overdue_reminder_count',
  defaultValue: 3,
  titleKey: 'overdueReminderCount',
  subtitleKey: 'overdueReminderCountDesc',
  icon: Icons.notifications_active_outlined,
  section: 'medications',
  order: 3,
  min: 0,
  max: 6,
  step: 1,
  dependsOn: 'medicine_feature_enabled',
  enabledWhen: true,
);

const overdueReminderIntervalSetting = IntSetting(
  'overdue_reminder_interval_minutes',
  defaultValue: 10,
  titleKey: 'overdueReminderInterval',
  subtitleKey: 'overdueReminderIntervalDesc',
  icon: Icons.timer_outlined,
  section: 'medications',
  order: 4,
  min: 1,
  max: 120,
  step: 1,
  dependsOn: 'medicine_feature_enabled',
  enabledWhen: true,
);

const shiftMissedDoseTimesSetting = BoolSetting(
  'shift_missed_dose_times',
  defaultValue: false,
  titleKey: 'shiftMissedDoseTimes',
  subtitleKey: 'shiftMissedDoseTimesDesc',
  icon: Icons.update,
  section: 'medications',
  order: 5,
  dependsOn: 'medicine_feature_enabled',
  enabledWhen: true,
  searchTerms: {
    'en': ['missed', 'late', 'move', 'shift', 'reschedule'],
    'ar': ['فائت', 'تأخير', 'تحريك', 'موعد'],
  },
);

const missedDoseShiftLimitSetting = IntSetting(
  'missed_dose_shift_limit_minutes',
  defaultValue: 60,
  titleKey: 'missedDoseShiftLimit',
  subtitleKey: 'missedDoseShiftLimitDesc',
  icon: Icons.timelapse,
  section: 'medications',
  order: 6,
  min: 15,
  max: 360,
  step: 15,
  dependsOn: 'shift_missed_dose_times',
  enabledWhen: true,
);

const showAllReminderRingsSetting = BoolSetting(
  'show_all_reminder_rings',
  defaultValue: true,
  titleKey: 'showAllReminderRings',
  subtitleKey: 'showAllReminderRingsDesc',
  icon: Icons.donut_large_outlined,
  section: 'medications',
  order: 7,
  dependsOn: 'medicine_feature_enabled',
  enabledWhen: true,
);

const debugDataServerSetting = BoolSetting(
  'debug_data_server',
  defaultValue: false,
  titleKey: 'debugDataServer',
  subtitleKey: 'debugDataServerDesc',
  icon: Icons.science_outlined,
  section: 'about',
  order: 5,
  visible: kDebugMode,
);

const bluetoothDevicesAction = ActionSetting(
  'bluetooth_devices',
  titleKey: 'bluetoothDevices',
  icon: Icons.bluetooth_searching,
  section: 'bluetooth',
  order: 2,
);

const useHealthConnectSetting = BoolSetting(
  'use_health_connect',
  defaultValue: false,
  titleKey: 'optEnableHealthConnect',
  subtitleKey: 'healthConnectDesc',
  icon: Icons.sync,
  section: 'data',
  order: 0,
  visible: false,
);

const syncPressureMeasurementsSetting = BoolSetting(
  'sync_pressure_measurements',
  defaultValue: true,
  titleKey: 'healthConnect',
  section: 'data',
  order: 1,
  dependsOn: 'use_health_connect',
  enabledWhen: true,
  visible: false,
);

const syncWeightMeasurementsSetting = BoolSetting(
  'sync_weight_measurements',
  defaultValue: true,
  titleKey: 'weight',
  section: 'data',
  order: 2,
  dependsOn: 'use_health_connect',
  enabledWhen: true,
  visible: false,
);

const syncOnAppStartSetting = BoolSetting(
  'sync_on_app_start',
  defaultValue: true,
  titleKey: 'syncOnAppStart',
  section: 'data',
  order: 3,
  dependsOn: 'use_health_connect',
  enabledWhen: true,
  visible: false,
);

const healthConnectAction = ActionSetting(
  'health_connect_screen',
  titleKey: 'healthConnect',
  icon: Icons.sync,
  section: 'data',
  order: 0,
);

const exportImportAction = ActionSetting(
  'export_import',
  titleKey: 'exportImport',
  icon: Icons.download,
  section: 'data',
  order: 1,
);

const deleteDataAction = ActionSetting(
  'delete_data',
  titleKey: 'delete',
  icon: Icons.delete,
  section: 'data',
  order: 4,
);

const onboardingCompletedSetting = BoolSetting(
  'onboarding_completed',
  defaultValue: false,
  titleKey: 'onboardingReplay',
  visible: false,
);

const replayOnboardingAction = ActionSetting(
  'replay_onboarding',
  titleKey: 'onboardingReplay',
  subtitleKey: 'onboardingReplayHint',
  icon: Icons.help_outline,
  section: 'about',
  order: 3,
);

const versionAction = ActionSetting(
  'version',
  titleKey: 'version',
  icon: Icons.info_outline,
  section: 'about',
  order: 0,
);

const sourceCodeAction = ActionSetting(
  'source_code',
  titleKey: 'sourceCode',
  icon: Icons.merge,
  section: 'about',
  order: 1,
);

const licensesAction = ActionSetting(
  'licenses',
  titleKey: 'licenses',
  icon: Icons.policy_outlined,
  section: 'about',
  order: 2,
);

const exportSettingsAction = ActionSetting(
  'export_settings',
  titleKey: 'exportSettings',
  icon: Icons.tune,
  section: 'data',
  order: 2,
);

const importSettingsAction = ActionSetting(
  'import_settings',
  titleKey: 'importSettings',
  subtitleKey: 'requiresAppRestart',
  icon: Icons.settings_backup_restore,
  section: 'data',
  order: 3,
);

const logsViewerAction = ActionSetting(
  'logs_viewer',
  titleKey: 'logs',
  icon: Icons.article_outlined,
  section: 'about',
  order: 4,
  searchTerms: {
    'en': ['logs', 'debug', 'crash'],
    'ar': ['سجلات', 'تتبع'],
  },
);

SettingsRegistry createAppSettingsRegistry() => SettingsRegistry.withSettings(
  sections: [
    styleSection,
    generalSection,
    bloodPressureSection,
    weightSection,
    medicationsSection,
    bluetoothSection,
    dataSection,
    aboutSection,
    graphSection,
  ],
  settings: [
    startWithAddMeasurementPageSetting,
    allowManualTimeInputSetting,
    validateInputsSetting,
    allowMissingValuesSetting,
    confirmDeletionSetting,
    compactListSetting,
    roundedReminderButtonSetting,
    preferredPressureUnitSetting,
    preferredWeightUnitSetting,
    autostartBluetoothInputSetting,
    syncBluetoothOnLaunchSetting,
    bluetoothImportModeSetting,
    trustBleTimeSetting,
    showBleTimeTrustDialogSetting,
    lastVersionSetting,
    bottomAppBarsSetting,
    sysColorSetting,
    diaColorSetting,
    pulColorSetting,
    graphLineThicknessSetting,
    needlePinBarWidthSetting,
    sysWarnSetting,
    diaWarnSetting,
    drawRegressionLinesSetting,
    interruptGraphAfterNDaysSetting,
    homeBpChartSetting,
    graphMarkingsAction,
    horizontalGraphLinesSetting,
    themeModeSetting,
    languageSetting,
    dateFormatStringSetting,
    animationSpeedSetting,
    accentColorSetting,
    graphSettingsAction,
    weightInputSetting,
    bloodPressureEnabledSetting,
    medicineFeatureEnabledSetting,
    bluetoothMeasurementsEnabledSetting,
    bleInputSetting,
    athleteModeSetting,
    bodyHeightCmSetting,
    birthYearSetting,
    bodySexSetting,
    knownBleDevicesSetting,
    bodyProfileAction,
    weightRangeLimitsAction,
    bpRangeLimitsAction,
    bmiNormalMinSetting,
    bmiOverweightMinSetting,
    bmiObeseMinSetting,
    sysElevatedMmHgSetting,
    sysHighMmHgSetting,
    diaHighMmHgSetting,
    medicationsAction,
    medicationNotificationsEnabledSetting,
    overdueReminderCountSetting,
    overdueReminderIntervalSetting,
    shiftMissedDoseTimesSetting,
    missedDoseShiftLimitSetting,
    showAllReminderRingsSetting,
    debugDataServerSetting,
    bluetoothDevicesAction,
    useHealthConnectSetting,
    syncPressureMeasurementsSetting,
    syncWeightMeasurementsSetting,
    syncOnAppStartSetting,
    healthConnectAction,
    exportImportAction,
    deleteDataAction,
    onboardingCompletedSetting,
    replayOnboardingAction,
    versionAction,
    sourceCodeAction,
    licensesAction,
    exportSettingsAction,
    importSettingsAction,
    logsViewerAction,
  ],
);
