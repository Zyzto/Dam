import 'package:blood_pressure_app/features/data_picker/interval_picker.dart';
import 'package:blood_pressure_app/features/home/ble_home_sync_indicator.dart';
import 'package:blood_pressure_app/features/measurement_list/measurement_filter_scope.dart';
import 'package:blood_pressure_app/features/measurement_list/measurement_list.dart';
import 'package:blood_pressure_app/features/settings/app_settings.dart';
import 'package:blood_pressure_app/features/statistics/dashboard/dashboard_range_bar.dart';
import 'package:blood_pressure_app/model/storage/interval_store_manager.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_settings_framework/safaeh.dart';

/// Shared chrome for every tab in the main shell.
///
/// [page] is the live [PageController.page], so titles, actions, and the
/// dashboard range control morph as the user swipes between tabs.
class DashboardAppBar extends ConsumerWidget implements PreferredSizeWidget {
  /// Create the pinned shell header for [page] (0 through the last tab).
  const DashboardAppBar({
    super.key,
    required this.page,
    this.titleKeys = _defaultTitleKeys,
    this.settingsSearchOpen,
    this.onSettingsSearch,
  });

  /// Current shell page position in the visible data tabs.
  final double page;

  /// Localization keys for the visible shell-tab titles, in swipe order.
  final List<String> titleKeys;

  /// Whether the settings search overlay is currently open.
  final ValueNotifier<bool>? settingsSearchOpen;

  /// Opens or closes the settings search overlay.
  final VoidCallback? onSettingsSearch;

  static const _defaultTitleKeys = ['title', 'weight', 'statistics'];

  @override
  Size get preferredSize => Size.fromHeight(
    kToolbarHeight + _rangeFactor * IntervalPicker.barSize.height,
  );

  bool get _hasSettings => titleKeys.isNotEmpty && titleKeys.last == 'settings';

  double get _rangeFactor {
    if (!_hasSettings) return 1;
    final settingsPage = (titleKeys.length - 1).toDouble();
    return (settingsPage - page).clamp(0.0, 1.0);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(appSettingsProvider);
    final showFilter =
        settings.medicineFeatureEnabled && settings.bloodPressureEnabled;
    final slot = showFilter
        ? BleHomeSyncIndicator.slotWidth + 48
        : BleHomeSyncIndicator.slotWidth;
    return SafaehMorphingAppBar(
      page: page,
      titles: [for (final key in titleKeys) Text(key.tr())],
      // Reserve the same leading width as the trailing action slot. This
      // keeps the title on the physical center line even when actions morph.
      leading: SizedBox(width: slot),
      leadingWidth: slot,
      actionSlotWidth: slot,
      actionsBuilder: (context, currentPage) => _ShellAppBarAction(
        page: currentPage,
        settingsPage: _hasSettings ? (titleKeys.length - 1).toDouble() : null,
        settingsSearchOpen: settingsSearchOpen,
        onSettingsSearch: onSettingsSearch,
        showFilter: showFilter,
      ),
      bottom: SafaehMorphingAppBarBottom(
        factor: _rangeFactor,
        height: IntervalPicker.barSize.height,
        child: const DashboardRangeBar(
          type: IntervalStoreManagerLocation.mainPage,
        ),
      ),
    );
  }
}

class _ShellAppBarAction extends StatelessWidget {
  const _ShellAppBarAction({
    required this.page,
    required this.settingsPage,
    required this.settingsSearchOpen,
    required this.onSettingsSearch,
    required this.showFilter,
  });

  final double page;

  /// Settings tab, when this shell has one. Null keeps Bluetooth visible on
  /// every page.
  final double? settingsPage;
  final ValueNotifier<bool>? settingsSearchOpen;
  final VoidCallback? onSettingsSearch;
  final bool showFilter;

  /// Full on measurements, weight, and statistics. Fades only into settings.
  double get _dataOpacity {
    final settings = settingsPage;
    if (settings == null) return 1;
    return (settings - page).clamp(0.0, 1.0);
  }

  /// The measurement filter belongs to the measurements tab.
  double get _filterOpacity => (1.0 - page).clamp(0.0, 1.0);

  @override
  Widget build(BuildContext context) {
    final dataOpacity = _dataOpacity;
    final filterOpacity = _filterOpacity;
    final settings = settingsPage;
    return Stack(
      alignment: AlignmentDirectional.centerEnd,
      children: [
        ExcludeSemantics(
          excluding: dataOpacity < 0.5,
          child: IgnorePointer(
            ignoring: dataOpacity < 0.5,
            child: Opacity(
              opacity: dataOpacity,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const _BleHomeAction(),
                  if (showFilter)
                    ExcludeSemantics(
                      excluding: filterOpacity < 0.5,
                      child: IgnorePointer(
                        ignoring: filterOpacity < 0.5,
                        child: ClipRect(
                          child: Align(
                            alignment: AlignmentDirectional.centerStart,
                            widthFactor: filterOpacity,
                            child: Opacity(
                              opacity: filterOpacity,
                              child: const _MeasurementFilterAction(),
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
        if (settings != null &&
            settingsSearchOpen != null &&
            onSettingsSearch != null)
          ValueListenableBuilder<bool>(
            valueListenable: settingsSearchOpen!,
            builder: (context, isOpen, _) => SafaehMorphingAppBarAction(
              page: page,
              targetPage: settings,
              child: SafaehSettingsSearchButton(
                isOpen: isOpen,
                hintText: 'searchSettings'.tr(),
                onPressed: onSettingsSearch!,
              ),
            ),
          ),
      ],
    );
  }
}

class _BleHomeAction extends StatelessWidget {
  const _BleHomeAction();

  @override
  Widget build(BuildContext context) {
    try {
      ProviderScope.containerOf(
        context,
        listen: false,
      ).read(appSettingsProvider);
    } catch (_) {
      return const SizedBox.shrink();
    }
    return const BleHomeSyncIndicator();
  }
}

class _MeasurementFilterAction extends StatelessWidget {
  const _MeasurementFilterAction();

  @override
  Widget build(BuildContext context) {
    final filter = MeasurementFilterScope.maybeOf(context);
    if (filter == null) return const SizedBox.shrink();
    final selected = filter.value;
    String label(MeasurementListFilter value) => switch (value) {
      MeasurementListFilter.all => 'filterAll'.tr(),
      MeasurementListFilter.bloodPressure => 'bloodPressure'.tr(),
      MeasurementListFilter.medicine => 'medications'.tr(),
    };
    IconData icon(MeasurementListFilter value) => switch (value) {
      MeasurementListFilter.all => Icons.filter_list,
      MeasurementListFilter.bloodPressure => Icons.monitor_heart_outlined,
      MeasurementListFilter.medicine => Icons.medication_outlined,
    };
    return SafaehAnchoredDropdownChip<MeasurementListFilter>(
      icon: icon(selected),
      label: label(selected),
      iconOnly: true,
      active: selected != MeasurementListFilter.all,
      selected: selected,
      options: [
        for (final value in MeasurementListFilter.values)
          SafaehDropdownOption(
            value: value,
            label: label(value),
            icon: icon(value),
          ),
      ],
      onSelected: filter.select,
    );
  }
}
