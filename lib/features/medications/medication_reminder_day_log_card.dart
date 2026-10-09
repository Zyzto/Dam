part of 'medication_reminders_screens.dart';

class _DayLogCard extends StatelessWidget {
  const _DayLogCard({
    required this.occurrence,
    required this.onTaken,
    required this.onSkip,
    required this.onSnooze,
    this.shiftedTo,
  });

  final DoseOccurrence occurrence;
  final DateTime? shiftedTo;
  final VoidCallback onTaken;
  final VoidCallback onSkip;
  final VoidCallback onSnooze;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final now = DateTime.now();
    final localizations = MaterialLocalizations.of(context);
    final schedule = occurrence.schedule;
    final medicine = schedule.medicine;
    final rawColor = medicine.color;
    final color = rawColor == null || rawColor == 0
        ? theme.colorScheme.primary
        : Color(rawColor);
    final status = _historyStatus(context, occurrence, now);
    final originalTime = localizations.formatTimeOfDay(
      TimeOfDay.fromDateTime(occurrence.scheduledAt),
    );
    final shifted = shiftedTo;
    final dueNow =
        shifted != null &&
        !shifted.isAfter(now) &&
        !_sameClockMinute(shifted, occurrence.scheduledAt);
    final movedAhead =
        shifted != null &&
        shifted.isAfter(now) &&
        !_sameClockMinute(shifted, occurrence.scheduledAt);
    final time = dueNow
        ? _t('reminderDueNow', 'Due now')
        : localizations.formatTimeOfDay(
            TimeOfDay.fromDateTime(
              movedAhead ? shifted : occurrence.scheduledAt,
            ),
          );
    final movedFrom = dueNow || movedAhead ? _movedFromLabel(originalTime) : null;
    final minute =
        occurrence.scheduledAt.hour * 60 + occurrence.scheduledAt.minute;
    final timing = schedule.timingForMinute(minute);
    final recorded = _doseIsRecorded(occurrence);
    final detail = _logDetail(context, occurrence, now, localizations);
    if (occurrence.statusAt(now) == 'taken') {
      final takenAt = occurrence.takenAt;
      return _CollapsedTakenLog(
        color: color,
        time: time,
        name: medicine.designation,
        dose: formatMedicationDose(schedule.doseAmount, schedule.doseUnit),
        takenAt: takenAt == null
            ? null
            : localizations.formatTimeOfDay(TimeOfDay.fromDateTime(takenAt)),
        statusLabel: status.$1,
        statusColor: status.$2,
      );
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withValues(alpha: 0.45)),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      time,
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  DecoratedBox(
                    decoration: BoxDecoration(
                      color: status.$2.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      child: Text(
                        status.$1,
                        style: theme.textTheme.labelLarge?.copyWith(
                          color: status.$2,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      medicine.designation,
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                formatMedicationDose(schedule.doseAmount, schedule.doseUnit),
                style: theme.textTheme.titleMedium,
              ),
              if (timing != MedicationDoseTiming.anytime) ...[
                const SizedBox(height: 8),
                Text(
                  _doseTimingLabel(timing),
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
              if (movedFrom != null) ...[
                const SizedBox(height: 8),
                Text(
                  movedFrom,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
              if (detail != null) ...[
                const SizedBox(height: 8),
                Text(
                  detail,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
              if (!recorded) ...[
                const SizedBox(height: 16),
                _DoseActionButtons(
                  onTaken: onTaken,
                  onSnooze: onSnooze,
                  onSkip: onSkip,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

String? _logDetail(
  BuildContext context,
  DoseOccurrence dose,
  DateTime now,
  MaterialLocalizations localizations,
) {
  final status = dose.statusAt(now);
  if (status == 'taken' && dose.takenAt != null) {
    final taken = localizations.formatTimeOfDay(
      TimeOfDay.fromDateTime(dose.takenAt!),
    );
    return '${_t('reminderStatusTaken', 'Taken')} · $taken';
  }
  if (status == 'snoozed' && dose.snoozeUntil != null) {
    final until = localizations.formatTimeOfDay(
      TimeOfDay.fromDateTime(dose.snoozeUntil!),
    );
    return '${_t('reminderStatusSnoozed', 'Snoozed')} · $until';
  }
  return null;
}

(String, Color) _historyStatus(
  BuildContext context,
  DoseOccurrence dose,
  DateTime now,
) {
  final theme = Theme.of(context);
  final status = dose.statusAt(now);
  return switch (status) {
    'taken' => (_t('reminderStatusTaken', 'Taken'), theme.colorScheme.primary),
    'skipped' => (
      _t('reminderStatusSkipped', 'Skipped'),
      theme.colorScheme.onSurfaceVariant,
    ),
    'snoozed' => (
      _t('reminderStatusSnoozed', 'Snoozed'),
      theme.colorScheme.tertiary,
    ),
    'unrecorded' => (
      _t('reminderStatusUnrecorded', 'Not recorded'),
      theme.colorScheme.error,
    ),
    _ when now.isAfter(dose.scheduledAt) => (
      _t('reminderStatusDue', 'Due now'),
      theme.colorScheme.error,
    ),
    _ => (_t('reminderStatusUpcoming', 'Upcoming'), theme.colorScheme.tertiary),
  };
}

/// Editor for one recurring medication schedule.
