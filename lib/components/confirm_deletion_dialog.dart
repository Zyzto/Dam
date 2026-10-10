import 'package:blood_pressure_app/core/layout/responsive_sheet.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:safaeh/safaeh.dart';

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
///
/// The title is the responsive sheet title. The message sits in a content
/// panel, and the actions use the shared sheet footer. Drag or the barrier
/// dismisses; there is no extra Cancel in the footer.
Future<DeleteChoice> showConfirmDeletionChoice(
  BuildContext context, {
  String? customDescription,
  bool allowBlacklist = false,
}) async {
  final result = await showResponsiveSheet<DeleteChoice>(
    context: context,
    title: 'confirmDelete'.tr(),
    child: _DeleteConfirmBody(
      description: customDescription ?? 'confirmDeleteDesc'.tr(),
      allowBlacklist: allowBlacklist,
    ),
  );
  return result ?? DeleteChoice.cancel;
}

class _DeleteConfirmBody extends StatelessWidget {
  const _DeleteConfirmBody({
    required this.description,
    required this.allowBlacklist,
  });

  final String description;
  final bool allowBlacklist;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final radius = BorderRadius.circular(SafaehTheme.of(context).radius);
    final contentStyle = theme.textTheme.bodyMedium?.copyWith(
      color: cs.onSurfaceVariant,
    );
    final filled = FilledButton.styleFrom(
      backgroundColor: cs.error,
      foregroundColor: cs.onError,
      shape: RoundedRectangleBorder(borderRadius: radius),
    );

    return buildSafaehSheetShell(
      showTitleInBody: false,
      body: SafaehContentPanel(
        child: Text(description, style: contentStyle),
      ),
      actions: [
        if (allowBlacklist)
          TextButton(
            key: const ValueKey('deleteAndBlacklist'),
            onPressed: () =>
                Navigator.pop(context, DeleteChoice.deleteAndBlacklist),
            child: Text('deleteAndBlacklist'.tr()),
          ),
        FilledButton(
          key: const ValueKey('safaeh_confirm'),
          style: filled,
          onPressed: () => Navigator.pop(context, DeleteChoice.delete),
          child: Text('delete'.tr()),
        ),
      ],
    );
  }
}
