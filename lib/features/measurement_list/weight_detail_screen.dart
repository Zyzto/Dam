import 'package:blood_pressure_app/components/animated_floating_action_button.dart';
import 'package:blood_pressure_app/components/confirm_deletion_dialog.dart';
import 'package:blood_pressure_app/components/snack_bar_stable_fab_location.dart';
import 'package:blood_pressure_app/core/repository/repo_context.dart';
import 'package:blood_pressure_app/core/widgets/toast.dart';
import 'package:blood_pressure_app/data_util/entry_context.dart';
import 'package:blood_pressure_app/domain/domain.dart';
import 'package:blood_pressure_app/features/bluetooth/logic/ble_measurement_duplicates.dart';
import 'package:blood_pressure_app/features/bluetooth/logic/eufy_body_composition.dart';
import 'package:blood_pressure_app/features/input/forms/entry_form_section.dart';
import 'package:blood_pressure_app/features/measurement_list/detail_form_value.dart';
import 'package:blood_pressure_app/features/measurement_list/metric_change.dart';
import 'package:blood_pressure_app/features/measurement_list/metric_info.dart';
import 'package:blood_pressure_app/features/measurement_list/metric_info_dialog.dart';
import 'package:blood_pressure_app/features/measurement_list/previous_measurement.dart';
import 'package:blood_pressure_app/features/settings/app_settings.dart';
import 'package:blood_pressure_app/features/settings/body_profile_screen.dart';
import 'package:blood_pressure_app/l10n/western_digits.dart';
import 'package:blood_pressure_app/model/combined_entry.dart';
import 'package:blood_pressure_app/theme/app_text.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:health/health.dart';
import 'package:safaeh/safaeh.dart';

/// Full weigh-in with comparison to the previous measurement.
class WeightDetailScreen extends ConsumerStatefulWidget {
  /// Show [record], optionally compared to [previous].
  const WeightDetailScreen({super.key, required this.record, this.previous});

  /// Weigh-in to display.
  final BodyweightRecord record;

  /// Next older weigh-in from the visible list, when known.
  final BodyweightRecord? previous;

  @override
  ConsumerState<WeightDetailScreen> createState() => _WeightDetailScreenState();
}

class _WeightDetailScreenState extends ConsumerState<WeightDetailScreen> {
  late BodyweightRecord _record;
  BodyweightRecord? _previous;
  var _editing = false;
  var _hopTick = 0;
  var _olderLoad = 0;
  final _hops = <String>{};

  @override
  void initState() {
    super.initState();
    // Route rebuilds still pass the original [widget.record]; keep [_record].
    _record = widget.record;
    _previous = widget.previous;
    if (_previous == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _loadOlder());
    }
  }

  Future<void> _loadOlder() async {
    final load = ++_olderLoad;
    final time = _record.time;
    BodyweightRepository repo;
    try {
      repo = context.weightRepo;
    } on StateError {
      return;
    }
    final older = await loadOlderWeight(repo, time);
    if (!mounted || load != _olderLoad) return;
    setState(() => _previous = older);
  }

  Future<void> _edit() async {
    if (_editing) return;
    final before = _record;
    setState(() => _editing = true);
    try {
      final saved = await context.createEntry(
        CombinedEntry(time: before.time, weight: before),
      );
      if (!mounted) return;
      final next = saved?.map((e) => e.weight).nonNulls.firstOrNull;
      if (next == null) return;
      final hops = _weightEditHops(before, next, ref.read(appSettingsProvider));
      setState(() {
        _record = next;
        if (hops.isEmpty) {
          _hops.clear();
          return;
        }
        _hopTick += 1;
        _hops
          ..clear()
          ..addAll(hops);
        _scheduleHopClear(_hopTick);
      });
      if (next.time != before.time) await _loadOlder();
    } finally {
      if (mounted) setState(() => _editing = false);
    }
  }

  void _scheduleHopClear(int tick) {
    Future<void>.delayed(const Duration(milliseconds: 700), () {
      if (!mounted || _hopTick != tick) return;
      setState(_hops.clear);
    });
  }

  Future<void> _delete() async {
    final settings = ref.read(appSettingsProvider);
    final weightRepo = context.weightRepo;
    var choice = DeleteChoice.delete;
    if (settings.confirmDeletion) {
      choice = await showConfirmDeletionChoice(
        context,
        allowBlacklist: true,
      );
      if (!mounted || choice == DeleteChoice.cancel) return;
    }
    final blacklistRepo = context.blacklistRepo;
    await weightRepo.remove(_record);
    String? blockedKey;
    if (choice == DeleteChoice.deleteAndBlacklist) {
      blockedKey = bodyweightRecordKey(_record);
      await blacklistRepo.add('weight', blockedKey);
    }
    if (settings.useHealthConnect && settings.syncWeightMeasurements) {
      await Health().delete(
        type: HealthDataType.WEIGHT,
        startTime: _record.time.subtract(const Duration(milliseconds: 500)),
        endTime: _record.time.add(const Duration(milliseconds: 500)),
      );
    }
    if (!mounted) return;
    context.dismissAllToasts();
    context.showToastWithAction(
      'deletionConfirmed'.tr(),
      actionLabel: 'btnUndo'.tr(),
      onAction: () async {
        await weightRepo.add(_record);
        if (blockedKey != null) {
          await blacklistRepo.remove('weight', blockedKey);
        }
      },
    );
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(appSettingsProvider);
    final unit = settings.weightUnit;
    final locale = context.locale.toString();
    final date = formatAppDate(_record.time, 'yyyy-MM-dd', locale);
    final timeOfDay = formatAppDate(_record.time, 'HH:mm', locale);
    final composition = EufyBodyComposition.fromRecord(_record, settings);
    final previousComposition = _previous == null
        ? null
        : EufyBodyComposition.fromRecord(_previous!, settings);
    final heightCm = settings.bodyHeightCm;
    final bmi = _bmi(_record.weight.kg, heightCm);
    final previousBmi = _previous == null
        ? null
        : _bmi(_previous!.weight.kg, heightCm);
    final accent = Theme.of(context).colorScheme.primary;
    return Scaffold(
      appBar: AppBar(
        title: Text('weight'.tr()),
        actions: [
          IconButton(
            icon: Icon(Icons.delete, semanticLabel: 'delete'.tr()),
            onPressed: _delete,
          ),
        ],
      ),
      floatingActionButton: AnimatedFloatingActionButton(
        tooltip: 'edit'.tr(),
        onPressed: _editing ? null : _edit,
        child: Icon(Icons.edit, semanticLabel: 'edit'.tr()),
      ),
      floatingActionButtonAnimator: FloatingActionButtonAnimator.noAnimation,
      floatingActionButtonLocation: const SnackBarStableFabLocation(
        base: FloatingActionButtonLocation.endFloat,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 88),
        children: [
          EntryFormSection(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                DetailTitleRow(
                  titles: [
                    Text('date'.tr(), style: AppText.title(context)),
                    Text('time'.tr(), style: AppText.title(context)),
                  ],
                ),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    DetailFormValue(value: date, hopToken: _token('date')),
                    const SizedBox(width: 12),
                    DetailFormValue(value: timeOfDay, hopToken: _token('time')),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          EntryFormSection(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: InkWell(
                        onTap: () => showMetricInfo(
                          context,
                          kind: MetricKind.weight,
                          current: unit.extract(_record.weight),
                          formattedValue: unit.format(_record.weight),
                          weightKg: _record.weight.kg,
                        ),
                        child: Text(
                          'weight'.tr(),
                          style: AppText.title(context),
                        ),
                      ),
                    ),
                    if (bmi != null)
                      Expanded(
                        child: InkWell(
                          onTap: () => showMetricInfo(
                            context,
                            kind: MetricKind.bmi,
                            current: bmi,
                            formattedValue: bmi.toStringAsFixed(1),
                            weightKg: _record.weight.kg,
                          ),
                          child: Text(
                            'bmi'.tr(),
                            style: AppText.title(context),
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    DetailFormValue(
                      value: unit.formatValue(_record.weight),
                      unit: unit.displayName,
                      accent: accent,
                      hopToken: _token('weight'),
                      change: _previous == null
                          ? null
                          : MetricChange(
                              current: unit.extract(_record.weight),
                              previous: unit.extract(_previous!.weight),
                            ),
                      onTap: () => showMetricInfo(
                        context,
                        kind: MetricKind.weight,
                        current: unit.extract(_record.weight),
                        formattedValue: unit.format(_record.weight),
                        weightKg: _record.weight.kg,
                      ),
                    ),
                    if (bmi != null) ...[
                      const SizedBox(width: 12),
                      DetailFormValue(
                        value: bmi.toStringAsFixed(1),
                        accent: accent,
                        hopToken: _token('bmi'),
                        change: MetricChange(
                          current: bmi,
                          previous: previousBmi,
                        ),
                        onTap: () => showMetricInfo(
                          context,
                          kind: MetricKind.bmi,
                          current: bmi,
                          formattedValue: bmi.toStringAsFixed(1),
                          weightKg: _record.weight.kg,
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          if (composition != null) ...[
            const SizedBox(height: 12),
            EntryFormSection(
              subtitle: 'bodyCompositionEstimated'.tr(),
              child: Column(
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _compositionValue(
                        context,
                        label: 'bodyFat'.tr(),
                        value: composition.bodyFatPercent.toStringAsFixed(1),
                        unit: '%',
                        kind: MetricKind.bodyFat,
                        current: composition.bodyFatPercent,
                        previous: previousComposition?.bodyFatPercent,
                        hopToken: _token('bodyFat'),
                        formattedValue:
                            '${composition.bodyFatPercent.toStringAsFixed(1)} %',
                      ),
                      const SizedBox(width: 12),
                      _compositionValue(
                        context,
                        label: 'muscleMass'.tr(),
                        value: composition.muscleKg.toStringAsFixed(1),
                        unit: 'kg',
                        kind: MetricKind.muscle,
                        current: composition.muscleKg,
                        previous: previousComposition?.muscleKg,
                        hopToken: _token('muscle'),
                        polarity: MetricPolarity.higherIsBetter,
                        formattedValue:
                            '${composition.muscleKg.toStringAsFixed(1)} kg',
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _compositionValue(
                        context,
                        label: 'boneMass'.tr(),
                        value: composition.boneKg.toStringAsFixed(1),
                        unit: 'kg',
                        kind: MetricKind.bone,
                        current: composition.boneKg,
                        previous: previousComposition?.boneKg,
                        hopToken: _token('bone'),
                        polarity: MetricPolarity.higherIsBetter,
                        formattedValue:
                            '${composition.boneKg.toStringAsFixed(1)} kg',
                      ),
                      const SizedBox(width: 12),
                      _compositionValue(
                        context,
                        label: 'bodyWater'.tr(),
                        value: composition.waterPercent.toStringAsFixed(1),
                        unit: '%',
                        kind: MetricKind.water,
                        current: composition.waterPercent,
                        previous: previousComposition?.waterPercent,
                        hopToken: _token('water'),
                        polarity: MetricPolarity.higherIsBetter,
                        formattedValue:
                            '${composition.waterPercent.toStringAsFixed(1)} %',
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _compositionValue(
                        context,
                        label: 'leanBodyMass'.tr(),
                        value: composition.lbmKg.toStringAsFixed(1),
                        unit: 'kg',
                        kind: MetricKind.lbm,
                        current: composition.lbmKg,
                        previous: previousComposition?.lbmKg,
                        hopToken: _token('lbm'),
                        polarity: MetricPolarity.higherIsBetter,
                        formattedValue:
                            '${composition.lbmKg.toStringAsFixed(1)} kg',
                      ),
                      const SizedBox(width: 12),
                      _compositionValue(
                        context,
                        label: 'bmr'.tr(),
                        value: '${composition.bmrKcal}',
                        unit: 'kcal',
                        kind: MetricKind.bmr,
                        current: composition.bmrKcal.toDouble(),
                        previous: previousComposition?.bmrKcal.toDouble(),
                        hopToken: _token('bmr'),
                        polarity: MetricPolarity.neutral,
                        fractionDigits: 0,
                        formattedValue: '${composition.bmrKcal} kcal',
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ] else if (_record.impedanceOhm != null &&
              !settings.hasBodyProfile) ...[
            const SizedBox(height: 12),
            EntryFormSection(
              child: ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.person_outline),
                title: Text('bodyProfileIncomplete'.tr()),
                trailing: Icon(safaehChevronEnd(context)),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute<void>(
                      builder: (context) => const BodyProfileScreen(),
                    ),
                  );
                },
              ),
            ),
          ],
        ],
      ),
    );
  }

  DetailFormValue _compositionValue(
    BuildContext context, {
    required String label,
    required String value,
    required String unit,
    required MetricKind kind,
    required double current,
    required double? previous,
    required int hopToken,
    required String formattedValue,
    MetricPolarity polarity = MetricPolarity.lowerIsBetter,
    int fractionDigits = 1,
  }) => DetailFormValue(
    label: label,
    value: value,
    unit: unit,
    hopToken: hopToken,
    fractionDigits: fractionDigits,
    change: MetricChange(
      current: current,
      previous: previous,
      polarity: polarity,
    ),
    onTap: () => showMetricInfo(
      context,
      kind: kind,
      current: current,
      formattedValue: formattedValue,
      weightKg: _record.weight.kg,
    ),
  );

  double? _bmi(double weightKg, double? heightCm) {
    if (heightCm == null || heightCm <= 0) return null;
    final heightM = heightCm / 100;
    return weightKg / (heightM * heightM);
  }

  int _token(String key) => _hops.contains(key) ? _hopTick : 0;

  Set<String> _weightEditHops(
    BodyweightRecord before,
    BodyweightRecord after,
    AppSettings settings,
  ) {
    final hops = <String>{};
    if (before.weight != after.weight) hops.add('weight');
    if (!_sameCalendarDay(before.time, after.time)) hops.add('date');
    if (!_sameClock(before.time, after.time)) hops.add('time');
    final beforeBmi = _bmi(before.weight.kg, settings.bodyHeightCm);
    final afterBmi = _bmi(after.weight.kg, settings.bodyHeightCm);
    if (beforeBmi != afterBmi) hops.add('bmi');
    final beforeComp = EufyBodyComposition.fromRecord(before, settings);
    final afterComp = EufyBodyComposition.fromRecord(after, settings);
    if (beforeComp?.bodyFatPercent != afterComp?.bodyFatPercent) {
      hops.add('bodyFat');
    }
    if (beforeComp?.muscleKg != afterComp?.muscleKg) hops.add('muscle');
    if (beforeComp?.boneKg != afterComp?.boneKg) hops.add('bone');
    if (beforeComp?.waterPercent != afterComp?.waterPercent) hops.add('water');
    if (beforeComp?.lbmKg != afterComp?.lbmKg) hops.add('lbm');
    if (beforeComp?.bmrKcal != afterComp?.bmrKcal) hops.add('bmr');
    return hops;
  }
}

bool _sameCalendarDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

bool _sameClock(DateTime a, DateTime b) =>
    a.hour == b.hour && a.minute == b.minute;
