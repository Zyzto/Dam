import 'package:blood_pressure_app/components/pressure_text.dart';
import 'package:blood_pressure_app/domain/domain.dart';
import 'package:blood_pressure_app/features/measurement_list/list_timestamp.dart';
import 'package:blood_pressure_app/features/measurement_list/measurement_detail_screen.dart';
import 'package:blood_pressure_app/features/measurement_list/metric_info.dart';
import 'package:blood_pressure_app/features/measurement_list/metric_info_dialog.dart';
import 'package:blood_pressure_app/features/measurement_list/previous_measurement.dart';
import 'package:blood_pressure_app/features/settings/app_settings.dart';
import 'package:blood_pressure_app/features/statistics/dashboard/dashboard_section.dart';
import 'package:blood_pressure_app/features/statistics/dashboard/dashboard_snapshot.dart';
import 'package:blood_pressure_app/l10n/bidi.dart';
import 'package:blood_pressure_app/model/combined_entry.dart';
import 'package:blood_pressure_app/theme/app_text.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_symbols_icons/symbols.dart';

/// Newest in-range reading with classification chips.
class LatestReadingCard extends ConsumerWidget {
  /// Create the latest-reading hero.
  const LatestReadingCard({
    super.key,
    required this.entry,
    required this.entriesNewestFirst,
    required this.count,
    this.perDay,
  });

  /// Newest blood-pressure row in the selected range.
  final CombinedEntry entry;

  /// Newest-first list used to find the previous reading.
  final List<CombinedEntry> entriesNewestFirst;

  /// Filtered measurement count shown in the footer.
  final int count;

  /// Measurements per day, when the analyzer can compute it.
  final int? perDay;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final locale = Localizations.localeOf(context).toString();
    final settings = ref.watch(appSettingsProvider);
    final unit = settings.preferredPressureUnit;
    final stamp = formatListTimestamp(entry.time, locale);
    final sysInfo = _info(
      kind: MetricKind.sys,
      pressure: entry.sys,
      settings: settings,
    );
    final diaInfo = _info(
      kind: MetricKind.dia,
      pressure: entry.dia,
      settings: settings,
    );
    final pulInfo = entry.pul == null
        ? null
        : MetricInfo.resolve(
            kind: MetricKind.pulse,
            current: entry.pul!.toDouble(),
            formattedValue: entry.pul!.toString(),
            pressureUnit: unit,
            sysWarn: settings.sysWarn,
            diaWarn: settings.diaWarn,
            limits: settings.rangeLimits,
          );

    final latestIndex = entriesNewestFirst.indexOf(entry);
    final previous = latestIndex < 0
        ? null
        : previousBloodPressureInList(entriesNewestFirst, latestIndex);

    return Semantics(
      button: true,
      label: 'dashboardLatestSemantics'.tr(
        namedArgs: {
          'sys': isolateLtr(formatDashboardPressure(entry.sys, unit)),
          'dia': isolateLtr(formatDashboardPressure(entry.dia, unit)),
          'pul': isolateLtr(entry.pul?.toString() ?? '—'),
          'time': isolateLtr(stamp),
        },
      ),
      child: DashboardSection(
        key: const Key('latest_reading_card'),
        icon: Symbols.heart_plus,
        title: 'dashboardLatest'.tr(),
        trailing: Text(stamp, style: AppText.subtitle(context)),
        accentColor: entry.color == null ? null : Color(entry.color!),
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) =>
                  MeasurementDetailScreen(entry: entry, previous: previous),
            ),
          );
        },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: _HeroMetric(
                    label: 'sysShort'.tr(),
                    color: settings.sysColor,
                    value: PressureText(entry.sys),
                    info: sysInfo,
                  ),
                ),
                Expanded(
                  child: _HeroMetric(
                    label: 'diaShort'.tr(),
                    color: settings.diaColor,
                    value: PressureText(entry.dia),
                    info: diaInfo,
                  ),
                ),
                Expanded(
                  child: _HeroMetric(
                    label: 'pulShort'.tr(),
                    color: settings.pulColor,
                    value: Text(entry.pul?.toString() ?? '—'),
                    info: pulInfo,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              perDay == null
                  ? 'dashboardActivityCount'.tr(
                      namedArgs: {'count': count.toString()},
                    )
                  : 'dashboardActivityLine'.tr(
                      namedArgs: {
                        'count': count.toString(),
                        'perDay': perDay.toString(),
                      },
                    ),
              style: AppText.subtitle(context),
            ),
          ],
        ),
      ),
    );
  }

  MetricInfo? _info({
    required MetricKind kind,
    required Pressure? pressure,
    required AppSettings settings,
  }) {
    final value = pressureInUnit(pressure, settings.preferredPressureUnit);
    if (value == null) return null;
    return MetricInfo.resolve(
      kind: kind,
      current: value,
      formattedValue: formatDashboardPressure(
        pressure,
        settings.preferredPressureUnit,
      ),
      pressureUnit: settings.preferredPressureUnit,
      sysWarn: settings.sysWarn,
      diaWarn: settings.diaWarn,
      limits: settings.rangeLimits,
    );
  }
}

class _HeroMetric extends StatelessWidget {
  const _HeroMetric({
    required this.label,
    required this.color,
    required this.value,
    required this.info,
  });

  final String label;
  final Color color;
  final Widget value;
  final MetricInfo? info;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: AppText.label(context, color: color)),
        const SizedBox(height: 4),
        ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 52),
          child: Align(
            alignment: AlignmentDirectional.centerStart,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                DefaultTextStyle.merge(
                  style: theme.textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: theme.colorScheme.onSurface,
                    height: 1.1,
                  ),
                  child: value,
                ),
                if (info?.currentBand != null) ...[
                  const SizedBox(width: 6),
                  Flexible(
                    child: _BandChip(
                      info: info!,
                      onTap: () => showMetricInfoDialog(context, info!),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _BandChip extends StatelessWidget {
  const _BandChip({required this.info, required this.onTap});

  final MetricInfo info;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final band = info.currentBand!;
    final color = metricBandColor(band.tone);
    return Material(
      color: color.withValues(alpha: 0.16),
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          child: Text(
            band.label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}
