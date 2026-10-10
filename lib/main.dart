import 'dart:async';

import 'package:blood_pressure_app/app.dart';
import 'package:blood_pressure_app/core/database/boot_health_store.dart';
import 'package:blood_pressure_app/core/database/database_providers.dart';
import 'package:blood_pressure_app/core/repository/repository_providers.dart';
import 'package:blood_pressure_app/core/settings/boot_file_settings.dart';
import 'package:blood_pressure_app/core/settings/storage_providers.dart';
import 'package:blood_pressure_app/features/settings/initialize_app_settings.dart';
import 'package:blood_pressure_app/features/medications/medication_reminder_runtime.dart';
import 'package:blood_pressure_app/l10n/app_locales.dart';
import 'package:blood_pressure_app/logging.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_settings_framework/flutter_settings_framework.dart';

Future<void> main() async {
  await runZonedGuarded(
    () async {
      WidgetsFlutterBinding.ensureInitialized();
      try {
        await MedicationReminderRuntime.instance.initialize();
      } catch (e, stack) {
        Log.warning(
          'Medication reminder initialization failed',
          error: e,
          stackTrace: stack,
        );
      }
      installCrashHandlers();
      await initAppLogging();
      try {
        await EasyLocalization.ensureInitialized();
      } catch (e, stack) {
        Log.warning(
          'EasyLocalization.ensureInitialized failed',
          error: e,
          stackTrace: stack,
        );
      }
      EasyLocalization.logger.enableBuildModes = [];

      SettingsProviders? settings;
      try {
        settings = await initializeAppSettings();
      } catch (e, stack) {
        Log.severe('Settings init failed', error: e, stackTrace: stack);
      }

      BootFileSettings? fileSettings;
      try {
        fileSettings = await BootFileSettings.load();
      } catch (e, stack) {
        Log.severe('File settings init failed', error: e, stackTrace: stack);
      }

      BootHealthStore? healthStore;
      try {
        healthStore = await BootHealthStore.open();
      } catch (e, stack) {
        Log.severe('Health database init failed', error: e, stackTrace: stack);
      }

      runApp(
        EasyLocalization(
          path: 'assets/translations',
          supportedLocales: appSupportedLocales,
          fallbackLocale: const Locale('en'),
          useFallbackTranslations: true,
          child: ProviderScope(
            overrides: [
              if (settings != null)
                settingsControllerProvider.overrideWithValue(
                  settings.controller,
                ),
              if (settings != null)
                settingsSearchIndexProvider.overrideWithValue(
                  settings.searchIndex,
                ),
              if (settings != null)
                settingsProvidersProvider.overrideWithValue(settings),
              if (fileSettings != null) ...[
                fileSettingsLoaderProvider.overrideWithValue(
                  fileSettings.loader,
                ),
                exportSettingsProvider.overrideWithValue(
                  fileSettings.exportSettings,
                ),
                csvExportSettingsProvider.overrideWithValue(
                  fileSettings.csvExportSettings,
                ),
                pdfExportSettingsProvider.overrideWithValue(
                  fileSettings.pdfExportSettings,
                ),
                excelExportSettingsProvider.overrideWithValue(
                  fileSettings.excelExportSettings,
                ),
                intervalStoreManagerProvider.overrideWithValue(
                  fileSettings.intervalStoreManager,
                ),
                exportColumnsManagerProvider.overrideWithValue(
                  fileSettings.exportColumnsManager,
                ),
              ],
              if (healthStore != null) ...[
                healthDatabaseProvider.overrideWithValue(healthStore.database),
                bloodPressureRepositoryProvider.overrideWithValue(
                  healthStore.bpRepo,
                ),
                noteRepositoryProvider.overrideWithValue(healthStore.noteRepo),
                medicineRepositoryProvider.overrideWithValue(
                  healthStore.medRepo,
                ),
                medicineIntakeRepositoryProvider.overrideWithValue(
                  healthStore.intakeRepo,
                ),
                bodyweightRepositoryProvider.overrideWithValue(
                  healthStore.weightRepo,
                ),
                medCacheProvider.overrideWithValue(healthStore.medCache),
              ],
            ],
            child: const App(),
          ),
        ),
      );
    },
    (error, stack) {
      LoggingService.severe(
        'Uncaught zone error: $error',
        component: 'CrashHandler',
        error: error,
        stackTrace: stack,
      );
    },
  );
}
