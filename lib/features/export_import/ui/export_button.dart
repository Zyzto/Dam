import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:blood_pressure_app/core/database/health_database.dart';
import 'package:blood_pressure_app/core/repository/repo_context.dart';
import 'package:blood_pressure_app/core/widgets/toast.dart';
import 'package:blood_pressure_app/features/export_import/model/csv_converter.dart';
import 'package:blood_pressure_app/features/export_import/model/excel_converter.dart';
import 'package:blood_pressure_app/features/export_import/model/export_entries.dart';
import 'package:blood_pressure_app/features/export_import/model/pdf_converter.dart';
import 'package:blood_pressure_app/features/settings/app_settings.dart';
import 'package:blood_pressure_app/logging.dart';
import 'package:blood_pressure_app/model/storage/interval_store_manager.dart';
import 'package:blood_pressure_app/model/storage/types/export_format_setting.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart';
import 'package:persistent_user_dir_access_android/persistent_user_dir_access_android.dart';
import 'package:share_plus/share_plus.dart';
import 'package:sqflite/sqflite.dart';

/// Text button to export entries like configured in the context.
class ExportButton extends StatelessWidget {
  /// Create a text button to export entries like configured in the context.
  const ExportButton({
    super.key,
    required this.share,
    this.rangeLocation = IntervalStoreManagerLocation.exportPage,
  });

  /// Whether to use the device sharing feature instead of the saving feature
  /// for export.
  final bool share;

  /// Interval used to choose exported measurements.
  final IntervalStoreManagerLocation rangeLocation;

  @override
  Widget build(BuildContext context) => TextButton.icon(
    label: Text(share ? 'btnShare'.tr() : 'export'.tr()),
    icon: Icon(share ? Icons.share : Icons.file_download_outlined),
    onPressed: () =>
        performExport(context, share, rangeLocation: rangeLocation),
  );
}

/// Perform a full export according to the configuration in [context].
Future<void> performExport(
  BuildContext context,
  bool share, {
  IntervalStoreManagerLocation rangeLocation =
      IntervalStoreManagerLocation.exportPage,
}) async {
  Log.debug('performExport - mounted=${context.mounted}');
  final exportSettings = context.exportSettings;
  Log.debug('performExport - exportSettings=${exportSettings.toJson()}');
  final filename = exportFileBaseName(
    addTimestamp: exportSettings.addTimestamp,
  );
  try {
    bool completed;
    switch (exportSettings.exportFormat) {
      case ExportFormat.db:
        try {
          await context.healthDatabase.execute('PRAGMA wal_checkpoint(FULL)');
        } catch (error, stackTrace) {
          Log.warning(
            'health.db checkpoint before export failed',
            error: error,
            stackTrace: stackTrace,
          );
        }
        final path = join(await getDatabasesPath(), HealthDatabase.fileName);
        final data = await File(path).readAsBytes();

        // https://mimetype.io/application/vnd.sqlite3
        if (!context.mounted) return;
        completed = await _exportData(
          context,
          data,
          '$filename.db',
          'application/vnd.sqlite3',
          share,
        );
      case ExportFormat.csv:
        final csvConverter = CsvConverter(
          context.csvExportSettings,
          context.exportColumnsManager,
          context.medCache.medications,
          exportSettings,
        );
        final csvString = csvConverter.create(
          await loadExportEntries(context, rangeLocation: rangeLocation),
        );
        final data = Uint8List.fromList(utf8.encode(csvString));
        if (!context.mounted) return;
        // https://www.rfc-editor.org/rfc/rfc7111
        completed = await _exportData(
          context,
          data,
          '$filename.csv',
          'text/csv',
          share,
        );
      case ExportFormat.pdf:
        final pdfConverter = PdfConverter(
          context.pdfExportSettings,
          context.readAppSettings(),
          context.exportColumnsManager,
          exportSettings,
          locale: context.locale.toLanguageTag(),
        );
        final pdf = await pdfConverter.create(
          await loadExportEntries(context, rangeLocation: rangeLocation),
        );
        if (!context.mounted) return;
        // https://www.rfc-editor.org/rfc/rfc3778
        completed = await _exportData(
          context,
          pdf,
          '$filename.pdf',
          'application/pdf',
          share,
        );
      case ExportFormat.xls:
        final xlsConverter = ExcelConverter(
          context.excelExportSettings,
          context.exportColumnsManager,
          context.medCache.medications,
          exportSettings,
        );
        final string = xlsConverter.create(
          await loadExportEntries(context, rangeLocation: rangeLocation),
        );
        final data = Uint8List.fromList(utf8.encode(string));
        if (!context.mounted) return;
        completed = await _exportData(
          context,
          data,
          '$filename.xls',
          'application/vnd.ms-excel',
          share,
        );
    }

    if (completed && context.mounted) {
      context.showSuccess('exportSuccess'.tr());
    }
  } catch (error, stackTrace) {
    Log.severe('Export failed', error: error, stackTrace: stackTrace);
    if (context.mounted) {
      context.showError('error'.tr(namedArgs: {'msg': error.toString()}));
    }
  }
}

/// Portable base filename for every exported format.
String exportFileBaseName({required bool addTimestamp, DateTime? now}) {
  if (!addTimestamp) return 'blood_press';
  final time = now ?? DateTime.now();
  String digits(int value, int width) => value.toString().padLeft(width, '0');
  final timestamp =
      '${digits(time.year, 4)}-${digits(time.month, 2)}-'
      '${digits(time.day, 2)}_${digits(time.hour, 2)}-'
      '${digits(time.minute, 2)}-${digits(time.second, 2)}-'
      '${digits(time.millisecond, 3)}${digits(time.microsecond, 3)}';
  return 'blood_press_$timestamp';
}

/// Save to default export path or share by providing binary data.
Future<bool> _exportData(
  BuildContext context,
  Uint8List data,
  String fullFileName,
  String mimeType,
  bool share,
) async {
  if (share) {
    Log.debug('_exportData - Saving file using SharePlus');
    final result = await SharePlus.instance.share(
      ShareParams(
        title: 'bloodPressure'.tr(),
        files: [XFile.fromData(data, name: fullFileName, mimeType: mimeType)],
      ),
    );
    Log.info('_exportData - Shared data with result: $result');
    return result.status != ShareResultStatus.dismissed;
  }

  final settings = context.exportSettings;
  if (settings.defaultExportDir.isEmpty || !Platform.isAndroid) {
    Log.debug('_exportData - Saving file using FilePicker');
    final path = await FilePicker.saveFile(
      type: FileType.any, // mimeType
      fileName: fullFileName,
      bytes: data,
    );
    return path != null;
  } else {
    Log.debug('_exportData - Saving file using PersistentUserDirAccessAndroid');
    return const PersistentUserDirAccessAndroid().writeFile(
      settings.defaultExportDir,
      fullFileName,
      mimeType,
      data,
      true,
    );
  }
}
