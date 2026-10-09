import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:blood_pressure_app/domain/domain.dart';
import 'package:blood_pressure_app/features/medications/medication_reminder_plan.dart';
import 'package:blood_pressure_app/features/medications/medication_timezone_database.dart';
import 'package:blood_pressure_app/features/medications/medicine_name.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:receive_intent/receive_intent.dart' as receive_intent;
import 'package:timezone/timezone.dart' as timezone;

final medicationNavigatorKey = GlobalKey<NavigatorState>();

String _reminderText(String key, String fallback) {
  final translated = key.tr();
  return translated == key ? fallback : translated;
}

@visibleForTesting
String medicationReminderNotificationTitle() =>
    _reminderText('reminderNotificationTitle', 'Medicine reminder');

NotificationDetails _medicationNotificationDetails() => NotificationDetails(
  android: AndroidNotificationDetails(
    'medication_reminders',
    _reminderText('reminderNotificationChannelName', 'Medicine reminders'),
    channelDescription: _reminderText(
      'reminderNotificationChannelDescription',
      'Reminders for saved medicine schedules',
    ),
    importance: Importance.high,
    priority: Priority.high,
  ),
  iOS: const DarwinNotificationDetails(),
);

@visibleForTesting
String formatMedicationDoseReminderBody(
  MedicationSchedule schedule,
  int minute,
) {
  final timing = switch (schedule.timingForMinute(minute)) {
    MedicationDoseTiming.anytime => '',
    MedicationDoseTiming.beforeFood =>
      ' · ${_reminderText('reminderTimingBeforeFood', 'Before food')}',
    MedicationDoseTiming.withFood =>
      ' · ${_reminderText('reminderTimingWithFood', 'With food')}',
    MedicationDoseTiming.afterFood =>
      ' · ${_reminderText('reminderTimingAfterFood', 'After food')}',
    MedicationDoseTiming.onWaking =>
      ' · ${_reminderText('reminderTimingOnWaking', 'When you wake')}',
    MedicationDoseTiming.beforeSleep =>
      ' · ${_reminderText('reminderTimingBeforeSleep', 'Before sleep')}',
  };
  return '${schedule.medicine.designation} · '
      '${formatMedicationDose(schedule.doseAmount, schedule.doseUnit)}$timing';
}

@visibleForTesting
Map<String, String> medicationReminderWidgetLabels() => {
  'statusAllSet': _reminderText('reminderWidgetAllSet', 'ALL SET'),
  'statusOverdue': _reminderText('reminderWidgetOverdue', 'OVERDUE'),
  'statusSnoozed': _reminderText('reminderWidgetSnoozed', 'SNOOZED'),
  'statusSoon': _reminderText('reminderWidgetSoon', 'SOON'),
  'statusNextDose': _reminderText('reminderWidgetNextDose', 'NEXT DOSE'),
  'noDoseDue': _reminderText('reminderWidgetNoDoseDue', 'No dose due'),
  'noMedicineDoseDue': _reminderText(
    'reminderWidgetNoMedicineDoseDue',
    'No medicine dose due',
  ),
  'now': _reminderText('reminderWidgetNow', 'now'),
  'hourUnit': _reminderText('reminderWidgetHourUnit', 'h'),
  'minuteUnit': _reminderText('reminderWidgetMinuteUnit', 'm'),
  'showsAll': _reminderText('homeWidgetShowsAll', 'All medicines'),
};

/// One widget view for every choice the Android configure screen can pin.
Map<String, Object> medicationWidgetCatalog(
  List<PlannedDose> open, {
  required bool showAll,
  required List<MedicationSchedule> schedules,
  Map<String, String>? labels,
}) {
  final widgetLabels = labels ?? medicationReminderWidgetLabels();
  final choices = <Map<String, String>>[
    {'id': '', 'name': widgetLabels['showsAll'] ?? 'All medicines'},
  ];
  final seen = <String>{''};
  void addChoice(String id, String name) {
    final scheduleId = id.trim();
    if (scheduleId.isEmpty || !seen.add(scheduleId)) return;
    final label = name.trim().isEmpty ? scheduleId : name.trim();
    choices.add({'id': scheduleId, 'name': label});
  }

  final colors = <String, int>{};
  for (final schedule in schedules) {
    final id = schedule.id;
    if (id == null) continue;
    addChoice(id, schedule.medicine.designation);
    final color = schedule.medicine.color;
    if (color != null && color != 0) colors[id] = color;
  }
  for (final dose in open) {
    addChoice(dose.scheduleId, dose.name);
    if (dose.color != 0) colors.putIfAbsent(dose.scheduleId, () => dose.color);
  }
  return {
    'choices': choices,
    'views': {
      for (final choice in choices)
        choice['id']!: _widgetView(
          selectReminderDoses(
            open,
            showAll: showAll,
            scheduleId: choice['id']!,
          ),
          widgetLabels,
          pinnedName: choice['id']!.isEmpty ? '' : choice['name']!,
          pinnedColor: colors[choice['id']],
        ),
    },
  };
}

Map<String, Object> _widgetView(
  List<PlannedDose> selected,
  Map<String, String> labels, {
  String pinnedName = '',
  int? pinnedColor,
}) {
  final rings = stackReminderRings(selected);
  final primary = rings.isEmpty ? null : rings.first;
  if (primary == null) {
    final view = Map<String, Object>.from(labels);
    final name = pinnedName.trim();
    if (name.isNotEmpty) {
      view['name'] = name;
      view['shortName'] = compactMedicineName(name);
      if (pinnedColor != null && pinnedColor != 0) view['color'] = pinnedColor;
    }
    return view;
  }
  return <String, Object>{
    ...labels,
    'name': primary.doses.first.name,
    'shortName': compactMedicineName(primary.doses.first.name),
    'color': primary.doses.first.color,
    'scheduledAtMs': primary.targetAt.millisecondsSinceEpoch,
    'status': primary.doses.first.status,
    'rings': [
      for (final ring in rings)
        {
          'dotted': ring.sharesTimer,
          'scheduledAtMs': ring.doses
              .map((dose) => dose.targetAt)
              .reduce((a, b) => a.isAfter(b) ? a : b)
              .millisecondsSinceEpoch,
          'status': ring.doses.first.status,
          'doses': [
            for (final dose in ring.doses)
              {
                'name': dose.name,
                'color': dose.color,
                'scheduledAtMs': dose.targetAt.millisecondsSinceEpoch,
                'intervalMs': dose.interval.inMilliseconds,
              },
          ],
        },
    ],
  };
}

/// Local notification and Android widget bridge for medication schedules.
class MedicationReminderRuntime {
  MedicationReminderRuntime._();

  static final instance = MedicationReminderRuntime._();
  static const _widgetChannel = MethodChannel(
    'com.shenepoy.janan/medication_widget',
  );

  final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();
  bool _initialized = false;
  bool _pendingWidgetRoute = false;
  StreamSubscription<receive_intent.Intent?>? _widgetIntentSubscription;

  Future<void> initialize() async {
    if (_initialized || (!Platform.isAndroid && !Platform.isIOS)) return;
    if (Platform.isAndroid) {
      _widgetIntentSubscription ??= receive_intent
          .ReceiveIntent
          .receivedIntentStream
          .listen((intent) {
            if (intent?.extra?['route'] == '/medications/today') {
              _pendingWidgetRoute = true;
              WidgetsBinding.instance.addPostFrameCallback((_) {
                flushPendingWidgetRoute();
              });
            }
          });
    }
    initializeMedicationTimezoneDatabase();
    final localTimezone = await FlutterTimezone.getLocalTimezone();
    timezone.setLocalLocation(medicationTimezone(localTimezone.identifier));
    await _notifications.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        iOS: DarwinInitializationSettings(),
      ),
      onDidReceiveNotificationResponse: (_) {
        medicationNavigatorKey.currentState?.pushNamed('/medications/today');
      },
    );
    _initialized = true;
  }

  /// Opens the agenda after the app has mounted its navigator.
  void flushPendingWidgetRoute() {
    if (!_pendingWidgetRoute) return;
    final navigator = medicationNavigatorKey.currentState;
    if (navigator == null) return;
    _pendingWidgetRoute = false;
    navigator.pushNamedAndRemoveUntil(
      '/medications/today',
      (route) => route.isFirst,
    );
  }

  /// Requests user-facing notification and exact-alarm access when available.
  Future<bool> requestPermissions() async {
    await initialize();
    if (Platform.isAndroid) {
      final android = _notifications
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();
      final permissionResult = await android?.requestNotificationsPermission();
      final notificationsEnabled =
          await android?.areNotificationsEnabled() ?? permissionResult ?? false;
      final exact = await android?.canScheduleExactNotifications() ?? false;
      if (notificationsEnabled && !exact) {
        await android?.requestExactAlarmsPermission();
      }
      return notificationsEnabled;
    }
    if (Platform.isIOS) {
      return await _notifications
              .resolvePlatformSpecificImplementation<
                IOSFlutterLocalNotificationsPlugin
              >()
              ?.requestPermissions(alert: true, badge: true, sound: true) ??
          false;
    }
    return false;
  }

  /// Returns the notification and exact-timing access currently granted.
  Future<
    ({bool supported, bool notificationsEnabled, bool? exactTimingEnabled})
  >
  permissionState() async {
    await initialize();
    if (Platform.isAndroid) {
      final android = _notifications
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();
      return (
        supported: true,
        notificationsEnabled: await android?.areNotificationsEnabled() ?? false,
        exactTimingEnabled:
            await android?.canScheduleExactNotifications() ?? false,
      );
    }
    if (Platform.isIOS) {
      final ios = _notifications
          .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin
          >();
      final permissions = await ios?.checkPermissions();
      return (
        supported: true,
        notificationsEnabled:
            permissions?.isEnabled == true ||
            permissions?.isProvisionalEnabled == true,
        exactTimingEnabled: null,
      );
    }
    return (
      supported: false,
      notificationsEnabled: false,
      exactTimingEnabled: null,
    );
  }

  /// Opens the operating system page for Janan's notification permission.
  Future<void> openNotificationSettings() async {
    await initialize();
    if (Platform.isAndroid) {
      await _notifications
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >()
          ?.openAppNotificationSettings();
    } else if (Platform.isIOS) {
      await _notifications
          .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin
          >()
          ?.openAppNotificationSettings();
    }
  }

  /// Opens Android's exact-alarm access page when access is unavailable.
  Future<void> requestExactAlarmPermission() async {
    await initialize();
    if (!Platform.isAndroid) return;
    await _notifications
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.requestExactAlarmsPermission();
  }

  Future<bool> get launchedFromNotification async {
    await initialize();
    final details = await _notifications.getNotificationAppLaunchDetails();
    return details?.didNotificationLaunchApp ?? false;
  }

  /// Rebuilds the next two weeks of reminders from saved local schedules.
  ///
  /// Overdue follow-ups are scheduled ahead of time so Android can restore
  /// them after a cold boot. Alarms whose time already passed while the
  /// device was off are not repeated; only instants still in the future
  /// are scheduled again the next time the app opens. When
  /// [notificationsEnabled] is false, pending alerts are cleared and nothing
  /// new is scheduled.
  Future<void> syncSchedules(
    List<MedicationSchedule> schedules, {
    List<DoseOccurrence> snoozedOccurrences = const [],
    List<DoseOccurrence> openOccurrences = const [],
    int overdueReminderCount = 3,
    Duration overdueReminderInterval = const Duration(minutes: 10),
    bool notificationsEnabled = true,
    bool shiftMissedDoseTimes = false,
    Duration missedDoseShiftLimit = const Duration(minutes: 60),
  }) async {
    await initialize();
    if (!_initialized) return;
    await _notifications.cancelAll();
    if (!notificationsEnabled) return;
    final android = _notifications
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    final exact = Platform.isAndroid
        ? await android?.canScheduleExactNotifications() ?? false
        : true;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final followUpFrom = <String, DateTime>{};
    final doseTargets = shiftedDoseTargets(
      openOccurrences,
      now: now,
      enabled: shiftMissedDoseTimes,
      grace: missedDoseShiftLimit,
      followUpFrom: followUpFrom,
    );
    final known = <String, DoseOccurrence>{
      for (final occurrence in openOccurrences) occurrence.id: occurrence,
    };
    for (final schedule in schedules.where((item) => item.active)) {
      for (var offset = 0; offset < 14; offset++) {
        final day = today.add(Duration(days: offset));
        if (!schedule.weekdays.contains(day.weekday)) continue;
        if (schedule.startDate != null &&
            _dateOnly(day).isBefore(_dateOnly(schedule.startDate!))) {
          continue;
        }
        if (schedule.endDate != null &&
            _dateOnly(day).isAfter(_dateOnly(schedule.endDate!))) {
          continue;
        }
        for (final minute in schedule.timeMinutes) {
          if (schedule.id == null) continue;
          final localTime = DateTime(
            day.year,
            day.month,
            day.day,
            minute ~/ 60,
            minute % 60,
          );
          final occurrenceId = medicationDoseOccurrenceId(
            schedule.id!,
            localTime,
          );
          if (doseClockAlarmClaimed(known[occurrenceId], now)) continue;
          final target = doseTargets[occurrenceId] ?? localTime;
          if (!target.isAfter(now)) continue;
          final scheduled = timezone.TZDateTime(
            timezone.local,
            target.year,
            target.month,
            target.day,
            target.hour,
            target.minute,
            target.second,
          );
          await _scheduleReminder(
            id: _notificationId(_doseNotificationKey(schedule.id!, localTime)),
            schedule: schedule,
            minute: minute,
            when: scheduled,
            exact: exact,
            payload: schedule.id,
          );
          await _scheduleOverdueFollowUps(
            schedule: schedule,
            scheduledAt: target,
            keyAt: localTime,
            bodyMinute: minute,
            now: now,
            count: overdueReminderCount,
            interval: overdueReminderInterval,
            exact: exact,
          );
        }
      }
    }
    for (final occurrence in openOccurrences) {
      final status = occurrence.statusAt(now);
      final scheduleId = occurrence.schedule.id;
      final movedTo = doseTargets[occurrence.id];
      if (scheduleId == null || occurrence.scheduledAt.isAfter(now)) continue;
      if (status != 'pending' && status != 'unrecorded') continue;
      final originalMinute =
          occurrence.scheduledAt.hour * 60 + occurrence.scheduledAt.minute;
      if (movedTo != null && movedTo.isAfter(now)) {
        if (!earlierDoseAlarmMovedAhead(
          scheduledAt: occurrence.scheduledAt,
          movedTo: movedTo,
          now: now,
        )) {
          continue;
        }
        await _scheduleReminder(
          id: _notificationId(
            _doseNotificationKey(scheduleId, occurrence.scheduledAt),
          ),
          schedule: occurrence.schedule,
          minute: originalMinute,
          when: timezone.TZDateTime(
            timezone.local,
            movedTo.year,
            movedTo.month,
            movedTo.day,
            movedTo.hour,
            movedTo.minute,
            movedTo.second,
          ),
          exact: exact,
          payload: scheduleId,
        );
        await _scheduleOverdueFollowUps(
          schedule: occurrence.schedule,
          scheduledAt: movedTo,
          keyAt: occurrence.scheduledAt,
          bodyMinute: originalMinute,
          now: now,
          count: overdueReminderCount,
          interval: overdueReminderInterval,
          exact: exact,
        );
        continue;
      }
      await _scheduleOverdueFollowUps(
        schedule: occurrence.schedule,
        scheduledAt:
            followUpFrom[occurrence.id] ??
            movedTo ??
            occurrence.scheduledAt,
        keyAt: occurrence.scheduledAt,
        bodyMinute: originalMinute,
        now: now,
        count: overdueReminderCount,
        interval: overdueReminderInterval,
        exact: exact,
      );
    }
    for (final occurrence in snoozedOccurrences) {
      final snoozeUntil = occurrence.snoozeUntil;
      if (occurrence.status != 'snoozed' ||
          snoozeUntil == null ||
          !snoozeUntil.isAfter(now)) {
        continue;
      }
      await _notifications.zonedSchedule(
        id: _snoozeNotificationId(occurrence.id),
        title: medicationReminderNotificationTitle(),
        body: formatMedicationDoseReminderBody(
          occurrence.schedule,
          occurrence.scheduledAt.hour * 60 + occurrence.scheduledAt.minute,
        ),
        scheduledDate: timezone.TZDateTime.from(snoozeUntil, timezone.local),
        notificationDetails: _medicationNotificationDetails(),
        androidScheduleMode: exact
            ? AndroidScheduleMode.exactAllowWhileIdle
            : AndroidScheduleMode.inexactAllowWhileIdle,
        payload: occurrence.id,
      );
    }
  }

  /// Schedules the follow-up alert for a snoozed dose.
  Future<void> scheduleSnooze(
    DoseOccurrence occurrence,
    DateTime until, {
    bool notificationsEnabled = true,
  }) async {
    await initialize();
    if (!_initialized ||
        !notificationsEnabled ||
        !until.isAfter(DateTime.now())) {
      return;
    }
    final android = _notifications
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    final exact = Platform.isAndroid
        ? await android?.canScheduleExactNotifications() ?? false
        : true;
    await _notifications.zonedSchedule(
      id: _snoozeNotificationId(occurrence.id),
      title: medicationReminderNotificationTitle(),
      body: formatMedicationDoseReminderBody(
        occurrence.schedule,
        occurrence.scheduledAt.hour * 60 + occurrence.scheduledAt.minute,
      ),
      scheduledDate: timezone.TZDateTime.from(until, timezone.local),
      notificationDetails: _medicationNotificationDetails(),
      androidScheduleMode: exact
          ? AndroidScheduleMode.exactAllowWhileIdle
          : AndroidScheduleMode.inexactAllowWhileIdle,
      payload: occurrence.id,
    );
  }

  /// Cancels a snooze alert once its dose is recorded or snoozed again.
  Future<void> cancelSnooze(String occurrenceId) async {
    await initialize();
    if (!_initialized) return;
    await _notifications.cancel(id: _snoozeNotificationId(occurrenceId));
  }

  /// Drops the on-time alert and overdue follow-ups for a recorded dose.
  Future<void> cancelClaimedDose(String occurrenceId) async {
    await initialize();
    if (!_initialized) return;
    final parsed = _parsedOccurrenceId(occurrenceId);
    if (parsed == null) return;
    await _notifications.cancel(
      id: _notificationId(
        _doseNotificationKey(parsed.scheduleId, parsed.scheduledAt),
      ),
    );
    for (var index = 1; index <= 6; index++) {
      await _notifications.cancel(
        id: _notificationId(
          _overdueNotificationKey(parsed.scheduleId, parsed.scheduledAt, index),
        ),
      );
    }
    await cancelSnooze(occurrenceId);
  }

  /// Shares a view per medicine so each home-screen widget can pin its own.
  Future<void> updateWidget(
    List<DoseOccurrence> occurrences, {
    bool showAll = true,
    List<MedicationSchedule> schedules = const [],
    bool shiftMissedDoseTimes = false,
    Duration missedDoseShiftLimit = const Duration(minutes: 60),
  }) async {
    if (!Platform.isAndroid) return;
    final now = DateTime.now();
    final targets = shiftedDoseTargets(
      occurrences,
      now: now,
      enabled: shiftMissedDoseTimes,
      grace: missedDoseShiftLimit,
    );
    final open = [
      for (final occurrence in occurrences)
        if (_plannedDose(
              occurrence,
              now,
              targets,
              grace: missedDoseShiftLimit,
            )
            case final dose?)
          dose,
    ]..sort((a, b) => a.targetAt.compareTo(b.targetAt));
    try {
      await _widgetChannel.invokeMethod<void>('update', {
        'summary': jsonEncode(
          medicationWidgetCatalog(open, showAll: showAll, schedules: schedules),
        ),
      });
    } on MissingPluginException {
      // The widget bridge is Android-only.
    } on PlatformException {
      // The in-app reminder flow remains available if widget refresh fails.
    }
  }

  Future<void> _scheduleReminder({
    required int id,
    required MedicationSchedule schedule,
    required int minute,
    required timezone.TZDateTime when,
    required bool exact,
    String? payload,
  }) {
    return _notifications.zonedSchedule(
      id: id,
      title: medicationReminderNotificationTitle(),
      body: formatMedicationDoseReminderBody(schedule, minute),
      scheduledDate: when,
      notificationDetails: _medicationNotificationDetails(),
      androidScheduleMode: exact
          ? AndroidScheduleMode.exactAllowWhileIdle
          : AndroidScheduleMode.inexactAllowWhileIdle,
      payload: payload ?? schedule.id,
    );
  }

  Future<void> _scheduleOverdueFollowUps({
    required MedicationSchedule schedule,
    required DateTime scheduledAt,
    required DateTime keyAt,
    required int bodyMinute,
    required DateTime now,
    required int count,
    required Duration interval,
    required bool exact,
  }) async {
    final scheduleId = schedule.id;
    if (scheduleId == null) return;
    for (final when in overdueReminderInstants(
      scheduledAt: scheduledAt,
      now: now,
      count: count,
      interval: interval,
    )) {
      final index =
          when.difference(scheduledAt).inMinutes ~/
          (interval.inMinutes == 0 ? 1 : interval.inMinutes);
      await _scheduleReminder(
        id: _notificationId(
          _overdueNotificationKey(scheduleId, keyAt, index),
        ),
        schedule: schedule,
        minute: bodyMinute,
        when: timezone.TZDateTime.from(when, timezone.local),
        exact: exact,
        payload: scheduleId,
      );
    }
  }

  PlannedDose? _plannedDose(
    DoseOccurrence occurrence,
    DateTime now,
    Map<String, DateTime> targets, {
    Duration grace = Duration.zero,
  }) {
    final status = occurrence.statusAt(now);
    if (status != 'pending' && status != 'snoozed' && status != 'unrecorded') {
      return null;
    }
    if (!reminderDoseIsCurrent(
      occurrence,
      now,
      targets,
      grace: grace,
    )) {
      return null;
    }
    final target = doseTakeAt(occurrence, now, targets);
    final raw = occurrence.schedule.medicine.color;
    return PlannedDose(
      scheduleId: occurrence.schedule.id ?? '',
      medicineId: occurrence.schedule.medicineId,
      targetAt: target,
      color: raw == null || raw == 0 ? 0xff92dccf : raw,
      name: occurrence.schedule.medicine.designation,
      status: status,
      interval: scheduledDoseInterval(
        occurrence.schedule,
        occurrence.scheduledAt,
      ),
    );
  }

  static String _doseNotificationKey(String scheduleId, DateTime scheduledAt) =>
      '$scheduleId:${scheduledAt.year}-${scheduledAt.month}-${scheduledAt.day}:${scheduledAt.hour * 60 + scheduledAt.minute}';

  static String _overdueNotificationKey(
    String scheduleId,
    DateTime scheduledAt,
    int index,
  ) => '${_doseNotificationKey(scheduleId, scheduledAt)}:overdue:$index';

  static ({String scheduleId, DateTime scheduledAt})? _parsedOccurrenceId(
    String occurrenceId,
  ) {
    final parts = occurrenceId.split('.');
    if (parts.length < 3) return null;
    final minute = int.tryParse(parts.last);
    final day = DateTime.tryParse(parts[parts.length - 2]);
    if (minute == null || day == null) return null;
    final scheduleId = parts.sublist(0, parts.length - 2).join('.');
    return (
      scheduleId: scheduleId,
      scheduledAt: DateTime(
        day.year,
        day.month,
        day.day,
        minute ~/ 60,
        minute % 60,
      ),
    );
  }

  static int _notificationId(String key) {
    var hash = 0x811c9dc5;
    for (final unit in key.codeUnits) {
      hash = ((hash ^ unit) * 0x01000193) & 0x7fffffff;
    }
    return hash == 0 ? 1 : hash;
  }

  static int _snoozeNotificationId(String occurrenceId) =>
      _notificationId('snooze:$occurrenceId');

  static DateTime _dateOnly(DateTime value) =>
      DateTime(value.year, value.month, value.day);
}
