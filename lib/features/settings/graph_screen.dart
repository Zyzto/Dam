import 'package:blood_pressure_app/features/settings/app_settings.dart';
import 'package:blood_pressure_app/features/settings/configure_warn_values_screen.dart';
import 'package:blood_pressure_app/features/settings/graph_markings_screen.dart';
import 'package:blood_pressure_app/features/settings/registry.dart';
import 'package:blood_pressure_app/features/settings/settings_subpage.dart';
import 'package:blood_pressure_app/features/settings/tiles/color_picker_list_tile.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_settings_framework/flutter_settings_framework.dart';
import 'package:safaeh/safaeh.dart';

class GraphScreen extends ConsumerWidget {
  const GraphScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(appSettingsProvider);
    if (!settings.bloodPressureEnabled) {
      return Scaffold(
        appBar: AppBar(title: Text('graphSettings'.tr())),
        body: SafaehStatusBody(
          icon: Icons.show_chart_outlined,
          message: Text('bloodPressureDisabledHint'.tr()),
        ),
      );
    }
    final colorOptions = [for (final color in appColorOptions) Color(color)];
    return SettingsSubpage(
      title: Text('graphSettings'.tr()),
      children: [
        SettingsPageCard(
          key: const ValueKey('graph-display'),
          sectionId: 'graph-display',
          title: 'bloodPressure'.tr(),
          icon: Icons.show_chart_outlined,
          children: [
            ActionSettingsTile(
              leading: const Icon(Icons.legend_toggle_outlined),
              title: Text('customGraphMarkings'.tr()),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute<void>(
                    builder: (context) => const GraphMarkingsScreen(),
                  ),
                );
              },
            ),
            SwitchSettingsTile(
              leading: const Icon(Icons.trending_down_outlined),
              title: Text('drawRegressionLines'.tr()),
              subtitle: Text('drawRegressionLinesDesc'.tr()),
              value: settings.drawRegressionLines,
              onChanged: (value) {
                ref.updateSetting(drawRegressionLinesSetting, value);
              },
            ),
            ActionSettingsTile(
              leading: const Icon(Icons.warning_amber_outlined),
              title: Text('determineWarnValues'.tr()),
              subtitle: Text('aboutWarnValuesScreenDesc'.tr()),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute<void>(
                    builder: (context) => const ConfigureWarnValuesScreen(),
                  ),
                );
              },
            ),
            _GraphSlider(
              title: 'maxDataInterval'.tr(),
              subtitle: 'maxDataIntervalDesc'.tr(),
              icon: Icons.auto_graph_outlined,
              value: settings.interruptGraphAfterNDays.toDouble(),
              min: 0,
              max: 30,
              onChanged: (value) {
                ref.updateSetting(interruptGraphAfterNDaysSetting, value.toInt());
              },
            ),
          ],
        ),
        SettingsPageCard(
          key: const ValueKey('graph-appearance'),
          sectionId: 'graph-appearance',
          title: 'appearance'.tr(),
          icon: Icons.palette_outlined,
          children: [
            ColorSelectionListTile(
              title: Text('sysColor'.tr()),
              initialColor: settings.sysColor,
              availableColors: colorOptions,
              showTransparentColor: false,
              swatchAtEnd: true,
              onMainColorChanged: (color) =>
                  ref.updateSetting(sysColorSetting, color.toARGB32()),
            ),
            ColorSelectionListTile(
              title: Text('diaColor'.tr()),
              initialColor: settings.diaColor,
              availableColors: colorOptions,
              showTransparentColor: false,
              swatchAtEnd: true,
              onMainColorChanged: (color) =>
                  ref.updateSetting(diaColorSetting, color.toARGB32()),
            ),
            ColorSelectionListTile(
              title: Text('pulColor'.tr()),
              initialColor: settings.pulColor,
              availableColors: colorOptions,
              showTransparentColor: false,
              swatchAtEnd: true,
              onMainColorChanged: (color) =>
                  ref.updateSetting(pulColorSetting, color.toARGB32()),
            ),
            _GraphSlider(
              title: 'graphLineThickness'.tr(),
              icon: Icons.line_weight,
              value: settings.graphLineThickness,
              min: 1,
              max: 5,
              onChanged: (value) {
                ref.updateSetting(graphLineThicknessSetting, value);
              },
            ),
            _GraphSlider(
              title: 'needlePinBarWidth'.tr(),
              subtitle: 'needlePinBarWidthDesc'.tr(),
              icon: Icons.line_weight,
              value: settings.needlePinBarWidth,
              min: 1,
              max: 20,
              onChanged: (value) {
                ref.updateSetting(needlePinBarWidthSetting, value);
              },
            ),
          ],
        ),
      ],
    );
  }
}

class _GraphSlider extends StatelessWidget {
  const _GraphSlider({
    required this.title,
    required this.icon,
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
    this.subtitle,
  });

  final String title;
  final String? subtitle;
  final IconData icon;
  final double value;
  final double min;
  final double max;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SliderSettingsTile(
      leading: Icon(icon),
      dialogTitle: title,
      title: subtitle == null
          ? Text(title)
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title),
                Text(
                  subtitle!,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
      value: value.clamp(min, max),
      min: min,
      max: max,
      divisions: (max - min).round(),
      valueFormatter: (v) => v.round().toString(),
      onChanged: onChanged,
    );
  }
}
