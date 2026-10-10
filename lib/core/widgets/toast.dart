import 'package:flutter/material.dart';
import 'package:safaeh/safaeh.dart';

/// Space kept clear on each side of a toast.
const toastSideInset = 16.0;

/// Toast width that leaves [toastSideInset] visible on both sides.
///
/// The overlay already adds [MediaQueryData.viewPadding] as margin, so that
/// inset is taken out of the width as well.
double toastItemWidth(BuildContext context) {
  final media = MediaQuery.of(context);
  return (media.size.width - media.viewPadding.horizontal - toastSideInset * 2)
      .clamp(0.0, double.infinity);
}

/// Extra space under a toast when the floating nav is on screen.
///
/// Zero while the keyboard is up, because the nav hides and the overlay
/// already clears the keyboard. The system bar is added separately as
/// view padding, so this is only the nav's own height.
double toastBottomInset(BuildContext context, {required bool shellNavVisible}) {
  if (!shellNavVisible || MediaQuery.viewInsetsOf(context).bottom > 0) {
    return 0;
  }
  return SafaehBottomNavMetrics.defaultVisualClearance;
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
