import 'package:blood_pressure_app/components/animated_floating_action_button.dart';
import 'package:blood_pressure_app/components/snack_bar_stable_fab_location.dart';
import 'package:blood_pressure_app/core/repository/repo_context.dart';
import 'package:blood_pressure_app/data_util/entry_context.dart';
import 'package:blood_pressure_app/domain/domain.dart';
import 'package:blood_pressure_app/features/input/forms/entry_form_section.dart';
import 'package:blood_pressure_app/features/measurement_list/cartoon_hop.dart';
import 'package:blood_pressure_app/features/measurement_list/detail_form_value.dart';
import 'package:blood_pressure_app/features/measurement_list/metric_change.dart';
import 'package:blood_pressure_app/features/measurement_list/metric_info.dart';
import 'package:blood_pressure_app/features/measurement_list/metric_info_dialog.dart';
import 'package:blood_pressure_app/features/measurement_list/previous_measurement.dart';
import 'package:blood_pressure_app/features/settings/app_settings.dart';
import 'package:blood_pressure_app/l10n/western_digits.dart';
import 'package:blood_pressure_app/model/blood_pressure/pressure_unit.dart';
import 'package:blood_pressure_app/model/combined_entry.dart';
import 'package:blood_pressure_app/theme/app_text.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:safaeh/safaeh.dart';

/// Full blood-pressure entry with comparison to the previous reading.
class MeasurementDetailScreen extends ConsumerStatefulWidget {
  /// Show [entry], optionally compared to [previous].
  const MeasurementDetailScreen({
    super.key,
    required this.entry,
    this.previous,
  });

  /// Entry to display.
  final CombinedEntry entry;

  /// Next older blood-pressure reading from the visible list, when known.
  final CombinedEntry? previous;

  @override
  ConsumerState<MeasurementDetailScreen> createState() =>
      _MeasurementDetailScreenState();
}

class _MeasurementDetailScreenState
    extends ConsumerState<MeasurementDetailScreen> {
  late CombinedEntry _entry;
  BloodPressureRecord? _previousRecord;
  var _editing = false;
  var _hopTick = 0;
  var _olderLoad = 0;
  final _hops = <String>{};

  @override
  void initState() {
    super.initState();
    // Route rebuilds still pass the original [widget.entry]; keep [_entry].
    _entry = widget.entry;
    _previousRecord = widget.previous?.record;
    if (ref.read(appSettingsProvider).bloodPressureEnabled &&
        (_previousRecord == null ||
            (_previousRecord!.sys == null &&
                _previousRecord!.dia == null &&
                _previousRecord!.pul == null))) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _loadOlder());
    }
  }

  Future<void> _loadOlder() async {
    if (!ref.read(appSettingsProvider).bloodPressureEnabled) return;
    final load = ++_olderLoad;
    final time = _entry.time;
    BloodPressureRepository repo;
    try {
      repo = context.bpRepo;
    } on StateError {
      return;
    }
    final older = await loadOlderBloodPressure(repo, time);
    if (!mounted || load != _olderLoad) return;
    setState(() => _previousRecord = older);
  }

  Future<void> _edit() async {
    if (_editing) return;
    final before = _copyEntry(_entry);
    setState(() => _editing = true);
    try {
      final saved = await context.createEntry(_entry);
      if (!mounted) return;
      final next = _savedEntry(saved);
      if (next == null) return;
      final hops = _editHops(before, next);
      setState(() {
        _entry = next;
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

  CombinedEntry? _savedEntry(List<CombinedEntry>? saved) {
    if (saved == null || saved.isEmpty) return null;
    for (final entry in saved) {
      if (entry.record != null) return entry;
    }
    return saved.first;
  }

  Future<void> _delete() async {
    final deleted = await context.deleteEntry(_entry);
    if (deleted && mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(appSettingsProvider);
    final entry = _entry;
    final intakes = settings.medicineFeatureEnabled
        ? entry.allIntakes
        : const <MedicineIntake>[];
    if (!settings.bloodPressureEnabled && intakes.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: Text('measurements'.tr())),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              'bloodPressureDisabledHint'.tr(),
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
    }
    final locale = context.locale.toString();
    final unit = settings.preferredPressureUnit;
    final date = formatAppDate(entry.time, 'yyyy-MM-dd', locale);
    final timeOfDay = formatAppDate(entry.time, 'HH:mm', locale);
    return Scaffold(
      appBar: AppBar(
        title: Text(
          settings.bloodPressureEnabled
              ? 'bloodPressure'.tr()
              : 'medications'.tr(),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.delete, semanticLabel: 'delete'.tr()),
            onPressed: _delete,
          ),
        ],
      ),
      floatingActionButton: AnimatedFloatingActionButton(
        tooltip: 'edit'.tr(),
        burstKind: FabBurstKind.hearts,
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
          if (settings.bloodPressureEnabled) ...[
            const SizedBox(height: 12),
            EntryFormSection(
              title: 'bloodPressure'.tr(),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _PressureValue(
                    title: 'sysLong'.tr(),
                    kind: MetricKind.sys,
                    accent: settings.sysColor,
                    pressure: entry.sys,
                    previous: _previousRecord?.sys,
                    unit: unit,
                    hopToken: _token('sys'),
                  ),
                  const SizedBox(width: 12),
                  _PressureValue(
                    title: 'diaLong'.tr(),
                    kind: MetricKind.dia,
                    accent: settings.diaColor,
                    pressure: entry.dia,
                    previous: _previousRecord?.dia,
                    unit: unit,
                    hopToken: _token('dia'),
                  ),
                  const SizedBox(width: 12),
                  _PulseValue(
                    pulse: entry.pul,
                    previous: _previousRecord?.pul,
                    accent: settings.pulColor,
                    hopToken: _token('pul'),
                  ),
                ],
              ),
            ),
          ],
          if (intakes.isNotEmpty) ...[
            const SizedBox(height: 12),
            EntryFormSection(
              title: 'medications'.tr(),
              child: Column(
                children: [
                  for (var i = 0; i < intakes.length; i++) ...[
                    if (i > 0) const SizedBox(height: 12),
                    _IntakeCard(
                      intake: intakes[i],
                      timeLabel: formatAppDate(
                        intakes[i].time,
                        'HH:mm',
                        locale,
                      ),
                      nameHopToken: _token('med:$i:name'),
                      doseHopToken: _token('med:$i:dose'),
                      timeHopToken: _token('med:$i:time'),
                    ),
                  ],
                ],
              ),
            ),
          ],
          if (settings.bloodPressureEnabled &&
              (entry.note?.note?.isNotEmpty ?? false)) ...[
            const SizedBox(height: 12),
            EntryFormSection(
              title: 'note'.tr(),
              child: hopping(
                _token('note'),
                SafaehUserText(
                  entry.note!.note!,
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  int _token(String key) => _hops.contains(key) ? _hopTick : 0;
}

class _PressureValue extends StatelessWidget {
  const _PressureValue({
    required this.title,
    required this.kind,
    required this.accent,
    required this.pressure,
    required this.previous,
    required this.unit,
    this.hopToken = 0,
  });

  final String title;
  final MetricKind kind;
  final Color accent;
  final Pressure? pressure;
  final Pressure? previous;
  final PressureUnit unit;
  final int hopToken;

  @override
  Widget build(BuildContext context) {
    final current = _inUnit(pressure, unit);
    final formatted = current == null
        ? '—'
        : unit == PressureUnit.kPa
        ? current.toStringAsFixed(1)
        : current.round().toString();
    return DetailFormValue(
      label: title,
      value: formatted,
      unit: unit.name,
      accent: accent,
      hopToken: hopToken,
      fractionDigits: unit == PressureUnit.kPa ? 1 : 0,
      change: previous == null
          ? null
          : MetricChange(
              current: current ?? 0,
              previous: _inUnit(previous, unit),
              unchangedEpsilon: unit == PressureUnit.kPa ? 0.05 : 0.5,
            ),
      onTap: current == null
          ? null
          : () => showMetricInfo(
              context,
              kind: kind,
              current: current,
              formattedValue: formatted,
            ),
    );
  }
}

class _PulseValue extends StatelessWidget {
  const _PulseValue({
    required this.pulse,
    required this.previous,
    required this.accent,
    this.hopToken = 0,
  });

  final int? pulse;
  final int? previous;
  final Color accent;
  final int hopToken;

  @override
  Widget build(BuildContext context) {
    final formatted = pulse?.toString() ?? '—';
    return DetailFormValue(
      label: 'pulLong'.tr(),
      value: formatted,
      unit: 'bpm',
      accent: accent,
      hopToken: hopToken,
      fractionDigits: 0,
      change: pulse == null
          ? null
          : MetricChange(
              current: pulse!.toDouble(),
              previous: previous?.toDouble(),
            ),
      onTap: pulse == null
          ? null
          : () => showMetricInfo(
              context,
              kind: MetricKind.pulse,
              current: pulse!.toDouble(),
              formattedValue: formatted,
            ),
    );
  }
}

class _IntakeCard extends StatelessWidget {
  const _IntakeCard({
    required this.intake,
    required this.timeLabel,
    this.nameHopToken = 0,
    this.doseHopToken = 0,
    this.timeHopToken = 0,
  });

  final MedicineIntake intake;
  final String timeLabel;
  final int nameHopToken;
  final int doseHopToken;
  final int timeHopToken;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final raw = intake.medicine.color;
    final color = raw == null || raw == 0
        ? theme.colorScheme.primary
        : Color(raw);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.18)),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            hopping(
              nameHopToken,
              Text(intake.medicine.designation, style: AppText.title(context)),
            ),
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                DetailFormValue(
                  label: 'dosis'.tr(),
                  value: formatDoseAmount(intake.dosis.mg),
                  unit: intake.medicine.unit.localizedSymbol,
                  accent: color,
                  hopToken: doseHopToken,
                ),
                const SizedBox(width: 12),
                DetailFormValue(
                  label: 'medicationTime'.tr(),
                  value: timeLabel,
                  accent: theme.colorScheme.primary,
                  hopToken: timeHopToken,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

double? _inUnit(Pressure? value, PressureUnit unit) {
  if (value == null) return null;
  return switch (unit) {
    PressureUnit.mmHg => value.mmHg.toDouble(),
    PressureUnit.kPa => value.kPa,
  };
}

Set<String> _editHops(CombinedEntry before, CombinedEntry after) {
  final hops = <String>{};
  if (!_sameCalendarDay(before.time, after.time)) hops.add('date');
  if (!_sameClock(before.time, after.time)) hops.add('time');
  if (before.sys != after.sys) hops.add('sys');
  if (before.dia != after.dia) hops.add('dia');
  if (before.pul != after.pul) hops.add('pul');
  if ((before.note?.note ?? '') != (after.note?.note ?? '')) hops.add('note');

  final oldIntakes = before.allIntakes;
  final newIntakes = after.allIntakes;
  final used = <int>{};
  for (var i = 0; i < newIntakes.length; i++) {
    final neu = newIntakes[i];
    var oldIndex = -1;
    for (var j = 0; j < oldIntakes.length; j++) {
      if (used.contains(j)) continue;
      if (oldIntakes[j].medicine == neu.medicine) {
        oldIndex = j;
        break;
      }
    }
    if (oldIndex < 0) {
      hops.addAll(['med:$i:name', 'med:$i:dose', 'med:$i:time']);
      continue;
    }
    used.add(oldIndex);
    final old = oldIntakes[oldIndex];
    if (old.medicine.designation != neu.medicine.designation) {
      hops.add('med:$i:name');
    }
    if (old.dosis != neu.dosis) hops.add('med:$i:dose');
    if (!_sameCalendarDay(old.time, neu.time) ||
        !_sameClock(old.time, neu.time)) {
      hops.add('med:$i:time');
    }
  }
  return hops;
}

bool _sameCalendarDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

bool _sameClock(DateTime a, DateTime b) =>
    a.hour == b.hour && a.minute == b.minute;

CombinedEntry _copyEntry(CombinedEntry entry) => CombinedEntry(
  time: entry.time,
  note: entry.note,
  record: entry.record,
  intake: entry.intake,
  weight: entry.weight,
  dayIntakes: entry.dayIntakes,
);
