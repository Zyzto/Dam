import 'package:blood_pressure_app/core/layout/responsive_sheet.dart';
import 'package:blood_pressure_app/features/measurement_list/metric_info.dart';
import 'package:blood_pressure_app/features/settings/app_settings.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

/// Resolve [kind] from `settings` and open the visual card.
Future<void> showMetricInfo(
  BuildContext context, {
  required MetricKind kind,
  required double current,
  required String formattedValue,
  double? weightKg,
}) {
  final settings = context.readAppSettings();
  final info = MetricInfo.resolve(
    kind: kind,
    current: current,
    formattedValue: formattedValue,
    sex: settings.bodySex,
    heightCm: settings.bodyHeightCm,
    weightKg: weightKg,
    weightUnit: settings.weightUnit,
    pressureUnit: settings.preferredPressureUnit,
    sysWarn: settings.sysWarn,
    diaWarn: settings.diaWarn,
    limits: settings.rangeLimits,
  );
  return showMetricInfoDialog(context, info);
}

/// Open the visual description and ranges card for [info].
Future<void> showMetricInfoDialog(BuildContext context, MetricInfo info) =>
    showResponsiveSheet<void>(
      context: context,
      title: info.title,
      maxWidth: 400,
      child: MetricInfoDialog(info: info),
    );

/// Compact card explaining a metric and its typical ranges.
class MetricInfoDialog extends StatelessWidget {
  /// Create the metric info card.
  const MetricInfoDialog({super.key, required this.info});

  /// Resolved copy, ranges, and current value.
  final MetricInfo info;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final currentBand = info.currentBand;
    return SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            info.formattedValue,
            style: theme.textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          if (currentBand != null) ...[
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: _BandPill(band: currentBand),
            ),
          ] else if (info.note != null) ...[
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: Chip(label: Text(info.note!)),
            ),
          ],
          const SizedBox(height: 12),
          Text(
            info.description,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          if (info.showBar) ...[
            const SizedBox(height: 16),
            _RangeBar(info: info),
          ],
          if (info.bands.isNotEmpty) ...[
            const SizedBox(height: 12),
            for (final band in info.bands)
              _RangeRow(
                band: band,
                selected:
                    identical(band, currentBand) || band.id == currentBand?.id,
              ),
          ],
          if (info.warnLabel != null) ...[
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: Chip(
                label: Text(info.warnLabel!),
                side: BorderSide(color: theme.colorScheme.outline),
                backgroundColor: Colors.transparent,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'warnAboutTxt1'.tr(),
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _BandPill extends StatelessWidget {
  const _BandPill({required this.band});

  final MetricRangeBand band;

  @override
  Widget build(BuildContext context) {
    final color = metricBandColor(band.tone);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        band.label,
        style: Theme.of(context).textTheme.labelLarge?.copyWith(
          color: color,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _RangeRow extends StatelessWidget {
  const _RangeRow({required this.band, required this.selected});

  final MetricRangeBand band;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = metricBandColor(band.tone);
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: selected ? color.withValues(alpha: 0.16) : null,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              band.label,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
          ),
          Text(
            band.interval,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _RangeBar extends StatelessWidget {
  const _RangeBar({required this.info});

  final MetricInfo info;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final min = info.barMin!;
    final max = info.barMax!;
    final span = max - min;
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        return SizedBox(
          height: 18,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned(
                left: 0,
                right: 0,
                top: 5,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: SizedBox(
                    height: 8,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        for (final band in info.bands)
                          if (_widthFor(band, min, span) > 0)
                            Expanded(
                              flex: _widthFor(band, min, span),
                              child: ColoredBox(
                                color: metricBandColor(band.tone),
                                child: const SizedBox.expand(),
                              ),
                            ),
                      ],
                    ),
                  ),
                ),
              ),
              Positioned(
                left: (info.barFraction * width) - 6,
                top: 1,
                child: Container(
                  width: 12,
                  height: 16,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.onSurface,
                    borderRadius: BorderRadius.circular(3),
                    border: Border.all(
                      color: theme.colorScheme.surface,
                      width: 2,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  int _widthFor(MetricRangeBand band, double min, double span) {
    final start = (band.min ?? min).clamp(min, min + span);
    final end = (band.maxExclusive ?? (min + span)).clamp(min, min + span);
    final width = end - start;
    if (width <= 0) return 0;
    return (width * 100).round().clamp(1, 10000);
  }
}
