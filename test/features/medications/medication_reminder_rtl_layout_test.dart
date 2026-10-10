import 'package:blood_pressure_app/features/home/navigation_action_buttons.dart';
import 'package:blood_pressure_app/features/medications/medication_reminder_providers.dart';
import 'package:blood_pressure_app/features/medications/medication_reminders_screens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../util.dart';

void main() {
  testWidgets('Arabic reminder editor keeps its save action on-screen', (
    tester,
  ) async {
    usePhoneTestSurface(tester);

    await pumpApp(
      tester,
      await materialApp(
        const MedicationScheduleEditorScreen(),
        locale: const Locale('ar'),
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('إضافة تذكير'), findsOneWidget);
    expect(find.text('الدواء'), findsOneWidget);
    expect(find.text('Medicine'), findsNothing);
    final saveButton = find.text('حفظ التذكير');
    expect(saveButton, findsOneWidget);
    var saveBounds = tester.getRect(saveButton);
    expect(saveBounds.left, greaterThanOrEqualTo(0));
    expect(saveBounds.right, lessThanOrEqualTo(390));
    expect(saveBounds.top, greaterThanOrEqualTo(0));
    expect(saveBounds.bottom, lessThanOrEqualTo(844));

    await tester.drag(find.byType(ListView).last, const Offset(0, -300));
    await tester.pump();
    saveBounds = tester.getRect(saveButton);
    expect(saveBounds.bottom, lessThanOrEqualTo(844));
    expect(tester.takeException(), isNull);
  });

  testWidgets('Arabic reminder panel stays inside a phone viewport', (
    tester,
  ) async {
    usePhoneTestSurface(tester);

    await pumpApp(
      tester,
      await materialApp(
        const Scaffold(
          body: SizedBox.expand(),
          floatingActionButton: NavigationActionButtons(),
          floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
        ),
        locale: const Locale('ar'),
        overrides: [
          medicationSchedulesProvider.overrideWith((ref) async => []),
          homeMedicationOccurrencesProvider.overrideWith((ref) async => []),
        ],
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));

    final reminderButton = find.byTooltip('إعداد تذكير للدواء');
    expect(reminderButton, findsOneWidget);
    await tester.tap(reminderButton);
    await tester.pumpAndSettle();

    final panel = find.byKey(const ValueKey('medicationReminderDosePanel'));
    expect(panel, findsOneWidget);
    final bounds = tester.getRect(panel);
    final fabBounds = tester.getRect(reminderButton);
    expect(bounds.left, greaterThanOrEqualTo(0));
    expect(bounds.top, greaterThanOrEqualTo(0));
    expect(bounds.right, lessThanOrEqualTo(390));
    expect(bounds.bottom, lessThanOrEqualTo(844));
    expect(bounds.left, closeTo(fabBounds.left, 1));
    expect(bounds.bottom, closeTo(fabBounds.top - 8, 1));

    final addReminder = find.text('إضافة تذكير');
    expect(addReminder, findsOneWidget);
    final buttonBounds = tester.getRect(addReminder);
    expect(buttonBounds.left, greaterThanOrEqualTo(bounds.left));
    expect(buttonBounds.right, lessThanOrEqualTo(bounds.right));
    expect(buttonBounds.top, greaterThanOrEqualTo(bounds.top));
    expect(buttonBounds.bottom, lessThanOrEqualTo(bounds.bottom));
    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle();
    expect(panel, findsNothing);
  });

  testWidgets('English reminder panel opens above the timer FAB', (
    tester,
  ) async {
    usePhoneTestSurface(tester);

    await pumpApp(
      tester,
      await materialApp(
        const Scaffold(
          body: SizedBox.expand(),
          floatingActionButton: NavigationActionButtons(),
          floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
        ),
        locale: const Locale('en'),
        overrides: [
          medicationSchedulesProvider.overrideWith((ref) async => []),
          homeMedicationOccurrencesProvider.overrideWith((ref) async => []),
        ],
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));

    final reminderButton = find.byTooltip('Set up a medicine reminder');
    expect(reminderButton, findsOneWidget);
    await tester.tap(reminderButton);
    await tester.pumpAndSettle();

    final panel = find.byKey(const ValueKey('medicationReminderDosePanel'));
    expect(panel, findsOneWidget);
    final bounds = tester.getRect(panel);
    final fabBounds = tester.getRect(reminderButton);
    expect(bounds.right, closeTo(fabBounds.right, 1));
    expect(bounds.bottom, closeTo(fabBounds.top - 8, 1));
    expect(tester.takeException(), isNull);
  });
}
