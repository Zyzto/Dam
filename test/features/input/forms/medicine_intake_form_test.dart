import 'package:blood_pressure_app/features/input/forms/medicine_intake_form.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:blood_pressure_app/domain/domain.dart';

import '../../../util.dart';

void main() {
  testWidgets('shows hint when no medicines exist', (WidgetTester tester) async {
    await pumpApp(tester, await appBase(const MedicineIntakeForm(),
        medRepo: MockMedRepo([])));
    expect(find.text('Add a medication first so you can mark when you take it.'),
        findsOneWidget);
    expect(find.text('Manage medications'), findsOneWidget);
    expect(find.byIcon(Icons.medication_outlined), findsOneWidget);
    expect(find.byType(TextField), findsNothing);
  });

  testWidgets('shows a picker on single med', (WidgetTester tester) async {
    final mockMed = mockMedicine(designation: 'monozernorditrocin');
    await pumpApp(tester, await appBase(MedicineIntakeForm(),
        medRepo: MockMedRepo([mockMed])));
    expect(find.byKey(medicationPickerKey), findsOneWidget);
    expect(find.byKey(medicationDoseFieldKey), findsNothing);

    await tester.tap(find.byKey(medicationPickerKey));
    await tester.pumpAndSettle();
    expect(find.text('monozernorditrocin').hitTestable(), findsWidgets);
  });

  testWidgets('shows a picker on multiple meds', (WidgetTester tester) async {
    final med1 = mockMedicine(designation: 'tetraebraphthyme');
    final med2 = mockMedicine(designation: 'hypovonyhensas');
    await pumpApp(tester, await appBase(MedicineIntakeForm(),
        medRepo: MockMedRepo([med1,med2])));
    expect(find.byKey(medicationPickerKey), findsOneWidget);
    expect(find.byKey(medicationDoseFieldKey), findsNothing);

    await selectMedicineFromPicker(tester, 'hypovonyhensas');

    expect(find.text('hypovonyhensas'), findsWidgets);
    expect(find.byKey(medicationDoseFieldKey), findsOneWidget);

    await selectMedicineFromPicker(tester, 'No medication');

    expect(find.byKey(medicationDoseFieldKey), findsNothing);

    await selectMedicineFromPicker(tester, 'tetraebraphthyme');

    expect(find.text('tetraebraphthyme'), findsWidgets);
    expect(find.byKey(medicationDoseFieldKey), findsOneWidget);
  });

  testWidgets('returns entered values', (WidgetTester tester) async {
    final med1 = mockMedicine(designation: 'tetraebraphthyme');
    final med2 = mockMedicine(designation: 'hypovonyhensas');
    final key = GlobalKey<MedicineIntakeFormState>();

    await pumpApp(tester, await appBase(MedicineIntakeForm(
      key: key,
    ), medRepo: MockMedRepo([med1,med2])));

    expect(key.currentState!.validate(), isTrue);
    expect(key.currentState!.save(), isNull);

    await selectMedicineFromPicker(tester, med1.designation);
    await tester.enterText(find.byKey(medicationDoseFieldKey), ',..,');

    expect(key.currentState!.validate(), isFalse);
    expect(key.currentState!.save(), isNull);

    await tester.enterText(find.byKey(medicationDoseFieldKey), '3.14');
    expect(key.currentState!.validate(), isTrue);
    expect(key.currentState!.save(), (med1, Weight.mg(3.14)));
  });

  testWidgets('prefills values when selecting med', (WidgetTester tester) async {
    final med1 = mockMedicine(designation: 'tetraebraphthyme', defaultDosis: 3.141);
    final med2 = mockMedicine(designation: 'hypovonyhensas');
    await pumpApp(tester, await appBase(MedicineIntakeForm(), medRepo: MockMedRepo([med1,med2])));

    await selectMedicineFromPicker(tester, med1.designation);

    expect(find.text(formatDoseAmount(med1.dosis!.mg)), findsOneWidget);
  });

  testWidgets('returns passed values on edit', (WidgetTester tester) async {
    final med1 = mockMedicine(designation: 'tetraebraphthyme');
    final med2 = mockMedicine(designation: 'hypovonyhensas');
    final key = GlobalKey<MedicineIntakeFormState>();

    await pumpApp(tester, await appBase(MedicineIntakeForm(
      key: key,
      initialValue: (med2, Weight.mg(3.141)),
    ), medRepo: MockMedRepo([med1,med2])));

    expect(find.text(med2.designation), findsOneWidget);
    expect(find.text('3.141'), findsOneWidget);
    expect(find.byKey(medicationDoseFieldKey), findsOneWidget);

    expect(key.currentState!.validate(), isTrue);
    expect(key.currentState!.save(), (med2, Weight.mg(3.141)));
  });

  testWidgets('shows a separate time when the dose was logged separately', (tester) async {
    final med = mockMedicine(designation: 'amlodipine');
    await pumpApp(tester, await appBase(MedicineIntakeForm(
      initialValue: (med, Weight.mg(5)),
      entryTime: DateTime(2026, 8, 26, 8),
      initialIntakeTime: DateTime(2026, 8, 26, 21, 30),
      showSeparateTime: true,
    ), medRepo: MockMedRepo([med])));

    expect(find.text('Time taken'), findsOneWidget);
    expect(find.text('21:30'), findsOneWidget);
  });

  testWidgets('shows every attached dose and a time on the standalone one', (tester) async {
    final withReading = mockMedicine(designation: 'amlodipine', defaultDosis: 5);
    final standalone = mockMedicine(designation: 'lisinopril', defaultDosis: 10);
    final key = GlobalKey<MedicineIntakeFormState>();
    final readingTime = DateTime(2026, 8, 26, 8);
    await pumpApp(tester, await appBase(MedicineIntakeForm(
      key: key,
      entryTime: readingTime,
      allowMultiple: true,
      initialIntakes: [
        mockIntake(withReading, time: readingTime.millisecondsSinceEpoch, dosis: 5),
        mockIntake(standalone, time: DateTime(2026, 8, 26, 21, 30).millisecondsSinceEpoch, dosis: 10),
      ],
    ), medRepo: MockMedRepo([withReading, standalone])));

    expect(find.byKey(medicationPickerKey), findsNWidgets(2));
    expect(find.text('Time taken'), findsOneWidget);
    expect(find.text('21:30'), findsOneWidget);
    expect(find.byTooltip('Add medication'), findsOneWidget);

    final saved = key.currentState!.saveIntakes(readingTime);
    expect(saved, hasLength(2));
    expect(saved.first.medicine.designation, 'amlodipine');
    expect(saved.last.medicine.designation, 'lisinopril');
    expect(saved.last.time, DateTime(2026, 8, 26, 21, 30));
  });

  testWidgets('steps the dose with plus and minus', (tester) async {
    final med = mockMedicine(designation: 'amlodipine', defaultDosis: 5);
    await pumpApp(tester, await appBase(MedicineIntakeForm(
      initialValue: (med, Weight.mg(5)),
    ), medRepo: MockMedRepo([med])));

    await tester.tap(find.byKey(const ValueKey('dose-plus')));
    await tester.pump();
    expect(find.text('6'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('dose-minus')));
    await tester.pump();
    expect(find.text('5'), findsOneWidget);
  });

  testWidgets('keeps the dose unit on the right in RTL', (tester) async {
    final med = mockMedicine(designation: 'amlodipine', defaultDosis: 5);
    await pumpApp(tester, await appBase(
      MedicineIntakeForm(initialValue: (med, Weight.mg(5))),
      medRepo: MockMedRepo([med]),
      locale: const Locale('ar'),
    ));

    final number = tester.getRect(find.text('5').first);
    final unit = tester.getRect(find.text('مغ'));
    expect(unit.left, greaterThan(number.center.dx));
    expect(unit.right, lessThan(tester.getRect(find.byKey(const ValueKey('dose-minus'))).left));
  });
}
