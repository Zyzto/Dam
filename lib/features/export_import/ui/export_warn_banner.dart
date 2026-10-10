import 'package:blood_pressure_app/core/repository/repo_context.dart';
import 'package:blood_pressure_app/features/export_import/model/export_preset.dart';
import 'package:blood_pressure_app/features/export_import/model/import_field_type.dart';
import 'package:blood_pressure_app/model/storage/export_csv_settings.dart';
import 'package:blood_pressure_app/model/storage/export_settings.dart';
import 'package:blood_pressure_app/model/storage/types/export_format_setting.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:safaeh/safaeh.dart';

/// Banner that gives the user information on the importability of their export.
class ExportWarnBanner extends StatefulWidget {
  /// Create either a banner that informs the user of import problems or an
  /// empty widget.
  ///
  /// Whether the config is importable is determined by the passed settings.
  const ExportWarnBanner({super.key});

  @override
  State<ExportWarnBanner> createState() => _ExportWarnBannerState();
}

class _ExportWarnBannerState extends State<ExportWarnBanner> {
  /// Whether the banner was hidden by pressing a button.
  bool _hidden = false;

  @override
  Widget build(BuildContext context) {
    final exportSettings = context.exportSettings;
    final csvExportSettings = context.csvExportSettings;
    return ListenableBuilder(
      listenable: Listenable.merge([exportSettings, csvExportSettings]),
      builder: (context, _) => _buildBanner(context, exportSettings, csvExportSettings),
    );
  }

  Widget _buildBanner(
    BuildContext context,
    ExportSettings exportSettings,
    CsvExportSettings csvExportSettings,
  ) {
    if (_hidden) return _buildOK();
    switch (exportSettings.exportFormat) {
      case ExportFormat.db:
        return _buildOK();
      case ExportFormat.pdf:
        return _buildNotImportable(context);
      case ExportFormat.csv:
        if (!csvExportSettings.exportHeadline) return _buildNoHeadline(context);
        if (![',', '|', ';'].contains(csvExportSettings.fieldDelimiter)) {
          return _buildNotImportable(context);
        }
        if (!['"', "'"].contains(csvExportSettings.textDelimiter)) {
          return _buildNotImportable(context);
        }
        final preset = exportSettings
            .getPresetById(csvExportSettings.activePreset);
        final availableColumns = context.exportColumnsManager;
        final exportedTypes = availableColumns
            .resolveColumns(preset?.columns ?? [])
            .map((c) => c.restoreAbleType)
            .nonNulls;
        final expectedTypes = availableColumns
            .resolveColumns(ExportPreset.appDefault.columns)
            .map((c) => c.restoreAbleType)
            .nonNulls
            .toSet();

        final missingTypes = [
          for (final t in expectedTypes)
            if (!exportedTypes.contains(t))
              t,
        ];
        if (missingTypes.isEmpty) {
          return _buildOK();
        } else {
          return _buildIncompleteExport(context, missingTypes);
        }
      case ExportFormat.xls:
        return _buildNotImportable(context);
    }
  }

  /// Exports made with this configuration are importable.
  Widget _buildOK() => const SizedBox.shrink();

  /// Exports made with this configuration are not importable for a variety of reasons.
  Widget _buildNotImportable(BuildContext context) =>
    _banner('exportWarnConfigNotImportable'.tr());

  /// Exports made with this configuration are not importable because there
  /// is no headline to infer types.
  Widget _buildNoHeadline(BuildContext context) =>
    _banner('errNeedHeadline'.tr());

  /// Exports made with this configuration are not fully importable.
  Widget _buildIncompleteExport(BuildContext context, Iterable<RowDataFieldType?> missingTypes) {
    final fields = missingTypes.nonNulls.map((e) => e.localize()).join(', ');
    return _banner('exportWarnNotEveryFieldExported'.tr(namedArgs: {
      'count': '${missingTypes.length}',
      'fields': fields,
    }));
  }

  Widget _banner(String text) => SafaehInlineBanner(
    message: text,
    tone: SafaehBannerTone.warning,
    icon: Icons.warning_amber_outlined,
    trailing: TextButton(
      onPressed: () => setState(() {
        _hidden = true;
      }),
      child: Text('btnConfirm'.tr()),
    ),
  );
}
