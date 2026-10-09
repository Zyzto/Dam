import 'package:blood_pressure_app/domain/domain.dart';
import 'package:blood_pressure_app/features/medications/medication_reminder_plan.dart';
import 'package:blood_pressure_app/features/medications/medication_reminder_runtime.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final due = DateTime(2026, 10, 3, 8);

  test('overdue reminders repeat after the dose, skipping times already passed', () {
    expect(
      overdueReminderInstants(
        scheduledAt: due,
        now: DateTime(2026, 10, 3, 7, 50),
        count: 3,
        interval: const Duration(minutes: 10),
      ),
      [
        DateTime(2026, 10, 3, 8, 10),
        DateTime(2026, 10, 3, 8, 20),
        DateTime(2026, 10, 3, 8, 30),
      ],
    );
    expect(
      overdueReminderInstants(
        scheduledAt: due,
        now: DateTime(2026, 10, 3, 8, 15),
        count: 3,
        interval: const Duration(minutes: 10),
      ),
      [DateTime(2026, 10, 3, 8, 20), DateTime(2026, 10, 3, 8, 30)],
    );
    expect(
      overdueReminderInstants(
        scheduledAt: due,
        now: due,
        count: 0,
        interval: const Duration(minutes: 10),
      ),
      isEmpty,
    );
  });

  test('manual logs match the closest open dose inside 12 hours', () {
    expect(
      closestOpenDoseId(
        [
          (id: 'later', scheduledUnix: 1_000 + 30 * 60),
          (id: 'closer', scheduledUnix: 1_000 + 5 * 60),
          (id: 'far', scheduledUnix: 1_000 + 13 * 60 * 60),
        ],
        1_000,
      ),
      'closer',
    );
    expect(closestOpenDoseId(const [], 1_000), isNull);
  });

  PlannedDose dose(String id, DateTime at, {int color = 1}) => PlannedDose(
    scheduleId: id,
    targetAt: at,
    color: color,
    name: id,
    status: 'pending',
  );

  test('show all keeps the soon dose outside and the rest on one ring', () {
    final selected = selectReminderDoses(
      [
        dose('a', DateTime(2026, 10, 3, 9)),
        dose('b', DateTime(2026, 10, 3, 8)),
        dose('c', DateTime(2026, 10, 3, 11)),
        dose('d', DateTime(2026, 10, 3, 12)),
      ],
      showAll: true,
    );
    final rings = stackReminderRings(selected);
    expect(rings, hasLength(2));
    expect(rings.first.doses.single.scheduleId, 'b');
    expect(rings.first.sharesTimer, isFalse);
    expect(rings.last.doses.map((item) => item.scheduleId), ['a', 'c', 'd']);
    expect(rings.last.sharesTimer, isTrue);
  });

  test('doses in the same minute share one dotted ring of up to three colors', () {
    final minute = DateTime(2026, 10, 3, 8);
    final rings = stackReminderRings([
      dose('a', minute, color: 1),
      dose('b', minute.add(const Duration(seconds: 20)), color: 2),
      dose('c', minute.add(const Duration(seconds: 40)), color: 3),
      dose('d', minute.add(const Duration(seconds: 50)), color: 4),
    ]);
    expect(rings, hasLength(1));
    expect(rings.single.sharesTimer, isTrue);
    expect(rings.single.doses.map((item) => item.color), [1, 2, 3]);
  });

  test('the home widget can pin one schedule or the next dose only', () {
    final doses = [
      dose('a', DateTime(2026, 10, 3, 8)),
      dose('a', DateTime(2026, 10, 3, 20)),
      dose('b', DateTime(2026, 10, 3, 9)),
    ];
    expect(
      selectReminderDoses(doses, showAll: true, scheduleId: 'a')
          .map((item) => item.targetAt.hour),
      [8],
    );
    expect(
      selectReminderDoses(doses, showAll: false).single.scheduleId,
      'a',
    );
  });

  test('later doses of the same medicine stay off the rings', () {
    final selected = selectReminderDoses(
      [
        dose('amlodipine', DateTime(2026, 10, 3, 22)),
        dose('amlodipine', DateTime(2026, 10, 4, 22)),
        dose('amlodipine', DateTime(2026, 10, 5, 22)),
        dose('metformin', DateTime(2026, 10, 3, 23)),
      ],
      showAll: true,
    );

    expect(
      selected.map((item) => '${item.scheduleId}-${item.targetAt.day}'),
      ['amlodipine-3', 'metformin-3'],
    );
    final rings = stackReminderRings(selected);
    expect(rings, hasLength(2));
    expect(rings.first.doses.single.name, 'amlodipine');
    expect(rings.last.doses.single.name, 'metformin');
  });

  test('countdown rounds an hour or more to a whole hour', () {
    expect(
      formatCompactCountdown(
        const Duration(hours: 1, minutes: 48),
        overdue: false,
      ),
      '2h',
    );
    expect(
      formatCompactCountdown(const Duration(hours: 2), overdue: false),
      '2h',
    );
    expect(
      formatCompactCountdown(const Duration(minutes: 45), overdue: false),
      '45m',
    );
    expect(
      formatCompactCountdown(
        const Duration(hours: 1, minutes: 30),
        overdue: true,
      ),
      '1h',
    );
    expect(
      formatCompactCountdown(
        const Duration(hours: 13, minutes: 29),
        overdue: true,
      ),
      '13h',
    );
    expect(formatCompactCountdown(Duration.zero, overdue: false), 'now');

    final daily = MedicationSchedule(
      medicineId: 'amlodipine',
      medicine: Medicine(designation: 'Amlodipine'),
      doseAmount: 5,
      doseUnit: MedicationUnit.mg,
      timeMinutes: const [22 * 60],
      weekdays: const {1, 2, 3, 4, 5, 6, 7},
    );
    final target = DateTime(2026, 10, 3, 22);
    final now = DateTime(2026, 10, 3, 20, 12);
    final interval = scheduledDoseInterval(daily, target);
    expect(interval, const Duration(hours: 24));
    expect(
      doseRingFraction(target, now, interval),
      closeTo(1 - (108 * 60) / (24 * 3600), 0.0001),
    );

    final twice = MedicationSchedule(
      medicineId: 'metformin',
      medicine: Medicine(designation: 'Metformin'),
      doseAmount: 500,
      doseUnit: MedicationUnit.mg,
      timeMinutes: const [10 * 60, 22 * 60],
      weekdays: const {1, 2, 3, 4, 5, 6, 7},
    );
    expect(
      scheduledDoseInterval(twice, DateTime(2026, 10, 3, 22)),
      const Duration(hours: 12),
    );
    expect(
      scheduledDoseInterval(twice, DateTime(2026, 10, 3, 10)),
      const Duration(hours: 12),
    );
  });

  test('widget catalog keeps a view for every medicine', () {
    final catalog = medicationWidgetCatalog(
      [
        PlannedDose(
          scheduleId: 'a',
          targetAt: DateTime(2026, 10, 3, 23, 30),
          color: 1,
          name: 'Aspirin',
          status: 'pending',
        ),
      ],
      showAll: true,
      schedules: [
        MedicationSchedule(
          id: 'a',
          medicineId: 'a',
          medicine: const Medicine(designation: 'Aspirin'),
          doseAmount: 81,
          doseUnit: MedicationUnit.mg,
          timeMinutes: const [23 * 60 + 30],
          weekdays: const {1, 2, 3, 4, 5, 6, 7},
        ),
        MedicationSchedule(
          id: 'b',
          medicineId: 'b',
          medicine: const Medicine(designation: 'Metformin'),
          doseAmount: 500,
          doseUnit: MedicationUnit.mg,
          timeMinutes: const [8 * 60],
          weekdays: const {1, 2, 3, 4, 5, 6, 7},
        ),
      ],
      labels: const {'showsAll': 'All medicines'},
    );
    final choices = catalog['choices']! as List<Map<String, String>>;
    expect(choices.map((choice) => choice['name']), [
      'All medicines',
      'Aspirin',
      'Metformin',
    ]);
    final views = catalog['views']! as Map;
    expect(views['']['name'], 'Aspirin');
    expect(views['a']['name'], 'Aspirin');
    expect(views['b']['name'], 'Metformin');
    expect(views['b'].containsKey('scheduledAtMs'), isFalse);
  });

  DoseOccurrence slot(
    String id,
    DateTime at, {
    String medicineId = 'med',
    String? scheduleId,
    String status = 'pending',
    DateTime? takenAt,
    DateTime? snoozeUntil,
    List<int> times = const [8 * 60, 20 * 60],
  }) {
    return DoseOccurrence(
      id: id,
      schedule: MedicationSchedule(
        id: scheduleId,
        medicineId: medicineId,
        medicine: Medicine(designation: medicineId.isEmpty ? id : medicineId),
        doseAmount: 1,
        doseUnit: MedicationUnit.mg,
        timeMinutes: times,
        weekdays: const {1, 2, 3, 4, 5, 6, 7},
      ),
      scheduledAt: at,
      status: status,
      takenAt: takenAt,
      snoozeUntil: snoozeUntil,
    );
  }

  const grace = Duration(minutes: 60);

  test('a dose still inside the limit keeps its saved time', () {
    final morning = DateTime(2026, 10, 3, 8);
    final evening = DateTime(2026, 10, 3, 20);
    final targets = shiftedDoseTargets(
      [
        slot('morning', morning),
        slot('evening', evening),
      ],
      now: DateTime(2026, 10, 3, 8, 40),
      enabled: true,
      grace: grace,
    );
    expect(targets, isEmpty);
  });

  test('past the limit, the missed dose is due now and the next one slides', () {
    final morning = DateTime(2026, 10, 3, 8);
    final evening = DateTime(2026, 10, 3, 20);
    final now = DateTime(2026, 10, 3, 10, 30);
    final targets = shiftedDoseTargets(
      [
        slot('morning', morning),
        slot('evening', evening),
      ],
      now: now,
      enabled: true,
      grace: grace,
    );
    expect(targets['morning'], now);
    expect(targets['evening'], DateTime(2026, 10, 3, 22, 30));
  });

  test('a late taken dose slides the next dose and an on-time dose clears it', () {
    final morning = DateTime(2026, 10, 3, 8);
    final evening = DateTime(2026, 10, 3, 20);
    final nextMorning = DateTime(2026, 10, 4, 8);
    final takenLate = shiftedDoseTargets(
      [
        slot(
          'morning',
          morning,
          status: 'taken',
          takenAt: DateTime(2026, 10, 3, 10, 30),
        ),
        slot('evening', evening),
        slot('next', nextMorning),
      ],
      now: DateTime(2026, 10, 3, 12),
      enabled: true,
      grace: grace,
    );
    expect(takenLate.containsKey('morning'), isFalse);
    expect(takenLate['evening'], DateTime(2026, 10, 3, 22, 30));
    expect(takenLate['next'], DateTime(2026, 10, 4, 10, 30));

    final backOnTime = shiftedDoseTargets(
      [
        slot(
          'morning',
          morning,
          status: 'taken',
          takenAt: DateTime(2026, 10, 3, 10, 30),
        ),
        slot(
          'evening',
          evening,
          status: 'taken',
          takenAt: DateTime(2026, 10, 3, 20, 20),
        ),
        slot('next', nextMorning),
      ],
      now: DateTime(2026, 10, 3, 21),
      enabled: true,
      grace: grace,
    );
    expect(backOnTime, isEmpty);
  });

  test('a miss closer to the next dose does not move that next dose', () {
    final morning = DateTime(2026, 10, 3, 8);
    final evening = DateTime(2026, 10, 3, 20);
    final targets = shiftedDoseTargets(
      [
        slot('morning', morning),
        slot('evening', evening),
      ],
      now: DateTime(2026, 10, 3, 15),
      enabled: true,
      grace: grace,
    );
    expect(targets, isEmpty);
  });

  test('one medicine sliding does not move another', () {
    final now = DateTime(2026, 10, 3, 10);
    final targets = shiftedDoseTargets(
      [
        slot('a-morning', DateTime(2026, 10, 3, 8), medicineId: 'a'),
        slot('b-morning', DateTime(2026, 10, 3, 9), medicineId: 'b'),
      ],
      now: now,
      enabled: true,
      grace: grace,
    );
    expect(targets['a-morning'], now);
    expect(targets.containsKey('b-morning'), isFalse);
  });

  test('the shift stays off until the setting is on', () {
    final now = DateTime(2026, 10, 3, 12);
    final morning = slot('morning', DateTime(2026, 10, 3, 8));
    final evening = slot('evening', DateTime(2026, 10, 3, 20));
    final yesterday = slot(
      'yesterday',
      DateTime(2026, 10, 2, 8),
      status: 'pending',
    );
    final takenLate = slot(
      'taken',
      DateTime(2026, 10, 3, 8),
      status: 'taken',
      takenAt: DateTime(2026, 10, 3, 11),
    );
    final anchors = <String, DateTime>{};
    final targets = shiftedDoseTargets(
      [morning, evening, yesterday, takenLate],
      now: now,
      enabled: false,
      grace: grace,
      followUpFrom: anchors,
    );

    expect(targets, isEmpty);
    expect(anchors, isEmpty);
    expect(doseTakeAt(morning, now, targets), morning.scheduledAt);
    expect(doseTakeAt(evening, now, targets), evening.scheduledAt);
    expect(doseTakeAt(takenLate, now, targets), takenLate.scheduledAt);
    expect(
      reminderHorizonDays(shiftMissedDoseTimes: false, grace: grace),
      savedReminderHorizonDays,
    );
    expect(
      reminderHorizonDays(
        shiftMissedDoseTimes: true,
        grace: Duration.zero,
      ),
      savedReminderHorizonDays,
    );
    expect(
      dosesForReminderList(
        history: [yesterday, takenLate],
        upcoming: [morning, evening],
        now: now,
        shiftMissedDoseTimes: false,
        grace: grace,
      ),
      [morning, evening],
    );

    final moved = shiftedDoseTargets(
      [morning, evening],
      now: now,
      enabled: true,
      grace: grace,
    );
    expect(moved['morning'], now);
    expect(moved['evening'], DateTime(2026, 10, 4));
  });

  test('edges around the limit and the halfway point', () {
    final morning = DateTime(2026, 10, 3, 8);
    final evening = DateTime(2026, 10, 3, 20);
    Map<String, DateTime> at(DateTime now) => shiftedDoseTargets(
      [slot('morning', morning), slot('evening', evening)],
      now: now,
      enabled: true,
      grace: grace,
    );

    expect(at(DateTime(2026, 10, 3, 9)), isEmpty);
    expect(at(DateTime(2026, 10, 3, 9, 1))['morning'], DateTime(2026, 10, 3, 9, 1));
    expect(at(DateTime(2026, 10, 3, 9, 1))['evening'], DateTime(2026, 10, 3, 21, 1));
    expect(at(DateTime(2026, 10, 3, 13, 59))['evening'], DateTime(2026, 10, 4, 1, 59));
    expect(at(DateTime(2026, 10, 3, 14)), isEmpty);
    expect(
      shiftedDoseTargets(const [], now: morning, enabled: true, grace: grace),
      isEmpty,
    );
    expect(
      at(DateTime(2026, 10, 3, 10)).isEmpty,
      isFalse,
    );
    expect(
      shiftedDoseTargets(
        [slot('morning', morning), slot('evening', evening)],
        now: DateTime(2026, 10, 3, 10),
        enabled: true,
        grace: Duration.zero,
      ),
      isEmpty,
    );
  });

  test('a limit longer than half the gap never moves the next dose', () {
    final targets = shiftedDoseTargets(
      [
        slot('early', DateTime(2026, 10, 3, 8), times: const [8 * 60, 10 * 60]),
        slot('next', DateTime(2026, 10, 3, 10), times: const [8 * 60, 10 * 60]),
      ],
      now: DateTime(2026, 10, 3, 9, 31),
      enabled: true,
      grace: const Duration(minutes: 90),
    );
    expect(targets, isEmpty);
  });

  test('early, missing, and exact-limit takes do not slide later doses', () {
    final morning = DateTime(2026, 10, 3, 8);
    final evening = DateTime(2026, 10, 3, 20);
    Map<String, DateTime> taken(DateTime? takenAt) => shiftedDoseTargets(
      [
        slot('morning', morning, status: 'taken', takenAt: takenAt),
        slot('evening', evening),
      ],
      now: DateTime(2026, 10, 3, 12),
      enabled: true,
      grace: grace,
    );

    expect(taken(DateTime(2026, 10, 3, 7, 30)), isEmpty);
    expect(taken(null), isEmpty);
    expect(taken(DateTime(2026, 10, 3, 9)), isEmpty);
    expect(taken(DateTime(2026, 10, 3, 9, 1))['evening'], DateTime(2026, 10, 3, 21, 1));
  });

  test('a skip clears a slide and a snooze does not become a new time', () {
    final morning = DateTime(2026, 10, 3, 8);
    final evening = DateTime(2026, 10, 3, 20);
    final nextMorning = DateTime(2026, 10, 4, 8);
    final skipped = shiftedDoseTargets(
      [
        slot(
          'morning',
          morning,
          status: 'taken',
          takenAt: DateTime(2026, 10, 3, 10, 30),
        ),
        slot('evening', evening, status: 'skipped'),
        slot('next', nextMorning),
      ],
      now: DateTime(2026, 10, 3, 21),
      enabled: true,
      grace: grace,
    );
    expect(skipped, isEmpty);

    final snoozed = shiftedDoseTargets(
      [
        slot(
          'morning',
          morning,
          status: 'taken',
          takenAt: DateTime(2026, 10, 3, 10, 30),
        ),
        slot(
          'evening',
          evening,
          status: 'snoozed',
          snoozeUntil: DateTime(2026, 10, 3, 21),
        ),
        slot('next', nextMorning),
      ],
      now: DateTime(2026, 10, 3, 18),
      enabled: true,
      grace: grace,
    );
    expect(snoozed.containsKey('evening'), isFalse);
    expect(snoozed['next'], DateTime(2026, 10, 4, 10, 30));

    final snoozeOnly = shiftedDoseTargets(
      [
        slot(
          'morning',
          morning,
          status: 'snoozed',
          snoozeUntil: DateTime(2026, 10, 3, 8, 10),
        ),
        slot('evening', evening),
      ],
      now: DateTime(2026, 10, 3, 8, 5),
      enabled: true,
      grace: grace,
    );
    expect(snoozeOnly, isEmpty);
  });

  test('an expired snooze is open again', () {
    final now = DateTime(2026, 10, 3, 10, 30);
    final targets = shiftedDoseTargets(
      [
        slot(
          'morning',
          DateTime(2026, 10, 3, 8),
          status: 'snoozed',
          snoozeUntil: DateTime(2026, 10, 3, 9),
        ),
        slot('evening', DateTime(2026, 10, 3, 20)),
      ],
      now: now,
      enabled: true,
      grace: grace,
    );
    expect(targets['morning'], now);
    expect(targets['evening'], DateTime(2026, 10, 3, 22, 30));
  });

  test('a late take keeps the gap even when that passes the next clock time', () {
    final targets = shiftedDoseTargets(
      [
        slot(
          'first',
          DateTime(2026, 10, 3, 8),
          status: 'taken',
          takenAt: DateTime(2026, 10, 3, 13),
          times: const [8 * 60, 12 * 60, 14 * 60],
        ),
        slot('second', DateTime(2026, 10, 3, 12), times: const [8 * 60, 12 * 60, 14 * 60]),
        slot('third', DateTime(2026, 10, 3, 14), times: const [8 * 60, 12 * 60, 14 * 60]),
      ],
      now: DateTime(2026, 10, 3, 13, 10),
      enabled: true,
      grace: grace,
    );
    expect(targets['second'], DateTime(2026, 10, 3, 17));
    expect(targets['third'], DateTime(2026, 10, 3, 19));
  });

  test('doses saved for the same minute stay together', () {
    final now = DateTime(2026, 10, 3, 10, 30);
    final targets = shiftedDoseTargets(
      [
        slot('b', DateTime(2026, 10, 3, 8)),
        slot('later', DateTime(2026, 10, 3, 20)),
        slot('a', DateTime(2026, 10, 3, 8)),
      ],
      now: now,
      enabled: true,
      grace: grace,
    );
    expect(targets['a'], now);
    expect(targets['b'], now);
    expect(targets['later'], DateTime(2026, 10, 3, 22, 30));
  });

  test('past halfway a previous slide stays and the dose after it does not', () {
    final targets = shiftedDoseTargets(
      [
        slot(
          'morning',
          DateTime(2026, 10, 3, 8),
          status: 'taken',
          takenAt: DateTime(2026, 10, 3, 10, 30),
        ),
        slot('evening', DateTime(2026, 10, 3, 20)),
        slot('next', DateTime(2026, 10, 4, 8)),
      ],
      now: DateTime(2026, 10, 4, 5),
      enabled: true,
      grace: grace,
    );
    expect(targets['evening'], DateTime(2026, 10, 3, 22, 30));
    expect(targets.containsKey('next'), isFalse);
  });

  test('an old miss past halfway does not move today, a late take does', () {
    final missedYesterday = shiftedDoseTargets(
      [
        slot('yesterday', DateTime(2026, 10, 2, 8)),
        slot('tonight', DateTime(2026, 10, 3, 20)),
      ],
      now: DateTime(2026, 10, 3, 10),
      enabled: true,
      grace: grace,
    );
    expect(missedYesterday, isEmpty);

    final takenEarlier = shiftedDoseTargets(
      [
        slot(
          'monday',
          DateTime(2026, 10, 5, 8),
          status: 'taken',
          takenAt: DateTime(2026, 10, 5, 11),
          times: const [8 * 60],
        ),
        slot('next-monday', DateTime(2026, 10, 12, 8), times: const [8 * 60]),
      ],
      now: DateTime(2026, 10, 8, 9),
      enabled: true,
      grace: grace,
    );
    expect(takenEarlier['next-monday'], DateTime(2026, 10, 12, 11));
  });

  test('a slid dose that passes the limit becomes due now', () {
    final now = DateTime(2026, 10, 3, 23, 40);
    final targets = shiftedDoseTargets(
      [
        slot(
          'morning',
          DateTime(2026, 10, 3, 8),
          status: 'taken',
          takenAt: DateTime(2026, 10, 3, 10, 30),
        ),
        slot('evening', DateTime(2026, 10, 3, 20)),
        slot('next', DateTime(2026, 10, 4, 8)),
      ],
      now: now,
      enabled: true,
      grace: grace,
    );
    expect(targets['evening'], now);
    expect(targets['next'], DateTime(2026, 10, 4, 11, 40));
  });

  test('input order and duplicate ids do not change the result', () {
    final morning = DateTime(2026, 10, 3, 8);
    final evening = DateTime(2026, 10, 3, 20);
    final now = DateTime(2026, 10, 3, 10, 30);
    final shuffled = shiftedDoseTargets(
      [slot('evening', evening), slot('morning', morning)],
      now: now,
      enabled: true,
      grace: grace,
    );
    expect(shuffled['morning'], now);
    expect(shuffled['evening'], DateTime(2026, 10, 3, 22, 30));

    final duplicate = shiftedDoseTargets(
      [
        slot(
          'morning',
          morning,
          status: 'taken',
          takenAt: DateTime(2026, 10, 3, 11),
        ),
        slot(
          'morning',
          morning,
          status: 'taken',
          takenAt: DateTime(2026, 10, 3, 8, 10),
        ),
        slot('evening', evening),
      ],
      now: DateTime(2026, 10, 3, 12),
      enabled: true,
      grace: grace,
    );
    expect(duplicate, isEmpty);
  });

  test('schedules for one medicine slide together and others do not', () {
    final now = DateTime(2026, 10, 3, 10, 30);
    final shared = shiftedDoseTargets(
      [
        slot('am', DateTime(2026, 10, 3, 8), medicineId: 'same', scheduleId: 'a'),
        slot('pm', DateTime(2026, 10, 3, 20), medicineId: 'same', scheduleId: 'b'),
      ],
      now: now,
      enabled: true,
      grace: grace,
    );
    expect(shared['pm'], DateTime(2026, 10, 3, 22, 30));

    final separate = shiftedDoseTargets(
      [
        slot('am', DateTime(2026, 10, 3, 8), medicineId: '', scheduleId: 'a'),
        slot('pm', DateTime(2026, 10, 3, 20), medicineId: '', scheduleId: 'b'),
      ],
      now: now,
      enabled: true,
      grace: grace,
    );
    expect(separate.containsKey('pm'), isFalse);
  });

  test('a once-daily dose slides tomorrow only before the halfway point', () {
    final today = DateTime(2026, 10, 3, 8);
    final tomorrow = DateTime(2026, 10, 4, 8);
    final doses = [
      slot('today', today, times: const [8 * 60]),
      slot('tomorrow', tomorrow, times: const [8 * 60]),
    ];
    final before = shiftedDoseTargets(
      doses,
      now: DateTime(2026, 10, 3, 10, 30),
      enabled: true,
      grace: grace,
    );
    expect(before['today'], DateTime(2026, 10, 3, 10, 30));
    expect(before['tomorrow'], DateTime(2026, 10, 4, 10, 30));

    final after = shiftedDoseTargets(
      doses,
      now: DateTime(2026, 10, 3, 21),
      enabled: true,
      grace: grace,
    );
    expect(after, isEmpty);
  });

  test('a taken, skipped, or snoozed dose does not get its clock alarm back', () {
    final at = DateTime(2026, 10, 3, 20);
    final now = DateTime(2026, 10, 3, 10);
    expect(
      doseClockAlarmClaimed(
        slot('taken', at, status: 'taken', takenAt: now),
        now,
      ),
      isTrue,
    );
    expect(
      doseClockAlarmClaimed(slot('skipped', at, status: 'skipped'), now),
      isTrue,
    );
    expect(doseClockAlarmClaimed(slot('open', at), now), isFalse);
    expect(doseClockAlarmClaimed(null, now), isFalse);
    expect(
      doseClockAlarmClaimed(
        slot(
          'snoozed',
          at,
          status: 'snoozed',
          snoozeUntil: DateTime(2026, 10, 3, 10, 30),
        ),
        now,
      ),
      isTrue,
    );
    expect(
      doseClockAlarmClaimed(
        slot(
          'expired',
          at,
          status: 'snoozed',
          snoozeUntil: DateTime(2026, 10, 3, 9, 30),
        ),
        now,
      ),
      isFalse,
    );
  });

  test('a weekly miss from before today stays due until halfway', () {
    final monday = DateTime(2026, 10, 5, 8);
    final nextMonday = DateTime(2026, 10, 12, 8);
    final now = DateTime(2026, 10, 6, 10);
    final stillDue = earlierOpenDosesStillDue(
      earlierOpen: [slot('monday', monday, times: const [8 * 60])],
      context: [slot('next', nextMonday, times: const [8 * 60])],
      now: now,
      grace: grace,
    );
    expect(stillDue.map((dose) => dose.id), ['monday']);
  });

  test('a daily miss from yesterday drops off once it is past halfway', () {
    final yesterday = DateTime(2026, 10, 5, 8);
    final today = DateTime(2026, 10, 6, 8);
    final now = DateTime(2026, 10, 6, 10);
    final stillDue = earlierOpenDosesStillDue(
      earlierOpen: [slot('yesterday', yesterday, times: const [8 * 60])],
      context: [slot('today', today, times: const [8 * 60])],
      now: now,
      grace: grace,
    );
    expect(stillDue, isEmpty);
  });

  test('a snooze from before today stays while it is still running', () {
    final yesterday = DateTime(2026, 10, 5, 8);
    final now = DateTime(2026, 10, 6, 10);
    final stillDue = earlierOpenDosesStillDue(
      earlierOpen: [
        slot(
          'snoozed',
          yesterday,
          status: 'snoozed',
          snoozeUntil: DateTime(2026, 10, 6, 11),
          times: const [8 * 60],
        ),
      ],
      context: [slot('today', DateTime(2026, 10, 6, 8), times: const [8 * 60])],
      now: now,
      grace: grace,
    );
    expect(stillDue.map((dose) => dose.id), ['snoozed']);

    final expired = earlierOpenDosesStillDue(
      earlierOpen: [
        slot(
          'expired',
          yesterday,
          status: 'snoozed',
          snoozeUntil: DateTime(2026, 10, 5, 9),
          times: const [8 * 60],
        ),
      ],
      context: [slot('today', DateTime(2026, 10, 6, 8), times: const [8 * 60])],
      now: now,
      grace: grace,
    );
    expect(expired, isEmpty);
  });

  test('a due dose keeps the same follow-up start as time passes', () {
    final morning = DateTime(2026, 10, 3, 8);
    final evening = DateTime(2026, 10, 3, 20);
    final doses = [slot('morning', morning), slot('evening', evening)];
    final first = <String, DateTime>{};
    final later = <String, DateTime>{};
    shiftedDoseTargets(
      doses,
      now: DateTime(2026, 10, 3, 10),
      enabled: true,
      grace: grace,
      followUpFrom: first,
    );
    shiftedDoseTargets(
      doses,
      now: DateTime(2026, 10, 3, 10, 5),
      enabled: true,
      grace: grace,
      followUpFrom: later,
    );
    expect(first['morning'], DateTime(2026, 10, 3, 9));
    expect(later['morning'], first['morning']);
  });

  test('a slid dose follows up from the moved limit, not the saved one', () {
    final anchors = <String, DateTime>{};
    shiftedDoseTargets(
      [
        slot(
          'morning',
          DateTime(2026, 10, 3, 8),
          status: 'taken',
          takenAt: DateTime(2026, 10, 3, 11),
        ),
        slot('evening', DateTime(2026, 10, 3, 20)),
      ],
      now: DateTime(2026, 10, 4, 0, 30),
      enabled: true,
      grace: grace,
      followUpFrom: anchors,
    );
    expect(anchors['evening'], DateTime(2026, 10, 4, 0));
  });

  test('a dose saved before today still needs an alarm after it moves ahead', () {
    final yesterday = DateTime(2026, 10, 2, 20);
    final movedTo = DateTime(2026, 10, 3, 1);
    final now = DateTime(2026, 10, 3, 0, 30);
    expect(
      earlierDoseAlarmMovedAhead(
        scheduledAt: yesterday,
        movedTo: movedTo,
        now: now,
      ),
      isTrue,
    );
    expect(
      earlierDoseAlarmMovedAhead(
        scheduledAt: DateTime(2026, 10, 3, 8),
        movedTo: DateTime(2026, 10, 3, 11),
        now: now,
      ),
      isFalse,
    );
    expect(
      earlierDoseAlarmMovedAhead(
        scheduledAt: yesterday,
        movedTo: null,
        now: now,
      ),
      isFalse,
    );
  });

  test('a late take stops sliding once a later dose passes halfway', () {
    final times = [8 * 60 + 42, 23 * 60 + 30];
    final doses = <DoseOccurrence>[];
    for (var offset = -6; offset < 7; offset++) {
      final day = DateTime(2026, 10, 9).add(Duration(days: offset));
      final atMorning = DateTime(day.year, day.month, day.day, 8, 42);
      final atEvening = DateTime(day.year, day.month, day.day, 23, 30);
      doses.add(
        slot(
          'am$offset',
          atMorning,
          times: times,
          status: offset == -6 ? 'taken' : 'pending',
          takenAt: offset == -6 ? DateTime(2026, 10, 3, 21, 36) : null,
        ),
      );
      doses.add(slot('pm$offset', atEvening, times: times));
    }
    final now = DateTime(2026, 10, 9, 23, 59);
    final firstDay = DateTime(2026, 10, 9);
    final listed = dosesForReminderList(
      history: [
        for (final dose in doses)
          if (dose.scheduledAt.isBefore(firstDay)) dose,
      ],
      upcoming: [
        for (final dose in doses)
          if (!dose.scheduledAt.isBefore(firstDay)) dose,
      ],
      now: now,
      shiftMissedDoseTimes: true,
      grace: grace,
    );
    final targets = shiftedDoseTargets(
      listed,
      now: now,
      enabled: true,
      grace: grace,
    );
    final morning = listed.firstWhere((dose) => dose.id == 'am0');
    final evening = listed.firstWhere((dose) => dose.id == 'pm0');
    expect(targets.containsKey('am0'), isFalse);
    expect(targets.containsKey('pm0'), isFalse);
    expect(doseTakeAt(morning, now, targets), morning.scheduledAt);
    expect(doseTakeAt(evening, now, targets), evening.scheduledAt);
    expect(reminderDoseIsCurrent(morning, now, targets, grace: grace), isTrue);
    expect(
      reminderDoseIsCurrent(
        listed.firstWhere((dose) => dose.id == 'am-1'),
        now,
        targets,
        grace: grace,
      ),
      isFalse,
    );

    final justAfterMidnight = DateTime(2026, 10, 10, 0, 10);
    final afterMidnight = shiftedDoseTargets(
      listed,
      now: justAfterMidnight,
      enabled: true,
      grace: grace,
    );
    final lastNight = listed.firstWhere((dose) => dose.id == 'pm0');
    expect(afterMidnight.containsKey('pm0'), isFalse);
    expect(
      reminderDoseIsCurrent(lastNight, justAfterMidnight, afterMidnight, grace: grace),
      isTrue,
    );
    expect(
      reminderDoseIsCurrent(
        lastNight,
        DateTime(2026, 10, 10, 5),
        shiftedDoseTargets(
          listed,
          now: DateTime(2026, 10, 10, 5),
          enabled: true,
          grace: grace,
        ),
        grace: grace,
      ),
      isFalse,
    );
  });

  test('a running snooze is the take-time, even when the dose also slid', () {
    final now = DateTime(2026, 10, 3, 10);
    final dose = slot(
      'morning',
      DateTime(2026, 10, 3, 8),
      status: 'snoozed',
      snoozeUntil: DateTime(2026, 10, 3, 10, 30),
    );
    expect(
      doseTakeAt(dose, now, {'morning': DateTime(2026, 10, 3, 11)}),
      DateTime(2026, 10, 3, 10, 30),
    );
    final expired = slot(
      'morning',
      DateTime(2026, 10, 3, 8),
      status: 'snoozed',
      snoozeUntil: DateTime(2026, 10, 3, 9, 30),
    );
    expect(
      doseTakeAt(expired, now, {'morning': DateTime(2026, 10, 3, 11)}),
      DateTime(2026, 10, 3, 11),
    );
  });
}
