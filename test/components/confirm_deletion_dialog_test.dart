import 'package:blood_pressure_app/components/confirm_deletion_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../util.dart';

void main() {
  testWidgets('shows entire content', (tester) async {
    usePhoneTestSurface(tester);
    await loadDialog(tester, showConfirmDeletionDialog);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('safaeh_cancel')), findsNothing);
    expect(find.byKey(const ValueKey('safaeh_confirm')), findsOneWidget);
    expect(find.byKey(const ValueKey('deleteAndBlacklist')), findsNothing);

    expect(find.text('Confirm deletion'), findsOneWidget);
    expect(find.text('Delete this entry? (You can turn off these confirmations in the settings.)'), findsOneWidget);
    expect(find.text('Delete'), findsOneWidget);
  });

  testWidgets('cancel returns DeleteChoice.cancel', (tester) async {
    usePhoneTestSurface(tester);
    DeleteChoice? choice;
    await loadDialog(tester, (context) {
      showConfirmDeletionChoice(context, allowBlacklist: true)
          .then((value) => choice = value);
    });
    await dismissSafaeh(tester);
    await tester.pumpAndSettle();
    expect(choice, DeleteChoice.cancel);
  });

  testWidgets('delete returns DeleteChoice.delete', (tester) async {
    usePhoneTestSurface(tester);
    DeleteChoice? choice;
    await loadDialog(tester, (context) {
      showConfirmDeletionChoice(context, allowBlacklist: true)
          .then((value) => choice = value);
    });
    await tester.tap(find.byKey(const ValueKey('safaeh_confirm')));
    await tester.pumpAndSettle();
    expect(choice, DeleteChoice.delete);
  });

  testWidgets('block button returns DeleteChoice.deleteAndBlacklist', (tester) async {
    usePhoneTestSurface(tester);
    DeleteChoice? choice;
    await loadDialog(tester, (context) {
      showConfirmDeletionChoice(context, allowBlacklist: true)
          .then((value) => choice = value);
    });
    expect(find.byKey(const ValueKey('deleteAndBlacklist')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('deleteAndBlacklist')));
    await tester.pumpAndSettle();
    expect(choice, DeleteChoice.deleteAndBlacklist);
  });
}
