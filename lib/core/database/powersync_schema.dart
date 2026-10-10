import 'package:powersync/powersync.dart';

/// Local-only PowerSync schema. Never synced; no `ps_crud` growth.
const schema = Schema([
  Table.localOnly('blood_pressure', [
    Column.integer('timestamp_unix_s'),
    Column.real('sys_kpa'),
    Column.real('dia_kpa'),
    Column.integer('pul'),
  ]),
  Table.localOnly('notes', [
    Column.integer('timestamp_unix_s'),
    Column.text('note'),
    Column.integer('color'),
  ]),
  Table.localOnly('weights', [
    Column.integer('timestamp_unix_s'),
    Column.real('weight_kg'),
    Column.real('impedance_ohm'),
  ]),
  Table.localOnly('medicines', [
    Column.text('designation'),
    Column.integer('color'),
    Column.real('default_dose_mg'),
    Column.text('dose_unit'),
    Column.integer('removed'),
  ]),
  Table.localOnly('intakes', [
    Column.integer('timestamp_unix_s'),
    Column.text('med_id'),
    Column.real('dosis_mg'),
    Column.text('occurrence_id'),
  ]),
  Table.localOnly('medication_schedules', [
    Column.text('med_id'),
    Column.real('dose_amount'),
    Column.text('dose_unit'),
    Column.text('time_minutes_json'),
    Column.text('dose_timings_json'),
    Column.integer('weekdays_mask'),
    Column.text('start_date'),
    Column.text('end_date'),
    Column.integer('active'),
    Column.integer('ended'),
    Column.integer('shift_missed_doses'),
  ]),
  Table.localOnly('dose_occurrences', [
    Column.text('schedule_id'),
    Column.text('local_key'),
    Column.integer('scheduled_unix_s'),
    Column.text('status'),
    Column.integer('snooze_until_unix_s'),
    Column.integer('taken_at_unix_s'),
    Column.text('intake_id'),
  ]),
  Table.localOnly('ble_blacklist', [
    Column.text('kind'),
    Column.text('key'),
    Column.integer('created_unix_s'),
  ]),
]);
