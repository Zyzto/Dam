import 'package:blood_pressure_app/domain/domain.dart';
import 'package:blood_pressure_app/features/measurement_list/measurement_detail_screen.dart';
import 'package:blood_pressure_app/features/medications/medication_reminder_providers.dart';
import 'package:blood_pressure_app/features/medications/medication_reminders_screens.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../util.dart';

void main() {
  testWidgets('tapping a taken dose opens the entry that records it', (
    tester,
  ) async {
    final now = DateTime.now();
    final day = DateTime(now.year, now.month, now.day);
    final takenAt = day.add(const Duration(hours: 8, minutes: 5));
    final readingAt = day.add(const Duration(hours: 21));
    const occurrenceId = 'schedule.today.480';
    final medicine = Medicine(
      designation: 'Amlodipine',
      dosis: Weight.mg(5),
    );
    final dose = DoseOccurrence(
      id: occurrenceId,
      schedule: MedicationSchedule(
        medicineId: 'med',
        medicine: medicine,
        doseAmount: 5,
        doseUnit: MedicationUnit.mg,
        timeMinutes: const [8 * 60],
        weekdays: const {1, 2, 3, 4, 5, 6, 7},
      ),
      scheduledAt: day.add(const Duration(hours: 8)),
      status: 'taken',
      takenAt: takenAt,
    );
    final store = MockHealthStore()
      ..intakeRepo = (MockMedicineIntakeRepository()
        ..data.add(
          MedicineIntake(
            time: takenAt,
            medicine: medicine,
            dosis: Weight.mg(5),
            occurrenceId: occurrenceId,
          ),
        ))
      ..bpRepo = (MockBloodPressureRepository()
        ..data.add(
          BloodPressureRecord(
            time: readingAt,
            sys: Pressure.mmHg(128),
            dia: Pressure.mmHg(82),
            pul: 70,
          ),
        ));

    await pumpApp(
      tester,
      await materialApp(
        const TodayMedicinesScreen(),
        store: store,
        overrides: [
          medicationDayProvider.overrideWith((ref, day) async => [dose]),
          homeMedicationOccurrencesProvider.overrideWith(
            (ref) async => [dose],
          ),
        ],
      ),
    );
    await _until(tester, find.text('Amlodipine'));

    await tester.tap(find.text('Amlodipine'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.byType(MeasurementDetailScreen), findsOneWidget);
    expect(find.text('128'), findsOneWidget);
    expect(find.text('Amlodipine'), findsWidgets);
  });
}

Future<void> _until(WidgetTester tester, Finder finder) async {
  for (var i = 0; i < 30 && finder.evaluate().isEmpty; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
  expect(finder, findsOneWidget);
}
