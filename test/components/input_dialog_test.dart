import 'package:blood_pressure_app/components/input_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:safaeh/safaeh.dart';

import '../util.dart';

void main() {
  group('showInputDialog', () {
    testWidgets('should start with input focused', (tester) async {
      await loadDialog(tester, (context) => showInputDialog(context, initialValue: 'testval'));

      expect(find.byType(SafaehTextInputSheet), findsOneWidget);
      final primaryFocus = FocusManager.instance.primaryFocus;
      expect(primaryFocus?.context?.widget, isNotNull);
      final focusedTextField = find.ancestor(
        of: find.byWidget(primaryFocus!.context!.widget),
        matching: find.byType(TextField),
      );
      expect(find.descendant(of: focusedTextField, matching: find.text('testval')), findsOneWidget);
    });
    testWidgets('should allow entering a value', (tester) async {
      String? result = 'init';
      await loadDialog(tester, (context) async => result = await showInputDialog(context));
      expect(find.byType(SafaehTextInputSheet), findsOneWidget);
      expect(find.byType(TextField), findsOneWidget);

      await tester.enterText(find.byType(TextField), 'inputted text');
      await tapSafaehConfirm(tester);
      await tester.pumpAndSettle();

      expect(result, 'inputted text');
    });
    testWidgets('should not return value on cancel', (tester) async {
      String? result = 'init';
      await loadDialog(tester, (context) async => result = await showInputDialog(context, initialValue: 'test'));
      expect(find.byType(SafaehTextInputSheet), findsOneWidget);
      expect(find.byType(TextField), findsOneWidget);

      await tester.enterText(find.byType(TextField), 'inputted text');
      await dismissSafaeh(tester);
      await tester.pumpAndSettle();

      expect(result, null);
    });
  });
  group('showNumberInputDialog', () {
    testWidgets('should start with input focused', (tester) async {
      await loadDialog(tester, (context) => showNumberInputDialog(context, initialValue: 123));

      expect(find.byType(SafaehTextInputSheet), findsOneWidget);
      expect(find.text('123'), findsOneWidget);

      final primaryFocus = FocusManager.instance.primaryFocus;
      expect(primaryFocus?.context?.widget, isNotNull);
      final focusedTextField = find.ancestor(
        of: find.byWidget(primaryFocus!.context!.widget),
        matching: find.byType(TextField),
      );
      expect(find.descendant(of: focusedTextField, matching: find.text('123')), findsOneWidget);
    });
    testWidgets('should allow entering a number', (tester) async {
      double? result = -1;
      await loadDialog(tester, (context) async => result = await showNumberInputDialog(context));
      expect(find.byType(SafaehTextInputSheet), findsOneWidget);
      expect(find.byType(TextField), findsOneWidget);

      await tester.enterText(find.byType(TextField), '123.76');
      expect(find.text('OK'), findsOneWidget);
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();

      expect(result, 123.76);
    });
    testWidgets('should not allow entering text', (tester) async {
      usePhoneTestSurface(tester);
      double? result = -1;
      await loadDialog(tester, (context) async => result = await showNumberInputDialog(context));
      expect(find.byType(SafaehTextInputSheet), findsOneWidget);

      await tester.enterText(find.byType(TextField), 'test');
      expect(find.text('OK'), findsOneWidget);
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();

      expect(find.byType(SafaehTextInputSheet), findsOneWidget);
      expect(find.text('Please enter a number'), findsOneWidget);

      await dismissSafaeh(tester);
      await tester.pumpAndSettle();

      expect(result, null);
    });
  });
}
