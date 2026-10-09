import 'package:blood_pressure_app/domain/blood_pressure_record.dart';
import 'package:blood_pressure_app/domain/bodyweight_record.dart';
import 'package:blood_pressure_app/domain/date_range.dart';
import 'package:blood_pressure_app/domain/medication_schedule.dart';
import 'package:blood_pressure_app/domain/medicine.dart';
import 'package:blood_pressure_app/domain/medicine_intake.dart';
import 'package:blood_pressure_app/domain/note.dart';

/// High-level access to stored health records.
abstract class Repository<T> {
  /// Adds a new value, replacing any existing value at the same time.
  Future<void> add(T value);

  /// Removes a value known to be in the repository.
  Future<void> remove(T value);

  /// Inclusively returns all values in the specified [range].
  Future<List<T>> get(DateRange range);

  /// Emits whenever the data changes.
  Stream<T?> subscribe();
}

/// Repository for [BloodPressureRecord]s.
abstract class BloodPressureRepository
    extends Repository<BloodPressureRecord> {}

/// Repository for [Note]s.
abstract class NoteRepository extends Repository<Note> {}

/// Repository for [BodyweightRecord]s.
abstract class BodyweightRepository extends Repository<BodyweightRecord> {}

/// Repository for [MedicineIntake]s.
abstract class MedicineIntakeRepository extends Repository<MedicineIntake> {
  /// Returns the most recently used intake for each medicine, newest first.
  ///
  /// Implementations can override this to avoid loading the full history.
  Future<List<MedicineIntake>> getMostRecentlyUsed({int limit = 5}) async {
    if (limit <= 0) return <MedicineIntake>[];

    final intakes = await get(DateRange.all())
      ..sort((a, b) => b.time.compareTo(a.time));
    final used = <Medicine>{};
    final recent = <MedicineIntake>[];
    for (final intake in intakes) {
      if (!used.add(intake.medicine)) continue;
      recent.add(intake);
      if (recent.length == limit) break;
    }
    return recent;
  }
}

/// Local schedules and occurrence outcomes for scheduled medicine doses.
abstract class MedicationScheduleRepository {
  /// Get all saved schedules, including paused and ended schedules.
  Future<List<MedicationSchedule>> getAll();

  /// Save a new schedule or update one with the same id.
  Future<MedicationSchedule> save(MedicationSchedule schedule);

  /// Get today's scheduled occurrences, materializing them if needed.
  Future<List<DoseOccurrence>> getOccurrences(DateTime date);

  /// Get doses recorded as taken whose scheduled time falls in [range].
  Future<List<DoseOccurrence>> getTakenOccurrences(DateRange range);

  /// Saved dose rows in [range], without creating missing ones.
  ///
  /// A day the app never opened has no row, so a miss from that day is not
  /// invented. Callers decide which statuses to keep.
  Future<List<DoseOccurrence>> getExistingOccurrences(DateRange range);

  /// Change an occurrence state and, when taken, add a linked medicine intake.
  Future<void> setOccurrenceStatus(
    DoseOccurrence occurrence,
    String status, {
    DateTime? snoozeUntil,
  });

  /// Removes a schedule and its occurrences while preserving recorded intakes.
  Future<void> delete(String id);
}

/// Repository for medicines that are taken by the user.
abstract class MedicineRepository extends Repository<Medicine> {
  /// Get medicines that have not been marked as removed.
  Future<List<Medicine>> getAll();

  /// Get active medicines in the order they were created.
  ///
  /// Implementations without creation metadata can preserve their repository
  /// order. This is used to fill quick-add choices when fewer than five
  /// medicines have an intake history.
  Future<List<Medicine>> getAllInCreationOrder() => getAll();
}
