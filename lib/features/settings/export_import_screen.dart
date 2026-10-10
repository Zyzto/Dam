import 'dart:io';

import 'package:blood_pressure_app/core/settings/storage_providers.dart';
import 'package:blood_pressure_app/features/data_picker/interval_picker.dart';
import 'package:blood_pressure_app/features/export_import/ui/columns_config/active_column_customizer.dart';
import 'package:blood_pressure_app/features/export_import/ui/export_button.dart';
import 'package:blood_pressure_app/features/export_import/ui/export_column_management_screen.dart';
import 'package:blood_pressure_app/features/export_import/ui/export_field_format_documentation_screen.dart';
import 'package:blood_pressure_app/features/export_import/ui/export_warn_banner.dart';
import 'package:blood_pressure_app/features/export_import/ui/import_button.dart';
import 'package:blood_pressure_app/features/settings/settings_subpage.dart';
import 'package:blood_pressure_app/features/settings/tiles/dropdown_list_tile.dart';
import 'package:blood_pressure_app/features/settings/tiles/input_list_tile.dart';
import 'package:blood_pressure_app/features/settings/tiles/number_input_list_tile.dart';
import 'package:blood_pressure_app/model/storage/storage.dart';
import 'package:blood_pressure_app/model/storage/types/export_format_setting.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_settings_framework/flutter_settings_framework.dart';
import 'package:persistent_user_dir_access_android/persistent_user_dir_access_android.dart';

/// Screen to configure and perform exports and imports of blood pressure values.
class ExportImportScreen extends ConsumerWidget {
  /// Create a screen that shows options for ex- and importing data.
  const ExportImportScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(exportSettingsProvider);
    return ListenableBuilder(
      listenable: Listenable.merge([
        settings,
        ref.watch(csvExportSettingsProvider),
        ref.watch(pdfExportSettingsProvider),
      ]),
      builder: (context, _) {
        final showsColumns =
            settings.exportFormat == ExportFormat.csv ||
            settings.exportFormat == ExportFormat.pdf ||
            settings.exportFormat == ExportFormat.xls;
        return SettingsSubpage(
          title: Text('exportImport'.tr()),
          actions: [
            IconButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute<void>(
                    builder: (context) => InformationScreen(
                      text: 'exportImportDocumentation'.tr(),
                    ),
                  ),
                );
              },
              tooltip: 'exportImportDocumentationTooltip'.tr(),
              icon: const Icon(Icons.info_outline),
            ),
          ],
          bottom: const SettingsActionBar(
            children: [
              Expanded(child: ExportButton(share: true)),
              Expanded(child: ExportButton(share: false)),
              Expanded(child: ImportButton()),
            ],
          ),
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 4, 16, 8),
              child: ExportWarnBanner(),
            ),
            if (settings.exportFormat != ExportFormat.db)
              const IntervalPicker(type: IntervalStoreManagerLocation.exportPage),
            SettingsPageCard(
              key: const ValueKey('export-destination'),
              sectionId: 'export-destination',
              title: 'exportSettings'.tr(),
              icon: Icons.folder_outlined,
              children: [
                if (Platform.isAndroid)
                  ListTile(
                    leading: const Icon(Icons.folder_open),
                    title: Text('exportDir'.tr()),
                    subtitle: settings.defaultExportDir.isNotEmpty
                        ? Text(settings.defaultExportDir)
                        : null,
                    trailing: Icon(
                      settings.defaultExportDir.isEmpty
                          ? Icons.folder_open
                          : Icons.delete_outline,
                    ),
                    onTap: () async {
                      if (settings.defaultExportDir.isEmpty) {
                        final uri = await const PersistentUserDirAccessAndroid()
                            .requestDirectoryUri();
                        settings.defaultExportDir = uri ?? '';
                      } else {
                        settings.defaultExportDir = '';
                      }
                    },
                  ),
                if (Platform.isAndroid)
                  SwitchSettingsTile(
                    leading: const Icon(Icons.schedule_outlined),
                    title: Text('exportAddTimestamp'.tr()),
                    subtitle: Text('exportAddTimestampDesc'.tr()),
                    value: settings.addTimestamp,
                    onChanged: (value) {
                      settings.addTimestamp = value;
                    },
                  ),
                SwitchSettingsTile(
                  leading: const Icon(Icons.save_alt_outlined),
                  title: Text('exportAfterEveryInput'.tr()),
                  subtitle: Text('exportAfterEveryInputDesc'.tr()),
                  value: settings.exportAfterEveryEntry,
                  onChanged: (value) {
                    settings.exportAfterEveryEntry = value;
                  },
                ),
              ],
            ),
            SettingsPageCard(
              key: const ValueKey('export-format'),
              sectionId: 'export-format',
              title: 'exportFormat'.tr(),
              icon: Icons.description_outlined,
              children: [
                DropDownListTile<ExportFormat>(
                  key: const Key('exportFormat'),
                  leading: const Icon(Icons.insert_drive_file_outlined),
                  title: Text('exportFormat'.tr()),
                  value: settings.exportFormat,
                  items: [
                    DropdownMenuItem(
                      value: ExportFormat.csv,
                      child: Text('csv'.tr()),
                    ),
                    DropdownMenuItem(
                      value: ExportFormat.pdf,
                      child: Text('pdf'.tr()),
                    ),
                    DropdownMenuItem(
                      value: ExportFormat.db,
                      child: Text('db'.tr()),
                    ),
                    DropdownMenuItem(
                      value: ExportFormat.xls,
                      child: Text('xls'.tr()),
                    ),
                  ],
                  onChanged: (ExportFormat? value) {
                    if (value != null) {
                      settings.exportFormat = value;
                    }
                  },
                ),
                if (settings.exportFormat == ExportFormat.csv)
                  _CsvOptions(ref: ref),
                if (settings.exportFormat == ExportFormat.pdf)
                  _PdfOptions(ref: ref),
              ],
            ),
            if (showsColumns)
              SettingsPageCard(
                key: const ValueKey('export-columns'),
                sectionId: 'export-columns',
                title: 'manageExportColumns'.tr(),
                icon: Icons.view_column_outlined,
                children: [
                  ActionSettingsTile(
                    leading: const Icon(Icons.view_column_outlined),
                    title: Text('manageExportColumns'.tr()),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute<void>(
                          builder: (context) =>
                              const ExportColumnsManagementScreen(),
                        ),
                      );
                    },
                  ),
                  const ActiveColumnCustomizer(),
                ],
              ),
          ],
        );
      },
    );
  }
}

class _CsvOptions extends StatelessWidget {
  const _CsvOptions({required this.ref});

  final WidgetRef ref;

  @override
  Widget build(BuildContext context) {
    final csvExportSettings = ref.read(csvExportSettingsProvider);
    return Column(
      children: [
        InputListTile(
          label: 'fieldDelimiter'.tr(),
          value: csvExportSettings.fieldDelimiter,
          onSubmit: (value) {
            csvExportSettings.fieldDelimiter = value;
          },
        ),
        InputListTile(
          label: 'textDelimiter'.tr(),
          value: csvExportSettings.textDelimiter,
          onSubmit: (value) {
            csvExportSettings.textDelimiter = value;
          },
        ),
        SwitchSettingsTile(
          leading: const Icon(Icons.title),
          title: Text('exportCsvHeadline'.tr()),
          subtitle: Text('exportCsvHeadlineDesc'.tr()),
          value: csvExportSettings.exportHeadline,
          onChanged: (value) {
            csvExportSettings.exportHeadline = value;
          },
        ),
      ],
    );
  }
}

class _PdfOptions extends StatelessWidget {
  const _PdfOptions({required this.ref});

  final WidgetRef ref;

  @override
  Widget build(BuildContext context) {
    final pdfExportSettings = ref.read(pdfExportSettingsProvider);
    return Column(
      children: [
        SwitchSettingsTile(
          title: Text('exportPdfExportTitle'.tr()),
          value: pdfExportSettings.exportTitle,
          onChanged: (value) {
            pdfExportSettings.exportTitle = value;
          },
        ),
        SwitchSettingsTile(
          title: Text('exportPdfExportStatistics'.tr()),
          value: pdfExportSettings.exportStatistics,
          onChanged: (value) {
            pdfExportSettings.exportStatistics = value;
          },
        ),
        SwitchSettingsTile(
          title: Text('exportPdfExportData'.tr()),
          value: pdfExportSettings.exportData,
          onChanged: (value) {
            pdfExportSettings.exportData = value;
          },
        ),
        if (pdfExportSettings.exportData)
          SwitchSettingsTile(
            title: Text('exportPdfSeparateTables'.tr()),
            value: pdfExportSettings.separateWeightMedicineTables,
            onChanged: (value) {
              pdfExportSettings.separateWeightMedicineTables = value;
            },
          ),
        if (pdfExportSettings.exportData) ...[
          NumberInputListTile(
            value: pdfExportSettings.headerHeight,
            label: 'exportPdfHeaderHeight'.tr(),
            onParsableSubmit: (value) {
              pdfExportSettings.headerHeight = value;
            },
          ),
          NumberInputListTile(
            value: pdfExportSettings.cellHeight,
            label: 'exportPdfCellHeight'.tr(),
            onParsableSubmit: (value) {
              pdfExportSettings.cellHeight = value;
            },
          ),
          NumberInputListTile(
            value: pdfExportSettings.headerFontSize,
            label: 'exportPdfHeaderFontSize'.tr(),
            onParsableSubmit: (value) {
              pdfExportSettings.headerFontSize = value;
            },
          ),
          NumberInputListTile(
            value: pdfExportSettings.cellFontSize,
            label: 'exportPdfCellFontSize'.tr(),
            onParsableSubmit: (value) {
              pdfExportSettings.cellFontSize = value;
            },
          ),
        ],
      ],
    );
  }
}
