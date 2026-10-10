import 'package:blood_pressure_app/components/input_dialog.dart';
import 'package:blood_pressure_app/core/repository/repo_context.dart';
import 'package:blood_pressure_app/core/widgets/toast.dart';
import 'package:blood_pressure_app/features/export_import/model/export_active_preset.dart';
import 'package:blood_pressure_app/features/export_import/model/export_preset.dart';
import 'package:blood_pressure_app/features/export_import/ui/columns_config/active_preset_builder.dart';
import 'package:blood_pressure_app/features/export_import/ui/columns_config/preset_editor.dart';
import 'package:blood_pressure_app/features/export_import/ui/columns_config/preset_selector.dart';
import 'package:blood_pressure_app/model/storage/storage.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

/// Class orchestrates preset selector, preset editor and save/delete buttons
class ActiveColumnCustomizer extends StatelessWidget {
  const ActiveColumnCustomizer({super.key});

  @override
  Widget build(BuildContext context) {
    final exportSettings = context.exportSettings;
    return ListenableBuilder(
      listenable: Listenable.merge([
        exportSettings,
        context.csvExportSettings,
        context.pdfExportSettings,
        context.excelExportSettings,
      ]),
      builder: (context, _) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          PresetSelector(),
          ActivePresetBuilder(
            builder: (context, preset) {
              if (preset is! CustomPreset) return const SizedBox.shrink();
              return SizedBox(
                height: 400.0,
                child: Stack(
                  children: [
                    PresetEditor(editor: preset),
                    Align(
                      alignment: AlignmentDirectional.bottomEnd,
                      child: _PresetEditButtons(preset: preset),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _PresetEditButtons extends StatelessWidget {
  const _PresetEditButtons({required this.preset});

  final CustomPreset preset;

  /// Whether there is already a saved version of this
  bool get isStored => preset.baseId != null;

  Future<String?> _chooseId(BuildContext context, ExportSettings exportSettings) async {
    final blockedIds = exportSettings.allPresets.map((p) => p.id);
    String? id;
    id = await showInputDialog(context);
    while (id != null && (blockedIds.contains(id) || id.isEmpty)) {
      if (!context.mounted) break;
      context.showError('titleAlreadyExists'.tr());
      id = await showInputDialog(context);
      if (context.mounted) context.dismissAllToasts();
    }
    return id;
  }

  /// Updates or creates preset from columns
  Future<void> _save(BuildContext context) async {
    final exportSettings = context.exportSettings;
    final id = preset.baseId ?? await _chooseId(context, exportSettings);
    if (id == null || !context.mounted) return;

    final presets = exportSettings.presets;
    presets.removeWhere((p) => p.id == id);
    presets.add(ExportPreset(id, preset.columns, true));
    exportSettings.presets = presets;
    if (preset.baseId == null) {
      exportSettings.customPresetColumns = [];
      writeActivePresetId(context, id);
    }
  }

  /// Removes this column from stored presets but keeps columns.
  void _unsave(BuildContext context) {
    if (!isStored) return;
    final exportSettings = context.exportSettings;

    final oldPresets = exportSettings.presets;
    oldPresets.removeWhere((p) => p.id == preset.baseId);
    if (exportSettings.customPresetColumns.isEmpty) {
      exportSettings.customPresetColumns = preset.columns;
    }
    exportSettings.presets = oldPresets;

    if (context.csvExportSettings.activePreset == preset.baseId) {
      context.csvExportSettings.activePreset = CustomPreset([]).id;
    }
    if (context.pdfExportSettings.activePreset == preset.baseId) {
      context.pdfExportSettings.activePreset = CustomPreset([]).id;
    }
    if (context.excelExportSettings.activePreset == preset.baseId) {
      context.excelExportSettings.activePreset = CustomPreset([]).id;
    }
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsetsDirectional.only(end: 8.0),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        if (isStored)
          IconButton.filledTonal(
            icon: Icon(Icons.delete_forever_outlined),
            tooltip: 'delete'.tr(),
            onPressed: () => _unsave(context),
          ),
        if (isStored)
          SizedBox(width: 4.0),
        IconButton.filled(
          icon: Icon(Icons.save),
          tooltip: 'btnSave'.tr(),
          onPressed: () => _save(context),
        ),
      ],
    ),
  );
}
