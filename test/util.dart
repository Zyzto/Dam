import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:safaeh/safaeh.dart';
import 'package:blood_pressure_app/features/input/forms/measurement_value_field.dart';
import 'package:blood_pressure_app/features/settings/app_settings.dart';
import 'package:blood_pressure_app/features/settings/initialize_app_settings.dart';
import 'package:blood_pressure_app/features/settings/registry.dart';
import 'package:blood_pressure_app/l10n/app_locales.dart';
import 'package:blood_pressure_app/l10n/western_digits.dart';
import 'package:blood_pressure_app/logging.dart';
import 'package:blood_pressure_app/model/blood_pressure/pressure_unit.dart';
import 'package:blood_pressure_app/model/bluetooth_input_mode.dart';
import 'package:blood_pressure_app/model/bluetooth_measurement_import_mode.dart';
import 'package:blood_pressure_app/model/body_sex.dart';
import 'package:blood_pressure_app/model/horizontal_graph_line.dart';
import 'package:blood_pressure_app/model/known_ble_device.dart';
import 'package:blood_pressure_app/model/med_cache.dart';
import 'package:blood_pressure_app/model/storage/storage.dart';
import 'package:blood_pressure_app/model/weight_unit.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:easy_localization/src/localization.dart';
import 'package:easy_localization/src/translations.dart';
import 'package:flutter/material.dart';
import 'package:blood_pressure_app/core/repository/repository_providers.dart';
import 'package:blood_pressure_app/core/settings/storage_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_settings_framework/flutter_settings_framework.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:blood_pressure_app/domain/domain.dart';
import 'package:path/path.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Last controller created by [materialApp] / [appBase].
SettingsController? testSettingsController;

/// [TextField] inside the [MeasurementValueField] labeled [label].
Finder measurementValueField(String label) => find.descendant(
  of: find.ancestor(
    of: find.text(label),
    matching: find.byType(MeasurementValueField),
  ),
  matching: find.byType(TextField),
);

/// Open the medication picker sheet and choose [name].
Future<void> selectMedicineFromPicker(WidgetTester tester, String name) async {
  await tester.tap(find.byKey(const ValueKey('medication-picker')).first);
  await tester.pumpAndSettle();
  await tester.tap(find.text(name).last);
  await tester.pumpAndSettle();
}

/// Seed values applied to Edadat before the widget tree is built.
class TestSettingsSeed {
  TestSettingsSeed({
    this.language,
    this.accentColor,
    this.sysColor,
    this.diaColor,
    this.pulColor,
    this.horizontalGraphLines,
    this.dateFormatString,
    this.graphLineThickness,
    this.animationSpeed,
    this.sysWarn,
    this.diaWarn,
    this.lastVersion,
    this.allowManualTimeInput,
    this.confirmDeletion,
    this.themeMode,
    this.validateInputs,
    this.allowMissingValues,
    this.drawRegressionLines,
    this.startWithAddMeasurementPage,
    this.autostartBluetoothInput,
    this.syncBluetoothOnLaunch,
    this.bluetoothImportMode,
    this.compactList,
    this.bloodPressureEnabled,
    this.medicineFeatureEnabled,
    this.needlePinBarWidth,
    this.bottomAppBars,
    this.preferredPressureUnit,
    this.bleInput,
    this.weightInput,
    this.knownBleDev,
    this.weightUnit,
    this.bodyHeightCm,
    this.birthYear,
    this.bodySex,
    this.athleteMode,
    this.trustBLETime,
    this.showBLETimeTrustDialog,
    this.interruptGraphAfterNDays,
    this.useHealthConnect,
    this.syncWeightMeasurements,
    this.syncPressureMeasurements,
    this.syncOnAppStart,
    this.onboardingCompleted,
  });

  Locale? language;
  Color? accentColor;
  Color? sysColor;
  Color? diaColor;
  Color? pulColor;
  List<HorizontalGraphLine>? horizontalGraphLines;
  String? dateFormatString;
  double? graphLineThickness;
  int? animationSpeed;
  int? sysWarn;
  int? diaWarn;
  int? lastVersion;
  bool? allowManualTimeInput;
  bool? confirmDeletion;
  ThemeMode? themeMode;
  bool? validateInputs;
  bool? allowMissingValues;
  bool? drawRegressionLines;
  bool? startWithAddMeasurementPage;
  bool? autostartBluetoothInput;
  bool? syncBluetoothOnLaunch;
  BluetoothMeasurementImportMode? bluetoothImportMode;
  bool? compactList;
  bool? bloodPressureEnabled;
  bool? medicineFeatureEnabled;
  double? needlePinBarWidth;
  bool? bottomAppBars;
  PressureUnit? preferredPressureUnit;
  BluetoothInputMode? bleInput;
  bool? weightInput;
  List<KnownBleDevice>? knownBleDev;
  WeightUnit? weightUnit;
  double? bodyHeightCm;
  int? birthYear;
  BodySex? bodySex;
  bool? athleteMode;
  bool? trustBLETime;
  bool? showBLETimeTrustDialog;
  int? interruptGraphAfterNDays;
  bool? useHealthConnect;
  bool? syncWeightMeasurements;
  bool? syncPressureMeasurements;
  bool? syncOnAppStart;
  bool? onboardingCompleted;

  Future<void> apply(SettingsController controller) async {
    if (language != null) {
      await controller.set(languageSetting, languageKeyFromLocale(language));
    }
    if (accentColor != null) {
      await controller.set(accentColorSetting, accentColor!.toARGB32());
    }
    if (sysColor != null) {
      await controller.set(sysColorSetting, sysColor!.toARGB32());
    }
    if (diaColor != null) {
      await controller.set(diaColorSetting, diaColor!.toARGB32());
    }
    if (pulColor != null) {
      await controller.set(pulColorSetting, pulColor!.toARGB32());
    }
    if (horizontalGraphLines != null) {
      await controller.set(
        horizontalGraphLinesSetting,
        encodeHorizontalGraphLinesJson(horizontalGraphLines!),
      );
    }
    if (dateFormatString != null) {
      await controller.set(dateFormatStringSetting, dateFormatString!);
    }
    if (graphLineThickness != null) {
      await controller.set(graphLineThicknessSetting, graphLineThickness!);
    }
    if (animationSpeed != null) {
      await controller.set(animationSpeedSetting, animationSpeed!);
    }
    if (sysWarn != null) await controller.set(sysWarnSetting, sysWarn!);
    if (diaWarn != null) await controller.set(diaWarnSetting, diaWarn!);
    if (lastVersion != null)
      await controller.set(lastVersionSetting, lastVersion!);
    if (allowManualTimeInput != null) {
      await controller.set(allowManualTimeInputSetting, allowManualTimeInput!);
    }
    if (confirmDeletion != null) {
      await controller.set(confirmDeletionSetting, confirmDeletion!);
    }
    if (themeMode != null) {
      await controller.set(themeModeSetting, switch (themeMode!) {
        ThemeMode.dark => 'dark',
        ThemeMode.light => 'light',
        ThemeMode.system => 'system',
      });
    }
    if (validateInputs != null) {
      await controller.set(validateInputsSetting, validateInputs!);
    }
    if (allowMissingValues != null) {
      await controller.set(allowMissingValuesSetting, allowMissingValues!);
    }
    if (drawRegressionLines != null) {
      await controller.set(drawRegressionLinesSetting, drawRegressionLines!);
    }
    if (startWithAddMeasurementPage != null) {
      await controller.set(
        startWithAddMeasurementPageSetting,
        startWithAddMeasurementPage!,
      );
    }
    if (autostartBluetoothInput != null) {
      await controller.set(
        autostartBluetoothInputSetting,
        autostartBluetoothInput!,
      );
    }
    if (syncBluetoothOnLaunch != null) {
      await controller.set(
        syncBluetoothOnLaunchSetting,
        syncBluetoothOnLaunch!,
      );
    }
    if (bluetoothImportMode != null) {
      await controller.set(
        bluetoothImportModeSetting,
        bluetoothImportMode!.name,
      );
    }
    if (compactList != null)
      await controller.set(compactListSetting, compactList!);
    if (bloodPressureEnabled != null) {
      await controller.set(bloodPressureEnabledSetting, bloodPressureEnabled!);
    }
    if (medicineFeatureEnabled != null) {
      await controller.set(
        medicineFeatureEnabledSetting,
        medicineFeatureEnabled!,
      );
    }
    if (needlePinBarWidth != null) {
      await controller.set(needlePinBarWidthSetting, needlePinBarWidth!);
    }
    if (bottomAppBars != null) {
      await controller.set(bottomAppBarsSetting, bottomAppBars!);
    }
    if (preferredPressureUnit != null) {
      await controller.set(
        preferredPressureUnitSetting,
        preferredPressureUnit!.name,
      );
    }
    if (bleInput != null) await controller.set(bleInputSetting, bleInput!.name);
    if (weightInput != null)
      await controller.set(weightInputSetting, weightInput!);
    if (knownBleDev != null) {
      await persistKnownBleDevices(controller, knownBleDev!);
    }
    if (weightUnit != null) {
      await controller.set(preferredWeightUnitSetting, weightUnit!.name);
    }
    if (bodyHeightCm != null) {
      await controller.set(bodyHeightCmSetting, bodyHeightCm!);
    }
    if (birthYear != null) await controller.set(birthYearSetting, birthYear!);
    if (bodySex != null) await controller.set(bodySexSetting, bodySex!.name);
    if (athleteMode != null)
      await controller.set(athleteModeSetting, athleteMode!);
    if (trustBLETime != null)
      await controller.set(trustBleTimeSetting, trustBLETime!);
    if (showBLETimeTrustDialog != null) {
      await controller.set(
        showBleTimeTrustDialogSetting,
        showBLETimeTrustDialog!,
      );
    }
    if (interruptGraphAfterNDays != null) {
      await controller.set(
        interruptGraphAfterNDaysSetting,
        interruptGraphAfterNDays!,
      );
    }
    if (useHealthConnect != null) {
      await controller.set(useHealthConnectSetting, useHealthConnect!);
    }
    if (syncWeightMeasurements != null) {
      await controller.set(
        syncWeightMeasurementsSetting,
        syncWeightMeasurements!,
      );
    }
    if (syncPressureMeasurements != null) {
      await controller.set(
        syncPressureMeasurementsSetting,
        syncPressureMeasurements!,
      );
    }
    if (syncOnAppStart != null) {
      await controller.set(syncOnAppStartSetting, syncOnAppStart!);
    }
    if (onboardingCompleted != null) {
      await controller.set(onboardingCompletedSetting, onboardingCompleted!);
    }
  }
}

String encodeHorizontalGraphLinesJson(List<HorizontalGraphLine> lines) =>
    jsonEncode(lines.map((l) => l.toJson()).toList());

bool _loggingReady = false;
bool _prefsMocked = false;

Future<void> ensureTestLogging() async {
  if (!_prefsMocked) {
    SharedPreferences.setMockInitialValues({});
    _prefsMocked = true;
  }
  if (_loggingReady) return;
  await initAppLogging(memoryOnly: true);
  _loggingReady = true;
}

Future<void> disposeTestLogging() async {
  if (!_loggingReady) return;
  await LoggingService.dispose();
  _loggingReady = false;
}

/// Load locale JSON into EasyLocalization so `.tr()` works in unit tests.
void loadTestTranslations([Locale locale = const Locale('en')]) {
  final file = File('assets/translations/${translationFileTag(locale)}.json');
  final map = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
  Localization.load(locale, translations: Translations(map));
}

Future<SettingsProviders> createTestSettings([TestSettingsSeed? seed]) async {
  await ensureTestLogging();
  try {
    await EasyLocalization.ensureInitialized();
  } catch (_) {}
  EasyLocalization.logger.enableBuildModes = [];
  loadTestTranslations();
  final providers = await initializeAppSettings(storage: MemoryStorage());
  if (seed != null) await seed.apply(providers.controller);
  testSettingsController = providers.controller;
  return providers;
}

/// Reads locale JSON from disk so widget tests do not hang on [rootBundle].
class _FileTranslationLoader extends AssetLoader {
  const _FileTranslationLoader();

  @override
  Future<Map<String, dynamic>?> load(String path, Locale locale) async {
    final file = File('$path/${translationFileTag(locale)}.json');
    if (!file.existsSync()) return null;
    return jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
  }
}

Widget _easyApp({
  required Widget child,
  required SettingsProviders settings,
  required List overrides,
  Map<String, Widget Function(BuildContext)> routes = const {},
  bool wrapScaffold = true,
  Locale locale = const Locale('en'),
}) {
  return EasyLocalization(
    path: 'assets/translations',
    assetLoader: const _FileTranslationLoader(),
    supportedLocales: appSupportedLocales,
    fallbackLocale: const Locale('en'),
    startLocale: locale,
    useFallbackTranslations: true,
    saveLocale: false,
    child: Builder(
      builder: (context) {
        final resolved = context.locale;
        return ProviderScope(
          overrides: [
            settingsControllerProvider.overrideWithValue(settings.controller),
            settingsSearchIndexProvider.overrideWithValue(settings.searchIndex),
            settingsProvidersProvider.overrideWithValue(settings),
            ...overrides,
          ],
          child: MaterialApp(
            locale: resolved,
            localizationsDelegates: withWesternDigits(
              context.localizationDelegates,
            ),
            supportedLocales: context.supportedLocales,
            builder: (context, appChild) => SafaehFeedbackHost(
              child: Directionality(
                textDirection: resolved.languageCode == 'ar'
                    ? ui.TextDirection.rtl
                    : ui.TextDirection.ltr,
                child: appChild ?? const SizedBox.shrink(),
              ),
            ),
            home: wrapScaffold ? Scaffold(body: child) : child,
            routes: routes,
          ),
        );
      },
    ),
  );
}

/// Create a root material widget with localizations.
Future<Widget> materialApp(
  Widget child, {
  TestSettingsSeed? settings,
  ExportSettings? exportSettings,
  CsvExportSettings? csvExportSettings,
  PdfExportSettings? pdfExportSettings,
  ExcelExportSettings? excelExportSettings,
  TestSettingsSeed? hcSettings,
  IntervalStoreManager? intervallStoreManager,
  ExportColumnsManager? exportColumnsManager,
  Map<String, Widget Function(BuildContext)> routes = const {},
  List overrides = const [],
  Locale locale = const Locale('en'),
  MockHealthStore? store,
}) async {
  final merged = settings ?? hcSettings ?? TestSettingsSeed();
  if (hcSettings != null && settings != null) {
    merged.useHealthConnect ??= hcSettings.useHealthConnect;
    merged.syncPressureMeasurements ??= hcSettings.syncPressureMeasurements;
    merged.syncWeightMeasurements ??= hcSettings.syncWeightMeasurements;
    merged.syncOnAppStart ??= hcSettings.syncOnAppStart;
  }
  final edadat = await createTestSettings(merged);
  exportSettings ??= ExportSettings();
  csvExportSettings ??= CsvExportSettings();
  pdfExportSettings ??= PdfExportSettings();
  excelExportSettings ??= ExcelExportSettings();
  intervallStoreManager ??= IntervalStoreManager();
  exportColumnsManager ??= ExportColumnsManager();
  final db = store ?? MockHealthStore();
  return _easyApp(
    child: child,
    settings: edadat,
    locale: locale,
    routes: routes,
    overrides: [
      exportSettingsProvider.overrideWithValue(exportSettings),
      csvExportSettingsProvider.overrideWithValue(csvExportSettings),
      pdfExportSettingsProvider.overrideWithValue(pdfExportSettings),
      excelExportSettingsProvider.overrideWithValue(excelExportSettings),
      intervalStoreManagerProvider.overrideWithValue(intervallStoreManager),
      exportColumnsManagerProvider.overrideWithValue(exportColumnsManager),
      bloodPressureRepositoryProvider.overrideWithValue(db.bpRepo),
      medicineRepositoryProvider.overrideWithValue(db.medRepo),
      medicineIntakeRepositoryProvider.overrideWithValue(db.intakeRepo),
      noteRepositoryProvider.overrideWithValue(db.noteRepo),
      bodyweightRepositoryProvider.overrideWithValue(db.weightRepo),
      bleBlacklistRepositoryProvider.overrideWithValue(db.blacklistRepo),
      ...overrides,
    ],
  );
}

/// Pump [app] until EasyLocalization has applied translations.
///
/// Each locale JSON is a platform-channel read. The first test in a file
/// often completes those during settings init; later tests need enough
/// single frames for a new [EasyLocalization] to finish. Do not
/// [WidgetTester.pumpAndSettle] — logging can leave a timer that never idles.
///
/// [extraPumps] advances stream providers after the first real frame. Golden
/// graph tests pass `0` so chart animation stays on the captured frame.
Future<void> pumpApp(
  WidgetTester tester,
  Widget app, {
  int extraPumps = 5,
}) async {
  await tester.pumpWidget(app);
  for (var i = 0; i < 20; i++) {
    if (find.byType(Scaffold).evaluate().isNotEmpty) break;
    await tester.pump();
  }
  for (var i = 0; i < extraPumps; i++) {
    await tester.pump();
  }
}

/// Advance a short stretch of UI without waiting for every timer to go idle.
Future<void> pumpQuiet(
  WidgetTester tester, [
  Duration duration = const Duration(milliseconds: 50),
]) async {
  await tester.pump();
  await tester.pump(duration);
}

/// Creates a the same App as the main method.
Future<Widget> appBase(
  Widget child, {
  TestSettingsSeed? settings,
  ExportSettings? exportSettings,
  CsvExportSettings? csvExportSettings,
  PdfExportSettings? pdfExportSettings,
  IntervalStoreManager? intervallStoreManager,
  BloodPressureRepository? bpRepo,
  MedicineRepository? medRepo,
  NoteRepository? noteRepo,
  MedicineIntakeRepository? intakeRepo,
  BodyweightRepository? weightRepo,
  BleBlacklistRepository? blacklistRepo,
  Locale locale = const Locale('en'),
}) async {
  final db = MockHealthStore();
  medRepo ??= db.medRepo;
  List<Medicine> meds = [];
  if (medRepo is MockMedRepo) {
    meds = medRepo._meds;
  } else {
    medRepo.getAll().then((meds) {
      assert(meds.isEmpty);
    });
  }
  final medCache = MedCache(medRepo, meds);
  final edadat = await createTestSettings(settings);
  exportSettings ??= ExportSettings();
  csvExportSettings ??= CsvExportSettings();
  pdfExportSettings ??= PdfExportSettings();
  final excelExportSettings = ExcelExportSettings();
  intervallStoreManager ??= IntervalStoreManager();
  final exportColumnsManager = ExportColumnsManager();

  return _easyApp(
    child: child,
    settings: edadat,
    locale: locale,
    overrides: [
      exportSettingsProvider.overrideWithValue(exportSettings),
      csvExportSettingsProvider.overrideWithValue(csvExportSettings),
      pdfExportSettingsProvider.overrideWithValue(pdfExportSettings),
      excelExportSettingsProvider.overrideWithValue(excelExportSettings),
      intervalStoreManagerProvider.overrideWithValue(intervallStoreManager),
      exportColumnsManagerProvider.overrideWithValue(exportColumnsManager),
      bloodPressureRepositoryProvider.overrideWithValue(bpRepo ?? db.bpRepo),
      medicineRepositoryProvider.overrideWithValue(medRepo),
      medicineIntakeRepositoryProvider.overrideWithValue(
        intakeRepo ?? db.intakeRepo,
      ),
      noteRepositoryProvider.overrideWithValue(noteRepo ?? db.noteRepo),
      bodyweightRepositoryProvider.overrideWithValue(
        weightRepo ?? db.weightRepo,
      ),
      bleBlacklistRepositoryProvider.overrideWithValue(
        blacklistRepo ?? db.blacklistRepo,
      ),
      medCacheProvider.overrideWithValue(medCache),
    ],
  );
}

/// Creates a the same App as the main method.
Future<Widget> appBaseWithData(
  Widget child, {
  TestSettingsSeed? settings,
  ExportSettings? exportSettings,
  CsvExportSettings? csvExportSettings,
  PdfExportSettings? pdfExportSettings,
  IntervalStoreManager? intervallStoreManager,
  List<BloodPressureRecord>? records,
  List<Medicine>? meds,
  List<Note>? notes,
  List<MedicineIntake>? intakes,
  List<BodyweightRecord>? weights,
  Locale locale = const Locale('en'),
}) async {
  final db = MockHealthStore();
  final bpRepo = db.bpRepo;
  for (final r in records ?? []) {
    await bpRepo.add(r);
  }
  final medRepo = MockMedRepo(meds);
  final intakeRepo = db.intakeRepo;
  for (final i in intakes ?? []) {
    await intakeRepo.add(i);
  }
  final noteRepo = db.noteRepo;
  for (final n in notes ?? []) {
    await noteRepo.add(n);
  }
  final weightRepo = db.weightRepo;
  for (final w in weights ?? []) {
    await weightRepo.add(w);
  }

  return appBase(
    child,
    settings: settings,
    exportSettings: exportSettings,
    csvExportSettings: csvExportSettings,
    pdfExportSettings: pdfExportSettings,
    intervallStoreManager: intervallStoreManager,
    bpRepo: bpRepo,
    medRepo: medRepo,
    noteRepo: noteRepo,
    intakeRepo: intakeRepo,
    weightRepo: weightRepo,
    blacklistRepo: db.blacklistRepo,
    locale: locale,
  );
}

/// [materialApp] variant that doesn't assume scaffold.
Future<Widget> materialForScreens(
  Widget child, {
  TestSettingsSeed? settings,
  ExportSettings? exportSettings,
  CsvExportSettings? csvExportSettings,
  PdfExportSettings? pdfExportSettings,
  IntervalStoreManager? intervallStoreManager,
}) async {
  exportSettings ??= ExportSettings();
  csvExportSettings ??= CsvExportSettings();
  pdfExportSettings ??= PdfExportSettings();
  intervallStoreManager ??= IntervalStoreManager();
  final edadat = await createTestSettings(settings);
  return _easyApp(
    child: child,
    settings: edadat,
    wrapScaffold: false,
    overrides: [
      exportSettingsProvider.overrideWithValue(exportSettings),
      csvExportSettingsProvider.overrideWithValue(csvExportSettings),
      pdfExportSettingsProvider.overrideWithValue(pdfExportSettings),
      intervalStoreManagerProvider.overrideWithValue(intervallStoreManager),
    ],
  );
}

Future<Widget> appBaseForScreen(
  Widget child, {
  TestSettingsSeed? settings,
  ExportSettings? exportSettings,
  CsvExportSettings? csvExportSettings,
  PdfExportSettings? pdfExportSettings,
  IntervalStoreManager? intervallStoreManager,
  BloodPressureRepository? bpRepo,
  MedicineRepository? medRepo,
  NoteRepository? noteRepo,
  MedicineIntakeRepository? intakeRepo,
  BodyweightRepository? weightRepo,
  BleBlacklistRepository? blacklistRepo,
}) async {
  final db = MockHealthStore();
  return _easyApp(
    child: child,
    settings: await createTestSettings(settings),
    wrapScaffold: false,
    overrides: [
      exportSettingsProvider.overrideWithValue(
        exportSettings ?? ExportSettings(),
      ),
      csvExportSettingsProvider.overrideWithValue(
        csvExportSettings ?? CsvExportSettings(),
      ),
      pdfExportSettingsProvider.overrideWithValue(
        pdfExportSettings ?? PdfExportSettings(),
      ),
      intervalStoreManagerProvider.overrideWithValue(
        intervallStoreManager ?? IntervalStoreManager(),
      ),
      bloodPressureRepositoryProvider.overrideWithValue(bpRepo ?? db.bpRepo),
      medicineRepositoryProvider.overrideWithValue(medRepo ?? db.medRepo),
      medicineIntakeRepositoryProvider.overrideWithValue(
        intakeRepo ?? db.intakeRepo,
      ),
      noteRepositoryProvider.overrideWithValue(noteRepo ?? db.noteRepo),
      bodyweightRepositoryProvider.overrideWithValue(
        weightRepo ?? db.weightRepo,
      ),
      bleBlacklistRepositoryProvider.overrideWithValue(
        blacklistRepo ?? db.blacklistRepo,
      ),
    ],
  );
}

/// Phone-sized surface so Safaeh uses its phone sheet chrome in widget tests.
void usePhoneTestSurface(WidgetTester tester) {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

Finder safaehConfirm() => find.byKey(const ValueKey('safaeh_confirm'));
Finder safaehCancel() => find.byKey(const ValueKey('safaeh_cancel'));
Finder safaehTextDone() => find.byKey(const ValueKey('safaeh_text_done'));

Future<void> tapSafaehConfirm(WidgetTester tester) async {
  final target = safaehConfirm().evaluate().isNotEmpty
      ? safaehConfirm()
      : safaehTextDone();
  await tester.ensureVisible(target);
  await tester.tap(target);
}

Future<void> dismissSafaeh(WidgetTester tester) async {
  if (safaehCancel().evaluate().isNotEmpty) {
    await tester.tap(safaehCancel());
    return;
  }
  if (find.byIcon(Icons.close).evaluate().isNotEmpty) {
    await tester.tap(find.byIcon(Icons.close));
    return;
  }
  await tester.tapAt(const Offset(8, 8));
}

/// Open a dialog through a button press.
Future<void> loadDialog(
  WidgetTester tester,
  void Function(BuildContext context) dialogStarter, {
  String dialogStarterText = 'X',
  TestSettingsSeed? settings,
}) async {
  await pumpApp(
    tester,
    await appBase(
      Builder(
        builder: (context) => TextButton(
          onPressed: () => dialogStarter(context),
          child: Text(dialogStarterText),
        ),
      ),
      settings: settings,
    ),
  );
  await tester.tap(find.text(dialogStarterText));
  await tester.pumpAndSettle();
}

/// Get empty mock med repo.
MedicineRepository medRepo([List<Medicine>? meds]) => MockMedRepo(meds);

class MockMedRepo implements MedicineRepository {
  MockMedRepo(List<Medicine>? meds) {
    if (meds != null) _meds.addAll(meds);
  }

  final List<Medicine> _meds = [];

  final _controller = StreamController<Medicine?>.broadcast();

  @override
  Future<void> add(Medicine medicine) async {
    _meds.add(medicine);
    _controller.add(medicine);
  }

  @override
  Future<List<Medicine>> getAll() async => _meds;

  @override
  Future<List<Medicine>> getAllInCreationOrder() => getAll();

  @override
  Future<void> remove(Medicine value) async {
    _meds.remove(value);
    _controller.add(null);
  }

  @override
  @Deprecated('Medicines have no date. Use getAll directly')
  Future<List<Medicine>> get(DateRange range) => getAll();

  @override
  Stream<Medicine?> subscribe() => _controller.stream;
}

final List<Medicine> _meds = [];

Medicine mockMedicine({
  Color color = Colors.black,
  String designation = '',
  double? defaultDosis,
}) {
  final matchingMeds = _meds.where(
    (med) =>
        med.dosis?.mg == defaultDosis &&
        med.color == color.toARGB32() &&
        med.designation == designation,
  );
  if (matchingMeds.isNotEmpty) return matchingMeds.first;
  final med = Medicine(
    designation: designation,
    color: color.toARGB32(),
    dosis: defaultDosis == null ? null : Weight.mg(defaultDosis),
  );
  _meds.add(med);
  return med;
}

MedicineIntake mockIntake(Medicine medicine, {int? time, double? dosis}) =>
    MedicineIntake(
      time: time != null
          ? DateTime.fromMillisecondsSinceEpoch(time)
          : DateTime.now(),
      medicine: medicine,
      dosis: Weight.mg(dosis ?? medicine.dosis?.mg ?? 42.0),
    );

class MockHealthStore {
  BloodPressureRepository bpRepo = MockBloodPressureRepository();

  MedicineIntakeRepository intakeRepo = MockMedicineIntakeRepository();

  MedicineRepository medRepo = MockMedicineRepository();

  NoteRepository noteRepo = MockNoteRepository();

  BodyweightRepository weightRepo = MockBodyweightRepository();

  BleBlacklistRepository blacklistRepo = MockBleBlacklistRepository();
}

class MockBleBlacklistRepository implements BleBlacklistRepository {
  final Map<String, Set<String>> keys = {};

  @override
  Future<void> add(String kind, String key) async {
    keys.putIfAbsent(kind, () => <String>{}).add(key);
  }

  @override
  Future<void> remove(String kind, String key) async {
    keys[kind]?.remove(key);
  }

  @override
  Future<Set<String>> getKeys(String kind) async =>
      Set<String>.of(keys[kind] ?? const <String>{});
}

class _MockRepo<T> extends Repository<T> {
  List<T> data = [];
  final contr = StreamController<T?>.broadcast();

  @override
  Future<void> add(T value) async {
    data.add(value);
    contr.add(value);
  }

  @override
  Future<List<T>> get(DateRange range) async => List<T>.of(data);

  @override
  Future<void> remove(T value) async {
    data.remove(value);
    contr.sink.add(null);
  }

  @override
  Stream<T?> subscribe() => contr.stream;

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw Exception('unexpected call: $invocation');
}

class MockBloodPressureRepository extends _MockRepo<BloodPressureRecord>
    implements BloodPressureRepository {}

class MockMedicineIntakeRepository extends _MockRepo<MedicineIntake>
    implements MedicineIntakeRepository {}

class MockMedicineRepository extends _MockRepo<Medicine>
    implements MedicineRepository {
  @override
  Future<List<Medicine>> getAll() async => data;
}

class MockNoteRepository extends _MockRepo<Note> implements NoteRepository {}

class MockBodyweightRepository extends _MockRepo<BodyweightRecord>
    implements BodyweightRepository {}

dynamic myMatchesGoldenFile(String key) =>
    matchesGoldenFile(join('golden', key));
