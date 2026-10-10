import 'package:blood_pressure_app/core/layout/responsive_sheet.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:safaeh/safaeh.dart';

/// A localized option shown by [showOptionPickerSheet].
class SheetPickerOption<T> {
  const SheetPickerOption({
    required this.value,
    required this.label,
    this.subtitle,
    this.leading,
    this.trailing,
    this.enabled = true,
  });

  final T value;
  final String label;
  final String? subtitle;
  final Widget? leading;
  final Widget? trailing;
  final bool enabled;
}

/// One row for [showActionSheet].
typedef SheetAction<T> = SafaehAction<T>;

/// Shows a single-select list using the same adaptive modal as other sheets.
Future<T?> showOptionPickerSheet<T>(
  BuildContext context, {
  required String title,
  required List<SheetPickerOption<T>> options,
  T? selected,
  double? maxHeight,
  bool centerInFullViewport = true,
  Widget? header,
}) {
  final trailingByValue = {
    for (final option in options) option.value: option.trailing,
  };
  return showResponsiveSheet<T>(
    context: context,
    title: title,
    maxHeight: maxHeight ?? MediaQuery.sizeOf(context).height * 0.75,
    centerInFullViewport: centerInFullViewport,
    child: SafaehTilePickerBody<T>(
      showTitleInBody: false,
      header: header,
      options: [
        for (final option in options)
          SafaehTileOption<T>(
            value: option.value,
            label: option.label,
            subtitle: option.subtitle,
            leading: option.leading,
            enabled: option.enabled,
          ),
      ],
      selected: selected,
      tileBuilder: (ctx, option, isSelected) => SafaehLabeledOptionTile(
        title: option.label,
        subtitle: option.subtitle,
        leading: option.leading,
        trailing: trailingByValue[option.value],
        enabled: option.enabled,
        selected: isSelected,
        onTap: null,
      ),
    ),
  );
}

/// Action menu. Returns the selected action value, or null if dismissed.
///
/// Rows use the same bordered tiles as [showOptionPickerSheet].
Future<T?> showActionSheet<T>(
  BuildContext context, {
  required String title,
  required List<SheetAction<T>> actions,
  bool centerInFullViewport = true,
  Widget? header,
  double? maxHeight,
}) => showResponsiveSheet<T>(
  context: context,
  title: title,
  maxHeight: maxHeight ?? MediaQuery.sizeOf(context).height * 0.75,
  centerInFullViewport: centerInFullViewport,
  child: SafaehActionSheetBody<T>(
    header: header,
    actions: actions,
    tileBuilder: (sheetContext, action) => SafaehLabeledOptionTile(
      title: action.label,
      subtitle: action.subtitle,
      leading: action.leading,
      trailing: action.trailing,
      selected: action.selected,
      destructive: action.destructive,
      enabled: action.enabled,
      onTap: null,
    ),
  ),
);

/// Footer actions for a responsive sheet.
///
/// Phone sheets include a cancel button. Wide dialogs omit it: the title-bar
/// close button and the barrier already dismiss.
List<Widget> responsiveSheetActions(
  BuildContext context, {
  required List<Widget> actions,
  VoidCallback? onCancel,
  String? cancelLabel,
  bool includeCancel = true,
}) {
  final showCancel = includeCancel && !isWideModal(context);
  return [
    if (showCancel)
      TextButton(
        key: const ValueKey('safaeh_cancel'),
        onPressed: onCancel ?? () => Navigator.pop(context),
        child: Text(cancelLabel ?? 'btnCancel'.tr()),
      ),
    ...actions,
  ];
}

/// Builds a consistent sheet body with a title and an action row.
Widget buildSheetShell(
  BuildContext context, {
  required String title,
  required Widget body,
  required List<Widget> actions,
  bool showTitleInBody = true,
}) => buildSafaehSheetShell(
  title: Text(
    title,
    style: Theme.of(
      context,
    ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
  ),
  body: body,
  actions: actions,
  showTitleInBody: showTitleInBody,
);
