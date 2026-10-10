import 'package:blood_pressure_app/l10n/western_digits.dart';
import 'package:blood_pressure_app/theme/app_text.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:safaeh/safaeh.dart';

/// Open a compact range calendar dropping from the tapped date control.
Future<DateTimeRange?> showDashboardDateRange({
  required BuildContext context,
  required DateTimeRange initialRange,
  required DateTime firstDate,
  required DateTime lastDate,
}) => _showAnchored<DateTimeRange>(
  context: context,
  child: _DashboardDateRangeSheet(
    initialRange: initialRange,
    firstDate: firstDate,
    lastDate: lastDate,
  ),
);

/// Open the home calendar to pick one day, dropping from the tapped control.
Future<DateTime?> showDashboardDay({
  required BuildContext context,
  required DateTime initialDate,
  required DateTime firstDate,
  required DateTime lastDate,
}) async {
  final day = _dateOnly(initialDate);
  final range = await _showAnchored<DateTimeRange>(
    context: context,
    child: _DashboardDateRangeSheet(
      initialRange: DateTimeRange(start: day, end: day),
      firstDate: firstDate,
      lastDate: lastDate,
      singleDay: true,
    ),
  );
  if (range == null) return null;
  return _dateOnly(range.start);
}

Future<T?> _showAnchored<T>({
  required BuildContext context,
  required Widget child,
}) => showSafaehAnchored<T>(
  context: context,
  motion: SafaehAnchoredMotion.drop,
  sourceRect: _anchorRectOf(context),
  child: child,
);

Rect? _anchorRectOf(BuildContext context) {
  final box = context.findRenderObject();
  if (box is! RenderBox || !box.hasSize) return null;
  final overlay = Overlay.maybeOf(context)?.context.findRenderObject();
  final origin = overlay is RenderBox
      ? box.localToGlobal(Offset.zero, ancestor: overlay)
      : box.localToGlobal(Offset.zero);
  return origin & box.size;
}

class _DashboardDateRangeSheet extends StatefulWidget {
  const _DashboardDateRangeSheet({
    required this.initialRange,
    required this.firstDate,
    required this.lastDate,
    this.singleDay = false,
  });

  final DateTimeRange initialRange;
  final DateTime firstDate;
  final DateTime lastDate;
  final bool singleDay;

  @override
  State<_DashboardDateRangeSheet> createState() =>
      _DashboardDateRangeSheetState();
}

class _DashboardDateRangeSheetState extends State<_DashboardDateRangeSheet> {
  late DateTime _visibleMonth;
  DateTime? _start;
  DateTime? _end;

  @override
  void initState() {
    super.initState();
    _start = _dateOnly(widget.initialRange.start);
    _end = _dateOnly(widget.initialRange.end);
    _visibleMonth = DateTime(_end!.year, _end!.month);
  }

  bool get _canConfirm => _start != null && _end != null;

  void _onDayTap(DateTime day) {
    final date = _dateOnly(day);
    if (widget.singleDay) {
      setState(() {
        _start = date;
        _end = date;
      });
      return;
    }
    setState(() {
      if (_start == null || _end != null) {
        _start = date;
        _end = null;
        return;
      }
      if (date.isBefore(_start!)) {
        _end = _start;
        _start = date;
      } else {
        _end = date;
      }
    });
  }

  void _shiftMonth(int delta) {
    final next = DateTime(_visibleMonth.year, _visibleMonth.month + delta);
    final firstMonth = DateTime(widget.firstDate.year, widget.firstDate.month);
    final lastMonth = DateTime(widget.lastDate.year, widget.lastDate.month);
    if (next.isBefore(firstMonth) || next.isAfter(lastMonth)) return;
    setState(() => _visibleMonth = next);
  }

  void _confirm() {
    if (!_canConfirm) return;
    Navigator.of(context).pop(DateTimeRange(start: _start!, end: _end!));
  }

  @override
  Widget build(BuildContext context) {
    final locale = context.locale.toString();
    final rangeText = _rangeText(locale);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 8, 16),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
          Row(
            children: [
              Expanded(
                child: Padding(
                  padding: const EdgeInsetsDirectional.only(start: 4),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.singleDay
                            ? (rangeText ?? '')
                            : 'custom'.tr(),
                        style: AppText.title(context),
                      ),
                      if (!widget.singleDay && rangeText != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          rangeText,
                          style: AppText.subtitle(context),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              IconButton(
                visualDensity: VisualDensity.compact,
                tooltip: MaterialLocalizations.of(context).closeButtonTooltip,
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.close, size: 22),
              ),
            ],
          ),
          const SizedBox(height: 8),
          SafaehMonthCalendar(
            month: _visibleMonth,
            firstDate: widget.firstDate,
            lastDate: widget.lastDate,
            start: _start,
            end: _end,
            onDayTap: _onDayTap,
            monthLabel: WesternDateFormat.yMMMM(locale).format(_visibleMonth),
            weekdayLabels: _weekdayLabels(context, locale),
            previousTooltip: MaterialLocalizations.of(
              context,
            ).previousMonthTooltip,
            nextTooltip: MaterialLocalizations.of(context).nextMonthTooltip,
            onPreviousMonth: () => _shiftMonth(-1),
            onNextMonth: () => _shiftMonth(1),
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsetsDirectional.only(end: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text('btnCancel'.tr()),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  key: const Key('interval_range_confirm'),
                  onPressed: _canConfirm ? _confirm : null,
                  child: Text('btnConfirm'.tr()),
                ),
              ],
            ),
          ),
        ],
        ),
      ),
    );
  }

  List<String> _weekdayLabels(BuildContext context, String locale) {
    final first = MaterialLocalizations.of(context).firstDayOfWeekIndex;
    return List<String>.generate(7, (index) {
      final weekday = DateTime.utc(2023, 1, 1 + ((first + index) % 7));
      return WesternDateFormat.E(locale).format(weekday);
    });
  }

  String? _rangeText(String locale) {
    if (_start == null) return null;
    final format = widget.singleDay
        ? WesternDateFormat.yMMMd(locale)
        : WesternDateFormat.MMMd(locale);
    final start = format.format(_start!);
    if (widget.singleDay || _end == null) return start;
    return '$start – ${WesternDateFormat.MMMd(locale).format(_end!)}';
  }
}

DateTime _dateOnly(DateTime date) => DateTime(date.year, date.month, date.day);
