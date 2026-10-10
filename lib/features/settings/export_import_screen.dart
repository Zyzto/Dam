import 'dart:io';

import 'package:blood_pressure_app/core/settings/storage_providers.dart';
import 'package:blood_pressure_app/features/data_picker/interval_picker.dart';
import 'package:blood_pressure_app/features/export_import/ui/columns_config/active_column_customizer.dart';
import 'package:blood_pressure_app/features/export_import/ui/export_button.dart';
import 'package:blood_pressure_app/features/export_import/ui/export_column_management_screen.dart';
import 'package:blood_pressure_app/features/export_import/ui/export_field_format_documentation_screen.dart';
import 'package:blood_pressure_app/features/export_import/ui/export_warn_banner.dart';
import 'package:blood_pressure_app/features/export_import/ui/import_button.dart';
import 'package:blood_pressure_app/features/settings/tiles/dropdown_list_tile.dart';
import 'package:blood_pressure_app/features/settings/tiles/input_list_tile.dart';
import 'package:blood_pressure_app/features/settings/tiles/number_input_list_tile.dart';
import 'package:blood_pressure_app/model/storage/storage.dart';
import 'package:blood_pressure_app/model/storage/types/export_format_setting.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:persistent_user_dir_access_android/persistent_user_dir_access_android.dart';
import 'package:safaeh/safaeh.dart';

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
      builder: (context, _) => Scaffold(
      appBar: AppBar(
        title: Text('exportImport'.tr()),
        actions: [
          IconButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute<void>(
                  builder: (context) => InformationScreen(
                      text: 'exportImportDocumentation'.tr()),
                ),
              );
            },
            tooltip: 'exportImportDocumentationTooltip'.tr(),
            icon: Icon(
              Icons.info_outline,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
        ],
        backgroundColor: Theme.of(context).primaryColor,
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            ExportWarnBanner(),
            const SizedBox(
              height: 15,
            ),
            if (settings.exportFormat != ExportFormat.db)
              const IntervalPicker(type: IntervalStoreManagerLocation.exportPage),
            if (Platform.isAndroid) // only supported on android
              ListTile(
                title: Text('exportDir'.tr()),
                subtitle: settings.defaultExportDir.isNotEmpty ? Text(settings.defaultExportDir) : null,
                trailing: settings.defaultExportDir.isEmpty ? const Icon(Icons.folder_open) : const Icon(Icons.delete),
                onTap: () async {
                  if (settings.defaultExportDir.isEmpty) {
                    final uri = await const PersistentUserDirAccessAndroid().requestDirectoryUri();
                    settings.defaultExportDir = uri ?? '';
                  } else {
                    settings.defaultExportDir = '';
                  }
                },
              ),
            if (Platform.isAndroid) // only makes sense with exportDir, which is supported only for android
              SwitchListTile(
                title: Text('exportAddTimestamp'.tr()),
                subtitle: Text('exportAddTimestampDesc'.tr()),
                value: settings.addTimestamp,
                onChanged: (value) {
                  settings.addTimestamp = value;
                },
              ),
            SwitchListTile(
              title: Text('exportAfterEveryInput'.tr()),
              subtitle: Text('exportAfterEveryInputDesc'.tr()),
              value: settings.exportAfterEveryEntry,
              onChanged: (value) {
                settings.exportAfterEveryEntry = value;
              },
            ),
            DropDownListTile<ExportFormat>(
              key: const Key('exportFormat'),
              title: Text('exportFormat'.tr()),
              value: settings.exportFormat,
              items: [
                DropdownMenuItem(
                    value: ExportFormat.csv, child: Text('csv'.tr())),
                DropdownMenuItem(
                    value: ExportFormat.pdf, child: Text('pdf'.tr())),
                DropdownMenuItem(
                    value: ExportFormat.db, child: Text('db'.tr())),
                DropdownMenuItem(
                  value: ExportFormat.xls, child: Text('xls'.tr())),
              ],
              onChanged: (ExportFormat? value) {
                if (value != null) {
                  settings.exportFormat = value;
                }
              },
            ),
            if (settings.exportFormat == ExportFormat.csv)
              Builder(builder: (context) {
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
                    SwitchListTile(
                      title: Text('exportCsvHeadline'.tr()),
                      subtitle: Text('exportCsvHeadlineDesc'.tr()),
                      value: csvExportSettings.exportHeadline,
                      onChanged: (value) {
                        csvExportSettings.exportHeadline = value;
                      },
                    ),
                  ],
                );
              }),
            if (settings.exportFormat == ExportFormat.pdf)
              Builder(builder: (context) {
                final pdfExportSettings = ref.read(pdfExportSettingsProvider);
                return Column(
                  children: [
                    SwitchListTile(
                        title: Text('exportPdfExportTitle'.tr()),
                        value: pdfExportSettings.exportTitle,
                        onChanged: (value) {
                          pdfExportSettings.exportTitle = value;
                        },),
                    SwitchListTile(
                        title: Text('exportPdfExportStatistics'.tr()),
                        value: pdfExportSettings.exportStatistics,
                        onChanged: (value) {
                          pdfExportSettings.exportStatistics = value;
                        },),
                    SwitchListTile(
                        title: Text('exportPdfExportData'.tr()),
                        value: pdfExportSettings.exportData,
                        onChanged: (value) {
                          pdfExportSettings.exportData = value;
                        },),
                    if (pdfExportSettings.exportData)
                      SwitchListTile(
                        title: Text('exportPdfSeparateTables'.tr()),
                        value: pdfExportSettings.separateWeightMedicineTables,
                        onChanged: (value) {
                          pdfExportSettings.separateWeightMedicineTables = value;
                        },
                      ),
                    if (pdfExportSettings.exportData)
                      Column(
                        children: [
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
                      ),
                  ],
                );
              }),
            if (settings.exportFormat == ExportFormat.csv
                || settings.exportFormat == ExportFormat.pdf
                || settings.exportFormat == ExportFormat.xls) ...[
              ListTile(
                title: Text('manageExportColumns'.tr()),
                trailing: Icon(safaehChevronEnd(context)),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute<void>(builder: (context) => const ExportColumnsManagementScreen()));
                },
              ),
              ActiveColumnCustomizer(),
            ],
          ],
        ),
      ),
      persistentFooterButtons: const [
        ExportButton(share: true),
        ExportButton(share: false),
        ImportButton(),
      ],
    ),
    );
  }
}
