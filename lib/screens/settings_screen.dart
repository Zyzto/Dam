import 'dart:convert';
import 'dart:io';

import 'package:archive/archive_io.dart';
import 'package:blood_pressure_app/app.dart';
import 'package:blood_pressure_app/components/color_picker.dart';
import 'package:blood_pressure_app/core/layout/responsive_sheet.dart';
import 'package:blood_pressure_app/core/repository/repo_context.dart';
import 'package:blood_pressure_app/core/widgets/defer_until_sheet_settled.dart';
import 'package:blood_pressure_app/core/widgets/sheet_helpers.dart';
import 'package:blood_pressure_app/core/widgets/toast.dart';
import 'package:blood_pressure_app/features/settings/app_settings.dart';
import 'package:blood_pressure_app/features/settings/bluetooth_devices_screen.dart';
import 'package:blood_pressure_app/features/settings/body_profile_screen.dart';
import 'package:blood_pressure_app/features/settings/delete_data_screen.dart';
import 'package:blood_pressure_app/features/settings/edadat_prefs.dart';
import 'package:blood_pressure_app/features/settings/graph_markings_screen.dart';
import 'package:blood_pressure_app/features/settings/range_limits_screen.dart';
import 'package:blood_pressure_app/features/settings/registry.dart';
import 'package:blood_pressure_app/features/settings/storage/edadat_file_storage.dart';
import 'package:blood_pressure_app/features/settings/tiles/ble_engine_settings_tile.dart';
import 'package:blood_pressure_app/features/settings/version_screen.dart';
import 'package:blood_pressure_app/l10n/app_locales.dart';
import 'package:blood_pressure_app/l10n/western_digits.dart';
import 'package:blood_pressure_app/logging.dart';
import 'package:blood_pressure_app/model/bluetooth_input_mode.dart';
import 'package:blood_pressure_app/model/storage/storage.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_logging_service/flutter_logging_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_settings_framework/flutter_settings_framework.dart';
import 'package:flutter_settings_framework/safaeh.dart';
import 'package:path/path.dart';
import 'package:url_launcher/url_launcher.dart';

/// Drop rows whose registry definition marks them invisible. The catalog page
/// still builds every setting in a section; Health Connect internals and other
/// power-user flags must stay off this list.
@visibleForTesting
List<Widget> visibleCatalogChildren(
  SettingsRegistry registry,
  List<Widget> children,
) {
  final visible = {
    for (final setting in registry.settings) setting.key: setting.visible,
  };
  return [
    for (final child in children)
      if (child is! SettingAnchor || (visible[child.settingKey] ?? true)) child,
  ];
}

/// Searchable settings catalog backed by Edadat and Safaeh chrome.
class SettingsPage extends ConsumerStatefulWidget {
  const SettingsPage({super.key, this.searchOpen, this.showAppBar = true});

  /// Shared search state used when the page is embedded in the main shell.
  final ValueNotifier<bool>? searchOpen;

  /// Whether to render a page-local app bar when used outside the main shell.
  final bool showAppBar;

  @override
  ConsumerState<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends ConsumerState<SettingsPage> {
  late final SettingsRegistry _registry;
  final _scrollController = ScrollController();
  final _scrollViewportKey = GlobalKey();
  final _anchors = SettingAnchorRegistry();
  final _sectionKeys = <String, GlobalKey>{};
  final _sectionExpanded = <String, bool>{};
  final _subSectionExpanded = <String, bool>{};
  String? _activeSectionId;
  bool _searchOpen = false;
  bool _activeUpdateScheduled = false;

  bool get _isSearchOpen => widget.searchOpen?.value ?? _searchOpen;

  @override
  void initState() {
    super.initState();
    widget.searchOpen?.addListener(_handleSearchOpenChanged);
    _searchOpen = widget.searchOpen?.value ?? false;
    _registry = createAppSettingsRegistry();
    for (final section in _registry.getSortedSections()) {
      _sectionKeys[section.key] = GlobalKey();
    }
    _scrollController.addListener(_scheduleActiveSectionUpdate);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scheduleActiveSectionUpdate();
    });
  }

  @override
  void dispose() {
    widget.searchOpen?.removeListener(_handleSearchOpenChanged);
    _scrollController.removeListener(_scheduleActiveSectionUpdate);
    _scrollController.dispose();
    _anchors.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant SettingsPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.searchOpen == widget.searchOpen) return;
    oldWidget.searchOpen?.removeListener(_handleSearchOpenChanged);
    widget.searchOpen?.addListener(_handleSearchOpenChanged);
    _searchOpen = widget.searchOpen?.value ?? false;
  }

  void _handleSearchOpenChanged() {
    if (!mounted) return;
    setState(() => _searchOpen = widget.searchOpen?.value ?? false);
  }

  void _setSearchOpen(bool value) {
    if (widget.searchOpen != null) {
      widget.searchOpen!.value = value;
    } else if (_searchOpen != value) {
      setState(() => _searchOpen = value);
    }
  }

  List<SettingSection> get _displayedSections => _registry
      .getSortedSections()
      .where(
        (section) =>
            _registry.getVisibleSettingsInSection(section.key).isNotEmpty,
      )
      .toList();

  bool _isWide(BuildContext context) =>
      MediaQuery.sizeOf(context).width >=
      SafaehTheme.of(context).tabletBreakpoint;

  String _sectionTitle(String key) => key.tr();

  String _settingTitle(SettingDefinition<Object?> setting) =>
      setting.titleKey.tr();

  String? _settingSubtitle(SettingDefinition<Object?> setting) =>
      setting.subtitleKey?.tr();

  void _scheduleActiveSectionUpdate() {
    if (_activeUpdateScheduled) return;
    _activeUpdateScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _activeUpdateScheduled = false;
      if (!mounted || _isSearchOpen) return;
      final scrollContext = _scrollViewportKey.currentContext;
      if (scrollContext == null) return;
      final active = activeSafaehSettingsSectionId(
        sections: _displayedSections,
        sectionKeys: _sectionKeys,
        scrollContext: scrollContext,
      );
      if (active != null && active != _activeSectionId) {
        setState(() => _activeSectionId = active);
      }
    });
  }

  void _setSectionExpanded(String sectionId, bool expanded) {
    if (_sectionExpanded[sectionId] == expanded) return;
    setState(() => _sectionExpanded[sectionId] = expanded);
  }

  String _subSectionId(String sectionKey, String subKey) =>
      '$sectionKey/$subKey';

  bool _isSubSectionExpanded(String sectionKey, String subKey) =>
      _subSectionExpanded[_subSectionId(sectionKey, subKey)] ?? false;

  void _setSubSectionExpanded(String sectionKey, String subKey, bool expanded) {
    final id = _subSectionId(sectionKey, subKey);
    if (_subSectionExpanded[id] == expanded) return;
    setState(() => _subSectionExpanded[id] = expanded);
  }

  Future<void> _selectSection(SettingSection section) async {
    final key = _sectionKeys[section.key];
    if (key == null) return;
    final wasExpanded =
        _sectionExpanded[section.key] ?? section.initiallyExpanded;
    setState(() {
      _activeSectionId = section.key;
      _sectionExpanded[section.key] = true;
    });
    if (!wasExpanded) {
      await Future<void>.delayed(const Duration(milliseconds: 220));
    }
    if (!mounted) return;
    await scrollToPageSection(key, controller: _scrollController);
    _scheduleActiveSectionUpdate();
  }

  Future<void> _selectSearchResult(SearchResult result) async {
    final setting = result.setting;
    final sectionKey = setting.section;
    if (sectionKey == null) return;
    final section = _registry.getSection(sectionKey);
    if (section == null) return;
    final wasExpanded =
        _sectionExpanded[sectionKey] ?? section.initiallyExpanded;
    final subKey = setting.subSection;
    final subWasExpanded =
        subKey == null ||
        subKey.isEmpty ||
        _isSubSectionExpanded(sectionKey, subKey);
    setState(() {
      _sectionExpanded[sectionKey] = true;
      if (subKey != null && subKey.isNotEmpty) {
        _subSectionExpanded[_subSectionId(sectionKey, subKey)] = true;
      }
      _activeSectionId = sectionKey;
    });
    if (!wasExpanded || !subWasExpanded) {
      await Future<void>.delayed(const Duration(milliseconds: 220));
    }
    if (!mounted) return;
    await _anchors.scrollTo(setting.key);
    _scheduleActiveSectionUpdate();
  }

  bool _isSearchResultVisible(SearchResult result) {
    final setting = result.setting;
    return setting.visible &&
        (setting.section == null ||
            _registry.getSection(setting.section!) != null);
  }

  List<Widget> _sectionChildren(
    BuildContext context,
    SettingsProviders settings,
    String sectionKey,
  ) {
    final bySub = _registry.getSettingsGroupedBySubSection(sectionKey);
    final result = <Widget>[];
    final keys = bySub.keys.toList()
      ..sort((a, b) => (a ?? '').compareTo(b ?? ''));

    for (final subKey in keys) {
      final settingsList = bySub[subKey]!
          .where((setting) => setting.visible)
          .toList();
      if (settingsList.isEmpty) continue;
      final tiles = <Widget>[];
      for (final setting in settingsList) {
        final tile = _buildTileForSetting(context, settings, setting);
        if (tile != null) tiles.add(_anchors.wrap(setting.key, tile));
      }
      if (tiles.isEmpty) continue;
      if (subKey != null && subKey.isNotEmpty) {
        final expanded = _isSubSectionExpanded(sectionKey, subKey);
        result.add(
          SettingsCollapsibleSubsection(
            title: subKey.tr(),
            expanded: expanded,
            onToggle: () =>
                _setSubSectionExpanded(sectionKey, subKey, !expanded),
            children: expanded ? tiles : const [],
          ),
        );
        continue;
      }
      result.addAll(tiles);
    }
    return visibleCatalogChildren(_registry, result);
  }

  Widget _sectionWidget(
    BuildContext context,
    SettingsProviders settings,
    SettingSection section,
  ) {
    final isExpanded =
        _sectionExpanded[section.key] ?? section.initiallyExpanded;
    return KeyedSubtree(
      key: _sectionKeys[section.key],
      child: CardSettingsSection(
        title: _sectionTitle(section.titleKey),
        icon: section.icon ?? Icons.settings,
        isExpanded: isExpanded,
        onExpansionChanged: (expanded) =>
            _setSectionExpanded(section.key, expanded),
        sectionId: section.key,
        children: _sectionChildren(context, settings, section.key),
      ),
    );
  }

  Widget _buildSettingsList(BuildContext context, SettingsProviders settings) {
    final bottomInset =
        SafaehBottomNavScope.maybeOf(context)?.contentInsetWithSafeArea ?? 0.0;
    return ListView(
      key: _scrollViewportKey,
      controller: _scrollController,
      padding: EdgeInsets.fromLTRB(0, 8, 0, bottomInset + 16),
      children: [
        for (final section in _displayedSections)
          _sectionWidget(context, settings, section),
      ],
    );
  }

  Widget _buildBody(BuildContext context, SettingsProviders settings) {
    final list = Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720),
        child: _buildSettingsList(context, settings),
      ),
    );
    final wide = _isWide(context);
    final content = wide
        ? Row(
            children: [
              Expanded(child: list),
              SizedBox(
                width: 236,
                child: Material(
                  color: Theme.of(context).scaffoldBackgroundColor,
                  child: SafaehSettingsPageIndex(
                    title: 'settingsOnThisPage'.tr(),
                    sections: _displayedSections,
                    sectionKeys: _sectionKeys,
                    labelBuilder: (section) => _sectionTitle(section.titleKey),
                    activeId: _activeSectionId,
                    onSelect: _selectSection,
                  ),
                ),
              ),
            ],
          )
        : list;

    return Stack(
      fit: StackFit.expand,
      children: [
        content,
        if (!wide)
          SafaehSettingsPageIndexOverlay(
            title: 'settingsOnThisPage'.tr(),
            sections: _displayedSections,
            sectionKeys: _sectionKeys,
            labelBuilder: (section) => _sectionTitle(section.titleKey),
            activeId: _activeSectionId,
            onSelect: _selectSection,
          ),
        SafaehSettingsSearchOverlay(
          isOpen: _isSearchOpen,
          onClose: () => _setSearchOpen(false),
          searchIndex: settings.searchIndex,
          resultFilter: _isSearchResultVisible,
          onResultSelected: _selectSearchResult,
          hintText: 'searchSettings'.tr(),
          sectionTitleBuilder: _sectionTitle,
          settingTitleBuilder: _settingTitle,
          settingSubtitleBuilder: _settingSubtitle,
          emptyMessageBuilder: (query) =>
              'settingsNoSearchResults'.tr(namedArgs: {'query': query}),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<String>(ref.settings.provider(languageSetting), (
      previous,
      next,
    ) {
      final locale = localeFromLanguageKey(next);
      if (locale == null) {
        context.resetLocale();
      } else {
        context.setLocale(locale);
      }
    });

    final settings = ref.settings;
    return Scaffold(
      primary: false,
      appBar: widget.showAppBar
          ? AppBar(
              title: Text('settings'.tr()),
              actions: [
                SafaehSettingsSearchButton(
                  isOpen: _isSearchOpen,
                  hintText: 'searchSettings'.tr(),
                  onPressed: () => _setSearchOpen(!_isSearchOpen),
                ),
              ],
            )
          : null,
      body: _buildBody(context, settings),
    );
  }

  Widget? _buildTileForSetting(
    BuildContext context,
    SettingsProviders settings,
    SettingDefinition<Object?> setting,
  ) {
    final defaultTile = _buildDefaultTile(context, settings, setting);
    if (setting.key == bluetoothMeasurementsEnabledSetting.key) {
      final appSettings = ref.watch(appSettingsProvider);
      return SwitchSettingsTile.fromSetting(
        setting: bluetoothMeasurementsEnabledSetting,
        title: _settingTitle(setting),
        subtitle: _settingSubtitle(setting),
        value: appSettings.bluetoothMeasurementsEnabled,
        enabled: true,
        onChanged: ref.setBluetoothMeasurementsEnabled,
      );
    }
    if (setting.key == bleInputSetting.key) {
      return const BleEngineSettingsTile();
    }
    if (setting.key == dateFormatStringSetting.key) {
      final appSettings = ref.watch(appSettingsProvider);
      final locale = Localizations.localeOf(context).toString();
      final current = appSettings.dateFormatString;
      final previewAt = DateTime.now();

      return ListTile(
        leading: const Icon(Icons.schedule),
        title: Text('enterTimeFormatScreen'.tr()),
        subtitle: Text(_formatDatePreview(current, locale, previewAt)),
        trailing: settingsChevronEnd(context),
        onTap: () async {
          final patterns = [
            if (!dateFormatStringOptions.contains(current)) current,
            ...dateFormatStringOptions,
          ];
          final title = 'enterTimeFormatScreen'.tr();
          final result = await showResponsiveSheet<String>(
            context: context,
            title: title,
            maxHeight: MediaQuery.sizeOf(context).height * 0.75,
            child: DeferUntilSheetSettled(
              placeholder: SheetOptionSkeleton(
                count: patterns.length,
                twoLine: true,
              ),
              child: _TimeFormatPicker(
                patterns: patterns,
                selected: current,
                locale: locale,
              ),
            ),
          );
          if (!mounted || result == null) return;
          await ref.updateSetting(dateFormatStringSetting, result);
        },
      );
    }
    if (setting is! ActionSetting) return defaultTile;
    if (setting.key == bodyProfileAction.key) {
      final appSettings = ref.watch(appSettingsProvider);
      return ActionSettingsTile(
        leading: const Icon(Icons.accessibility_new),
        title: Text('bodyProfile'.tr()),
        subtitle: Text(
          appSettings.hasBodyProfile
              ? '${appSettings.bodyHeightCm!.round()} cm · ${appSettings.birthYear}'
              : 'bodyProfileIncomplete'.tr(),
        ),
        enabled: appSettings.weightInput,
        onTap: appSettings.weightInput
            ? () => _handleAction(context, setting.key)
            : null,
      );
    }
    if (setting.key == bluetoothDevicesAction.key) {
      final appSettings = ref.watch(appSettingsProvider);
      final enabled =
          appSettings.bluetoothMeasurementsEnabled &&
          appSettings.bleInput != BluetoothInputMode.disabled;
      return ActionSettingsTile(
        leading: const Icon(Icons.bluetooth_searching),
        title: Text('bluetoothDevices'.tr()),
        subtitle: appSettings.knownBleDev.isEmpty
            ? null
            : Text(
                appSettings.knownBleDev
                    .map((device) => device.displayName)
                    .join(', '),
              ),
        enabled: enabled,
        onTap: enabled ? () => _handleAction(context, setting.key) : null,
      );
    }
    final appSettings = ref.watch(appSettingsProvider);
    final enabled = switch (setting.key) {
      'graph_settings' || 'bp_range_limits' => appSettings.bloodPressureEnabled,
      'weight_range_limits' => appSettings.weightInput,
      'medications' => appSettings.medicineFeatureEnabled,
      _ => isSettingEnabled(settings, setting, ref),
    };
    return ActionSettingsTile(
      leading: setting.icon != null ? Icon(setting.icon) : null,
      title: Text(setting.titleKey.tr()),
      subtitle: setting.subtitleKey != null
          ? Text(setting.subtitleKey!.tr())
          : null,
      enabled: enabled,
      onTap: enabled ? () => _handleAction(context, setting.key) : null,
    );
  }

  Widget? _buildDefaultTile(
    BuildContext context,
    SettingsProviders settings,
    SettingDefinition<Object?> setting,
  ) {
    var enabled = isSettingEnabled(settings, setting, ref);
    if (setting.key == overdueReminderCountSetting.key ||
        setting.key == overdueReminderIntervalSetting.key) {
      enabled =
          enabled &&
          ref.watch(appSettingsProvider).medicationNotificationsEnabled;
    }
    final title = setting.titleKey.tr();
    final subtitle = setting.subtitleKey?.tr();

    String enumLabel(String value) {
      if (setting is EnumSetting && setting.useRawLabels) return value;
      if (setting is EnumSetting && setting.optionLabels != null) {
        final key = setting.optionLabels![value];
        if (key != null) return _enumLabel(key);
      }
      return _enumLabel(value);
    }

    if (setting is ActionSetting) {
      return ActionSettingsTile(
        leading: setting.icon != null ? Icon(setting.icon) : null,
        title: Text(title),
        subtitle: subtitle != null ? Text(subtitle) : null,
        onTap: null,
      );
    }
    if (setting is BoolSetting) {
      final value = ref.watch(settings.provider(setting));
      return SwitchSettingsTile.fromSetting(
        setting: setting,
        title: title,
        subtitle: subtitle,
        value: value,
        enabled: enabled,
        onChanged: enabled
            ? (value) =>
                  ref.read(settings.provider(setting).notifier).set(value)
            : null,
      );
    }
    if (setting is EnumSetting) {
      final value = ref.watch(settings.provider(setting));
      final options = setting.options ?? const <String>[];
      return ListTile(
        leading: setting.icon != null ? Icon(setting.icon) : null,
        title: Text(title),
        subtitle: Text(enumLabel(value)),
        trailing: settingsChevronEnd(context),
        enabled: enabled,
        onTap: enabled
            ? () async {
                final result = await showOptionPickerSheet<String>(
                  context,
                  title: title,
                  selected: value,
                  maxHeight: MediaQuery.sizeOf(context).height * 0.75,
                  deferUntilSettled: setting.key == languageSetting.key,
                  options: [
                    for (final option in options)
                      SheetPickerOption<String>(
                        value: option,
                        label: enumLabel(option),
                      ),
                  ],
                );
                if (!mounted || result == null) return;
                await ref.read(settings.provider(setting).notifier).set(result);
              }
            : null,
      );
    }
    if (setting is IntSetting) {
      final value = ref.watch(settings.provider(setting));
      return IntSettingsTile.fromSetting(
        setting: setting,
        title: title,
        subtitle: value.toString(),
        value: value,
        enabled: enabled,
        dialogTitle: title,
        onChanged: enabled
            ? (value) =>
                  ref.read(settings.provider(setting).notifier).set(value)
            : null,
      );
    }
    if (setting is DoubleSetting) {
      final value = ref.watch(settings.provider(setting));
      return SliderSettingsTile.fromDoubleSetting(
        setting: setting,
        title: title,
        value: value,
        enabled: enabled,
        dialogTitle: title,
        onChanged: enabled
            ? (value) =>
                  ref.read(settings.provider(setting).notifier).set(value)
            : null,
      );
    }
    if (setting is ColorSetting) {
      final value = ref.watch(settings.provider(setting));
      final colors = [
        for (final color in setting.colorOptions ?? appColorOptions)
          Color(color),
      ];
      final preview = Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: Color(value),
          shape: BoxShape.circle,
          border: Border.all(color: Theme.of(context).dividerColor, width: 2),
        ),
      );
      return ListTile(
        leading: setting.icon != null ? Icon(setting.icon) : null,
        title: Text(title),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            preview,
            const SizedBox(width: 8),
            settingsChevronEnd(
              context,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ],
        ),
        enabled: enabled,
        onTap: enabled
            ? () async {
                final result = await showConcreteColorPickerSheet(
                  context,
                  initialColor: Color(value),
                  availableColors: colors,
                  title: title,
                );
                if (!mounted || result == null) return;
                await ref
                    .read(settings.provider(setting).notifier)
                    .set(result.toARGB32());
              }
            : null,
      );
    }
    if (setting is StringSetting) {
      final value = ref.watch(settings.provider(setting));
      return ListTile(
        leading: setting.icon != null ? Icon(setting.icon) : null,
        title: Text(title),
        subtitle: Text(value),
        enabled: enabled,
      );
    }
    return null;
  }

  String _enumLabel(String key) {
    if (key == 'system') return 'system'.tr();
    if (languageSettingOptions.contains(key) && key != 'system') {
      final locale = localeFromLanguageKey(key);
      return locale == null ? key : getDisplayLanguage(locale);
    }
    return key.tr();
  }

  Future<void> _handleAction(BuildContext context, String key) async {
    switch (key) {
      case 'graph_settings':
        await Navigator.pushNamed(context, AppRoute.settingsGraph.path);
      case 'graph_markings':
        await Navigator.push(
          context,
          MaterialPageRoute<void>(builder: (_) => const GraphMarkingsScreen()),
        );
      case 'body_profile':
        await Navigator.push(
          context,
          MaterialPageRoute<void>(builder: (_) => const BodyProfileScreen()),
        );
      case 'weight_range_limits':
      case 'bp_range_limits':
        await Navigator.push(
          context,
          MaterialPageRoute<void>(builder: (_) => const RangeLimitsScreen()),
        );
      case 'medications':
        await Navigator.pushNamed(context, AppRoute.settingsMedications.path);
      case 'bluetooth_devices':
        await Navigator.push(
          context,
          MaterialPageRoute<void>(
            builder: (_) => const BluetoothDevicesScreen(),
          ),
        );
      case 'health_connect_screen':
        await Navigator.pushNamed(context, AppRoute.settingsHealthConnect.path);
      case 'export_import':
        await Navigator.pushNamed(context, AppRoute.settingsExport.path);
      case 'delete_data':
        await Navigator.push(
          context,
          MaterialPageRoute<void>(builder: (_) => const DeleteDataScreen()),
        );
      case 'replay_onboarding':
        await Navigator.pushNamed(context, AppRoute.onboarding.path);
      case 'version':
        await Navigator.push(
          context,
          MaterialPageRoute<void>(builder: (_) => const VersionScreen()),
        );
      case 'source_code':
        final url = Uri.parse(
          'https://github.com/Zyzto/blood-pressure-monitor-fl',
        );
        if (await canLaunchUrl(url)) {
          await launchUrl(url, mode: LaunchMode.externalApplication);
        }
      case 'licenses':
        if (context.mounted) showLicensePage(context: context);
      case 'export_settings':
        await _exportSettings(context);
      case 'import_settings':
        await _importSettings(context);
      case 'logs_viewer':
        await Navigator.push(
          context,
          MaterialPageRoute<void>(
            builder: (_) => LogViewer(
              labels: LogViewerLabels(
                title: 'logs'.tr(),
                filterHint: 'searchSettings'.tr(),
              ),
            ),
          ),
        );
    }
  }

  Future<void> _exportSettings(BuildContext context) async {
    final fileSettingsLoader = context.fileSettingsLoader;
    final controller = ProviderScope.containerOf(
      context,
      listen: false,
    ).read(settingsControllerProvider);
    final loader = fileSettingsLoader ?? await FileSettingsLoader.load();
    final archive = await loader.createArchive(
      edadatJson: jsonEncode(dumpEdadatController(controller)),
    );
    if (archive == null) {
      if (context.mounted) context.showError('errCantCreateArchive'.tr());
      return;
    }
    final compressed = ZipEncoder().encodeBytes(archive);
    await FilePicker.saveFile(
      type: FileType.any,
      fileName: 'bloodPressureSettings.zip',
      bytes: compressed,
    );
  }

  Future<void> _importSettings(BuildContext context) async {
    final exportSettings = context.exportSettings;
    final csvExportSettings = context.csvExportSettings;
    final pdfExportSettings = context.pdfExportSettings;
    final xlsExportSettings = context.excelExportSettings;
    final intervalStoreManager = context.intervalStoreManager;
    final exportColumnsManager = context.exportColumnsManager;
    final file = await FilePicker.pickFile();
    if (!context.mounted) return;
    if (file == null) {
      context.showError('errNoFileOpened'.tr());
      return;
    }
    final path = file.path;
    if (path == null) {
      context.showError('errCantReadFile'.tr());
      return;
    }
    if (path.endsWith('db')) {
      context.showError('error'.tr(namedArgs: {'msg': 'Format too old'}));
      return;
    }
    if (!path.endsWith('zip')) {
      context.showError('errNotImportable'.tr());
      return;
    }
    try {
      final decoded = ZipDecoder().decodeStream(InputFileStream(path));
      final dir = join(Directory.systemTemp.path, 'settingsBackup');
      await extractArchiveToDisk(decoded, dir);
      final loader = await FileSettingsLoader.load(path: dir);
      exportSettings.copyFrom(await loader.loadExportSettings());
      csvExportSettings.copyFrom(await loader.loadCsvExportSettings());
      pdfExportSettings.copyFrom(await loader.loadPdfExportSettings());
      xlsExportSettings.copyFrom(await loader.loadXlsExportSettings());
      intervalStoreManager.copyFrom(await loader.loadIntervalStorageManager());
      exportColumnsManager.copyFrom(await loader.loadExportColumnsManager());
      final edadatFile = File(join(dir, EdadatFileStorage.fileName));
      if (edadatFile.existsSync()) {
        final raw = jsonDecode(edadatFile.readAsStringSync());
        if (raw is Map<String, dynamic>) {
          if (!context.mounted) return;
          final controller = ProviderScope.containerOf(
            context,
            listen: false,
          ).read(settingsControllerProvider);
          await importEdadatMap(controller, raw);
        }
      }
      if (!context.mounted) return;
      context.showSuccess(
        'success'.tr(namedArgs: {'msg': 'importSettings'.tr()}),
      );
    } on FormatException catch (e, stack) {
      if (context.mounted) context.showError('invalidZip'.tr());
      Log.warning('invalid zip', error: e, stackTrace: stack);
    }
  }
}

String _formatDatePreview(String pattern, String locale, DateTime at) {
  try {
    return WesternDateFormat(pattern, locale).format(at);
  } catch (_) {
    return pattern;
  }
}

/// Time-format rows, including a preview for each pattern.
///
/// Mounted only after the sheet animation settles. Building a formatter per
/// pattern during the slide is what made this picker hitch.
class _TimeFormatPicker extends StatefulWidget {
  const _TimeFormatPicker({
    required this.patterns,
    required this.selected,
    required this.locale,
  });

  final List<String> patterns;
  final String selected;
  final String locale;

  @override
  State<_TimeFormatPicker> createState() => _TimeFormatPickerState();
}

class _TimeFormatPickerState extends State<_TimeFormatPicker> {
  late final DateTime _previewAt = DateTime.now();
  late final List<String> _labels = [
    for (final pattern in widget.patterns)
      _formatDatePreview(pattern, widget.locale, _previewAt),
  ];

  @override
  Widget build(BuildContext context) {
    return SafaehTilePickerBody<String>(
      showTitleInBody: false,
      selected: widget.selected,
      options: [
        for (var i = 0; i < widget.patterns.length; i++)
          SafaehTileOption<String>(
            value: widget.patterns[i],
            label: _labels[i],
            subtitle: widget.patterns[i],
          ),
      ],
    );
  }
}
