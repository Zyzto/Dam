import 'package:blood_pressure_app/core/layout/responsive_sheet.dart';
import 'package:blood_pressure_app/core/widgets/sheet_helpers.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

/// Outcome of the deletion confirmation sheet.
enum DeleteChoice {
  /// User dismissed or cancelled.
  cancel,

  /// Delete without blocking a later BLE re-import.
  delete,

  /// Delete and remember the reading so a device dump will not re-add it.
  deleteAndBlacklist,
}

/// Show a dialog that prompts the user to confirm a deletion.
Future<bool> showConfirmDeletionDialog(
  BuildContext context, [
  String? customDescription,
]) async {
  final choice = await showConfirmDeletionChoice(
    context,
    customDescription: customDescription,
  );
  return choice != DeleteChoice.cancel;
}

/// Confirm deletion, optionally offering to block the reading from BLE re-import.
Future<DeleteChoice> showConfirmDeletionChoice(
  BuildContext context, {
  String? customDescription,
  bool allowBlacklist = false,
}) async {
  final title = 'confirmDelete'.tr();
  final result = await showResponsiveSheet<DeleteChoice>(
    context: context,
    title: title,
    child: buildSheetShell(
      context,
      title: title,
      showTitleInBody: false,
      body: Text(customDescription ?? 'confirmDeleteDesc'.tr()),
      actions: responsiveSheetActions(
        context,
        onCancel: () => Navigator.pop(context, DeleteChoice.cancel),
        actions: [
          if (allowBlacklist)
            TextButton(
              key: const ValueKey('safaeh_confirm'),
              onPressed: () => Navigator.pop(context, DeleteChoice.delete),
              child: Text('delete'.tr()),
            )
          else
            FilledButton(
              key: const ValueKey('safaeh_confirm'),
              style: FilledButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.error,
                foregroundColor: Theme.of(context).colorScheme.onError,
              ),
              onPressed: () => Navigator.pop(context, DeleteChoice.delete),
              child: Text('delete'.tr()),
            ),
          if (allowBlacklist)
            FilledButton(
              key: const ValueKey('deleteAndBlacklist'),
              style: FilledButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.error,
                foregroundColor: Theme.of(context).colorScheme.onError,
              ),
              onPressed: () =>
                  Navigator.pop(context, DeleteChoice.deleteAndBlacklist),
              child: Text('deleteAndBlacklist'.tr()),
            ),
        ],
      ),
    ),
  );
  return result ?? DeleteChoice.cancel;
}
