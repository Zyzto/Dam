import 'package:blood_pressure_app/components/color_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../util.dart';

void main() {
  testWidgets('should initialize without errors', (tester) async {
    await pumpApp(
      tester,
      await materialApp(ColorPicker(onColorSelected: (color) {})),
    );
    await pumpApp(
      tester,
      await materialApp(
        ColorPicker(availableColors: const [], onColorSelected: (color) {}),
      ),
    );
    await pumpApp(
      tester,
      await materialApp(
        ColorPicker(showTransparentColor: false, onColorSelected: (color) {}),
      ),
    );
    await pumpApp(
      tester,
      await materialApp(
        ColorPicker(circleSize: 15, onColorSelected: (color) {}),
      ),
    );
    await pumpApp(
      tester,
      await materialApp(
        ColorPicker(
          availableColors: const [],
          initialColor: Colors.red,
          onColorSelected: (color) {},
        ),
      ),
    );
    expect(tester.takeException(), isNull);
  });
  testWidgets('should report correct picked color', (tester) async {
    int onColorSelectedCallCount = 0;
    await pumpApp(
      tester,
      await materialApp(
        ColorPicker(
          onColorSelected: (color) {
            expect(color, Colors.blue);
            onColorSelectedCallCount += 1;
          },
        ),
      ),
    );

    final containers = find.byType(AnimatedContainer).evaluate();
    final blueColor = containers.where((element) {
      final widget = element.widget as AnimatedContainer;
      final decoration = widget.decoration;
      if (decoration is BoxDecoration) {
        return decoration.color == Colors.blue;
      }
      return false;
    });
    expect(blueColor.length, 1);
    await tester.tap(find.byWidget(blueColor.first.widget));
    expect(onColorSelectedCallCount, 1);
  });

  testWidgets('adapts columns to keep the final palette row full', (
    tester,
  ) async {
    usePhoneTestSurface(tester);
    final colors = [
      for (var index = 0; index < 19; index++) Color(0xFF000000 | (index + 1)),
    ];

    await pumpApp(
      tester,
      await materialApp(
        ColorPicker(
          availableColors: colors,
          showTransparentColor: false,
          onColorSelected: (_) {},
        ),
      ),
    );

    final swatches = find.byType(InkWell);
    expect(swatches, findsNWidgets(19));

    final rowCounts = <int, int>{};
    for (var index = 0; index < swatches.evaluate().length; index++) {
      final top = tester.getTopLeft(swatches.at(index)).dy;
      final row = (top * 100).round();
      rowCounts[row] = (rowCounts[row] ?? 0) + 1;
    }

    expect(rowCounts.length, greaterThan(1));
  });
}
