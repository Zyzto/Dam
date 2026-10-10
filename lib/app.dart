import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:blood_pressure_app/core/database/database_providers.dart';
import 'package:blood_pressure_app/core/database/health_database.dart';
import 'package:blood_pressure_app/core/repository/powersync_blood_pressure_repository.dart';
import 'package:blood_pressure_app/core/repository/powersync_bodyweight_repository.dart';
import 'package:blood_pressure_app/core/repository/powersync_medicine_intake_repository.dart';
import 'package:blood_pressure_app/core/repository/powersync_medicine_repository.dart';
import 'package:blood_pressure_app/core/repository/powersync_note_repository.dart';
import 'package:blood_pressure_app/core/repository/repository_providers.dart';
import 'package:blood_pressure_app/core/settings/storage_providers.dart';
import 'package:blood_pressure_app/data_util/consistent_future_builder.dart';
import 'package:blood_pressure_app/domain/domain.dart';
import 'package:blood_pressure_app/features/bluetooth/ui/ble_launch_sync_host.dart';
import 'package:blood_pressure_app/features/debug/debug_data_server.dart';
import 'package:blood_pressure_app/features/health_connect/bp_sync_model.dart';
import 'package:blood_pressure_app/features/health_connect/health_connect_screen.dart';
import 'package:blood_pressure_app/features/health_connect/sync_model.dart';
import 'package:blood_pressure_app/features/health_connect/weight_sync_model.dart';
import 'package:blood_pressure_app/features/input/forms/add_entry_form.dart';
import 'package:blood_pressure_app/features/medications/medication_reminder_providers.dart';
import 'package:blood_pressure_app/features/medications/medication_reminder_runtime.dart';
import 'package:blood_pressure_app/features/medications/medication_reminders_screens.dart';
import 'package:blood_pressure_app/features/onboarding/onboarding_screen.dart';
import 'package:blood_pressure_app/features/settings/app_settings.dart';
import 'package:blood_pressure_app/features/settings/export_import_screen.dart';
import 'package:blood_pressure_app/features/settings/graph_screen.dart';
import 'package:blood_pressure_app/features/settings/medicine_manager_screen.dart';
import 'package:blood_pressure_app/features/settings/registry.dart';
import 'package:blood_pressure_app/features/shell/app_shell.dart';
import 'package:blood_pressure_app/features/shell/shell_nav_chrome.dart';
import 'package:blood_pressure_app/l10n/western_digits.dart';
import 'package:blood_pressure_app/logging.dart';
import 'package:blood_pressure_app/model/bluetooth_input_mode.dart';
import 'package:blood_pressure_app/model/med_cache.dart';
import 'package:blood_pressure_app/model/storage/storage.dart';
import 'package:blood_pressure_app/screens/add_entry_screen.dart';
import 'package:blood_pressure_app/screens/error_reporting_screen.dart';
import 'package:blood_pressure_app/screens/home_screen.dart';
import 'package:blood_pressure_app/screens/settings_screen.dart';
import 'package:blood_pressure_app/screens/statistics_screen.dart';
import 'package:blood_pressure_app/screens/weight_screen.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_settings_framework/flutter_settings_framework.dart';
import 'package:health/health.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path/path.dart';
import 'package:powersync/powersync.dart';
import 'package:receive_intent/receive_intent.dart';
import 'package:safaeh/safaeh.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Base class for the entire app.
class App extends ConsumerStatefulWidget {
  const App({super.key});

  @override
  ConsumerState<App> createState() => _AppState();
}

class _AppState extends ConsumerState<App> with Loggable {
  PowerSyncDatabase? _entryDB;
  final HomePresenceObserver _homePresence = HomePresenceObserver();
  final GlobalKey _launchSyncHostKey = GlobalKey();
  final GlobalKey _bootScopeKey = GlobalKey();

  Future<void>? _loadFuture;
  var _ready = false;
  var _ownsFileSettings = false;
  var _ownsDb = false;
  AppRoute _initialRoute = AppRoute.home;

  FileSettingsLoader? _settingsLoader;
  ExportSettings? _exportSettings;
  CsvExportSettings? _csvExportSettings;
  PdfExportSettings? _pdfExportSettings;
  ExcelExportSettings? _xlsExportSettings;
  IntervalStoreManager? _intervalStorageManager;
  ExportColumnsManager? _exportColumnsManager;
  BloodPressureRepository? _bpRepo;
  NoteRepository? _noteRepo;
  MedicineRepository? _medRepo;
  MedicineIntakeRepository? _intakeRepo;
  BodyweightRepository? _weightRepo;
  MedCache? _medCache;

  @override
  void dispose() {
    if (_ownsDb) {
      _entryDB?.close();
    }
    _entryDB = null;
    if (_ownsFileSettings) {
      _exportSettings?.dispose();
      _csvExportSettings?.dispose();
      _pdfExportSettings?.dispose();
      _xlsExportSettings?.dispose();
      _intervalStorageManager?.dispose();
      _exportColumnsManager?.dispose();
    }
    _homePresence.dispose();
    super.dispose();
  }

  Future<void> _loadApp() async {
    if (!Platform.isAndroid && !Platform.isIOS) {
      databaseFactory = databaseFactoryFfi;
    }

    if (kDebugMode && (const bool.fromEnvironment('testing_mode'))) {
      final dbPath = await getDatabasesPath();
      try {
        for (final name in [
          HealthDatabase.legacyFileName,
          '${HealthDatabase.legacyFileName}-journal',
          '${HealthDatabase.legacyFileName}-wal',
          '${HealthDatabase.legacyFileName}-shm',
          HealthDatabase.legacyBackupName,
          HealthDatabase.fileName,
          '${HealthDatabase.fileName}-journal',
          '${HealthDatabase.fileName}-wal',
          '${HealthDatabase.fileName}-shm',
        ]) {
          final file = File(join(dbPath, name));
          if (file.existsSync()) file.deleteSync();
        }
      } on FileSystemException {
        // already gone
      }
      try {
        Directory(
          join(await getDatabasesPath(), 'settings'),
        ).deleteSync(recursive: true);
      } on FileSystemException {
        // already gone
      }
      await FileSettingsLoader.clearPreferences();
    }

    try {
      _exportSettings = ref.read(exportSettingsProvider);
      _csvExportSettings = ref.read(csvExportSettingsProvider);
      _pdfExportSettings = ref.read(pdfExportSettingsProvider);
      _xlsExportSettings = ref.read(excelExportSettingsProvider);
      _intervalStorageManager = ref.read(intervalStoreManagerProvider);
      _exportColumnsManager = ref.read(exportColumnsManagerProvider);
      _settingsLoader = ref.read(fileSettingsLoaderProvider);
    } catch (_) {
      try {
        _settingsLoader = await FileSettingsLoader.load();
        _exportSettings = await _settingsLoader!.loadExportSettings();
        _csvExportSettings = await _settingsLoader!.loadCsvExportSettings();
        _pdfExportSettings = await _settingsLoader!.loadPdfExportSettings();
        _xlsExportSettings = await _settingsLoader!.loadXlsExportSettings();
        _intervalStorageManager = await _settingsLoader!
            .loadIntervalStorageManager();
        _exportColumnsManager = await _settingsLoader!
            .loadExportColumnsManager();
        _ownsFileSettings = true;
      } catch (e, stack) {
        await ErrorReporting.reportCriticalError(
          'Error loading settings from files',
          '$e\n$stack',
        );
      }
    }

    try {
      // Prefer the root boot overrides. [Ref.exists] is false until the
      // provider is first read, so using it here opened a second PowerSync
      // client and a second repo set. Home watches the root repos;
      // AddEntryScreen writes the nested ones — subscribe() never fired.
      _entryDB = ref.read(healthDatabaseProvider);
      _bpRepo = ref.read(bloodPressureRepositoryProvider);
      _noteRepo = ref.read(noteRepositoryProvider);
      _medRepo = ref.read(medicineRepositoryProvider);
      _intakeRepo = ref.read(medicineIntakeRepositoryProvider);
      _weightRepo = ref.read(bodyweightRepositoryProvider);
    } on UnimplementedError {
      try {
        _entryDB = await HealthDatabase.open();
        _bpRepo = PowerSyncBloodPressureRepository(_entryDB!);
        _noteRepo = PowerSyncNoteRepository(_entryDB!);
        _medRepo = PowerSyncMedicineRepository(_entryDB!);
        _intakeRepo = PowerSyncMedicineIntakeRepository(_entryDB!);
        _weightRepo = PowerSyncBodyweightRepository(_entryDB!);
        _ownsDb = true;
      } catch (e, stack) {
        await ErrorReporting.reportCriticalError(
          'Error loading entry db',
          '$e\n$stack',
        );
      }
    } catch (e, stack) {
      await ErrorReporting.reportCriticalError(
        'Error loading entry db',
        '$e\n$stack',
      );
    }

    final settings = ref.read(appSettingsProvider);
    try {
      if (settings.allowMissingValues && settings.validateInputs) {
        await ref.updateSetting(validateInputsSetting, false);
      }

      if (settings.lastVersion <= 55 &&
          settings.bleInput == BluetoothInputMode.oldBluetoothInput) {
        await ref.updateSetting(
          bleInputSetting,
          BluetoothInputMode.newBluetoothInputCrossPlatform.name,
        );
      }
      if (settings.bleInput != BluetoothInputMode.disabled) {
        await ref.updateSetting(bluetoothMeasurementsEnabledSetting, true);
      }

      final buildNumber = int.parse(
        (await PackageInfo.fromPlatform()).buildNumber,
      );
      if (settings.lastVersion <= 57 &&
          settings.knownBleDev.isNotEmpty &&
          settings.bleInput != BluetoothInputMode.disabled) {
        await ref.updateSetting(syncBluetoothOnLaunchSetting, true);
      }
      if (settings.lastVersion > 0 && !settings.onboardingCompleted) {
        await ref.updateSetting(onboardingCompletedSetting, true);
      }
      await ref.updateSetting(
        lastVersionSetting,
        buildNumber < 58 ? 58 : buildNumber,
      );

      _intervalStorageManager!.mainPage.setToMostRecentInterval();
    } catch (e, stack) {
      await ErrorReporting.reportCriticalError(
        'Error performing upgrades:',
        '$e\n$stack',
      );
    }

    final dbPath = await getDatabasesPath();
    if (File(join(dbPath, 'config.db')).existsSync()) {
      File(join(dbPath, 'config.db')).deleteSync();
    }
    if (File(join(dbPath, 'config.db-journal')).existsSync()) {
      File(join(dbPath, 'config.db-journal')).deleteSync();
    }

    final hc = ref.read(appSettingsProvider);
    if (hc.useHealthConnect && hc.syncOnAppStart) {
      if (hc.bloodPressureEnabled && hc.syncPressureMeasurements) {
        logInfo('Syncing blood pressure measurements');
        await BPSyncModel(bpRepo: _bpRepo!, health: Health()).sync();
      }
      if (hc.weightInput && hc.syncWeightMeasurements) {
        logInfo('Syncing weight measurements');
        await WeightSyncModel(
          weightRepo: _weightRepo!,
          health: Health(),
        ).sync();
      }
    }

    if (hc.useHealthConnect) {
      final health = Health();
      if (hc.weightInput && hc.syncWeightMeasurements) {
        _weightRepo!.subscribe().listen((record) async {
          final current = ref.read(appSettingsProvider);
          if (record != null &&
              current.useHealthConnect &&
              current.weightInput &&
              current.syncWeightMeasurements) {
            final canWrite = await health.requestPermissionsIfMissing([
              HealthDataType.WEIGHT,
            ], HealthDataAccess.WRITE);
            if (!canWrite) {
              logWarning('Health Connect weight write permissions not granted');
            }
            await health.writeHealthData(
              type: HealthDataType.WEIGHT,
              value: record.weight.kg,
              startTime: record.time,
              recordingMethod: RecordingMethod.manual,
            );
          }
        });
      }
      if (hc.bloodPressureEnabled && hc.syncPressureMeasurements) {
        _bpRepo!.subscribe().listen((record) async {
          final current = ref.read(appSettingsProvider);
          if (record?.sys != null &&
              record?.dia != null &&
              current.useHealthConnect &&
              current.bloodPressureEnabled &&
              current.syncPressureMeasurements) {
            final canWrite = await health.requestPermissionsIfMissing([
              HealthDataType.BLOOD_PRESSURE_SYSTOLIC,
              HealthDataType.BLOOD_PRESSURE_DIASTOLIC,
            ], HealthDataAccess.WRITE);
            if (!canWrite) {
              logWarning('Health Connect BP write permissions not granted');
            }
            await health.writeBloodPressure(
              systolic: record!.sys!.mmHg,
              diastolic: record.dia!.mmHg,
              startTime: record.time,
            );
          }
        });
      }
    }

    AppRoute initialRoute = AppRoute.home;
    if (!hc.onboardingCompleted) {
      initialRoute = AppRoute.onboarding;
    } else if (hc.startWithAddMeasurementPage && hc.bloodPressureEnabled) {
      initialRoute = AppRoute.add;
    }
    if (hc.onboardingCompleted && Platform.isAndroid) {
      try {
        final intent = await ReceiveIntent.getInitialIntent();
        logInfo('Received intent: $intent');
        if (hc.medicineFeatureEnabled &&
            intent?.extra?['route'] == AppRoute.medicationToday.path) {
          initialRoute = AppRoute.medicationToday;
        } else if (intent?.action ==
            'android.intent.action.VIEW_PERMISSION_USAGE') {
          switch (intent!
              .extra?['android.intent.extra.PERMISSION_GROUP_NAME']) {
            case 'android.permission-group.HEALTH':
              initialRoute = AppRoute.settingsHealthConnect;
              break;
            case 'android.permission-group.NEARBY_DEVICES':
              initialRoute = AppRoute.settings;
              break;
          }
        }
      } on PlatformException {
        // Don't try too hard
      }
    }
    if (hc.medicineFeatureEnabled &&
        hc.onboardingCompleted &&
        Platform.isAndroid &&
        await MedicationReminderRuntime.instance.launchedFromNotification) {
      initialRoute = AppRoute.medicationToday;
    }

    try {
      _medCache = ref.read(medCacheProvider);
    } on UnimplementedError {
      _medCache = MedCache(_medRepo!, await _medRepo!.getAll());
    }
    try {
      await syncMedicationReminders(
        ref.read(medicationScheduleRepositoryProvider),
        hc,
      );
    } catch (e, stack) {
      logWarning('Medication reminder refresh failed: $e\n$stack');
    }
    _initialRoute = initialRoute;
    if (mounted) {
      setState(() => _ready = true);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        MedicationReminderRuntime.instance.flushPendingWidgetRoute();
      });
    }
  }

  Widget _bootScope() => ProviderScope(
    key: _bootScopeKey,
    overrides: [
      healthDatabaseProvider.overrideWithValue(_entryDB!),
      // Same instances as Health Connect / MedCache; subscribe() is per object.
      bloodPressureRepositoryProvider.overrideWithValue(_bpRepo!),
      noteRepositoryProvider.overrideWithValue(_noteRepo!),
      medicineRepositoryProvider.overrideWithValue(_medRepo!),
      medicineIntakeRepositoryProvider.overrideWithValue(_intakeRepo!),
      bodyweightRepositoryProvider.overrideWithValue(_weightRepo!),
      fileSettingsLoaderProvider.overrideWithValue(_settingsLoader),
      exportSettingsProvider.overrideWithValue(_exportSettings!),
      csvExportSettingsProvider.overrideWithValue(_csvExportSettings!),
      pdfExportSettingsProvider.overrideWithValue(_pdfExportSettings!),
      excelExportSettingsProvider.overrideWithValue(_xlsExportSettings!),
      intervalStoreManagerProvider.overrideWithValue(_intervalStorageManager!),
      exportColumnsManagerProvider.overrideWithValue(_exportColumnsManager!),
      medCacheProvider.overrideWithValue(_medCache!),
    ],
    child: _AppRoot(
      initialRoute: _initialRoute,
      homePresence: _homePresence,
      launchSyncHostKey: _launchSyncHostKey,
    ),
  );

  @override
  Widget build(BuildContext context) {
    if (_ready && _entryDB != null) return _bootScope();
    _loadFuture ??= _loadApp();
    return ConsistentFutureBuilder(
      future: _loadFuture!,
      cacheFuture: true,
      onWaiting: const SizedBox.shrink(),
      onData: (context, _) => _bootScope(),
    );
  }
}

class _AppRoot extends ConsumerStatefulWidget {
  const _AppRoot({
    required this.initialRoute,
    required this.homePresence,
    required this.launchSyncHostKey,
  });

  final AppRoute initialRoute;
  final HomePresenceObserver homePresence;
  final GlobalKey launchSyncHostKey;

  @override
  ConsumerState<_AppRoot> createState() => _AppRootState();
}

class _AppRootState extends ConsumerState<_AppRoot> {
  final _settingsSearchOpen = ValueNotifier<bool>(false);
  StreamSubscription<MedicineIntake?>? _intakeClaims;
  DebugDataServer? _debugServer;
  String? _syncedReminderLocale;
  String? _appliedAppLocaleKey;

  @override
  void initState() {
    super.initState();
    if (kDebugMode) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        final enabled = ref
            .read(settingsProvidersProvider)
            .controller
            .get(debugDataServerSetting);
        unawaited(_setDebugServer(enabled));
      });
    }
    _intakeClaims = ref.read(medicineIntakeRepositoryProvider).subscribe().listen((
      intake,
    ) {
      final settings = ref.read(appSettingsProvider);
      final occurrenceId = intake?.occurrenceId;
      if (!settings.shiftMissedDoseTimes) {
        if (occurrenceId == null) return;
        unawaited(
          MedicationReminderRuntime.instance.cancelClaimedDose(occurrenceId),
        );
        ref.invalidate(homeMedicationOccurrencesProvider);
        ref.invalidate(todayMedicationOccurrencesProvider);
        ref.invalidate(medicationDayProvider);
        return;
      }
      if (occurrenceId != null) {
        unawaited(
          MedicationReminderRuntime.instance.cancelClaimedDose(occurrenceId),
        );
      }
      ref.invalidate(homeMedicationOccurrencesProvider);
      ref.invalidate(todayMedicationOccurrencesProvider);
      ref.invalidate(medicationDayProvider);
      if (!mounted) return;
      unawaited(_refreshMedicationRuntime(settings.medicineFeatureEnabled));
    });
  }

  @override
  void dispose() {
    unawaited(_debugServer?.stop());
    _intakeClaims?.cancel();
    _settingsSearchOpen.dispose();
    super.dispose();
  }

  Future<void> _setDebugServer(bool enabled) async {
    if (!kDebugMode) return;
    if (!enabled) {
      await _debugServer?.stop();
      return;
    }
    _debugServer ??= DebugDataServer(ref);
    await _debugServer!.start();
  }

  Future<void> _syncAndroidAppNameLocale(String languageKey) async {
    if (!Platform.isAndroid) return;
    final tag = switch (languageKey) {
      'system' || '' => '',
      'zh' => 'zh-CN',
      _ => languageKey,
    };
    try {
      await const MethodChannel(
        'com.shenepoy.janan/app_locale',
      ).invokeMethod<void>('set', {'tag': tag});
    } on MissingPluginException {
      // Desktop and tests do not expose the Android locale channel.
    } on PlatformException {
      // A locale the system rejects must not block the in-app language.
    }
  }

  Future<void> _refreshMedicationRuntime(bool enabled) async {
    try {
      if (!enabled) {
        await clearMedicationReminders();
        return;
      }
      await syncMedicationReminders(
        ref.read(medicationScheduleRepositoryProvider),
        ref.read(appSettingsProvider),
      );
    } catch (error, stack) {
      debugPrint('Medication reminder refresh failed: $error\n$stack');
    }
  }

  Widget _shell(ShellTab tab) => AppShell(
    homePresence: widget.homePresence,
    initialTab: tab,
    settingsSearchOpen: _settingsSearchOpen,
    onSettingsSearch: () =>
        _settingsSearchOpen.value = !_settingsSearchOpen.value,
    pages: [
      const AppHome(),
      const WeightScreen(),
      const StatisticsScreen(),
      SettingsPage(searchOpen: _settingsSearchOpen, showAppBar: false),
    ],
  );

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(appSettingsProvider);
    if (kDebugMode) {
      ref.listen(
        ref.watch(settingsProvidersProvider).provider(debugDataServerSetting),
        (previous, next) => unawaited(_setDebugServer(next)),
      );
    }
    ref.listen(appSettingsProvider, (previous, next) {
      if (previous == null) return;
      final remindersChanged =
          previous.medicineFeatureEnabled != next.medicineFeatureEnabled ||
          previous.medicationNotificationsEnabled !=
              next.medicationNotificationsEnabled ||
          previous.overdueReminderCount != next.overdueReminderCount ||
          previous.overdueReminderIntervalMinutes !=
              next.overdueReminderIntervalMinutes ||
          previous.shiftMissedDoseTimes != next.shiftMissedDoseTimes ||
          previous.missedDoseShiftLimitMinutes !=
              next.missedDoseShiftLimitMinutes ||
          previous.showAllReminderRings != next.showAllReminderRings;
      if (remindersChanged) {
        unawaited(_refreshMedicationRuntime(next.medicineFeatureEnabled));
      }
    });
    final languageKey = settings.languageKey;
    if (_appliedAppLocaleKey != languageKey) {
      _appliedAppLocaleKey = languageKey;
      unawaited(_syncAndroidAppNameLocale(languageKey));
    }
    final localeTag = context.locale.toLanguageTag();
    if (_syncedReminderLocale != localeTag) {
      final hadLocale = _syncedReminderLocale != null;
      _syncedReminderLocale = localeTag;
      if (hadLocale) {
        final enabled = settings.medicineFeatureEnabled;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted || context.locale.toLanguageTag() != localeTag) return;
          unawaited(_refreshMedicationRuntime(enabled));
        });
      }
    }
    final isRtl = context.locale.languageCode == 'ar';
    return SafaehTheme(
      data: const SafaehThemeData(
        tabletBreakpoint: 600,
        dialogMaxWidth: 560,
        floatingAppearance: SafaehFloatingAppearance(
          style: SafaehFloatingSurfaceStyle.glass,
        ),
      ),
      child: MaterialApp(
        navigatorKey: medicationNavigatorKey,
        title: 'Janan',
        onGenerateTitle: (context) => 'title'.tr(),
        theme: _buildTheme(
          ColorScheme.fromSeed(seedColor: settings.accentColor),
        ),
        darkTheme: _buildTheme(
          ColorScheme.fromSeed(
            seedColor: settings.accentColor,
            brightness: Brightness.dark,
          ),
        ),
        themeMode: settings.themeMode,
        localizationsDelegates: withWesternDigits(
          context.localizationDelegates,
        ),
        supportedLocales: context.supportedLocales,
        locale: context.locale,
        debugShowCheckedModeBanner: false,
        navigatorObservers: [widget.homePresence],
        builder: (context, child) {
          final directed = Directionality(
            textDirection: isRtl ? ui.TextDirection.rtl : ui.TextDirection.ltr,
            child: child ?? const SizedBox.shrink(),
          );
          return SafaehFeedbackHost(
            itemWidthBuilder: ShellNavChrome.feedbackItemWidth,
            bottomInsetBuilder: ShellNavChrome.feedbackBottomInset,
            startInsetBuilder: ShellNavChrome.feedbackStartInset,
            endInsetBuilder: ShellNavChrome.feedbackEndInset,
            relayout: ShellNavChrome.actionColumnWidth,
            child: BleLaunchSyncHost(
              key: widget.launchSyncHostKey,
              homePresence: widget.homePresence,
              child: directed,
            ),
          );
        },
        initialRoute: widget.initialRoute.path,
        routes: {
          AppRoute.onboarding.path: (_) =>
              OnboardingScreen(firstRun: !settings.onboardingCompleted),
          AppRoute.home.path: (_) => _shell(ShellTab.home),
          AppRoute.add.path: (_) => settings.bloodPressureEnabled
              ? const AddEntryScreen(kind: AddEntryKind.bloodPressure)
              : _shell(ShellTab.home),
          AppRoute.addWeight.path: (_) => settings.weightInput
              ? const AddEntryScreen(kind: AddEntryKind.weight)
              : _shell(ShellTab.home),
          AppRoute.addMedicine.path: (_) => settings.medicineFeatureEnabled
              ? const AddEntryScreen(kind: AddEntryKind.medicine)
              : _shell(ShellTab.home),
          AppRoute.weight.path: (_) => settings.weightInput
              ? _shell(ShellTab.weight)
              : _shell(ShellTab.home),
          AppRoute.statistics.path: (_) => settings.bloodPressureEnabled
              ? _shell(ShellTab.statistics)
              : _shell(ShellTab.home),
          AppRoute.settings.path: (_) => _shell(ShellTab.settings),
          AppRoute.settingsExport.path: (_) => const ExportImportScreen(),
          AppRoute.settingsGraph.path: (_) => settings.bloodPressureEnabled
              ? const GraphScreen()
              : _shell(ShellTab.home),
          AppRoute.settingsHealthConnect.path: (_) =>
              const HealthConnectScreen(),
          AppRoute.settingsMedications.path: (_) =>
              settings.medicineFeatureEnabled
              ? const MedicineManagerScreen()
              : _shell(ShellTab.home),
          AppRoute.medicationSchedules.path: (_) =>
              settings.medicineFeatureEnabled
              ? const MedicationSchedulesScreen()
              : _shell(ShellTab.home),
          AppRoute.medicationToday.path: (_) => settings.medicineFeatureEnabled
              ? const TodayMedicinesScreen()
              : _shell(ShellTab.home),
        },
      ),
    );
  }

  ThemeData _buildTheme(ColorScheme colorScheme) {
    final inputBorder = OutlineInputBorder(
      borderSide: BorderSide(
        width: 3,
        color: (colorScheme.brightness == Brightness.dark)
            ? colorScheme.outlineVariant
            : colorScheme.outline,
      ),
      borderRadius: BorderRadius.circular(20),
    );

    return ThemeData(
      colorScheme: colorScheme,
      useMaterial3: true,
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: colorScheme.primary,
        foregroundColor: colorScheme.onPrimary,
      ),
      inputDecorationTheme: InputDecorationTheme(
        errorMaxLines: 5,
        border: inputBorder,
        enabledBorder: inputBorder,
      ),
      scaffoldBackgroundColor: colorScheme.brightness == Brightness.dark
          ? Colors.black
          : Colors.white,
      appBarTheme: const AppBarTheme(
        centerTitle: true,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.only(
            bottomRight: Radius.circular(15),
            bottomLeft: Radius.circular(15),
          ),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }
}

enum AppRoute {
  onboarding('/onboarding'),
  home('/'),
  add('/add'),
  addWeight('/add-weight'),
  addMedicine('/add-medicine'),
  weight('/weight'),
  statistics('/statistics'),
  settings('/settings'),
  settingsExport('/settings/export'),
  settingsGraph('/settings/graph'),
  settingsHealthConnect('/settings/healthConnect'),
  settingsMedications('/settings/medications'),
  medicationSchedules('/medications'),
  medicationToday('/medications/today');

  const AppRoute(this.path);

  final String path;

  String get name => path;
}
