import 'package:blood_pressure_app/features/settings/add_medication_dialog.dart';
import 'package:blood_pressure_app/features/settings/tiles/color_picker_list_tile.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:blood_pressure_app/domain/domain.dart';

import '../../util.dart';

void main() {
  testWidgets('should prefill initialValue', (tester) async {
    await pumpApp(
      tester,
      await materialApp(
        AddMedicationDialog(
          initialValue: Medicine(
            designation: 'testmed 1',
            color: Colors.red.toARGB32(),
            dosis: Weight.mg(12.34),
          ),
        ),
      ),
    );
    expect(find.text('testmed 1'), findsOneWidget);
    expect(find.text('12.34'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('medication-unit-dropdown')),
      findsOneWidget,
    );
    expect(find.byType(ChoiceChip), findsNothing);
  });

  testWidgets('lets the dose field choose a unit from its trailing dropdown', (
    tester,
  ) async {
    await pumpApp(tester, await materialApp(const AddMedicationDialog()));

    final dropdown = find.byKey(const ValueKey('medication-unit-dropdown'));
    expect(dropdown, findsOneWidget);

    await tester.tap(dropdown);
    await tester.pumpAndSettle();
    expect(find.text('tablet').last, findsOneWidget);

    await tester.tap(find.text('tablet').last);
    await tester.pumpAndSettle();
    expect(find.text('tablet'), findsOneWidget);
  });

  testWidgets('opens the Edadat color palette from the medication dialog', (
    tester,
  ) async {
    usePhoneTestSurface(tester);
    await pumpApp(tester, await materialApp(const AddMedicationDialog()));

    await tester.tap(find.byType(ColorSelectionListTile));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.byWidgetPredicate(_isRedSwatch), findsOneWidget);
  });

  testWidgets('localizes the unit dropdown and keeps it trailing in RTL', (
    tester,
  ) async {
    await pumpApp(
      tester,
      await materialApp(
        const AddMedicationDialog(),
        locale: const Locale('ar'),
      ),
    );

    final doseField = find.byType(TextFormField).at(1);
    final doseRect = tester.getRect(doseField);
    final unitDropdown = find.byKey(const ValueKey('medication-unit-dropdown'));
    expect(
      tester.getRect(unitDropdown).center.dx,
      lessThan(doseRect.center.dx),
    );
    expect(find.text('مغ'), findsOneWidget);

    await tester.tap(unitDropdown);
    await tester.pumpAndSettle();
    expect(find.text('قرص').last, findsOneWidget);
  });

  testWidgets('requires a name before save', (tester) async {
    await pumpApp(tester, await materialApp(const AddMedicationDialog()));
    await tester.tap(find.text('SAVE'));
    await tester.pumpAndSettle();
    expect(find.text('Please enter a name'), findsOneWidget);
    expect(find.byType(AddMedicationDialog), findsOneWidget);
  });
}

bool _isRedSwatch(Widget widget) {
  if (widget is! AnimatedContainer) return false;
  final decoration = widget.decoration;
  return decoration is BoxDecoration && decoration.color == Colors.red;
}
