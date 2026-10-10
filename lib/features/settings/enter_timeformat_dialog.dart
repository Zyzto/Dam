import 'package:blood_pressure_app/core/layout/responsive_sheet.dart';
import 'package:blood_pressure_app/core/widgets/sheet_helpers.dart';
import 'package:blood_pressure_app/features/export_import/ui/export_field_format_documentation_screen.dart';
import 'package:blood_pressure_app/l10n/western_digits.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';

/// Fullscreen dialog that explains the time format and pops the context with either null or a time format string.
class EnterTimeFormatDialog extends StatefulWidget {
  /// Create dialog for entering time formats as used by the [DateFormat] class.
  const EnterTimeFormatDialog({
    super.key,
    required this.initialValue,
    this.previewTime,
    this.bottomAppBars = false,
  });

  /// Text that is initially in time format field.
  final String initialValue;

  /// Timestamp used to generate time format preview.
  ///
  /// When previewTime is null [DateTime.now] will be used.
  final DateTime? previewTime;

  /// Whether to move the app bar for saving and loading to the bottom of the
  /// screen.
  final bool bottomAppBars;

  @override
  State<EnterTimeFormatDialog> createState() => _EnterTimeFormatDialogState();
}

class _EnterTimeFormatDialogState extends State<EnterTimeFormatDialog> {
  final timeFormatFieldController = TextEditingController();
  final focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    timeFormatFieldController.text = widget.initialValue;
    timeFormatFieldController.addListener(() => setState(() {}));
    focusNode.requestFocus();
  }

  @override
  void dispose() {
    timeFormatFieldController.dispose();
    focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
      child: Column(
        children: [
          Markdown(
            shrinkWrap: true,
            onTapLink: getLinkTapHandler(context),
            physics: const NeverScrollableScrollPhysics(),
            data: 'enterTimeFormatDesc'.tr(),
          ),
          Text(
            WesternDateFormat(
              timeFormatFieldController.text,
              context.locale.toString(),
            ).format(widget.previewTime ?? DateTime.now()),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              controller: timeFormatFieldController,
              focusNode: focusNode,
              decoration: InputDecoration(
                border: const OutlineInputBorder(),
                labelText: 'enterTimeFormatString'.tr(),
                errorText: timeFormatFieldController.text.isEmpty
                    ? 'errNoValue'.tr()
                    : null,
              ),
            ),
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
                  onPressed: () {
                    if (timeFormatFieldController.text.isNotEmpty) {
                      Navigator.pop(context, timeFormatFieldController.text);
                    }
                  },
                  child: Text('btnSave'.tr()),
                ),
              ],
            ),
          ),
        ],
      ),
    );
}

/// Shows a dialog that explains the ICU DateTime format and allows editing [initialTimeFormat] with a preview.
///
/// When canceled null is returned.
Future<String?> showTimeFormatPickerDialog(
  BuildContext context,
  String initialTimeFormat,
  bool bottomAppBars,
) => showResponsiveSheet<String?>(
  context: context,
  title: 'enterTimeFormatScreen'.tr(),
  maxHeight: MediaQuery.sizeOf(context).height * 0.8,
  child: EnterTimeFormatDialog(
    initialValue: initialTimeFormat,
    bottomAppBars: bottomAppBars,
  ),
);
