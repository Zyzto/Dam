import 'package:blood_pressure_app/domain/medication_unit.dart';
import 'package:blood_pressure_app/domain/medicine.dart';

/// Extra instruction shown with a dose reminder.
enum MedicationDoseTiming {
  /// No additional meal or daypart instruction.
  anytime,

  /// Take before eating.
  beforeFood,

  /// Take with food.
  withFood,

  /// Take after eating.
  afterFood,

  /// Take when waking up.
  onWaking,

  /// Take before going to sleep.
  beforeSleep,
}

/// Lifecycle state for a recurring medication schedule.
enum MedicationScheduleState { active, paused, ended }

/// A recurring instruction for taking a medicine.
class MedicationSchedule {
  const MedicationSchedule({
    this.id,
    required this.medicineId,
    required this.medicine,
    required this.doseAmount,
    required this.doseUnit,
    required this.timeMinutes,
    this.doseTimings = const [],
    required this.weekdays,
    this.startDate,
    this.endDate,
    this.state = MedicationScheduleState.active,
    this.shiftMissedDoseTimes,
  });

  final String? id;
  final String medicineId;
  final Medicine medicine;
  final double doseAmount;
  final MedicationUnit doseUnit;

  /// Minutes after local midnight for each dose time.
  final List<int> timeMinutes;

  /// Optional instruction corresponding to each entry in [timeMinutes].
  ///
  /// Missing entries from older schedules default to [MedicationDoseTiming.anytime].
  final List<MedicationDoseTiming> doseTimings;

  /// Timing instruction associated with a scheduled local minute.
  MedicationDoseTiming timingForMinute(int minute) {
    final index = timeMinutes.indexOf(minute);
    return index < 0 || index >= doseTimings.length
        ? MedicationDoseTiming.anytime
        : doseTimings[index];
  }

  /// ISO weekday numbers, Monday = 1 through Sunday = 7.
  final Set<int> weekdays;
  final DateTime? startDate;
  final DateTime? endDate;
  final MedicationScheduleState state;

  /// Whether a missed dose moves later times for this reminder.
  ///
  /// Null follows the app setting. True forces the move. False keeps the
  /// saved times.
  final bool? shiftMissedDoseTimes;

  /// Whether this schedule currently creates upcoming doses.
  bool get active => state == MedicationScheduleState.active;

  /// The app setting applies when this reminder has no override.
  bool movesAfterMissedDose(bool appSetting) =>
      shiftMissedDoseTimes ?? appSetting;

  /// Returns this schedule with [state] changed.
  MedicationSchedule copyWith({
    MedicationScheduleState? state,
    Object? shiftMissedDoseTimes = _keepShiftOverride,
  }) => MedicationSchedule(
    id: id,
    medicineId: medicineId,
    medicine: medicine,
    doseAmount: doseAmount,
    doseUnit: doseUnit,
    timeMinutes: timeMinutes,
    doseTimings: doseTimings,
    weekdays: weekdays,
    startDate: startDate,
    endDate: endDate,
    state: state ?? this.state,
    shiftMissedDoseTimes: identical(shiftMissedDoseTimes, _keepShiftOverride)
        ? this.shiftMissedDoseTimes
        : shiftMissedDoseTimes as bool?,
  );
}

const _keepShiftOverride = Object();

/// One scheduled dose on a particular local date and time.
class DoseOccurrence {
  const DoseOccurrence({
    required this.id,
    required this.schedule,
    required this.scheduledAt,
    required this.status,
    this.snoozeUntil,
    this.takenAt,
  });

  final String id;
  final MedicationSchedule schedule;
  final DateTime scheduledAt;
  final String status;
  final DateTime? snoozeUntil;
  final DateTime? takenAt;

  /// An unrecorded dose is a missing log, not a claim that the dose was missed.
  String statusAt(DateTime now) {
    if (status == 'snoozed' &&
        snoozeUntil != null &&
        now.isBefore(snoozeUntil!)) {
      return 'snoozed';
    }
    if ((status == 'pending' || status == 'snoozed') &&
        now.isAfter(scheduledAt.add(const Duration(hours: 2)))) {
      return 'unrecorded';
    }
    return status == 'snoozed' ? 'pending' : status;
  }
}

/// The open scheduled dose a manual log should satisfy, if one is close enough.
///
/// [open] rows are still pending, snoozed, or unrecorded. The match is the
/// scheduled time nearest [intakeUnix], and only when it falls inside
/// [windowSeconds].
String? closestOpenDoseId(
  Iterable<({String id, int scheduledUnix})> open,
  int intakeUnix, {
  int windowSeconds = 12 * 60 * 60,
}) {
  String? bestId;
  var bestDistance = windowSeconds + 1;
  for (final row in open) {
    final distance = (row.scheduledUnix - intakeUnix).abs();
    if (distance > windowSeconds || distance >= bestDistance) continue;
    bestDistance = distance;
    bestId = row.id;
  }
  return bestId;
}

/// Stable id for one local dose slot. Matches rows in `dose_occurrences`.
String medicationDoseOccurrenceId(String scheduleId, DateTime localTime) {
  final day = DateTime(localTime.year, localTime.month, localTime.day);
  final minute = localTime.hour * 60 + localTime.minute;
  final key =
      '${day.year.toString().padLeft(4, '0')}-'
      '${day.month.toString().padLeft(2, '0')}-'
      '${day.day.toString().padLeft(2, '0')}';
  return '$scheduleId.$key.$minute';
}
