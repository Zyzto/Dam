import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:safaeh/safaeh.dart';

/// Creates a dialog for prompting a single user input.
Future<String?> showInputDialog(
  BuildContext context, {
  String? hintText,
  String? initialValue,
}) async => showSafaehTextInput(
  context: context,
  title: hintText ?? 'addNote'.tr(),
  hint: hintText,
  initialValue: initialValue ?? '',
  doneLabel: 'btnConfirm'.tr(),
  cancelLabel: 'btnCancel'.tr(),
);

/// Creates a dialog that only allows int and double inputs.
Future<double?> showNumberInputDialog(
  BuildContext context, {
  String? hintText,
  num? initialValue,
}) async {
  final result = await showSafaehTextInput(
    context: context,
    title: hintText ?? 'errNoValue'.tr(),
    hint: hintText,
    initialValue: initialValue?.toString() ?? '',
    doneLabel: 'btnConfirm'.tr(),
    cancelLabel: 'btnCancel'.tr(),
    keyboardType: TextInputType.number,
    inputFormatters: [
      FilteringTextInputFormatter.allow(RegExp(r'([0-9]+(\.([0-9]*))?)')),
    ],
    validator: (text) {
      double? value = double.tryParse(text);
      value ??= int.tryParse(text)?.toDouble();
      if (text.isEmpty || value == null) {
        return 'errNaN'.tr();
      }
      return null;
    },
  );

  double? value = double.tryParse(result ?? '');
  value ??= int.tryParse(result ?? '')?.toDouble();
  return value;
}
