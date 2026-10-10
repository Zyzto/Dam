import 'package:blood_pressure_app/app.dart';
import 'package:blood_pressure_app/features/settings/graph_screen.dart';
import 'package:blood_pressure_app/features/statistics/value_graph.dart';
import 'package:blood_pressure_app/model/horizontal_graph_line.dart';
import 'package:collection/collection.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:blood_pressure_app/domain/domain.dart';

import '../../model/blood_pressure_analyzer_test.dart';
import '../../util.dart';

void main() {
  test('Creates correct sys series', () {
    final records = [
      mockRecord(time: DateTime(2000), sys: 123),
      mockRecord(time: DateTime(2001), sys: 120),
      // ignore: avoid_redundant_argument_values
      mockRecord(time: DateTime(2002), sys: null),
      mockRecord(time: DateTime(2003), sys: 123),
      mockRecord(time: DateTime(2004), sys: 200),
    ];
    assert(records.isSorted((a, b) => a.time.compareTo(b.time)));

    final graph = records.sysGraph();
    expect(graph, hasLength(4));
    expect(graph.isSorted((a, b) => a.$1.compareTo(b.$1)), isTrue);
    expect(graph.elementAt(0).$2, 123);
    expect(graph.elementAt(1).$2, 120);
    expect(graph.elementAt(2).$2, 123);
    expect(graph.elementAt(3).$2, 200);
  });
  test('Creates correct dia series', () {
    final records = [
      mockRecord(time: DateTime(2000), dia: 123),
      mockRecord(time: DateTime(2001), dia: 120),
      // ignore: avoid_redundant_argument_values
      mockRecord(time: DateTime(2002), dia: null),
      mockRecord(time: DateTime(2003), dia: 123),
      mockRecord(time: DateTime(2004), dia: 200),
    ];
    assert(records.isSorted((a, b) => a.time.compareTo(b.time)));

    final graph = records.diaGraph();
    expect(graph, hasLength(4));
    expect(graph.isSorted((a, b) => a.$1.compareTo(b.$1)), isTrue);
    expect(graph.elementAt(0).$2, 123);
    expect(graph.elementAt(1).$2, 120);
    expect(graph.elementAt(2).$2, 123);
    expect(graph.elementAt(3).$2, 200);
  });
  test('Creates correct pul series', () {
    final records = [
      mockRecord(time: DateTime(2000), pul: 123),
      mockRecord(time: DateTime(2001), pul: 120),
      // ignore: avoid_redundant_argument_values
      mockRecord(time: DateTime(2002), pul: null),
      mockRecord(time: DateTime(2003), pul: 123),
      mockRecord(time: DateTime(2004), pul: 200),
    ];
    assert(records.isSorted((a, b) => a.time.compareTo(b.time)));

    final graph = records.pulGraph();
    expect(graph, hasLength(4));
    expect(graph.isSorted((a, b) => a.$1.compareTo(b.$1)), isTrue);
    expect(graph.elementAt(0).$2, 123.0);
    expect(graph.elementAt(1).$2, 120.0);
    expect(graph.elementAt(2).$2, 123.0);
    expect(graph.elementAt(3).$2, 200.0);
  });
  test('splitSeriesByGap keeps a connected series together', () {
    final segments = splitSeriesByGap([
      (DateTime(2026, 3, 1), 110.0),
      (DateTime(2026, 3, 2), 120.0),
      (DateTime(2026, 3, 3), 100.0),
    ], 2);
    expect(segments, hasLength(1));
    expect(segments.single, hasLength(3));
  });
  test('splitSeriesByGap breaks when the gap is larger than the setting', () {
    final segments = splitSeriesByGap([
      (DateTime(2026, 3, 1), 110.0),
      (DateTime(2026, 3, 2), 120.0),
      (DateTime(2026, 3, 6), 88.0),
      (DateTime(2026, 3, 7), 110.0),
    ], 2);
    expect(segments, hasLength(2));
    expect(segments[0], hasLength(2));
    expect(segments[1], hasLength(2));
  });
  test('isGraphEntirelyDisconnected is true when every segment is a single point', () {
    expect(isGraphEntirelyDisconnected(
      sys: [
        (DateTime(2003), 110.0),
        (DateTime(2005), 123.0),
      ],
      dia: const [],
      pul: const [],
      interruptAfterNDays: 5,
    ), isTrue);
    expect(isGraphEntirelyDisconnected(
      sys: [
        (DateTime(2003), 110.0),
        (DateTime(2005), 123.0),
      ],
      dia: const [],
      pul: const [],
      interruptAfterNDays: -1,
    ), isFalse);
  });
  testWidgets('BloodPressureValueGraph shows when there are not enough values', (tester) async {
    await pumpApp(tester, await _buildGraph([], [], []));
    await tester.pump();
    expect(find.text('Not enough data to draw a graph.'), findsOneWidget);
  });
  testWidgets('[gold] graph with all extras is rendered correctly', (tester) async {
    await pumpApp(tester, await _buildGraph([
      mockRecord(time: DateTime(2005), sys: 123, dia: 80, pul: 50),
      mockRecord(time: DateTime(2003), sys: 110, dia: 73, pul: 130),
      mockRecord(time: DateTime(2003, 5), sys: 140, dia: 74, pul: 64),
      mockRecord(time: DateTime(2007), sys: 132, dia: 100, pul: 75),
    ], [
      (DateTime(2005), Colors.purple),
      (DateTime(2005, 3), Colors.tealAccent),
      (DateTime(2007), Colors.yellow),
    ], [
      mockIntake(mockMedicine(color: Colors.blueGrey), time: DateTime(2005).millisecondsSinceEpoch),
      mockIntake(mockMedicine(color: Colors.indigoAccent), time: DateTime(2004).millisecondsSinceEpoch),
    ],
    settings: TestSettingsSeed(
      drawRegressionLines: true,
      graphLineThickness: 3.2,
      diaWarn: 75,
      needlePinBarWidth: 7.0,
      horizontalGraphLines: [
        HorizontalGraphLine(Colors.lightBlue, 113),
        HorizontalGraphLine(Colors.amber, 45),
      ],
      interruptGraphAfterNDays: 0,
    )), extraPumps: 0);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Not enough data to draw a graph.'), findsNothing);

    await expectLater(find.byType(BloodPressureValueGraph), myMatchesGoldenFile('full_graph-years.png'));
  }, tags: 'gold');

  testWidgets('BloodPressureValueGraph is fine with enough values in sys category', (tester) async {
    await pumpApp(tester, await _buildGraph([
      mockRecord(time: DateTime(2005), sys: 123),
      mockRecord(time: DateTime(2003), sys: 110),
    ], [], []));
    await tester.pump();
    expect(find.text('Not enough data to draw a graph.'), findsNothing);
    expect(find.byType(LineChart), findsOneWidget);
  });
  testWidgets('BloodPressureValueGraph is fine with enough values in dia category', (tester) async {
    await pumpApp(tester, await _buildGraph([
      mockRecord(time: DateTime(2005), dia: 123),
      mockRecord(time: DateTime(2003), dia: 110),
    ], [], []));
    await tester.pump();
    expect(find.text('Not enough data to draw a graph.'), findsNothing);
    expect(find.byType(LineChart), findsOneWidget);
  });
  testWidgets('BloodPressureValueGraph is fine with enough values in pul category', (tester) async {
    await pumpApp(tester, await _buildGraph([
      mockRecord(time: DateTime(2005), pul: 123),
      mockRecord(time: DateTime(2003), pul: 110),
    ], [], []));
    await tester.pump();
    expect(find.text('Not enough data to draw a graph.'), findsNothing);
    expect(find.byType(LineChart), findsOneWidget);
  });
  testWidgets('Displays warning when data is too far apart', (tester) async {
    await pumpApp(tester, await materialApp(_buildGraphWithoutApp([
      mockRecord(time: DateTime(2005), sys: 123),
      mockRecord(time: DateTime(2003), sys: 110),
    ], [], []),
      settings: TestSettingsSeed(interruptGraphAfterNDays: 5),
      routes: { AppRoute.settingsGraph.path: (_) => const GraphScreen(), },
    ));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('The time between measurements is greater than the maximum distance displayed without interruptions. You can change that in the settings.'), findsOneWidget);
    expect(find.text('Open Settings'), findsOneWidget);

    expect(find.byType(GraphScreen), findsNothing);
    await tester.tap(find.text('Open Settings'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 700));
    expect(find.byType(GraphScreen), findsOneWidget);
  });
  testWidgets('Not displaying bigGraphSplit warning when splitting is disabled', (tester) async {
    await pumpApp(tester, await _buildGraph([
      mockRecord(time: DateTime(2005), sys: 123),
      mockRecord(time: DateTime(2003), sys: 110),
    ], [], [], settings: TestSettingsSeed(interruptGraphAfterNDays: 0)));
    expect(find.text('The time between measurements is greater than the maximum distance displayed without interruptions. You can change that in the settings.'), findsNothing);
  });

  testWidgets('[gold] graph renders area at start correctly', (tester) async {
    await pumpApp(tester, await _buildGraph([
        mockRecord(time: DateTime(2003), sys: 170, dia: 100, pul: 50),
        mockRecord(time: DateTime(2005), sys: 110, dia: 70, pul: 50),
      ], [], [],
      settings: TestSettingsSeed(
        diaWarn: 75,
        sysWarn: 120,
        interruptGraphAfterNDays: 0,
      ),
    ), extraPumps: 0);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Not enough data to draw a graph.'), findsNothing);

    await expectLater(find.byType(BloodPressureValueGraph), myMatchesGoldenFile('value-graph-start-warn.png'));
  }, tags: 'gold');
  testWidgets('[gold] graph renders area at end correctly', (tester) async {
    await pumpApp(tester, await _buildGraph([
      mockRecord(time: DateTime(2005), sys: 170, dia: 100, pul: 50),
      mockRecord(time: DateTime(2003), sys: 110, dia: 70, pul: 50),
    ], [], [],
      settings: TestSettingsSeed(
        diaWarn: 75,
        sysWarn: 120,
        interruptGraphAfterNDays: 0,
      ),
    ), extraPumps: 0);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Not enough data to draw a graph.'), findsNothing);

    await expectLater(find.byType(BloodPressureValueGraph), myMatchesGoldenFile('value-graph-end-warn.png'));
  }, tags: 'gold');
  testWidgets('[gold] warn area not drawn above graph', (tester) async {
    await pumpApp(tester, await _buildGraph([
      mockRecord(time: DateTime(2005), sys: 103, dia: null, pul: null),
      mockRecord(time: DateTime(2003), sys: 89, dia: null, pul: null),
    ], [], [],
      settings: TestSettingsSeed(
        sysWarn: 120,
        interruptGraphAfterNDays: 0,
      ),
    ), extraPumps: 0);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Not enough data to draw a graph.'), findsNothing);

    await expectLater(find.byType(BloodPressureValueGraph), myMatchesGoldenFile('value-graph-warn-not-above.png'));
  }, tags: 'gold');
  testWidgets('[gold] interrupts graph correctly', (tester) async {
    await pumpApp(tester, await _buildGraph([
      mockRecord(time: DateTime(2026, 2, 28), sys: 110),
      mockRecord(time: DateTime(2026, 3, 1), sys: 120),
      mockRecord(time: DateTime(2026, 3, 2), sys: 89),
      mockRecord(time: DateTime(2026, 3, 3), sys: 100),
      mockRecord(time: DateTime(2026, 3, 6), sys: 88),
      mockRecord(time: DateTime(2026, 3, 7), sys: 110),
      mockRecord(time: DateTime(2026, 3, 8), sys: 97),
      mockRecord(time: DateTime(2026, 3, 10), sys: 80),
    ], [], [],
      settings: TestSettingsSeed(
        sysWarn: 120,
        interruptGraphAfterNDays: 2,
      ),
    ), extraPumps: 0);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    await expectLater(find.byType(BloodPressureValueGraph), myMatchesGoldenFile('value-graph-interrupts.png'));
  }, tags: 'gold');
}

Future<Widget> _buildGraph(
  List<BloodPressureRecord> data,
  List<(DateTime, Color)> colors,
  List<MedicineIntake> intakes, {
  TestSettingsSeed? settings,
}) => materialApp(
  _buildGraphWithoutApp(data, colors, intakes),
  settings: settings,
);

Widget _buildGraphWithoutApp(
  List<BloodPressureRecord> data,
  List<(DateTime, Color)> colors,
  List<MedicineIntake> intakes,
) => SizedBox(
  width: 500,
  height: 300,
  child: BloodPressureValueGraph(
    records: data,
    colors: colors.map((e) => Note(time: e.$1, color: e.$2.toARGB32())).toList(),
    intakes: intakes,
  ),
);
