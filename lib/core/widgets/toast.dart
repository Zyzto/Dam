import 'package:flutter/material.dart';
import 'package:safaeh/safaeh.dart';
import 'package:toastification/toastification.dart';

/// Mounts Safaeh feedback and cancels its timers when the host is removed.
///
/// Toastification keeps a process-wide manager. Leaving its auto-close timers
/// running after the tree is gone fails widget tests and can fire against a
/// disposed overlay.
class AppToastHost extends StatefulWidget {
  /// Create a feedback host around [child].
  const AppToastHost({
    super.key,
    required this.child,
    this.itemWidthBuilder,
    this.bottomInsetBuilder,
    this.startInsetBuilder,
    this.endInsetBuilder,
    this.relayout,
  });

  /// App content, normally the navigator.
  final Widget child;

  /// Toast width. Defaults to Safaeh's fixed width when null.
  final double Function(BuildContext context)? itemWidthBuilder;

  /// Extra space above the system inset, used to clear a floating nav bar.
  final SafaehFeedbackInsetBuilder? bottomInsetBuilder;

  /// Leading inset outside [itemWidthBuilder].
  final SafaehFeedbackInsetBuilder? startInsetBuilder;

  /// Trailing inset outside [itemWidthBuilder].
  final SafaehFeedbackInsetBuilder? endInsetBuilder;

  /// Rebuilds placement when shell chrome changes. Toastification keeps the
  /// first config for an alignment, so an idle manager is dropped too.
  final Listenable? relayout;

  @override
  State<AppToastHost> createState() => _AppToastHostState();
}

class _AppToastHostState extends State<AppToastHost> {
  @override
  void initState() {
    super.initState();
    widget.relayout?.addListener(_onRelayout);
  }

  @override
  void didUpdateWidget(covariant AppToastHost oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.relayout == widget.relayout) return;
    oldWidget.relayout?.removeListener(_onRelayout);
    widget.relayout?.addListener(_onRelayout);
  }

  void _onRelayout() {
    // ignore: invalid_use_of_visible_for_testing_member
    toastification.managers.removeWhere(
      (_, manager) =>
          // ignore: invalid_use_of_visible_for_testing_member
          manager.notifications.isEmpty &&
          // ignore: invalid_use_of_visible_for_testing_member
          manager.overlayEntry == null,
    );
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    widget.relayout?.removeListener(_onRelayout);
    // dismissAll() schedules another timer. These testing-visible members are
    // the only way to cancel auto-close timers in the same turn.
    // ignore: invalid_use_of_visible_for_testing_member
    for (final manager in toastification.managers.values) {
      // ignore: invalid_use_of_visible_for_testing_member
      for (final item in manager.notifications.toList()) {
        item.dispose();
      }
      // ignore: invalid_use_of_visible_for_testing_member
      manager.notifications.clear();
      // ignore: invalid_use_of_visible_for_testing_member
      manager.overlayEntry = null;
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SafaehFeedbackHost(
    itemWidthBuilder: widget.itemWidthBuilder,
    bottomInsetBuilder: widget.bottomInsetBuilder,
    startInsetBuilder: widget.startInsetBuilder,
    endInsetBuilder: widget.endInsetBuilder,
    child: widget.child,
  );
}

/// Janan's adapter over Safaeh feedback.
///
/// Use these extensions instead of a scaffold snack bar so messages keep
/// the same placement, timing, and styling.
extension ToastContext on BuildContext {
  /// Shows an informational toast with an optional [duration].
  void showToast(String message, {Duration? duration}) {
    showSafaehFeedback(
      message,
      duration: duration ?? const Duration(seconds: 4),
    );
  }

  /// Shows a success toast (e.g. "Copied", "Saved").
  void showSuccess(String message, {Duration? duration}) {
    showSafaehFeedback(
      message,
      type: SafaehFeedbackType.success,
      duration: duration ?? const Duration(seconds: 4),
    );
  }

  /// Shows an error toast (no actions).
  void showError(String message, {Duration? duration}) {
    showSafaehFeedback(
      message,
      type: SafaehFeedbackType.error,
      duration: duration ?? const Duration(seconds: 4),
    );
  }

  /// Shows an informational toast with one explicit action. Auto-dismiss does
  /// not invoke the action, which is important for Undo windows: only tapping
  /// the button should cancel the pending operation.
  void showToastWithAction(
    String message, {
    required String actionLabel,
    required VoidCallback onAction,
    Duration? duration,
    IconData icon = Icons.undo,
  }) {
    showSafaehFeedbackWithAction(
      message,
      actionLabel: actionLabel,
      onAction: onAction,
      duration: duration ?? const Duration(seconds: 8),
      icon: icon,
    );
  }

  /// Dismisses all visible toasts. Use before showing a replacement.
  void dismissAllToasts() {
    dismissSafaehFeedbacks();
  }
}
