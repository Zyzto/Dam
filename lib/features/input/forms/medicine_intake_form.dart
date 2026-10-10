import 'package:blood_pressure_app/core/layout/responsive_sheet.dart';
import 'package:blood_pressure_app/core/repository/repo_context.dart';
import 'package:blood_pressure_app/domain/domain.dart';
import 'package:blood_pressure_app/features/input/forms/entry_form_section.dart';
import 'package:blood_pressure_app/features/input/forms/form_base.dart';
import 'package:blood_pressure_app/theme/app_text.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:safaeh/safaeh.dart';

const _noneSentinel = Object();
const medicationPickerKey = ValueKey('medication-picker');
const medicationDoseFieldKey = ValueKey('dose-field');

/// Form to enter one or more medicine intakes.
class MedicineIntakeForm extends FormBase<(Medicine, Weight)> {
  /// Create form to enter medicine intakes.
  const MedicineIntakeForm({
    super.key,
    super.initialValue,
    this.initialIntakes,
    this.entryTime,
    this.initialIntakeTime,
    this.showSeparateTime = false,
    this.allowMultiple = false,
  });

  /// Existing doses on this row, including ones logged separately that day.
  final List<MedicineIntake>? initialIntakes;

  /// Timestamp of the blood-pressure entry this intake is shown on.
  final DateTime? entryTime;

  /// Time the dose was taken when it was logged separately.
  final DateTime? initialIntakeTime;

  /// Show a time field because the dose was not logged with the reading.
  final bool showSeparateTime;

  /// Allow adding another dose on the same form.
  final bool allowMultiple;

  @override
  FormStateBase<(Medicine, Weight), MedicineIntakeForm> createState() =>
      MedicineIntakeFormState();
}

class _IntakeSlot {
  _IntakeSlot({
    this.medicine,
    required this.time,
    required this.showTime,
    String dose = '',
  }) : controller = TextEditingController(text: dose);

  Medicine? medicine;
  DateTime time;
  bool showTime;
  String? error;
  final TextEditingController controller;

  void dispose() => controller.dispose();
}

/// State of form to enter medicine intakes.
class MedicineIntakeFormState
    extends FormStateBase<(Medicine, Weight), MedicineIntakeForm> {
  late List<_IntakeSlot> _slots;

  /// Time the first separately-logged dose was taken.
  DateTime? get intakeTime {
    for (final slot in _slots) {
      if (slot.medicine != null && slot.showTime) return slot.time;
    }
    return null;
  }

  @override
  void initState() {
    super.initState();
    _slots = _slotsFrom(
      intakes: widget.initialIntakes,
      single: widget.initialValue,
      singleTime: widget.initialIntakeTime,
      showSingleTime: widget.showSeparateTime,
    );
  }

  @override
  void dispose() {
    for (final slot in _slots) {
      slot.dispose();
    }
    super.dispose();
  }

  List<_IntakeSlot> _slotsFrom({
    List<MedicineIntake>? intakes,
    (Medicine, Weight)? single,
    DateTime? singleTime,
    bool showSingleTime = false,
  }) {
    if (intakes != null && intakes.isNotEmpty) {
      return [
        for (final intake in intakes)
          _IntakeSlot(
            medicine: intake.medicine,
            dose: _doseText(intake.dosis.mg),
            time: intake.time,
            showTime:
                widget.entryTime != null &&
                !_sameMinute(intake.time, widget.entryTime!),
          ),
      ];
    }
    if (single != null) {
      return [
        _IntakeSlot(
          medicine: single.$1,
          dose: _doseText(single.$2.mg),
          time: singleTime ?? widget.entryTime ?? DateTime.now(),
          showTime: showSingleTime,
        ),
      ];
    }
    return [
      _IntakeSlot(time: widget.entryTime ?? DateTime.now(), showTime: false),
    ];
  }

  void _replaceSlots(List<_IntakeSlot> next) {
    for (final slot in _slots) {
      slot.dispose();
    }
    _slots = next;
  }

  @override
  bool validate() {
    var ok = true;
    for (final slot in _slots) {
      if (slot.medicine != null &&
          double.tryParse(slot.controller.text) == null) {
        slot.error = 'errNaN'.tr();
        ok = false;
      } else {
        slot.error = null;
      }
    }
    setState(() {});
    return ok;
  }

  @override
  (Medicine, Weight)? save() {
    if (!validate()) return null;
    for (final slot in _slots) {
      if (slot.medicine == null) continue;
      return (slot.medicine!, Weight.mg(double.parse(slot.controller.text)));
    }
    return null;
  }

  /// Every selected dose, with distinct timestamps so they survive a merge.
  List<MedicineIntake> saveIntakes(DateTime entryTime) {
    if (!validate()) return const [];
    final used = <DateTime>{};
    final result = <MedicineIntake>[];
    for (final slot in _slots) {
      if (slot.medicine == null) continue;
      var time = slot.showTime ? slot.time : entryTime;
      while (used.contains(time)) {
        time = time.add(const Duration(seconds: 1));
      }
      used.add(time);
      result.add(
        MedicineIntake(
          time: time,
          medicine: slot.medicine!,
          dosis: Weight.mg(double.parse(slot.controller.text)),
        ),
      );
    }
    return result;
  }

  @override
  bool isEmptyInputFocused() => false;

  @override
  void fillForm((Medicine, Weight)? value) => setState(() {
    _replaceSlots(_slotsFrom(single: value));
  });

  /// Prefill medicine, dose, and the time it was taken.
  void fillIntake(MedicineIntake? value) =>
      fillIntakes(value == null ? const [] : [value]);

  /// Prefill every dose attached to this row.
  void fillIntakes(List<MedicineIntake> values) => setState(() {
    _replaceSlots(_slotsFrom(intakes: values));
  });

  @override
  bool get isEmpty => _slots.every((slot) => slot.medicine == null);

  @override
  bool get isDirty {
    final filled = [
      for (final slot in _slots)
        if (slot.medicine != null) slot,
    ];
    final initial = widget.initialIntakes;
    if (initial != null && initial.isNotEmpty) {
      if (filled.length != initial.length) return true;
      for (var i = 0; i < filled.length; i++) {
        final slot = filled[i];
        final intake = initial[i];
        if (slot.medicine != intake.medicine ||
            slot.controller.text != _doseText(intake.dosis.mg) ||
            (slot.showTime && !_sameMinute(slot.time, intake.time))) {
          return true;
        }
      }
      return false;
    }
    final single = widget.initialValue;
    if (single == null) return filled.isNotEmpty;
    if (filled.length != 1) return true;
    final first = filled.first;
    return first.medicine != single.$1 ||
        first.controller.text != _doseText(single.$2.mg) ||
        (first.showTime &&
            !_sameMinute(first.time, widget.initialIntakeTime ?? first.time));
  }

  Medicine? _matchMed(List<Medicine> meds, Medicine? value) {
    if (value == null) return null;
    for (final med in meds) {
      if (med == value) return med;
    }
    for (final med in meds) {
      if (med.designation == value.designation) return med;
    }
    return value;
  }

  Future<void> _openIntakeTimePicker(_IntakeSlot slot) async {
    FocusScope.of(context).unfocus();
    final timeOfDay = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(slot.time),
    );
    if (timeOfDay == null) return;
    setState(
      () => slot.time = slot.time.copyWith(
        hour: timeOfDay.hour,
        minute: timeOfDay.minute,
      ),
    );
  }

  Future<void> _openPicker(_IntakeSlot slot, List<Medicine> options) async {
    FocusScope.of(context).unfocus();
    final picked = await _showPicker(
      options: options,
      selected: _matchMed(options, slot.medicine),
    );
    if (!mounted || picked == null) return;
    if (picked == _noneSentinel) {
      _selectMedicine(slot, null);
    } else {
      _selectMedicine(slot, picked as Medicine);
    }
  }

  void _selectMedicine(_IntakeSlot slot, Medicine? med) {
    setState(() {
      slot.medicine = med;
      slot.error = null;
      if (med != null) {
        slot.controller.text = med.dosis == null
            ? ''
            : _doseText(med.dosis!.mg);
      } else {
        slot.controller.text = '';
        if (_slots.length > 1 && !identical(slot, _slots.first)) {
          slot.dispose();
          _slots.remove(slot);
        }
      }
    });
    _keepKeypadClosed();
  }

  void _clearOrRemove(_IntakeSlot slot) {
    _selectMedicine(slot, null);
    if (_slots.isEmpty) {
      setState(() {
        _slots.add(
          _IntakeSlot(
            time: widget.entryTime ?? DateTime.now(),
            showTime: false,
          ),
        );
      });
    }
  }

  void _nudge(_IntakeSlot slot, int direction) {
    final unit = slot.medicine?.unit ?? MedicationUnit.mg;
    final current = double.tryParse(slot.controller.text) ?? 0;
    final step = _doseStep(unit, current);
    final next = current + direction * step;
    setState(() {
      slot.error = null;
      slot.controller.text = next <= 0 ? _doseText(step) : _doseText(next);
    });
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
      listenable: context.medCache,
      builder: (context, _) {
        final meds = context.medCache.medications;
        if (meds.isEmpty) {
          return EntryFormSection(
            title: 'medications'.tr(),
            child: SafaehInlineBanner(
              message: 'noMedicationsHint'.tr(),
              tone: SafaehBannerTone.info,
              actions: [
                TextButton.icon(
                  onPressed: () => Navigator.of(
                    context,
                  ).pushNamed('/settings/medications'),
                  icon: const Icon(Icons.medication_outlined),
                  label: Text('manageMedications'.tr()),
                ),
              ],
            ),
          );
        }

        final filled = [
          for (final slot in _slots)
            if (slot.medicine != null) slot,
        ];
        final empty = _slots.cast<_IntakeSlot?>().firstWhere(
          (slot) => slot!.medicine == null,
          orElse: () => null,
        );
        final extras = <Medicine>[];
        for (final slot in filled) {
          final match = _matchMed(meds, slot.medicine);
          if (match != null &&
              !meds.contains(match) &&
              !extras.contains(match)) {
            extras.add(match);
          }
        }
        final options = [...extras, ...meds];
        final canAdd =
            widget.allowMultiple && empty == null && filled.isNotEmpty;
        return EntryFormSection(
          title: 'medications'.tr(),
          trailing: canAdd
              ? _RoundStepButton(
                  icon: Icons.add,
                  tooltip: 'addMedication'.tr(),
                  onPressed: () => _addFromPicker(options),
                )
              : null,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var i = 0; i < filled.length; i++) ...[
                if (i > 0) const SizedBox(height: 12),
                _doseCard(meds, filled[i]),
              ],
              if (empty != null) ...[
                if (filled.isNotEmpty) const SizedBox(height: 12),
                _AddMedicationRow(onTap: () => _openPicker(empty, options)),
              ],
            ],
          ),
        );
      },
    );

  Future<void> _addFromPicker(List<Medicine> options) async {
    FocusScope.of(context).unfocus();
    final picked = await _showPicker(options: options, selected: null);
    if (!mounted || picked is! Medicine) return;
    setState(() {
      _slots.add(
        _IntakeSlot(
          medicine: picked,
          dose: picked.dosis == null ? '' : _doseText(picked.dosis!.mg),
          time: widget.entryTime ?? DateTime.now(),
          showTime: false,
        ),
      );
    });
    _keepKeypadClosed();
  }

  void _keepKeypadClosed() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) FocusScope.of(context).unfocus();
    });
  }

  Future<Object?> _showPicker({
    required List<Medicine> options,
    required Medicine? selected,
  }) => showResponsiveSheet<Object>(
      context: context,
      title: 'selectMedication'.tr(),
      maxHeight: MediaQuery.sizeOf(context).height * 0.75,
      showDragHandle: true,
      child: _MedicinePickerSheet(medicines: options, selected: selected),
    );

  Widget _doseCard(List<Medicine> meds, _IntakeSlot slot) {
    final theme = Theme.of(context);
    final selected = _matchMed(meds, slot.medicine);
    if (selected == null) return const SizedBox.shrink();
    final options = [if (!meds.contains(selected)) selected, ...meds];
    final color = _medColor(selected, theme);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 8, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                _MedSwatch(color: color, empty: false),
                const SizedBox(width: 10),
                Expanded(
                  child: InkWell(
                    key: medicationPickerKey,
                    onTap: () => _openPicker(slot, options),
                    borderRadius: BorderRadius.circular(12),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              selected.designation,
                              style: AppText.title(context),
                            ),
                          ),
                          Icon(
                            Icons.unfold_more,
                            size: 20,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                _RoundStepButton(
                  icon: Icons.remove,
                  tooltip: 'noMedication'.tr(),
                  onPressed: () => _clearOrRemove(slot),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: _DoseStepper(
                    controller: slot.controller,
                    unit: selected.unit.localizedSymbol,
                    errorText: slot.error,
                    onMinus: () => _nudge(slot, -1),
                    onPlus: () => _nudge(slot, 1),
                  ),
                ),
                if (slot.showTime) ...[
                  const SizedBox(width: 12),
                  _IntakeTimeField(
                    time: slot.time,
                    onTap: () => _openIntakeTimePicker(slot),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _AddMedicationRow extends StatelessWidget {
  const _AddMedicationRow({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = theme.colorScheme.primary;
    return Material(
      color: color.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        key: medicationPickerKey,
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 14, 16, 14),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.16),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.add, color: color),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'addMedication'.tr(),
                  style: AppText.title(context).copyWith(color: color),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DoseStepper extends StatelessWidget {
  const _DoseStepper({
    required this.controller,
    required this.unit,
    required this.onMinus,
    required this.onPlus,
    this.errorText,
  });

  final TextEditingController controller;
  final String unit;
  final VoidCallback onMinus;
  final VoidCallback onPlus;
  final String? errorText;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DecoratedBox(
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: theme.colorScheme.outlineVariant.withValues(alpha: 0.7),
            ),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: SizedBox(
              height: 52,
              child: Row(
                children: [
                  _DoseEndButton(
                    key: const ValueKey('dose-minus'),
                    icon: Icons.remove,
                    tooltip: 'dosis'.tr(),
                    onPressed: onMinus,
                  ),
                  Expanded(
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        TextField(
                          key: medicationDoseFieldKey,
                          controller: controller,
                          autofocus: false,
                          textAlign: TextAlign.center,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          inputFormatters: [
                            FilteringTextInputFormatter.allow(
                              RegExp('[0-9,.]'),
                            ),
                          ],
                          style: theme.textTheme.headlineMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                            fontFeatures: const [FontFeature.tabularFigures()],
                            height: 1.1,
                          ),
                          decoration: const InputDecoration(
                            border: InputBorder.none,
                            enabledBorder: InputBorder.none,
                            focusedBorder: InputBorder.none,
                            filled: false,
                            isDense: true,
                            contentPadding: EdgeInsets.zero,
                            hintText: '—',
                          ),
                        ),
                        Positioned(
                          right: 10,
                          bottom: 6,
                          child: IgnorePointer(
                            child: Text(
                              unit,
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                                fontWeight: FontWeight.w600,
                                fontSize: 10,
                                height: 1,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  _DoseEndButton(
                    key: const ValueKey('dose-plus'),
                    icon: Icons.add,
                    tooltip: 'dosis'.tr(),
                    onPressed: onPlus,
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 4),
        _FieldCaption('dosis'.tr()),
        if (errorText != null) ...[
          const SizedBox(height: 2),
          Text(
            errorText!,
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.error,
            ),
          ),
        ],
      ],
    );
  }
}

class _DoseEndButton extends StatelessWidget {
  const _DoseEndButton({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Tooltip(
      message: tooltip,
      child: Material(
        color: theme.colorScheme.secondaryContainer,
        child: InkWell(
          onTap: onPressed,
          child: SizedBox(
            width: 56,
            height: 52,
            child: Icon(
              icon,
              size: 32,
              color: theme.colorScheme.onSecondaryContainer,
            ),
          ),
        ),
      ),
    );
  }
}

class _RoundStepButton extends StatelessWidget {
  const _RoundStepButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => IconButton.filledTonal(
      onPressed: onPressed,
      tooltip: tooltip,
      icon: Icon(icon, size: 20),
      style: IconButton.styleFrom(
        visualDensity: VisualDensity.compact,
        minimumSize: const Size(40, 40),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
    );
}

class _MedSwatch extends StatelessWidget {
  const _MedSwatch({required this.color, required this.empty});

  final Color color;
  final bool empty;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: empty
            ? theme.colorScheme.surfaceContainerHighest
            : color.withValues(alpha: 0.16),
        shape: BoxShape.circle,
      ),
      child: Icon(
        empty ? Icons.medication_outlined : Icons.medication,
        size: 20,
        color: empty ? theme.colorScheme.onSurfaceVariant : color,
      ),
    );
  }
}

class _MedicinePickerSheet extends StatelessWidget {
  const _MedicinePickerSheet({required this.medicines, required this.selected});

  final List<Medicine> medicines;
  final Medicine? selected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListView(
      shrinkWrap: true,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      children: [
        if (selected != null) ...[
          _PickerTile(
            swatch: _MedSwatch(color: theme.colorScheme.outline, empty: true),
            title: 'noMedication'.tr(),
            selected: false,
            onTap: () => Navigator.pop(context, _noneSentinel),
          ),
          const SizedBox(height: 8),
        ],
        for (var i = 0; i < medicines.length; i++) ...[
          if (i > 0) const SizedBox(height: 8),
          _PickerTile(
            swatch: _MedSwatch(
              color: _medColor(medicines[i], theme),
              empty: false,
            ),
            title: medicines[i].designation,
            subtitle: medicines[i].formattedDosis,
            selected: selected == medicines[i],
            onTap: () => Navigator.pop(context, medicines[i]),
          ),
        ],
      ],
    );
  }
}

class _PickerTile extends StatelessWidget {
  const _PickerTile({
    required this.swatch,
    required this.title,
    required this.selected,
    required this.onTap,
    this.subtitle,
  });

  final Widget swatch;
  final String title;
  final String? subtitle;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = selected
        ? theme.colorScheme.primaryContainer
        : theme.colorScheme.surface;
    return Material(
      color: color,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 14, 12),
          child: Row(
            children: [
              swatch,
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: AppText.title(context)),
                    if (subtitle != null) ...[
                      const SizedBox(height: 4),
                      DecoratedBox(
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          child: Text(
                            subtitle!,
                            style: AppText.subtitle(context),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (selected)
                Icon(Icons.check_circle, color: theme.colorScheme.primary),
            ],
          ),
        ),
      ),
    );
  }
}

class _FieldCaption extends StatelessWidget {
  const _FieldCaption(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Text(text, style: AppText.label(context));
}

class _IntakeTimeField extends StatelessWidget {
  const _IntakeTimeField({required this.time, required this.onTap});

  final DateTime time;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            height: 52,
            child: Align(
              alignment: AlignmentDirectional.centerStart,
              child: Text(
                DateFormat('HH:mm', 'en').format(time),
                style: theme.textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  fontFeatures: const [FontFeature.tabularFigures()],
                  height: 1.1,
                ),
              ),
            ),
          ),
          const SizedBox(height: 4),
          _FieldCaption('medicationTime'.tr()),
        ],
      ),
    );
  }
}

Color _medColor(Medicine? med, ThemeData theme) {
  if (med?.color == null || med!.color == 0) return theme.colorScheme.primary;
  return Color(med.color!);
}

String _doseText(double amount) => formatDoseAmount(amount);

double _doseStep(MedicationUnit unit, double value) {
  if (unit == MedicationUnit.tablet) return 1;
  if (value > 0 && value < 1) return 0.25;
  if (value > 0 && value != value.roundToDouble()) return 0.5;
  return 1;
}

bool _sameMinute(DateTime a, DateTime b) =>
    a.year == b.year &&
    a.month == b.month &&
    a.day == b.day &&
    a.hour == b.hour &&
    a.minute == b.minute;
