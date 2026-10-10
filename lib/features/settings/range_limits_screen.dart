import 'package:blood_pressure_app/components/input_dialog.dart';
import 'package:blood_pressure_app/core/widgets/toast.dart';
import 'package:blood_pressure_app/domain/domain.dart';
import 'package:blood_pressure_app/features/measurement_list/metric_info.dart';
import 'package:blood_pressure_app/features/settings/app_settings.dart';
import 'package:blood_pressure_app/features/settings/registry.dart';
import 'package:blood_pressure_app/model/blood_pressure/pressure_unit.dart';
import 'package:blood_pressure_app/model/range_limits.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_settings_framework/flutter_settings_framework.dart';

/// Edit BMI and blood-pressure category cutoffs.
class RangeLimitsScreen extends ConsumerWidget {
  /// Create the range-limits editor.
  const RangeLimitsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(appSettingsProvider);
    final limits = settings.rangeLimits;
    final unit = settings.preferredPressureUnit;
    final theme = Theme.of(context);
    final hintStyle = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    final weightPreview = _weightPreview(settings);
    return Scaffold(
      appBar: AppBar(title: Text('rangeLimits'.tr())),
      body: ListView(
        children: [
          _SectionTitle('bmi'.tr()),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Text('rangeLimitsBmiHint'.tr(), style: hintStyle),
          ),
          _LimitTile(
            label: 'rangeLimitNormalFrom'.tr(),
            value: limits.bmiNormalMin,
            onSubmit: (value) => _editBmi(context, ref, limits, normal: value),
          ),
          _LimitTile(
            label: 'rangeLimitOverweightFrom'.tr(),
            value: limits.bmiOverweightMin,
            onSubmit: (value) =>
                _editBmi(context, ref, limits, overweight: value),
          ),
          _LimitTile(
            label: 'rangeLimitObesityFrom'.tr(),
            value: limits.bmiObeseMin,
            onSubmit: (value) => _editBmi(context, ref, limits, obese: value),
          ),
          if (weightPreview != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
              child: Text(weightPreview, style: hintStyle),
            ),
          _SectionTitle(
            'rangeLimitsBpSection'.tr(namedArgs: {'unit': unit.name}),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Text('rangeLimitsBpHint'.tr(), style: hintStyle),
          ),
          _LimitTile(
            label: 'rangeLimitSysElevated'.tr(),
            value: _shownPressure(limits.sysElevatedMmHg, unit),
            onSubmit: (value) =>
                _editSys(context, ref, limits, unit, elevated: value),
          ),
          _LimitTile(
            label: 'rangeLimitSysHigh'.tr(),
            value: _shownPressure(limits.sysHighMmHg, unit),
            onSubmit: (value) =>
                _editSys(context, ref, limits, unit, high: value),
          ),
          _LimitTile(
            label: 'rangeLimitDiaHigh'.tr(),
            value: _shownPressure(limits.diaHighMmHg, unit),
            onSubmit: (value) => _editDia(context, ref, limits, unit, value),
          ),
          const SizedBox(height: 8),
          ListTile(
            leading: const Icon(Icons.restart_alt),
            title: Text('rangeLimitsReset'.tr()),
            onTap: () => _reset(ref),
          ),
        ],
      ),
    );
  }

  String? _weightPreview(AppSettings settings) {
    final height = settings.bodyHeightCm;
    if (height == null || height <= 0) return null;
    final info = MetricInfo.resolve(
      kind: MetricKind.weight,
      current: 0,
      formattedValue: '',
      heightCm: height,
      weightUnit: settings.weightUnit,
      limits: settings.rangeLimits,
    );
    if (info.bands.isEmpty) return null;
    return info.bands
        .map((band) => '${band.label}: ${band.interval}')
        .join('\n');
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
    child: Text(text, style: Theme.of(context).textTheme.titleMedium),
  );
}

class _LimitTile extends StatelessWidget {
  const _LimitTile({
    required this.label,
    required this.value,
    required this.onSubmit,
  });

  final String label;
  final num value;
  final ValueChanged<double> onSubmit;

  @override
  Widget build(BuildContext context) => ListTile(
    title: Text(label),
    subtitle: Text(_shown(value)),
    trailing: const Icon(Icons.edit),
    onTap: () async {
      final result = await showNumberInputDialog(
        context,
        initialValue: _editorValue(value),
        hintText: label,
      );
      if (result != null) onSubmit(result);
    },
  );
}

Future<void> _editBmi(
  BuildContext context,
  WidgetRef ref,
  RangeLimits current, {
  double? normal,
  double? overweight,
  double? obese,
}) async {
  final next = current.copyWith(
    bmiNormalMin: normal,
    bmiOverweightMin: overweight,
    bmiObeseMin: obese,
  );
  if (!next.bmiOrdered) {
    if (context.mounted) context.showError('rangeLimitsInvalid'.tr());
    return;
  }
  if (normal != null) await ref.updateSetting(bmiNormalMinSetting, normal);
  if (overweight != null) {
    await ref.updateSetting(bmiOverweightMinSetting, overweight);
  }
  if (obese != null) await ref.updateSetting(bmiObeseMinSetting, obese);
}

Future<void> _editSys(
  BuildContext context,
  WidgetRef ref,
  RangeLimits current,
  PressureUnit unit, {
  double? elevated,
  double? high,
}) async {
  final next = current.copyWith(
    sysElevatedMmHg: elevated == null ? null : unit.wrap(elevated).mmHg,
    sysHighMmHg: high == null ? null : unit.wrap(high).mmHg,
  );
  if (!next.sysOrdered) {
    if (context.mounted) context.showError('rangeLimitsInvalid'.tr());
    return;
  }
  if (elevated != null) {
    await ref.updateSetting(sysElevatedMmHgSetting, next.sysElevatedMmHg);
  }
  if (high != null) {
    await ref.updateSetting(sysHighMmHgSetting, next.sysHighMmHg);
  }
}

Future<void> _editDia(
  BuildContext context,
  WidgetRef ref,
  RangeLimits current,
  PressureUnit unit,
  double value,
) async {
  final next = current.copyWith(diaHighMmHg: unit.wrap(value).mmHg);
  if (!next.diaOrdered) {
    if (context.mounted) context.showError('rangeLimitsInvalid'.tr());
    return;
  }
  await ref.updateSetting(diaHighMmHgSetting, next.diaHighMmHg);
}

Future<void> _reset(WidgetRef ref) async {
  await ref.updateSetting(bmiNormalMinSetting, RangeLimits.defaultBmiNormalMin);
  await ref.updateSetting(
    bmiOverweightMinSetting,
    RangeLimits.defaultBmiOverweightMin,
  );
  await ref.updateSetting(bmiObeseMinSetting, RangeLimits.defaultBmiObeseMin);
  await ref.updateSetting(
    sysElevatedMmHgSetting,
    RangeLimits.defaultSysElevatedMmHg,
  );
  await ref.updateSetting(sysHighMmHgSetting, RangeLimits.defaultSysHighMmHg);
  await ref.updateSetting(diaHighMmHgSetting, RangeLimits.defaultDiaHighMmHg);
}

num _shownPressure(int mmHg, PressureUnit unit) {
  if (unit == PressureUnit.mmHg) return mmHg;
  return double.parse(Pressure.mmHg(mmHg).kPa.toStringAsFixed(1));
}

num _editorValue(num value) =>
    value == value.roundToDouble() ? value.round() : value;

String _shown(num value) {
  if (value == value.roundToDouble()) return value.round().toString();
  return value.toStringAsFixed(1);
}
