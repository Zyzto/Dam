import 'package:blood_pressure_app/components/snack_bar_stable_fab_location.dart';
import 'package:blood_pressure_app/features/bluetooth/ui/ble_launch_sync_host.dart';
import 'package:blood_pressure_app/features/home/navigation_action_buttons.dart';
import 'package:blood_pressure_app/features/measurement_list/measurement_filter_scope.dart';
import 'package:blood_pressure_app/features/settings/app_settings.dart';
import 'package:blood_pressure_app/features/shell/dashboard_app_bar.dart';
import 'package:blood_pressure_app/features/shell/shell_tab.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:safaeh/safaeh.dart';

export 'package:blood_pressure_app/features/shell/shell_tab.dart';

/// Home / statistics / settings chrome with a persistent destination bar.
class AppShell extends ConsumerWidget {
  const AppShell({
    super.key,
    required this.pages,
    this.homePresence,
    this.initialTab = ShellTab.home,
    this.showWeight,
    this.showBloodPressure,
    this.showMedicine,
    this.settingsSearchOpen,
    this.onSettingsSearch,
  });

  /// Measurements, weight, statistics, and settings pages, in that order.
  final List<Widget> pages;

  /// Presence state used by launch-sync to exclude the settings tab.
  final HomePresenceObserver? homePresence;

  /// Tab shown first. Falls back to home if [ShellTab.weight] is hidden.
  final ShellTab initialTab;

  /// When null, follows [AppSettings.weightInput]. Tests can pin it.
  final bool? showWeight;

  /// When null, follows [AppSettings.bloodPressureEnabled].
  final bool? showBloodPressure;

  /// When null, follows [AppSettings.medicineFeatureEnabled].
  final bool? showMedicine;

  /// Whether the settings search overlay is open.
  final ValueNotifier<bool>? settingsSearchOpen;

  /// Opens or closes the settings search overlay.
  final VoidCallback? onSettingsSearch;

  static const navHomeKey = ValueKey<String>('shell_nav_home');
  static const navWeightKey = ValueKey<String>('shell_nav_weight');
  static const navStatisticsKey = ValueKey<String>('shell_nav_statistics');
  static const navSettingsKey = ValueKey<String>('shell_nav_settings');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(appSettingsProvider);
    final enabled = showWeight ?? settings.weightInput;
    final showBloodPressure =
        this.showBloodPressure ?? settings.bloodPressureEnabled;
    final showMedicine = this.showMedicine ?? settings.medicineFeatureEnabled;
    final tabs = visibleShellTabs(
      showWeight: enabled,
      showBloodPressure: showBloodPressure,
    );
    return _AppShellView(
      pages: pages,
      homePresence: homePresence,
      initialTab: tabs.contains(initialTab) ? initialTab : ShellTab.home,
      showWeight: enabled,
      showBloodPressure: showBloodPressure,
      showMedicine: showMedicine,
      settingsSearchOpen: settingsSearchOpen,
      onSettingsSearch: onSettingsSearch,
    );
  }
}

class _AppShellView extends StatefulWidget {
  const _AppShellView({
    required this.pages,
    required this.initialTab,
    required this.showWeight,
    required this.showBloodPressure,
    required this.showMedicine,
    this.settingsSearchOpen,
    this.onSettingsSearch,
    this.homePresence,
  });

  final List<Widget> pages;
  final HomePresenceObserver? homePresence;
  final ShellTab initialTab;
  final bool showWeight;
  final bool showBloodPressure;
  final bool showMedicine;
  final ValueNotifier<bool>? settingsSearchOpen;
  final VoidCallback? onSettingsSearch;

  @override
  State<_AppShellView> createState() => _AppShellViewState();
}

class _AppShellViewState extends State<_AppShellView> {
  late int _index;
  late double _page;
  late final PageController _pageController;
  late final MeasurementFilterController _measurementFilter;
  bool _pageTickScheduled = false;
  int _tabLayoutVersion = 0;

  List<ShellTab> get _tabs => visibleShellTabs(
    showWeight: widget.showWeight,
    showBloodPressure: widget.showBloodPressure,
  );

  List<Widget> get _visiblePages {
    assert(widget.pages.length == 4);
    return [
      widget.pages[0],
      if (widget.showWeight) widget.pages[1],
      if (widget.showBloodPressure) widget.pages[2],
      widget.pages[3],
    ];
  }

  @override
  void initState() {
    super.initState();
    _index = _tabs.indexOf(widget.initialTab).clamp(0, _tabs.length - 1);
    _page = _index.toDouble();
    _measurementFilter = MeasurementFilterController();
    _pageController = PageController(initialPage: _index);
    _pageController.addListener(_syncPage);
    _updatePresence();
  }

  @override
  void didUpdateWidget(covariant _AppShellView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.showWeight == widget.showWeight &&
        oldWidget.showBloodPressure == widget.showBloodPressure) {
      return;
    }
    final oldTabs = visibleShellTabs(
      showWeight: oldWidget.showWeight,
      showBloodPressure: oldWidget.showBloodPressure,
    );
    final current = oldTabs[_index.clamp(0, oldTabs.length - 1)];
    var next = _tabs.indexOf(current);
    if (next < 0) next = 0;
    _index = next;
    _page = next.toDouble();
    _updatePresence();
    final layoutVersion = ++_tabLayoutVersion;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || layoutVersion != _tabLayoutVersion) return;
      if (_pageController.hasClients) {
        _pageController.jumpToPage(next);
      }
      if (_page != next.toDouble() && mounted) {
        setState(() => _page = next.toDouble());
      }
    });
  }

  @override
  void dispose() {
    _pageController.removeListener(_syncPage);
    _pageController.dispose();
    _measurementFilter.dispose();
    super.dispose();
  }

  void _syncPage() {
    if (!mounted || !_pageController.hasClients) return;
    final next = _pageController.page;
    if (next == null || next == _page) return;
    _page = next;
    if (_pageTickScheduled) return;
    _pageTickScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _pageTickScheduled = false;
      if (mounted) setState(() {});
    });
  }

  void _select(int index) {
    if (_index == index) return;
    setState(() => _index = index);
    if (index != _tabs.length - 1 && widget.settingsSearchOpen?.value == true) {
      widget.settingsSearchOpen!.value = false;
    }
    _updatePresence(index: index);
  }

  void _updatePresence({int? index}) {
    final selected = index ?? _index;
    widget.homePresence?.setShellTab(
      isHome: selected == 0,
      isSettings: selected == _tabs.length - 1,
    );
  }

  void _go(int index) {
    if (index == _index) return;
    if (index != _tabs.length - 1 && widget.settingsSearchOpen?.value == true) {
      widget.settingsSearchOpen!.value = false;
    }
    final tokens = SafaehTheme.of(context);
    final motion = safaehResolvedMotion(context, tokens.motion);
    if (motion == Duration.zero || !_pageController.hasClients) {
      _pageController.jumpToPage(index);
    } else {
      _pageController.animateToPage(
        index,
        duration: motion,
        curve: tokens.enterCurve,
      );
    }
  }

  List<SafaehSidenavDestination> _destinations() => [
    for (final tab in _tabs)
      switch (tab) {
        ShellTab.home => SafaehSidenavDestination(
          label: 'measurements'.tr(),
          icon: Icons.monitor_heart_outlined,
          selectedIcon: Icons.monitor_heart,
          tileKey: AppShell.navHomeKey,
        ),
        ShellTab.weight => SafaehSidenavDestination(
          label: 'weight'.tr(),
          icon: Icons.scale_outlined,
          selectedIcon: Icons.scale,
          tileKey: AppShell.navWeightKey,
        ),
        ShellTab.statistics => SafaehSidenavDestination(
          label: 'statistics'.tr(),
          icon: Icons.insights_outlined,
          selectedIcon: Icons.insights,
          tileKey: AppShell.navStatisticsKey,
        ),
        ShellTab.settings => SafaehSidenavDestination(
          label: 'settings'.tr(),
          icon: Icons.settings_outlined,
          selectedIcon: Icons.settings,
          tileKey: AppShell.navSettingsKey,
        ),
      },
  ];

  NavigationActionKind _actionKind() {
    final tab = _tabs[_page.round().clamp(0, _tabs.length - 1)];
    return switch (tab) {
      ShellTab.weight => NavigationActionKind.weight,
      ShellTab.statistics => NavigationActionKind.export,
      _ => NavigationActionKind.bloodPressure,
    };
  }

  @override
  Widget build(BuildContext context) {
    final localeTag = Localizations.localeOf(context).toString();
    final destinations = _destinations();
    final pages = _visiblePages;
    assert(pages.length == destinations.length);
    final dataTabCount = _tabs.length - 1;
    final titleKeys = [
      'measurements',
      if (widget.showWeight) 'weight',
      if (widget.showBloodPressure) 'statistics',
      'settings',
    ];
    return MeasurementFilterScope(
      controller: _measurementFilter,
      child: SafaehBottomNavScope(
      // The navigation is painted over the page, so expose its full visual
      // clearance to floating controls and page-index overlays.
      child: Builder(
        builder: (context) => PopScope(
          canPop: _index == 0,
          onPopInvokedWithResult: (didPop, _) {
            if (!didPop) _go(0);
          },
          child: Scaffold(
            // The floating navigation is shell chrome. Keep it stable while a
            // page-level text field resizes for the keyboard.
            resizeToAvoidBottomInset: false,
            appBar: DashboardAppBar(
              page: _page,
              titleKeys: titleKeys,
              settingsSearchOpen: widget.settingsSearchOpen,
              onSettingsSearch: widget.onSettingsSearch,
            ),
            body: Stack(
              fit: StackFit.expand,
              children: [
                ShellTabScope(
                  activeTab: _tabs[_index],
                  child: PageView(
                    controller: _pageController,
                    onPageChanged: _select,
                    children: [
                      for (var i = 0; i < pages.length; i++)
                        _KeepAlivePage(
                          // Tabs can be inserted or removed when settings
                          // change. Keep each page's identity tied to its tab
                          // so a visible page (especially SettingsPage with a
                          // scroll controller) is moved instead of recreated.
                          key: ValueKey<String>(
                            'shell-page-${_tabs[i].name}-$localeTag',
                          ),
                          child: pages[i],
                        ),
                    ],
                  ),
                ),
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 8,
                  child: SafaehFloatingNavBar(
                    key: const ValueKey('app_shell_floating_nav'),
                    selectedIndex: _index,
                    onDestinationSelected: _go,
                    destinations: destinations,
                    floatingAppearance: const SafaehFloatingAppearance(
                      style: SafaehFloatingSurfaceStyle.glass,
                    ),
                    hideWhenKeyboardVisible: true,
                  ),
                ),
              ],
            ),
            floatingActionButton: _index < dataTabCount
                ? NavigationActionButtons(
                    kind: _actionKind(),
                    showBloodPressure: widget.showBloodPressure,
                    showMedicine: widget.showMedicine,
                  )
                : null,
            floatingActionButtonAnimator: FloatingActionButtonAnimator.noAnimation,
            floatingActionButtonLocation:
                SnackBarStableFabLocation(
                  base: SafaehBottomNavAwareFabLocation.resolve(
                    context,
                    base: FloatingActionButtonLocation.endFloat,
                  ),
                ),
          ),
        ),
      ),
    ),
    );
  }
}

class _KeepAlivePage extends StatefulWidget {
  const _KeepAlivePage({super.key, required this.child});

  final Widget child;

  @override
  State<_KeepAlivePage> createState() => _KeepAlivePageState();
}

class _KeepAlivePageState extends State<_KeepAlivePage>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return widget.child;
  }
}
