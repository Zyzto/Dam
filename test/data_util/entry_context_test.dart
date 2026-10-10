import 'package:blood_pressure_app/data_util/entry_context.dart';
import 'package:blood_pressure_app/features/bluetooth/logic/ble_measurement_duplicates.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:health/health.dart';
import 'package:blood_pressure_app/domain/domain.dart';

import '../model/export_import/record_formatter_test.dart';
import '../util.dart';

void main() {
  testWidgets('fully deletes entries', (tester) async {
    final entry = mockEntry(time: DateTime.now(), sys: 123, note: 'test', intake: (mockMedicine(), 42.0));

    final BloodPressureRepository bpRepo = MockBloodPressureRepository() as BloodPressureRepository;
    final NoteRepository noteRepo = MockNoteRepository() as NoteRepository;
    final MedicineIntakeRepository intakeRepo = MockMedicineIntakeRepository() as MedicineIntakeRepository;
    await bpRepo.add(entry.record!);
    await noteRepo.add(entry.note!);
    await intakeRepo.add(entry.intake!);

    await pumpApp(tester, await appBase(
      settings: TestSettingsSeed(confirmDeletion: false),
      bpRepo: bpRepo,
      noteRepo: noteRepo,
      intakeRepo: intakeRepo,
      Builder(
        builder: (context) => TextButton(
          onPressed: () => context.deleteEntry(entry),
          child: Text('X'),
        ),
      ),
    ));

    expect(await bpRepo.get(DateRange.all()), hasLength(1));
    expect(await noteRepo.get(DateRange.all()), hasLength(1));
    expect(await intakeRepo.get(DateRange.all()), hasLength(1));

    await tester.tap(find.text('X'));
    await tester.pumpAndSettle();

    expect(await bpRepo.get(DateRange.all()), isEmpty);
    expect(await noteRepo.get(DateRange.all()), isEmpty);
    expect(await intakeRepo.get(DateRange.all()), isEmpty);
  });

  testWidgets('Also removes entries from health connect', (tester) async {
    final entry = mockEntry(time: DateTime.now(), sys: 123, dia: 456);

    final BloodPressureRepository bpRepo =
        MockBloodPressureRepository() as BloodPressureRepository;
    final NoteRepository noteRepo = MockNoteRepository() as NoteRepository;
    final MedicineIntakeRepository intakeRepo =
        MockMedicineIntakeRepository() as MedicineIntakeRepository;
    final fakeHealth = _FakeHealth();
    await bpRepo.add(entry.record!);

    await pumpApp(tester, await appBase(
      settings: TestSettingsSeed(
        confirmDeletion: false,
        useHealthConnect: true,
        syncPressureMeasurements: true,
      ),
      bpRepo: bpRepo,
      noteRepo: noteRepo,
      intakeRepo: intakeRepo,
      Builder(
        builder: (context) => TextButton(
          onPressed: () => context.deleteEntry(entry, fakeHealth),
          child: Text('X'),
        ),
      ),
    ));

    expect(fakeHealth.deletionRequests, isEmpty);

    await tester.tap(find.text('X'));
    await tester.pumpAndSettle();

    expect(fakeHealth.deletionRequests,
        contains(HealthDataType.BLOOD_PRESSURE_SYSTOLIC));
    expect(fakeHealth.deletionRequests,
        contains(HealthDataType.BLOOD_PRESSURE_DIASTOLIC));
    expect(fakeHealth.deletionRequests, hasLength(2));
  });

  testWidgets('writes a blacklist row only for deleteAndBlacklist', (tester) async {
    usePhoneTestSurface(tester);
    final entry = mockEntry(time: DateTime.utc(2026, 4, 5, 16, 19, 10), sys: 123);
    final bpRepo = MockBloodPressureRepository();
    final blacklist = MockBleBlacklistRepository();
    await bpRepo.add(entry.record!);

    await pumpApp(tester, await appBase(
      settings: TestSettingsSeed(confirmDeletion: true),
      bpRepo: bpRepo,
      blacklistRepo: blacklist,
      Builder(
        builder: (context) => TextButton(
          onPressed: () => context.deleteEntry(entry),
          child: const Text('X'),
        ),
      ),
    ));

    await tester.tap(find.text('X'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('safaeh_confirm')));
    await tester.pumpAndSettle();
    expect(await blacklist.getKeys('bp'), isEmpty);
    // The undo toast sits above the next sheet. Let it close first.
    await tester.pump(const Duration(seconds: 8));
    await tester.pumpAndSettle();

    await bpRepo.add(entry.record!);
    await tester.tap(find.text('X'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('deleteAndBlacklist')));
    await tester.pumpAndSettle();
    expect(
      await blacklist.getKeys('bp'),
      {bloodPressureRecordKey(entry.record!)},
    );
  });

  testWidgets('does not blacklist when confirmations are off', (tester) async {
    final entry = mockEntry(time: DateTime.utc(2026, 4, 5, 16, 19, 10), sys: 123);
    final bpRepo = MockBloodPressureRepository();
    final blacklist = MockBleBlacklistRepository();
    await bpRepo.add(entry.record!);

    await pumpApp(tester, await appBase(
      settings: TestSettingsSeed(confirmDeletion: false),
      bpRepo: bpRepo,
      blacklistRepo: blacklist,
      Builder(
        builder: (context) => TextButton(
          onPressed: () => context.deleteEntry(entry),
          child: const Text('X'),
        ),
      ),
    ));

    await tester.tap(find.text('X'));
    await tester.pumpAndSettle();
    expect(await blacklist.getKeys('bp'), isEmpty);
  });
}

class _FakeHealth extends Fake implements Health {
  _FakeHealth();

  List<HealthDataType> deletionRequests = [];

  @override
  Future<bool> delete(
      {required HealthDataType type,
      required DateTime startTime,
      DateTime? endTime}) async {
    deletionRequests.add(type);
    return true;
  }
}
