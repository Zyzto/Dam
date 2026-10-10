import 'package:blood_pressure_app/core/layout/responsive_sheet.dart';
import 'package:blood_pressure_app/core/widgets/sheet_helpers.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:safaeh/safaeh.dart';

/// Alert dialog for prompting single value input from the user.
class InputDialog extends StatefulWidget {
  /// Creates a dialog with a text input field.
  ///
  /// Pops the context after value submission with object of type [String?].
  const InputDialog({
    super.key,
    this.hintText,
    this.initialValue,
    this.inputFormatters,
    this.keyboardType,
    this.validator,
  });

  /// Initial content of the input field.
  final String? initialValue;

  /// Supporting text describing the input field.
  final String? hintText;

  /// Optional input validation and formatting overrides.
  final List<TextInputFormatter>? inputFormatters;

  /// The type of keyboard to use for editing the text.
  final TextInputType? keyboardType;

  /// Validation function called after submit.
  ///
  /// When the validator returns null the dialog completes normally,
  /// in case of receiving a String it will be displayed to the user
  /// and pressing of the submit button will be ignored.
  final String? Function(String)? validator;

  @override
  State<InputDialog> createState() => _InputDialogState();
}

class _InputDialogState extends State<InputDialog> {
  final controller = TextEditingController();
  final focusNode = FocusNode();

  String? errorText;

  @override
  void initState() {
    super.initState();
    if (widget.initialValue != null) controller.text = widget.initialValue!;
    focusNode.requestFocus();
  }

  @override
  void dispose() {
    controller.dispose();
    focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        TextField(
          controller: controller,
          focusNode: focusNode,
          inputFormatters: widget.inputFormatters,
          keyboardType: widget.keyboardType,
          decoration: InputDecoration(
            hintText: widget.hintText,
            labelText: widget.hintText,
            errorText: errorText,
          ),
          onSubmitted: _onSubmit,
        ),
        const SizedBox(height: 20),
        OverflowBar(
          alignment: MainAxisAlignment.end,
          spacing: 8,
          overflowAlignment: OverflowBarAlignment.end,
          overflowSpacing: 8,
          children: responsiveSheetActions(
            context,
            actions: [
              FilledButton(
                onPressed: () => _onSubmit(controller.text),
                child: Text('btnConfirm'.tr()),
              ),
            ],
          ),
        ),
      ],
    );

  void _onSubmit(String value) {
    final validationResult = widget.validator?.call(value);
    if (validationResult != null) {
      setState(() {
        errorText = validationResult;
      });
      return;
    }
    Navigator.pop(context, value);
  }
}

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
  final result = await showResponsiveSheet<String?>(
    context: context,
    title: hintText ?? 'errNoValue'.tr(),
    maxHeight: MediaQuery.sizeOf(context).height * 0.5,
    child: InputDialog(
      hintText: hintText,
      initialValue: initialValue?.toString(),
      inputFormatters: [
        FilteringTextInputFormatter.allow(RegExp(r'([0-9]+(\.([0-9]*))?)')),
      ],
      keyboardType: TextInputType.number,
      validator: (text) {
        double? value = double.tryParse(text);
        value ??= int.tryParse(text)?.toDouble();
        if (text.isEmpty || value == null) {
          return 'errNaN'.tr();
        }
        return null;
      },
    ),
  );

  double? value = double.tryParse(result ?? '');
  value ??= int.tryParse(result ?? '')?.toDouble();
  return value;
}
