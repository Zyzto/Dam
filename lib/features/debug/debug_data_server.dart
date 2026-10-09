import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:blood_pressure_app/core/repository/repository_providers.dart';
import 'package:blood_pressure_app/domain/domain.dart';
import 'package:blood_pressure_app/features/medications/medication_reminder_providers.dart';
import 'package:blood_pressure_app/features/medications/medication_reminders_screens.dart';
import 'package:blood_pressure_app/features/settings/app_settings.dart';
import 'package:blood_pressure_app/features/settings/registry.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_settings_framework/flutter_settings_framework.dart';

/// Localhost port the debug MCP bridge forwards to.
const debugDataPort = 8765;

/// Medicines created for reminder-ring tests use this prefix.
const testMedicinePrefix = 'Test ';

/// One seeded dose. `role` is `overdue`, `same_time`, or `later`.
typedef PlannedTestDose = ({
  String name,
  int color,
  DateTime at,
  String role,
  double doseMg,
});

/// Doses that exercise overdue alerts, a shared dotted ring, and a later ring.
///
/// Each dose exists only on its own calendar day, so a time after midnight
/// does not also create an earlier dose today.
List<PlannedTestDose> reminderRingFixture(DateTime now) {
  DateTime minute(DateTime value) =>
      DateTime(value.year, value.month, value.day, value.hour, value.minute);

  final overdue = minute(now.subtract(const Duration(minutes: 8)));
  var shared = minute(now.add(const Duration(minutes: 45)));
  if (!shared.isAfter(overdue)) {
    shared = overdue.add(const Duration(minutes: 1));
  }
  var later = minute(now.add(const Duration(hours: 3)));
  if (!later.isAfter(shared)) {
    later = shared.add(const Duration(hours: 1));
  }
  return [
    (
      name: '${testMedicinePrefix}Lisinopril',
      color: 0xFF4C78A8,
      at: overdue,
      role: 'overdue',
      doseMg: 10,
    ),
    (
      name: '${testMedicinePrefix}Metformin',
      color: 0xFFE07A5F,
      at: shared,
      role: 'same_time',
      doseMg: 500,
    ),
    (
      name: '${testMedicinePrefix}Aspirin',
      color: 0xFF3D9B7A,
      at: shared,
      role: 'same_time',
      doseMg: 81,
    ),
    (
      name: '${testMedicinePrefix}Atorvastatin',
      color: 0xFFE6B325,
      at: later,
      role: 'later',
      doseMg: 20,
    ),
  ];
}

/// HTTP server on [debugDataPort]. It listens only while the setting is on.
class DebugDataServer {
  DebugDataServer(this._ref);

  final WidgetRef _ref;
  HttpServer? _server;
  Future<void>? _starting;
  var _closed = false;

  Future<void> start() {
    if (!kDebugMode || _server != null) return Future<void>.value();
    _closed = false;
    return _starting ??= _bind();
  }

  Future<void> _bind() async {
    try {
      final server = await HttpServer.bind(
        InternetAddress.loopbackIPv4,
        debugDataPort,
      );
      if (_closed) {
        await server.close(force: true);
        return;
      }
      _server = server;
      server.listen(_onRequest);
      debugPrint('Debug data server listening on 127.0.0.1:$debugDataPort');
    } catch (error, stack) {
      debugPrint('Debug data server failed to bind: $error\n$stack');
    } finally {
      _starting = null;
    }
  }

  Future<void> stop() async {
    _closed = true;
    final server = _server;
    _server = null;
    await server?.close(force: true);
  }

  Future<void> _onRequest(HttpRequest request) async {
    try {
      final path = request.uri.path;
      if (request.method == 'GET' && path == '/health') {
        await _json(request, 200, {'ok': true, 'port': debugDataPort});
        return;
      }
      if (request.method == 'POST' && path == '/seed') {
        final body = await _body(request);
        final scenario = body['scenario'];
        if (scenario == 'reminder_rings') {
          final doses = await seedReminderRings(_ref);
          await _json(request, 200, {'ok': true, 'doses': doses});
          return;
        }
        if (scenario == 'history') {
          final counts = await seedSampleHistory(_ref);
          await _json(request, 200, {'ok': true, ...counts});
          return;
        }
        await _json(request, 400, {
          'ok': false,
          'error': 'Unknown scenario. Use reminder_rings or history.',
        });
        return;
      }
      if (request.method == 'POST' && path == '/clear') {
        final removed = await clearTestMedicines(_ref);
        await _json(request, 200, {'ok': true, 'removed': removed});
        return;
      }
      await _json(request, 404, {'ok': false, 'error': 'Not found'});
    } catch (error, stack) {
      debugPrint('Debug data request failed: $error\n$stack');
      await _json(request, 500, {'ok': false, 'error': '$error'});
    }
  }
}

Future<Map<String, Object?>> _body(HttpRequest request) async {
  final raw = await utf8.decoder.bind(request).join();
  if (raw.trim().isEmpty) return const {};
  final decoded = jsonDecode(raw);
  if (decoded is Map) return Map<String, Object?>.from(decoded);
  return const {};
}

Future<void> _json(
  HttpRequest request,
  int status,
  Map<String, Object?> body,
) async {
  request.response.statusCode = status;
  request.response.headers.contentType = ContentType.json;
  request.response.write(jsonEncode(body));
  await request.response.close();
}

/// Replaces test medicines with the reminder-ring fixture and reschedules.
Future<List<Map<String, Object?>>> seedReminderRings(WidgetRef ref) async {
  await clearTestMedicines(ref);
  final medicines = ref.read(medicineRepositoryProvider);
  final schedules = ref.read(medicationScheduleRepositoryProvider);
  final planned = reminderRingFixture(DateTime.now());
  for (final dose in planned) {
    final medicine = Medicine(
      designation: dose.name,
      color: dose.color,
      dosis: Weight.mg(dose.doseMg),
      unit: MedicationUnit.mg,
    );
    await medicines.add(medicine);
    final day = DateTime(dose.at.year, dose.at.month, dose.at.day);
    await schedules.save(
      MedicationSchedule(
        medicineId: '',
        medicine: medicine,
        doseAmount: dose.doseMg,
        doseUnit: MedicationUnit.mg,
        timeMinutes: [dose.at.hour * 60 + dose.at.minute],
        weekdays: const {1, 2, 3, 4, 5, 6, 7},
        startDate: day,
        endDate: day,
      ),
    );
    await schedules.getOccurrences(day);
  }
  final controller = ref.read(settingsProvidersProvider).controller;
  await controller.set(medicineFeatureEnabledSetting, true);
  await controller.set(showAllReminderRingsSetting, true);
  await _refreshReminders(ref);
  return [
    for (final dose in planned)
      {
        'name': dose.name,
        'role': dose.role,
        'at': dose.at.toIso8601String(),
        'color': dose.color,
      },
  ];
}

/// Fills the last two weeks with blood pressure, weight, and medicine logs.
///
/// Medicine logs stay on earlier days so today's open reminders are left alone.
Future<Map<String, Object?>> seedSampleHistory(WidgetRef ref) async {
  final now = DateTime.now();
  final day = DateTime(now.year, now.month, now.day);
  final bpRepo = ref.read(bloodPressureRepositoryProvider);
  final weightRepo = ref.read(bodyweightRepositoryProvider);
  final intakeRepo = ref.read(medicineIntakeRepositoryProvider);
  final medicineRepo = ref.read(medicineRepositoryProvider);
  var medicines = await medicineRepo.getAll();
  if (medicines.isEmpty) {
    final created = [
      Medicine(
        designation: 'Lisinopril',
        color: 0xFF4C78A8,
        dosis: Weight.mg(10),
      ),
      Medicine(
        designation: 'Metformin',
        color: 0xFFE07A5F,
        dosis: Weight.mg(500),
      ),
    ];
    for (final medicine in created) {
      await medicineRepo.add(medicine);
    }
    medicines = await medicineRepo.getAll();
  }

  var bpCount = 0;
  var weightCount = 0;
  var intakeCount = 0;
  for (var daysAgo = 13; daysAgo >= 0; daysAgo--) {
    final morning = day.subtract(Duration(days: daysAgo));
    final bpTime = DateTime(morning.year, morning.month, morning.day, 8, 20);
    if (!bpTime.isAfter(now)) {
      await bpRepo.add(
        BloodPressureRecord(
          time: bpTime,
          sys: Pressure.mmHg(118 + (daysAgo % 5) * 4),
          dia: Pressure.mmHg(74 + (daysAgo % 4) * 3),
          pul: 66 + (daysAgo % 7) * 2,
        ),
      );
      bpCount++;
    }
    if (daysAgo % 3 == 0) {
      final evening = DateTime(
        morning.year,
        morning.month,
        morning.day,
        19,
        40,
      );
      if (!evening.isAfter(now)) {
        await bpRepo.add(
          BloodPressureRecord(
            time: evening,
            sys: Pressure.mmHg(124 + (daysAgo % 4) * 3),
            dia: Pressure.mmHg(78 + (daysAgo % 3) * 2),
            pul: 70 + (daysAgo % 5),
          ),
        );
        bpCount++;
      }
    }
    final weighIn = DateTime(morning.year, morning.month, morning.day, 7, 10);
    if (!weighIn.isAfter(now)) {
      await weightRepo.add(
        BodyweightRecord(
          time: weighIn,
          weight: Weight.kg(81.4 - (13 - daysAgo) * 0.06),
        ),
      );
      weightCount++;
    }
    final logged = DateTime(morning.year, morning.month, morning.day, 8, 5);
    if (now.difference(logged) < const Duration(hours: 13)) continue;
    for (final medicine in medicines) {
      await intakeRepo.add(
        MedicineIntake(
          time: logged,
          medicine: medicine,
          dosis: medicine.dosis ?? Weight.mg(1),
        ),
      );
      intakeCount++;
    }
  }
  return {
    'bloodPressure': bpCount,
    'weight': weightCount,
    'medicineLogs': intakeCount,
    'medicines': [for (final medicine in medicines) medicine.designation],
  };
}

/// Deletes schedules and medicines created by the fixture.
Future<List<String>> clearTestMedicines(WidgetRef ref) async {
  final schedules = ref.read(medicationScheduleRepositoryProvider);
  final medicines = ref.read(medicineRepositoryProvider);
  final removed = <String>[];
  for (final schedule in await schedules.getAll()) {
    final name = schedule.medicine.designation;
    final id = schedule.id;
    if (id == null || !name.startsWith(testMedicinePrefix)) continue;
    await schedules.delete(id);
    removed.add(name);
  }
  for (final medicine in await medicines.getAll()) {
    if (!medicine.designation.startsWith(testMedicinePrefix)) continue;
    await medicines.remove(medicine);
    if (!removed.contains(medicine.designation)) {
      removed.add(medicine.designation);
    }
  }
  await _refreshReminders(ref);
  return removed;
}

Future<void> _refreshReminders(WidgetRef ref) async {
  final settings = ref.read(appSettingsProvider);
  final repository = ref.read(medicationScheduleRepositoryProvider);
  if (!settings.medicineFeatureEnabled) {
    await clearMedicationReminders();
  } else {
    await syncMedicationReminders(repository, settings);
  }
  ref.invalidate(medicationSchedulesProvider);
  ref.invalidate(homeMedicationOccurrencesProvider);
  ref.invalidate(todayMedicationOccurrencesProvider);
  ref.invalidate(medicationDayProvider);
}
