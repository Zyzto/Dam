import 'package:flutter/material.dart';
import 'package:safaeh/safaeh.dart';

/// Live visibility of the shell's floating navigation bar.
///
/// The feedback host sits above the navigator, so it cannot read
/// [SafaehBottomNavScope]. The shell writes [mobileBottomNavVisible]; toasts
/// read it to stay above the bar.
class ShellNavChrome {
  ShellNavChrome._();

  /// Whether the mobile floating nav is currently on screen.
  static bool mobileBottomNavVisible = false;

  /// Width reserved beside the toast when the action column is showing.
  ///
  /// 56dp matches the chip and the add button. 40dp keeps the toast clear of
  /// the button shadow.
  static const double actionColumnReserve = 96;

  /// Trailing space a toast must leave for the dose chip and add button.
  ///
  /// Those controls share one 56dp column. Lifting the toast by that column's
  /// height parks it across the list, so the toast stays at the nav and stops
  /// short of the column instead. The reserve is the default so the first
  /// toast, before the shell publishes a tab, already clears that column.
  static final ValueNotifier<double> actionColumnWidth = ValueNotifier(
    actionColumnReserve,
  );

  static double _queuedActionColumnWidth = 0;
  static bool _actionColumnPublishScheduled = false;

  /// Publish [next] after this frame. The shell sets it during build.
  static void publishActionColumnWidth(double next) {
    _queuedActionColumnWidth = next;
    if (_actionColumnPublishScheduled) return;
    if (actionColumnWidth.value == next) return;
    _actionColumnPublishScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _actionColumnPublishScheduled = false;
      if (actionColumnWidth.value != _queuedActionColumnWidth) {
        actionColumnWidth.value = _queuedActionColumnWidth;
      }
    });
  }

  /// Extra visual clearance for toasts while the floating nav is showing.
  static double feedbackBottomInset(BuildContext context) {
    if (!mobileBottomNavVisible) return 0;
    return SafaehBottomNavMetrics.fromContext(
      context,
      visible: true,
      hideWhenKeyboardVisible: true,
    ).visualInset;
  }

  /// Leading inset. Sixteen on a phone that is dodging the action column.
  static double feedbackStartInset(BuildContext context) {
    if (!_dodgeActionColumn(context)) return 0;
    return 16;
  }

  /// Trailing inset, including the action column when it is showing.
  static double feedbackEndInset(BuildContext context) {
    if (!_dodgeActionColumn(context)) return 0;
    return 16 + actionColumnWidth.value;
  }

  /// Toast width: content width on a phone, dialog width on a tablet.
  static double feedbackItemWidth(BuildContext context) {
    final tokens = SafaehTheme.of(context);
    final maxWidth = tokens.dialogMaxWidth;
    final width = MediaQuery.sizeOf(context).width;
    if (!_dodgeActionColumn(context)) {
      if (width >= tokens.tabletBreakpoint) return maxWidth;
      return (width - 32).clamp(0.0, maxWidth);
    }
    return (width - 32 - actionColumnWidth.value).clamp(0.0, maxWidth);
  }

  static bool _dodgeActionColumn(BuildContext context) {
    if (actionColumnWidth.value <= 0) return false;
    final tokens = SafaehTheme.of(context);
    final width = MediaQuery.sizeOf(context).width;
    if (width < tokens.tabletBreakpoint) return true;
    final side = (width - tokens.dialogMaxWidth) / 2;
    return side < 16 + actionColumnWidth.value;
  }
}
