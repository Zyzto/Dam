import 'package:blood_pressure_app/components/color_picker.dart';
import 'package:blood_pressure_app/components/confirm_deletion_dialog.dart';
import 'package:blood_pressure_app/components/input_dialog.dart';
import 'package:blood_pressure_app/core/repository/repo_context.dart';
import 'package:blood_pressure_app/core/widgets/toast.dart';
import 'package:blood_pressure_app/domain/domain.dart';
import 'package:blood_pressure_app/features/bluetooth/logic/ble_measurement_duplicates.dart';
import 'package:blood_pressure_app/features/settings/app_settings.dart';
import 'package:blood_pressure_app/features/settings/registry.dart';
import 'package:blood_pressure_app/logging.dart';
import 'package:blood_pressure_app/model/combined_entry.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:health/health.dart';

/// High-level bulk edits for selected list rows.
extension BulkEntryUtils on BuildContext {
  /// Set the calendar date of each entry, keeping its time of day.
  Future<bool> changeEntriesDate(Iterable<CombinedEntry> entries) async {
    if (entries.isEmpty) return false;
    final now = DateTime.now();
    final latest = entries
        .map((entry) => entry.time)
        .reduce((a, b) => a.isAfter(b) ? a : b);
    final date = await showDatePicker(
      context: this,
      initialDate: latest.isAfter(now) ? now : latest,
      firstDate: DateTime.fromMillisecondsSinceEpoch(1),
      lastDate: now,
    );
    if (date == null || !mounted) return false;
    try {
      for (final entry in entries) {
        await _rewriteEntry(entry, _withDate(entry.time, date));
      }
      _showUpdated();
      return true;
    } on StateError {
      Log.severe('changeEntriesDate called without repositories');
      return false;
    }
  }

  /// Set the calendar date of each weigh-in, keeping its time of day.
  Future<bool> changeWeightsDate(Iterable<BodyweightRecord> records) async {
    if (records.isEmpty) return false;
    final now = DateTime.now();
    final latest = records
        .map((record) => record.time)
        .reduce((a, b) => a.isAfter(b) ? a : b);
    final date = await showDatePicker(
      context: this,
      initialDate: latest.isAfter(now) ? now : latest,
      firstDate: DateTime.fromMillisecondsSinceEpoch(1),
      lastDate: now,
    );
    if (date == null || !mounted) return false;
    try {
      final repo = weightRepo;
      for (final record in records) {
        await repo.remove(record);
        await repo.add(record.copyWith(time: _withDate(record.time, date)));
      }
      _showUpdated();
      return true;
    } on StateError {
      Log.severe('changeWeightsDate called without repositories');
      return false;
    }
  }

  /// Replace the note text of each entry, keeping its color.
  Future<bool> changeEntriesNote(Iterable<CombinedEntry> entries) async {
    if (entries.isEmpty) return false;
    final notes = entries.map((entry) => entry.note?.note).toSet();
    final shared = notes.length == 1 ? notes.single : null;
    final text = await showInputDialog(
      this,
      hintText: 'editNote'.tr(),
      initialValue: shared,
    );
    if (text == null || !mounted) return false;
    try {
      final repo = noteRepo;
      for (final entry in entries) {
        if (entry.note != null) await repo.remove(entry.note!);
        final color = entry.note?.color;
        final trimmed = text.trim();
        if (trimmed.isEmpty && color == null) continue;
        await repo.add(Note(
          time: entry.time,
          note: trimmed.isEmpty ? null : trimmed,
          color: color,
        ));
      }
      _showUpdated();
      return true;
    } on StateError {
      Log.severe('changeEntriesNote called without repositories');
      return false;
    }
  }

  /// Replace the note color of each entry, keeping its text.
  Future<bool> changeEntriesColor(Iterable<CombinedEntry> entries) async {
    if (entries.isEmpty) return false;
    final colors = entries.map((entry) => entry.color).toSet();
    final shared = colors.length == 1 ? colors.single : null;
    final picked = await showColorPaletteSheet(
      this,
      availableColors: [for (final value in appColorOptions) Color(value)],
      initialColor: shared == null ? null : Color(shared),
      showTransparentColor: true,
      title: 'changeColor'.tr(),
    );
    if (picked == null || !mounted) return false;
    try {
      final repo = noteRepo;
      final color = picked == Colors.transparent ? null : picked.toARGB32();
      for (final entry in entries) {
        if (entry.note != null) await repo.remove(entry.note!);
        final text = entry.note?.note;
        if (text == null && color == null) continue;
        await repo.add(Note(time: entry.time, note: text, color: color));
      }
      _showUpdated();
      return true;
    } on StateError {
      Log.severe('changeEntriesColor called without repositories');
      return false;
    }
  }

  /// Delete every selected entry.
  Future<bool> deleteEntries(Iterable<CombinedEntry> entries) async {
    final list = entries.toList();
    if (list.isEmpty) return false;
    try {
      final settings = readAppSettings();
      var choice = DeleteChoice.delete;
      if (settings.confirmDeletion) {
        choice = await showConfirmDeletionChoice(
          this,
          allowBlacklist: list.any(
            (entry) => entry.record != null || entry.weight != null,
          ),
        );
        if (!mounted || choice == DeleteChoice.cancel) return false;
      }
      final blacklist = choice == DeleteChoice.deleteAndBlacklist;
      for (final entry in list) {
        await _removeEntry(
          entry,
          blacklist: blacklist,
          health: settings.useHealthConnect && settings.syncPressureMeasurements
              ? Health()
              : null,
        );
      }
      if (!mounted) return true;
      _showDeleted(list, blacklist: blacklist);
      return true;
    } on StateError {
      Log.severe('deleteEntries called without repositories');
      return false;
    }
  }

  /// Delete every selected weigh-in.
  Future<bool> deleteWeights(Iterable<BodyweightRecord> records) async {
    final list = records.toList();
    if (list.isEmpty) return false;
    try {
      final settings = readAppSettings();
      var choice = DeleteChoice.delete;
      if (settings.confirmDeletion) {
        choice = await showConfirmDeletionChoice(
          this,
          allowBlacklist: true,
        );
        if (!mounted || choice == DeleteChoice.cancel) return false;
      }
      final blacklist = choice == DeleteChoice.deleteAndBlacklist;
      final repo = weightRepo;
      final blocked = <String>[];
      for (final record in list) {
        await repo.remove(record);
        if (blacklist) {
          final key = bodyweightRecordKey(record);
          await blacklistRepo.add('weight', key);
          blocked.add(key);
        }
        if (settings.useHealthConnect && settings.syncWeightMeasurements) {
          await Health().delete(
            type: HealthDataType.WEIGHT,
            startTime: record.time.subtract(const Duration(milliseconds: 500)),
            endTime: record.time.add(const Duration(milliseconds: 500)),
          );
        }
      }
      if (!mounted) return true;
      dismissAllToasts();
      showToastWithAction(
        'deletionConfirmed'.tr(),
        actionLabel: 'btnUndo'.tr(),
        onAction: () async {
          for (final record in list) {
            await repo.add(record);
          }
          for (final key in blocked) {
            await blacklistRepo.remove('weight', key);
          }
        },
      );
      return true;
    } on StateError {
      Log.severe('deleteWeights called without repositories');
      return false;
    }
  }

  Future<void> _rewriteEntry(CombinedEntry entry, DateTime nextTime) async {
    await _removeEntry(entry, blacklist: false);
    if (entry.record != null) {
      await bpRepo.add(BloodPressureRecord(
        time: nextTime,
        sys: entry.record!.sys,
        dia: entry.record!.dia,
        pul: entry.record!.pul,
      ));
    }
    if (entry.note != null) {
      await noteRepo.add(Note(
        time: nextTime,
        note: entry.note!.note,
        color: entry.note!.color,
      ));
    }
    for (final intake in entry.allIntakes) {
      if (!_sameMinute(intake.time, entry.time)) continue;
      await intakeRepo.add(MedicineIntake(
        time: nextTime,
        medicine: intake.medicine,
        dosis: intake.dosis,
      ));
    }
    if (entry.weight != null) {
      await weightRepo.add(entry.weight!.copyWith(time: nextTime));
    }
  }

  Future<void> _removeEntry(
    CombinedEntry entry, {
    required bool blacklist,
    Health? health,
  }) async {
    if (entry.record != null) await bpRepo.remove(entry.record!);
    if (entry.note != null) await noteRepo.remove(entry.note!);
    for (final intake in entry.allIntakes) {
      if (!_sameMinute(intake.time, entry.time)) continue;
      await intakeRepo.remove(intake);
    }
    if (entry.weight != null) await weightRepo.remove(entry.weight!);
    if (blacklist) {
      if (entry.record != null) {
        await blacklistRepo.add('bp', bloodPressureRecordKey(entry.record!));
      }
      if (entry.weight != null) {
        await blacklistRepo.add(
          'weight',
          bodyweightRecordKey(entry.weight!),
        );
      }
    }
    if (health != null) {
      if (entry.sys != null) {
        await health.delete(
          type: HealthDataType.BLOOD_PRESSURE_SYSTOLIC,
          startTime: entry.time.subtract(const Duration(milliseconds: 500)),
          endTime: entry.time.add(const Duration(milliseconds: 500)),
        );
      }
      if (entry.dia != null) {
        await health.delete(
          type: HealthDataType.BLOOD_PRESSURE_DIASTOLIC,
          startTime: entry.time.subtract(const Duration(milliseconds: 500)),
          endTime: entry.time.add(const Duration(milliseconds: 500)),
        );
      }
    }
  }

  void _showDeleted(List<CombinedEntry> entries, {required bool blacklist}) {
    dismissAllToasts();
    showToastWithAction(
      'deletionConfirmed'.tr(),
      actionLabel: 'btnUndo'.tr(),
      onAction: () async {
        for (final entry in entries) {
          if (entry.record != null) await bpRepo.add(entry.record!);
          if (entry.note != null) await noteRepo.add(entry.note!);
          for (final intake in entry.allIntakes) {
            if (!_sameMinute(intake.time, entry.time)) continue;
            await intakeRepo.add(intake);
          }
          if (entry.weight != null) await weightRepo.add(entry.weight!);
          if (blacklist) {
            if (entry.record != null) {
              await blacklistRepo.remove(
                'bp',
                bloodPressureRecordKey(entry.record!),
              );
            }
            if (entry.weight != null) {
              await blacklistRepo.remove(
                'weight',
                bodyweightRecordKey(entry.weight!),
              );
            }
          }
        }
      },
    );
  }

  void _showUpdated() {
    showSuccess('entriesUpdated'.tr());
  }
}

DateTime _withDate(DateTime time, DateTime date) => DateTime(
  date.year,
  date.month,
  date.day,
  time.hour,
  time.minute,
  time.second,
  time.millisecond,
);

bool _sameMinute(DateTime a, DateTime b) =>
    a.year == b.year &&
    a.month == b.month &&
    a.day == b.day &&
    a.hour == b.hour &&
    a.minute == b.minute;
