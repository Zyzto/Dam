import 'package:blood_pressure_app/domain/domain.dart';
import 'package:blood_pressure_app/features/medications/medication_reminder_runtime.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../util.dart';

void main() {
  test('formats reminder notifications in Arabic', () {
    loadTestTranslations(const Locale('ar'));
    const schedule = MedicationSchedule(
      medicineId: 'amlodipine',
      medicine: Medicine(designation: 'Amlodipine'),
      doseAmount: 5,
      doseUnit: MedicationUnit.mg,
      timeMinutes: [480],
      doseTimings: [MedicationDoseTiming.beforeFood],
      weekdays: {1},
    );

    expect(medicationReminderNotificationTitle(), 'تذكير الدواء');
    expect(
      formatMedicationDoseReminderBody(schedule, 480),
      'Amlodipine · 5 مغ · قبل الطعام',
    );
    expect(medicationReminderWidgetLabels(), {
      'statusAllSet': 'تم',
      'statusOverdue': 'متأخرة',
      'statusSnoozed': 'مؤجل',
      'statusSoon': 'قريباً',
      'statusNextDose': 'التالي',
      'noDoseDue': 'لا توجد جرعة مستحقة',
      'noMedicineDoseDue': 'لا توجد جرعة دواء مستحقة',
      'showsAll': 'كل الأدوية',
      'now': 'الآن',
      'hourUnit': 'س',
      'minuteUnit': 'د',
    });
  });

  test('keeps English notification text in English', () {
    loadTestTranslations();
    const schedule = MedicationSchedule(
      medicineId: 'amlodipine',
      medicine: Medicine(designation: 'Amlodipine'),
      doseAmount: 5,
      doseUnit: MedicationUnit.mg,
      timeMinutes: [480],
      doseTimings: [MedicationDoseTiming.beforeFood],
      weekdays: {1},
    );

    expect(medicationReminderNotificationTitle(), 'Medicine reminder');
    expect(
      formatMedicationDoseReminderBody(schedule, 480),
      'Amlodipine · 5 mg · Before food',
    );
  });
}
