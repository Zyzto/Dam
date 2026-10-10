import 'package:blood_pressure_app/components/color_picker.dart';
import 'package:blood_pressure_app/components/input_dialog.dart';
import 'package:blood_pressure_app/features/settings/app_settings.dart';
import 'package:blood_pressure_app/features/settings/registry.dart';
import 'package:blood_pressure_app/features/settings/settings_subpage.dart';
import 'package:blood_pressure_app/model/horizontal_graph_line.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_settings_framework/flutter_settings_framework.dart';

class GraphMarkingsScreen extends ConsumerWidget {
  const GraphMarkingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(appSettingsProvider);
    final lines = settings.horizontalGraphLines.toList();
    return SettingsSubpage(
      title: Text('customGraphMarkings'.tr()),
      children: [
        SettingsPageCard(
          sectionId: 'graph-markings',
          title: 'horizontalLines'.tr(),
          icon: Icons.legend_toggle_outlined,
          children: [
            for (var i = 0; i < lines.length; i++)
              ListTile(
                leading: Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color: lines[i].color,
                    shape: BoxShape.circle,
                  ),
                ),
                title: Text(lines[i].height.toString()),
                trailing: IconButton(
                  icon: const Icon(Icons.delete_outline),
                  onPressed: () async {
                    final next = [...lines]..removeAt(i);
                    await ref.writeHorizontalGraphLines(next);
                  },
                ),
              ),
            ActionSettingsTile(
              leading: const Icon(Icons.add),
              title: Text('addLine'.tr()),
              onTap: () => _addLine(context, ref, lines),
            ),
          ],
        ),
      ],
    );
  }

  Future<void> _addLine(
    BuildContext context,
    WidgetRef ref,
    List<HorizontalGraphLine> lines,
  ) async {
    final color = await showConcreteColorPickerSheet(
      context,
      availableColors: [for (final value in appColorOptions) Color(value)],
    );
    if (!context.mounted) return;
    final height = await showNumberInputDialog(
      context,
      hintText: 'linePositionY'.tr(),
    );
    if (color == null || height == null) return;
    await ref.writeHorizontalGraphLines([
      ...lines,
      HorizontalGraphLine(color, height.round()),
    ]);
  }
}
