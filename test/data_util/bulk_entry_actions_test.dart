import 'package:blood_pressure_app/data_util/bulk_entry_actions.dart';
import 'package:blood_pressure_app/domain/domain.dart';
import 'package:blood_pressure_app/features/bluetooth/logic/ble_measurement_duplicates.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../model/export_import/record_formatter_test.dart';
import '../util.dart';

void main() {
  testWidgets('changeEntriesDate keeps each time of day', (tester) async {
    final first = mockEntry(
      time: DateTime(2026, 4, 5, 16, 19, 10),
      sys: 120,
      dia: 80,
      pul: 70,
    );
    final second = mockEntry(
      time: DateTime(2026, 4, 5, 8, 5, 30),
      sys: 130,
      dia: 80,
      pul: 70,
    );
    final bpRepo = MockBloodPressureRepository();
    await bpRepo.add(first.record!);
    await bpRepo.add(second.record!);

    await pumpApp(tester, await appBase(
      settings: TestSettingsSeed(confirmDeletion: false),
      bpRepo: bpRepo,
      Builder(
        builder: (context) => TextButton(
          onPressed: () => context.changeEntriesDate([first, second]),
          child: const Text('go'),
        ),
      ),
    ));

    await tester.tap(find.text('go'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('15'));
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();

    final records = await bpRepo.get(DateRange.all());
    expect(records, hasLength(2));
    expect(
      records.map((record) => record.time).toSet(),
      {
        DateTime(2026, 4, 15, 16, 19, 10),
        DateTime(2026, 4, 15, 8, 5, 30),
      },
    );
  });

  testWidgets('changeEntriesNote writes the same text per entry', (tester) async {
    usePhoneTestSurface(tester);
    final first = mockEntry(
      time: DateTime(2026, 4, 5, 16, 19, 10),
      sys: 120,
      note: 'one',
    );
    final second = mockEntry(
      time: DateTime(2026, 4, 5, 8, 5, 30),
      sys: 130,
      note: 'two',
    );
    final noteRepo = MockNoteRepository();
    await noteRepo.add(first.note!);
    await noteRepo.add(second.note!);

    await pumpApp(tester, await appBase(
      noteRepo: noteRepo,
      Builder(
        builder: (context) => TextButton(
          onPressed: () => context.changeEntriesNote([first, second]),
          child: const Text('go'),
        ),
      ),
    ));

    await tester.tap(find.text('go'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'shared note');
    await tapSafaehConfirm(tester);
    await tester.pumpAndSettle();

    final notes = await noteRepo.get(DateRange.all());
    expect(notes.map((note) => note.note).toSet(), {'shared note'});
    expect(notes, hasLength(2));
  });

  testWidgets('changeEntriesColor writes the same color per entry', (tester) async {
    usePhoneTestSurface(tester);
    final first = mockEntry(
      time: DateTime(2026, 4, 5, 16, 19, 10),
      sys: 120,
      note: 'one',
    );
    final second = mockEntry(
      time: DateTime(2026, 4, 5, 8, 5, 30),
      sys: 130,
      note: 'two',
    );
    final noteRepo = MockNoteRepository();
    await noteRepo.add(first.note!);
    await noteRepo.add(second.note!);

    await pumpApp(tester, await appBase(
      noteRepo: noteRepo,
      Builder(
        builder: (context) => TextButton(
          onPressed: () => context.changeEntriesColor([first, second]),
          child: const Text('go'),
        ),
      ),
    ));

    await tester.tap(find.text('go'));
    await tester.pumpAndSettle();
    final red = find.byWidgetPredicate((widget) {
      if (widget is! Container) return false;
      final decoration = widget.decoration;
      return decoration is BoxDecoration && decoration.color == const Color(0xFFF44336);
    });
    expect(red, findsOneWidget);
    await tester.tap(red);
    await tester.pumpAndSettle();

    final notes = await noteRepo.get(DateRange.all());
    expect(notes.map((note) => note.color).toSet(), {const Color(0xFFF44336).toARGB32()});
    expect(notes.map((note) => note.note).toSet(), {'one', 'two'});
  });

  testWidgets('deleteEntries removes records and undo restores them', (tester) async {
    final first = mockEntry(
      time: DateTime(2026, 4, 5, 16, 19, 10),
      sys: 120,
    );
    final second = mockEntry(
      time: DateTime(2026, 4, 5, 8, 5, 30),
      sys: 130,
    );
    final bpRepo = MockBloodPressureRepository();
    final blacklist = MockBleBlacklistRepository();
    await bpRepo.add(first.record!);
    await bpRepo.add(second.record!);

    await pumpApp(tester, await appBase(
      settings: TestSettingsSeed(confirmDeletion: false),
      bpRepo: bpRepo,
      blacklistRepo: blacklist,
      Builder(
        builder: (context) => TextButton(
          onPressed: () => context.deleteEntries([first, second]),
          child: const Text('go'),
        ),
      ),
    ));

    await tester.tap(find.text('go'));
    await tester.pumpAndSettle();
    expect(await bpRepo.get(DateRange.all()), isEmpty);
    expect(await blacklist.getKeys('bp'), isEmpty);

    await tester.tap(find.text('UNDO', skipOffstage: false));
    await tester.pumpAndSettle();
    expect(await bpRepo.get(DateRange.all()), hasLength(2));
  });

  testWidgets('bulk deleteAndBlacklist writes keys that undo removes', (tester) async {
    usePhoneTestSurface(tester);
    final entry = mockEntry(
      time: DateTime.utc(2026, 4, 5, 16, 19, 10),
      sys: 120,
    );
    final bpRepo = MockBloodPressureRepository();
    final blacklist = MockBleBlacklistRepository();
    await bpRepo.add(entry.record!);

    await pumpApp(tester, await appBase(
      settings: TestSettingsSeed(confirmDeletion: true),
      bpRepo: bpRepo,
      blacklistRepo: blacklist,
      Builder(
        builder: (context) => TextButton(
          onPressed: () => context.deleteEntries([entry]),
          child: const Text('go'),
        ),
      ),
    ));

    await tester.tap(find.text('go'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('deleteAndBlacklist')));
    await tester.pumpAndSettle();
    expect(
      await blacklist.getKeys('bp'),
      {bloodPressureRecordKey(entry.record!)},
    );

    await tester.tap(find.text('UNDO', skipOffstage: false));
    await tester.pumpAndSettle();
    expect(await blacklist.getKeys('bp'), isEmpty);
    expect(await bpRepo.get(DateRange.all()), hasLength(1));
  });
}
