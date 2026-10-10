import 'package:blood_pressure_app/domain/medication_schedule.dart';

/// One open dose the countdown surfaces can draw.
class PlannedDose {
  const PlannedDose({
    required this.scheduleId,
    required this.targetAt,
    required this.color,
    required this.name,
    required this.status,
    this.medicineId = '',
    this.interval = const Duration(hours: 24),
  });

  final String scheduleId;
  final String medicineId;
  final DateTime targetAt;
  final int color;
  final String name;
  final String status;

  /// Time from the previous scheduled dose of this medicine to [targetAt].
  final Duration interval;

  String get medicineKey => medicineId.isNotEmpty
      ? medicineId
      : (scheduleId.isNotEmpty ? scheduleId : name);
}

/// Doses that share one ring. More than one dose means a dotted multi-color ring.
class ReminderRingGroup {
  const ReminderRingGroup(this.doses);

  final List<PlannedDose> doses;

  bool get sharesTimer => doses.length > 1;

  DateTime get targetAt => doses.first.targetAt;
}

/// Follow-up alerts after a dose time. The on-time alert is separate.
///
/// Three reminders every 10 minutes means due+10, due+20, and due+30.
List<DateTime> overdueReminderInstants({
  required DateTime scheduledAt,
  required DateTime now,
  required int count,
  required Duration interval,
}) {
  if (count <= 0 || interval <= Duration.zero) return const [];
  return [
    for (var index = 1; index <= count; index++)
      if (scheduledAt.add(interval * index).isAfter(now))
        scheduledAt.add(interval * index),
  ];
}

/// Which open doses a countdown surface should draw.
///
/// A non-empty [scheduleId] limits the list to that schedule. Each medicine
/// keeps only its next open dose, so later days of the same medicine never
/// share the rings. When [showAll] is false, only the earliest of those
/// remains.
List<PlannedDose> selectReminderDoses(
  List<PlannedDose> sortedOpen, {
  required bool showAll,
  String scheduleId = '',
}) {
  final pinned = scheduleId.trim();
  final pool = pinned.isEmpty
      ? sortedOpen
      : sortedOpen.where((dose) => dose.scheduleId == pinned).toList();
  final unique = earliestDosePerMedicine(pool);
  if (!showAll) return unique.take(1).toList();
  return unique;
}

/// Keeps the soonest dose of each medicine. Later doses of that medicine drop.
List<PlannedDose> earliestDosePerMedicine(List<PlannedDose> doses) {
  final sorted = [...doses]..sort((a, b) {
    final byTime = a.targetAt.compareTo(b.targetAt);
    if (byTime != 0) return byTime;
    return a.medicineKey.compareTo(b.medicineKey);
  });
  final seen = <String>{};
  final kept = <PlannedDose>[];
  for (final dose in sorted) {
    if (seen.add(dose.medicineKey)) kept.add(dose);
  }
  return kept;
}

/// Gap from the previous scheduled slot of [schedule] to [scheduledAt].
///
/// One daily time is a full day. Two times use the hours between them, including
/// the wrap from the last time today to the first time tomorrow.
Duration scheduledDoseInterval(
  MedicationSchedule schedule,
  DateTime scheduledAt,
) {
  final times = [
    for (final minute in schedule.timeMinutes)
      if (minute >= 0 && minute < 24 * 60) minute,
  ]..sort();
  final weekdays = schedule.weekdays.isEmpty
      ? const {1, 2, 3, 4, 5, 6, 7}
      : schedule.weekdays;
  final doseMinute = scheduledAt.hour * 60 + scheduledAt.minute;
  for (var daysBack = 0; daysBack <= 7; daysBack++) {
    final day = DateTime(
      scheduledAt.year,
      scheduledAt.month,
      scheduledAt.day,
    ).subtract(Duration(days: daysBack));
    if (!weekdays.contains(day.weekday)) continue;
    var previousMinute = -1;
    for (final minute in times) {
      if (daysBack == 0 && minute >= doseMinute) continue;
      if (minute > previousMinute) previousMinute = minute;
    }
    if (previousMinute < 0) continue;
    final previous = DateTime(
      day.year,
      day.month,
      day.day,
      previousMinute ~/ 60,
      previousMinute % 60,
    );
    final due = DateTime(
      scheduledAt.year,
      scheduledAt.month,
      scheduledAt.day,
      doseMinute ~/ 60,
      doseMinute % 60,
    );
    final gap = due.difference(previous);
    if (gap > Duration.zero) return gap;
  }
  return const Duration(hours: 24);
}

/// Take-times after a dose stays untaken past [grace].
///
/// Saved schedule times stay as they are. The returned map only contains
/// doses whose take-time moved. When [grace] is zero, or [enabled] is false
/// and [movesTimes] is omitted, the map is empty. [movesTimes] decides each
/// dose on its own, so one reminder can follow the app setting while another
/// overrides it.
///
/// Doses of one medicine are walked from earliest to latest. Duplicate ids
/// collapse to the last copy.
///
/// * A dose taken more than [grace] after its saved time slides every later
///   dose of that medicine by that same lateness, so the gap between doses
///   stays. That can put a dose later than the next saved clock time.
/// * A dose taken within [grace], taken early, or skipped clears the slide.
///   The saved times return.
/// * An open dose still untaken more than [grace] after its current time
///   becomes due at [now], and later doses slide with it, while [now] is
///   still before the halfway point to the next later slot. Doses saved for
///   that same minute move together.
/// * After that halfway point the missed dose keeps a slide it already had,
///   and later doses go back to their saved times.
///
/// An active snooze is left on its snooze time. The slide from earlier doses
/// still applies after it. When [followUpFrom] is set, a dose that is due
/// now records the moment its limit ran out there. That instant stays put
/// while [now] moves.
Map<String, DateTime> shiftedDoseTargets(
  Iterable<DoseOccurrence> occurrences, {
  required DateTime now,
  required bool enabled,
  required Duration grace,
  bool Function(DoseOccurrence dose)? movesTimes,
  Map<String, DateTime>? followUpFrom,
}) {
  if (grace <= Duration.zero) return const {};
  if (movesTimes == null && !enabled) return const {};
  bool moves(DoseOccurrence dose) => movesTimes?.call(dose) ?? enabled;
  final unique = <String, DoseOccurrence>{};
  for (final dose in occurrences) {
    unique[dose.id] = dose;
  }
  final byMedicine = <String, List<DoseOccurrence>>{};
  for (final dose in unique.values) {
    if (!moves(dose)) continue;
    final key = dose.schedule.medicineId.isNotEmpty
        ? dose.schedule.medicineId
        : (dose.schedule.id ?? dose.id);
    byMedicine.putIfAbsent(key, () => []).add(dose);
  }
  final targets = <String, DateTime>{};
  for (final doses in byMedicine.values) {
    doses.sort((a, b) {
      final byTime = a.scheduledAt.compareTo(b.scheduledAt);
      if (byTime != 0) return byTime;
      return a.id.compareTo(b.id);
    });
    var carry = Duration.zero;
    for (var index = 0; index < doses.length; index++) {
      final dose = doses[index];
      final scheduled = dose.scheduledAt;
      if (dose.status == 'taken') {
        final late = (dose.takenAt ?? scheduled).difference(scheduled);
        carry = late > grace ? late : Duration.zero;
        continue;
      }
      if (dose.status == 'skipped') {
        carry = Duration.zero;
        continue;
      }
      final snoozeUntil = dose.snoozeUntil;
      if (dose.status == 'snoozed' &&
          snoozeUntil != null &&
          snoozeUntil.isAfter(now)) {
        continue;
      }
      final effective = scheduled.add(carry);
      if (!now.isAfter(effective.add(grace))) {
        _rememberSlide(targets, dose.id, scheduled, effective);
        continue;
      }
      final halfway = effective.add(
        Duration(microseconds: _gapUntilNextDose(doses, index).inMicroseconds ~/ 2),
      );
      if (!now.isBefore(halfway)) {
        _rememberSlide(targets, dose.id, scheduled, effective);
        carry = Duration.zero;
        continue;
      }
      targets[dose.id] = now;
      // The take-time stays at [now] so later doses keep sliding. Follow-ups
      // stay at the moment the limit ran out, which does not move on the
      // next rebuild.
      followUpFrom?[dose.id] = effective.add(grace);
      final late = now.difference(scheduled);
      carry = late.isNegative ? Duration.zero : late;
    }
  }
  return targets;
}

/// The saved-time alarm stays off when the dose is already settled.
///
/// Taken and skipped doses stay quiet. A snooze that is still ahead of [now]
/// is reminded by that snooze, so the saved time is not scheduled as well.
/// Where the countdown and the alarm should point for this dose.
///
/// A snooze that is still ahead of [now] wins. Otherwise a shifted take-time
/// wins, and the saved time remains when nothing moved.
DateTime doseTakeAt(
  DoseOccurrence dose,
  DateTime now,
  Map<String, DateTime> targets,
) {
  final snoozeUntil = dose.snoozeUntil;
  if (dose.status == 'snoozed' &&
      snoozeUntil != null &&
      snoozeUntil.isAfter(now)) {
    return snoozeUntil;
  }
  return targets[dose.id] ?? dose.scheduledAt;
}

/// A dose saved before today whose take-time has moved ahead of [now].
///
/// The schedule walk only covers today onward, so this dose still needs its
/// own alarm.
bool earlierDoseAlarmMovedAhead({
  required DateTime scheduledAt,
  required DateTime? movedTo,
  required DateTime now,
}) {
  if (movedTo == null || !movedTo.isAfter(now)) return false;
  final scheduledDay = DateTime(
    scheduledAt.year,
    scheduledAt.month,
    scheduledAt.day,
  );
  final today = DateTime(now.year, now.month, now.day);
  return scheduledDay.isBefore(today);
}

bool doseClockAlarmClaimed(DoseOccurrence? occurrence, DateTime now) {
  if (occurrence == null) return false;
  if (occurrence.status == 'taken' || occurrence.status == 'skipped') {
    return true;
  }
  final snoozeUntil = occurrence.snoozeUntil;
  return occurrence.status == 'snoozed' &&
      snoozeUntil != null &&
      snoozeUntil.isAfter(now);
}

/// Days of doses the home list and widget load.
///
/// With the move-times setting off this stays the original week. Turning the
/// setting on extends it so a weekly miss can still slide the next dose.
const int savedReminderHorizonDays = 7;
const int shiftedReminderHorizonDays = 14;

int reminderHorizonDays({
  required bool shiftMissedDoseTimes,
  required Duration grace,
}) => shiftMissedDoseTimes && grace > Duration.zero
    ? shiftedReminderHorizonDays
    : savedReminderHorizonDays;

/// The dose list the countdown and the alarms share.
///
/// When the setting is off, [history] is ignored and [upcoming] is returned
/// unchanged. When it is on, the whole saved history stays in front of
/// [upcoming]. A late take has to walk the doses after it, including ones
/// that are no longer shown, so it can stop sliding once one of them passes
/// the halfway point. Surfaces hide a dose from before today unless it is
/// still the one to take.
List<DoseOccurrence> dosesForReminderList({
  required List<DoseOccurrence> history,
  required List<DoseOccurrence> upcoming,
  required DateTime now,
  required bool shiftMissedDoseTimes,
  required Duration grace,
  bool Function(DoseOccurrence dose)? movesTimes,
}) {
  if (grace <= Duration.zero) return upcoming;
  bool moves(DoseOccurrence dose) =>
      movesTimes?.call(dose) ?? shiftMissedDoseTimes;
  if (!history.any(moves) && !upcoming.any(moves)) return upcoming;
  return [
    for (final dose in history)
      if (moves(dose)) dose,
    ...upcoming,
  ];
}

/// Whether a dose is shown on the countdown, the next-up lines, and the widget.
///
/// A dose saved before today is shown while a snooze is still running, while
/// its take-time is still ahead, or while [grace] has not run out. After that
/// limit, it stays up only until the halfway point. The saved row stays in
/// the reminder list either way, so later doses can still be placed from it.
bool reminderDoseIsCurrent(
  DoseOccurrence dose,
  DateTime now,
  Map<String, DateTime> targets, {
  Duration grace = Duration.zero,
}) {
  final today = DateTime(now.year, now.month, now.day);
  if (!dose.scheduledAt.isBefore(today)) return true;
  if (_stillTheDoseToTake(dose, targets[dose.id], now)) return true;
  if (grace <= Duration.zero) return false;
  final status = dose.statusAt(now);
  if (status != 'pending' && status != 'snoozed' && status != 'unrecorded') {
    return false;
  }
  return !now.isAfter(dose.scheduledAt.add(grace));
}

/// Open doses from before today that are still the ones to take.
///
/// [earlierOpen] holds pending and snoozed rows whose saved time is before
/// today. A row stays when its take-time is still ahead, or when a snooze is
/// still running. A miss past the halfway point drops out, so an old daily
/// dose does not sit on the timer. [context] is the recorded history and the
/// doses from today onward, which decide that halfway point.
List<DoseOccurrence> earlierOpenDosesStillDue({
  required Iterable<DoseOccurrence> earlierOpen,
  required Iterable<DoseOccurrence> context,
  required DateTime now,
  required Duration grace,
}) {
  if (grace <= Duration.zero) return const [];
  final targets = shiftedDoseTargets(
    [...context, ...earlierOpen],
    now: now,
    enabled: true,
    grace: grace,
  );
  return [
    for (final dose in earlierOpen)
      if (_stillTheDoseToTake(dose, targets[dose.id], now)) dose,
  ];
}

bool _stillTheDoseToTake(
  DoseOccurrence dose,
  DateTime? target,
  DateTime now,
) {
  final snoozeUntil = dose.snoozeUntil;
  if (dose.status == 'snoozed' &&
      snoozeUntil != null &&
      snoozeUntil.isAfter(now)) {
    return true;
  }
  return target != null && !target.isBefore(now);
}

void _rememberSlide(
  Map<String, DateTime> targets,
  String id,
  DateTime scheduled,
  DateTime effective,
) {
  if (!effective.isBefore(scheduled.add(const Duration(minutes: 1)))) {
    targets[id] = effective;
  }
}

/// Gap from this dose to the next dose saved for a later minute.
///
/// A second dose in the same minute is the same slot, not the next one.
/// With no later slot, the schedule's own interval is the gap.
Duration _gapUntilNextDose(List<DoseOccurrence> doses, int index) {
  final scheduled = doses[index].scheduledAt;
  for (var later = index + 1; later < doses.length; later++) {
    final gap = doses[later].scheduledAt.difference(scheduled);
    if (gap > Duration.zero) return gap;
  }
  return scheduledDoseInterval(doses[index].schedule, scheduled);
}

/// How full the countdown ring is for a dose due at [target].
///
/// The arc is the share of [interval] already elapsed, so a daily dose an hour
/// away is nearly complete. [interval] is the gap since the previous dose.
double doseRingFraction(DateTime target, DateTime now, Duration interval) {
  if (!target.isAfter(now)) return 1;
  final remaining = target.difference(now);
  if (interval <= Duration.zero || remaining >= interval) return 0.08;
  final elapsed = 1 - remaining.inSeconds / interval.inSeconds;
  return elapsed.clamp(0.08, 1.0);
}

/// Compact remaining time. An hour or more is a whole hour.
///
/// Upcoming time rounds up, so an hour and 48 minutes is `2h`. Overdue time
/// rounds down, so an hour and 30 minutes late is `1h`. Under an hour stays
/// in minutes.
String formatCompactCountdown(
  Duration remaining, {
  required bool overdue,
  String dueNow = 'now',
}) {
  final seconds = remaining.inSeconds.abs();
  if (seconds == 0) return dueNow;
  final elapsedMinutes = seconds ~/ 60;
  final minutes = overdue
      ? (elapsedMinutes == 0 ? 1 : elapsedMinutes)
      : (seconds + 59) ~/ 60;
  final hours = overdue ? minutes ~/ 60 : (minutes + 59) ~/ 60;
  return minutes >= 60 ? '${hours}h' : '${minutes}m';
}

/// Splits doses into two countdown rings. The soonest dose is first.
///
/// Medicines due in that same minute share the outer ring, dotted, with at
/// most [maxSameTime] colors. Every later medicine shares the inner ring,
/// again at most [maxSameTime] colors.
List<ReminderRingGroup> stackReminderRings(
  List<PlannedDose> doses, {
  int maxSameTime = 3,
}) {
  final sorted = [...doses]..sort((a, b) => a.targetAt.compareTo(b.targetAt));
  if (sorted.isEmpty) return const [];
  final soon = <PlannedDose>[sorted.first];
  final others = <PlannedDose>[];
  for (final dose in sorted.skip(1)) {
    final withSoon =
        soon.first.targetAt.difference(dose.targetAt).inSeconds.abs() < 60;
    if (withSoon) {
      if (soon.length < maxSameTime) soon.add(dose);
    } else if (others.length < maxSameTime) {
      others.add(dose);
    }
  }
  return [
    ReminderRingGroup(soon),
    if (others.isNotEmpty) ReminderRingGroup(others),
  ];
}
