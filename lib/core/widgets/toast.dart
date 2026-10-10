import 'package:flutter/material.dart';
import 'package:safaeh/safaeh.dart';

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
