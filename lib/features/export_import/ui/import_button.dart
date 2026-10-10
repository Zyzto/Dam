import 'dart:convert';

import 'package:blood_pressure_app/core/database/db_import.dart';
import 'package:blood_pressure_app/core/repository/repo_context.dart';
import 'package:blood_pressure_app/core/widgets/toast.dart';
import 'package:blood_pressure_app/features/export_import/model/csv_converter.dart';
import 'package:blood_pressure_app/features/export_import/model/csv_record_parsing_actor.dart';
import 'package:blood_pressure_app/features/export_import/ui/import_preview_dialog.dart';
import 'package:blood_pressure_app/features/settings/app_settings.dart';
import 'package:blood_pressure_app/model/combined_entry.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

/// Text button to import entries like configured in the context.
class ImportButton extends StatelessWidget {
  /// Create text button to import entries like configured in the context.
  const ImportButton({super.key});

  @override
  Widget build(BuildContext context) => TextButton.icon(
    label: Text('import'.tr()),
    icon: Icon(Icons.file_upload_outlined),
    onPressed: () async {
      final exportSettings = context.exportSettings;

      final file = await FilePicker.pickFile();
      if (!context.mounted) return;
      if (file == null) {
        context.showError('errNoFileOpened'.tr());
        return;
      }
      if (!context.mounted) return;
      final name = file.name;
      final dot = name.lastIndexOf('.');
      final extension = dot >= 0 ? name.substring(dot + 1).toLowerCase() : '';
      switch(extension) {
        case 'csv':
          final binaryContent = await file.readAsBytes();
          if (!context.mounted) return;
          final csvSettings = context.csvExportSettings;
          final exportColumnsManager = context.exportColumnsManager;
          final converter = CsvConverter(
            csvSettings,
            exportColumnsManager,
            context.medCache.medications,
            exportSettings,
          );
          if (!context.mounted) return;
          final importedRecords = await showImportPreview(
            context,
            CsvRecordParsingActor(
              converter,
              utf8.decode(binaryContent),
            ),
            exportColumnsManager,
            context.readAppSettings().bottomAppBars,
          );
          if (importedRecords == null || !context.mounted) return;
          final bpRepo = context.bpRepo;
          final noteRepo = context.noteRepo;
          final intakeRepo = context.intakeRepo;
          final weightRepo = context.weightRepo;
          await Future.forEach<CombinedEntry>(importedRecords, (e) async {
            if (e.sys != null || e.dia != null || e.pul != null) {
              await bpRepo.add(e.record!);
            }
            if (e.note != null) await noteRepo.add(e.note!);
            if (e.weight != null) await weightRepo.add(e.weight!);
            if (e.intake != null) await intakeRepo.add(e.intake!);
          });
          if (!context.mounted) return;
          context.showSuccess('importSuccess'.tr(namedArgs: {'count': '${importedRecords.length}'}));
          break;
        case 'db':
          if (file.path == null) return;
          var count = 0;
          try {
            count = await importMeasurementDatabase(
              path: file.path!,
              bpRepo: context.bpRepo,
              noteRepo: context.noteRepo,
              intakeRepo: context.intakeRepo,
              medRepo: context.medRepo,
              weightRepo: context.weightRepo,
            );
          } catch (e) {
            // DB doesn't conform
          }
          if (!context.mounted) return;
          context.showSuccess('importSuccess'.tr(namedArgs: {'count': '$count'}));
          break;
        default:
          context.showError('errWrongImportFormat'.tr());
      }
    },
  );
}
