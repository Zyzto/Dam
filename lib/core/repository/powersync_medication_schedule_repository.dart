import 'dart:convert';

import 'package:blood_pressure_app/core/repository/powersync_medicine_repository.dart';
import 'package:blood_pressure_app/domain/domain.dart';
import 'package:powersync/powersync.dart';
import 'package:uuid/uuid.dart';

/// PowerSync implementation of [MedicationScheduleRepository].
class PowerSyncMedicationScheduleRepository
    implements MedicationScheduleRepository {
  PowerSyncMedicationScheduleRepository(this._db, this._intakes)
    : _medicines = PowerSyncMedicineRepository(_db);

  final PowerSyncDatabase _db;
  final PowerSyncMedicineRepository _medicines;
  final MedicineIntakeRepository _intakes;
  final _uuid = const Uuid();

  @override
  Future<List<MedicationSchedule>> getAll() async {
    final rows = await _db.getAll(
      'SELECT s.id, s.med_id, s.dose_amount, s.dose_unit, '
      's.time_minutes_json, s.dose_timings_json, s.weekdays_mask, '
      's.start_date, s.end_date, '
      's.active, s.ended, m.designation, m.color, m.default_dose_mg, '
      'm.dose_unit AS medicine_unit '
      'FROM medication_schedules s JOIN medicines m ON m.id = s.med_id '
      'ORDER BY s.active DESC, s.ended ASC, m.designation COLLATE NOCASE',
    );
    return [for (final row in rows) _scheduleFromRow(row)];
  }

  @override
  Future<MedicationSchedule> save(MedicationSchedule schedule) async {
    final medId = schedule.medicineId.isEmpty
        ? await _medicines.idFor(schedule.medicine)
        : schedule.medicineId;
    if (medId == null) throw StateError('Medicine is not in the catalog');

    final id = schedule.id ?? _uuid.v4();
    final weekdaysMask = schedule.weekdays.fold<int>(
      0,
      (mask, day) => mask | (1 << (day - 1)),
    );
    final doseTimings = List<MedicationDoseTiming>.generate(
      schedule.timeMinutes.length,
      (index) => index < schedule.doseTimings.length
          ? schedule.doseTimings[index]
          : MedicationDoseTiming.anytime,
    );
    final values = [
      medId,
      schedule.doseAmount,
      schedule.doseUnit.name,
      jsonEncode(schedule.timeMinutes),
      jsonEncode([for (final timing in doseTimings) timing.name]),
      weekdaysMask,
      _dateKey(schedule.startDate),
      _dateKey(schedule.endDate),
      schedule.active ? 1 : 0,
      schedule.state == MedicationScheduleState.ended ? 1 : 0,
    ];
    final existing = await _db.getAll(
      'SELECT id FROM medication_schedules WHERE id = ?',
      [id],
    );
    if (existing.isEmpty) {
      await _db.execute(
        'INSERT INTO medication_schedules '
        '(id, med_id, dose_amount, dose_unit, time_minutes_json, '
        'dose_timings_json, weekdays_mask, '
        'start_date, end_date, active, ended) '
        'VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)',
        [id, ...values],
      );
    } else {
      await _db.execute(
        'UPDATE medication_schedules SET med_id = ?, dose_amount = ?, dose_unit = ?, '
        'time_minutes_json = ?, dose_timings_json = ?, weekdays_mask = ?, '
        'start_date = ?, end_date = ?, '
        'active = ?, ended = ? WHERE id = ?',
        [...values, id],
      );
      await _db.execute(
        "DELETE FROM dose_occurrences WHERE schedule_id = ? AND status IN ('pending', 'snoozed')",
        [id],
      );
    }
    return MedicationSchedule(
      id: id,
      medicineId: medId,
      medicine: schedule.medicine,
      doseAmount: schedule.doseAmount,
      doseUnit: schedule.doseUnit,
      timeMinutes: schedule.timeMinutes,
      doseTimings: doseTimings,
      weekdays: schedule.weekdays,
      startDate: schedule.startDate,
      endDate: schedule.endDate,
      state: schedule.state,
    );
  }

  @override
  Future<List<DoseOccurrence>> getOccurrences(DateTime date) async {
    final day = DateTime(date.year, date.month, date.day);
    final dayKey = _dateKey(day)!;
    final schedules = await getAll();
    for (final schedule in schedules.where((schedule) => schedule.active)) {
      if (schedule.id == null || !schedule.weekdays.contains(day.weekday))
        continue;
      if (schedule.startDate != null && day.isBefore(_day(schedule.startDate!)))
        continue;
      if (schedule.endDate != null && day.isAfter(_day(schedule.endDate!)))
        continue;
      for (final minute in schedule.timeMinutes) {
        final localKey = '$dayKey/$minute';
        final scheduledAt = day.add(Duration(minutes: minute));
        final occurrenceId = medicationDoseOccurrenceId(schedule.id!, scheduledAt);
        final existing = await _db.getAll(
          'SELECT id FROM dose_occurrences WHERE id = ?',
          [occurrenceId],
        );
        if (existing.isNotEmpty) continue;
        await _db.execute(
          'INSERT INTO dose_occurrences '
          '(id, schedule_id, local_key, scheduled_unix_s, status) '
          'VALUES (?, ?, ?, ?, ?)',
          [
            occurrenceId,
            schedule.id,
            localKey,
            scheduledAt.millisecondsSinceEpoch ~/ 1000,
            'pending',
          ],
        );
      }
    }

    final start = day.millisecondsSinceEpoch ~/ 1000;
    final end = day.add(const Duration(days: 1)).millisecondsSinceEpoch ~/ 1000;
    final rows = await _db.getAll(
      'SELECT o.id AS occurrence_id, o.scheduled_unix_s, o.status, '
      'o.snooze_until_unix_s, o.taken_at_unix_s, '
      's.id AS schedule_id, s.med_id, s.dose_amount, s.dose_unit, '
      's.time_minutes_json, s.dose_timings_json, s.weekdays_mask, '
      's.start_date, s.end_date, s.active, s.ended, '
      'm.designation, m.color, m.default_dose_mg, m.dose_unit AS medicine_unit '
      'FROM dose_occurrences o '
      'JOIN medication_schedules s ON s.id = o.schedule_id '
      'JOIN medicines m ON m.id = s.med_id '
      'WHERE o.scheduled_unix_s >= ? AND o.scheduled_unix_s < ? AND s.active = 1 '
      'ORDER BY o.scheduled_unix_s',
      [start, end],
    );
    return [
      for (final row in rows)
        DoseOccurrence(
          id: row['occurrence_id'] as String,
          schedule: _scheduleFromRow(row),
          scheduledAt: DateTime.fromMillisecondsSinceEpoch(
            (row['scheduled_unix_s'] as int) * 1000,
          ),
          status: row['status'] as String,
          snoozeUntil: _dateTime(row['snooze_until_unix_s']),
          takenAt: _dateTime(row['taken_at_unix_s']),
        ),
    ];
  }

  @override
  Future<List<DoseOccurrence>> getTakenOccurrences(DateRange range) async {
    final rows = await _db.getAll(
      'SELECT o.id AS occurrence_id, o.scheduled_unix_s, o.status, '
      'o.snooze_until_unix_s, o.taken_at_unix_s, '
      's.id AS schedule_id, s.med_id, s.dose_amount, s.dose_unit, '
      's.time_minutes_json, s.dose_timings_json, s.weekdays_mask, '
      's.start_date, s.end_date, s.active, s.ended, '
      'm.designation, m.color, m.default_dose_mg, m.dose_unit AS medicine_unit '
      'FROM dose_occurrences o '
      'JOIN medication_schedules s ON s.id = o.schedule_id '
      'JOIN medicines m ON m.id = s.med_id '
      "WHERE o.scheduled_unix_s BETWEEN ? AND ? AND o.status = 'taken' "
      'AND o.taken_at_unix_s IS NOT NULL '
      'ORDER BY o.scheduled_unix_s',
      [range.startStamp, range.endStamp],
    );
    return [
      for (final row in rows)
        DoseOccurrence(
          id: row['occurrence_id'] as String,
          schedule: _scheduleFromRow(row),
          scheduledAt: DateTime.fromMillisecondsSinceEpoch(
            (row['scheduled_unix_s'] as int) * 1000,
          ),
          status: row['status'] as String,
          snoozeUntil: _dateTime(row['snooze_until_unix_s']),
          takenAt: _dateTime(row['taken_at_unix_s']),
        ),
    ];
  }

  @override
  Future<List<DoseOccurrence>> getExistingOccurrences(DateRange range) async {
    final rows = await _db.getAll(
      'SELECT o.id AS occurrence_id, o.scheduled_unix_s, o.status, '
      'o.snooze_until_unix_s, o.taken_at_unix_s, '
      's.id AS schedule_id, s.med_id, s.dose_amount, s.dose_unit, '
      's.time_minutes_json, s.dose_timings_json, s.weekdays_mask, '
      's.start_date, s.end_date, s.active, s.ended, '
      'm.designation, m.color, m.default_dose_mg, m.dose_unit AS medicine_unit '
      'FROM dose_occurrences o '
      'JOIN medication_schedules s ON s.id = o.schedule_id '
      'JOIN medicines m ON m.id = s.med_id '
      'WHERE o.scheduled_unix_s BETWEEN ? AND ? '
      'ORDER BY o.scheduled_unix_s',
      [range.startStamp, range.endStamp],
    );
    return [
      for (final row in rows)
        DoseOccurrence(
          id: row['occurrence_id'] as String,
          schedule: _scheduleFromRow(row),
          scheduledAt: DateTime.fromMillisecondsSinceEpoch(
            (row['scheduled_unix_s'] as int) * 1000,
          ),
          status: row['status'] as String,
          snoozeUntil: _dateTime(row['snooze_until_unix_s']),
          takenAt: _dateTime(row['taken_at_unix_s']),
        ),
    ];
  }

  @override
  Future<void> delete(String id) async {
    await _db.execute(
      'UPDATE intakes SET occurrence_id = NULL WHERE occurrence_id LIKE ?',
      ['$id.%'],
    );
    await _db.execute('DELETE FROM dose_occurrences WHERE schedule_id = ?', [
      id,
    ]);
    await _db.execute('DELETE FROM medication_schedules WHERE id = ?', [id]);
  }

  @override
  Future<void> setOccurrenceStatus(
    DoseOccurrence occurrence,
    String status, {
    DateTime? snoozeUntil,
  }) async {
    final takenAt = status == 'taken' ? DateTime.now() : null;
    await _db.execute(
      'UPDATE dose_occurrences SET status = ?, snooze_until_unix_s = ?, '
      'taken_at_unix_s = ? WHERE id = ?',
      [
        status,
        snoozeUntil?.millisecondsSinceEpoch == null
            ? null
            : snoozeUntil!.millisecondsSinceEpoch ~/ 1000,
        takenAt?.millisecondsSinceEpoch == null
            ? null
            : takenAt!.millisecondsSinceEpoch ~/ 1000,
        occurrence.id,
      ],
    );
    if (takenAt == null) return;
    await _intakes.add(
      MedicineIntake(
        time: takenAt,
        medicine: occurrence.schedule.medicine,
        dosis: Weight.mg(occurrence.schedule.doseAmount),
        occurrenceId: occurrence.id,
      ),
    );
    await _db.execute(
      'UPDATE dose_occurrences SET intake_id = ('
      'SELECT id FROM intakes WHERE occurrence_id = ?) WHERE id = ?',
      [occurrence.id, occurrence.id],
    );
  }

  MedicationSchedule _scheduleFromRow(Map<String, dynamic> row) {
    final medicine = Medicine(
      designation: row['designation'] as String,
      color: row['color'] as int?,
      dosis: (row['default_dose_mg'] as num?) == null
          ? null
          : Weight.mg((row['default_dose_mg'] as num).toDouble()),
      unit: MedicationUnit.parse(row['medicine_unit']),
    );
    final mask = (row['weekdays_mask'] as num).toInt();
    final timeMinutes = [
      for (final value
          in (jsonDecode(row['time_minutes_json'] as String) as List))
        (value as num).toInt(),
    ];
    final rawDoseTimings = row['dose_timings_json'] as String?;
    final decodedDoseTimings = rawDoseTimings == null
        ? const <Object?>[]
        : jsonDecode(rawDoseTimings) as List<Object?>;
    return MedicationSchedule(
      id: row['id'] as String? ?? row['schedule_id'] as String?,
      medicineId: row['med_id'] as String,
      medicine: medicine,
      doseAmount: (row['dose_amount'] as num).toDouble(),
      doseUnit: MedicationUnit.parse(row['dose_unit']),
      timeMinutes: timeMinutes,
      doseTimings: [
        for (var index = 0; index < timeMinutes.length; index++)
          MedicationDoseTiming.values.firstWhere(
            (timing) =>
                index < decodedDoseTimings.length &&
                timing.name == decodedDoseTimings[index],
            orElse: () => MedicationDoseTiming.anytime,
          ),
      ],
      weekdays: {
        for (var day = 1; day <= 7; day++)
          if ((mask & (1 << (day - 1))) != 0) day,
      },
      startDate: _parseDate(row['start_date'] as String?),
      endDate: _parseDate(row['end_date'] as String?),
      state: (row['ended'] as num?)?.toInt() == 1
          ? MedicationScheduleState.ended
          : (row['active'] as num).toInt() == 1
          ? MedicationScheduleState.active
          : MedicationScheduleState.paused,
    );
  }

  static String? _dateKey(DateTime? value) => value == null
      ? null
      : '${value.year.toString().padLeft(4, '0')}-'
            '${value.month.toString().padLeft(2, '0')}-'
            '${value.day.toString().padLeft(2, '0')}';

  static DateTime? _parseDate(String? value) =>
      value == null ? null : DateTime.tryParse(value);

  static DateTime _day(DateTime value) =>
      DateTime(value.year, value.month, value.day);

  static DateTime? _dateTime(Object? seconds) => seconds is num
      ? DateTime.fromMillisecondsSinceEpoch(seconds.toInt() * 1000)
      : null;
}
