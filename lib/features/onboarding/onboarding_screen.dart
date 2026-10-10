import 'package:blood_pressure_app/features/settings/app_settings.dart';
import 'package:blood_pressure_app/features/settings/registry.dart';
import 'package:blood_pressure_app/l10n/app_locales.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_settings_framework/flutter_settings_framework.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:safaeh/safaeh.dart';

const _tutorialPages = 4;

/// Classic carousel onboarding: hero, short centered copy, dots, full-width CTA.
///
/// Used for first run and as a replayable tour.
class OnboardingScreen extends ConsumerStatefulWidget {
  /// Create the tour. [firstRun] drives Skip vs Close and Get started vs Done.
  const OnboardingScreen({super.key, required this.firstRun});

  /// Whether this is the first launch (not a replay from Settings).
  final bool firstRun;

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final PageController _pager = PageController();
  int _page = 0;

  @override
  void dispose() {
    _pager.dispose();
    super.dispose();
  }

  bool get _onLastPage => _page == _tutorialPages - 1;

  Future<void> _goTo(int page) async {
    await _pager.animateToPage(
      page,
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
    );
  }

  Future<void> _finish() async {
    if (widget.firstRun && !ref.read(appSettingsProvider).onboardingCompleted) {
      await ref.updateSetting(onboardingCompletedSetting, true);
    }
    if (!mounted) return;
    if (widget.firstRun) {
      await Navigator.of(context).pushReplacementNamed('/');
    } else {
      Navigator.of(context).pop();
    }
  }

  Future<void> _setLanguage(String key) async {
    await ref.updateSetting(languageSetting, key);
    if (!mounted) return;
    final locale = localeFromLanguageKey(key);
    if (locale == null) {
      await context.resetLocale();
    } else {
      await context.setLocale(locale);
    }
  }

  Future<void> _cycleTheme() async {
    final current = ref.read(appSettingsProvider).themeMode;
    final next = switch (current) {
      ThemeMode.system => ThemeMode.light,
      ThemeMode.light => ThemeMode.dark,
      ThemeMode.dark => ThemeMode.system,
    };
    await ref.setThemeMode(next);
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(appSettingsProvider);
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        if (_page > 0) {
          _goTo(_page - 1);
        } else if (!widget.firstRun) {
          _finish();
        }
      },
      child: Scaffold(
        backgroundColor: Theme.of(context).colorScheme.surface,
        body: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: Row(
                  children: [
                    _LanguageMenuButton(
                      languageKey: settings.languageKey,
                      onSelect: _setLanguage,
                    ),
                    _ThemeCycleButton(
                      themeMode: settings.themeMode,
                      onPressed: _cycleTheme,
                    ),
                    const Spacer(),
                    if (widget.firstRun)
                      TextButton(
                        key: const Key('onboarding-skip'),
                        onPressed: _finish,
                        child: Text('onboardingSkip'.tr()),
                      )
                    else
                      IconButton(
                        key: const Key('onboarding-close'),
                        onPressed: _finish,
                        tooltip: 'onboardingDone'.tr(),
                        icon: const Icon(Icons.close),
                      ),
                  ],
                ),
              ),
              Expanded(
                child: PageView(
                  controller: _pager,
                  onPageChanged: (page) => setState(() => _page = page),
                  children: const [
                    _OnboardingPage(page: 0),
                    _OnboardingPage(page: 1),
                    _OnboardingPage(page: 2),
                    _FeatureSetupPage(),
                  ],
                ),
              ),
              _PageDots(current: _page, count: _tutorialPages),
              const SizedBox(height: 20),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: FilledButton(
                    key: const Key('onboarding-cta'),
                    style: FilledButton.styleFrom(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(28),
                      ),
                      textStyle: Theme.of(context).textTheme.titleMedium,
                    ),
                    onPressed: () {
                      if (_onLastPage) {
                        _finish();
                      } else {
                        _goTo(_page + 1);
                      }
                    },
                    child: Text(
                      !_onLastPage
                          ? 'onboardingNext'.tr()
                          : widget.firstRun
                          ? 'onboardingGetStarted'.tr()
                          : 'onboardingDone'.tr(),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 28),
            ],
          ),
        ),
      ),
    );
  }
}

class _FeatureSetupPage extends ConsumerWidget {
  const _FeatureSetupPage();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(appSettingsProvider);
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: Column(
        children: [
          Icon(
            Icons.tune,
            size: 44,
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(height: 12),
          Text(
            'featuresSetting'.tr(),
            style: Theme.of(context).textTheme.headlineSmall,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            'onboardingFeaturesHint'.tr(),
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          SwitchListTile(
            key: const Key('onboarding-feature-blood-pressure'),
            title: Text('bloodPressure'.tr()),
            secondary: const Icon(Symbols.heart_plus),
            value: settings.bloodPressureEnabled,
            onChanged: (value) =>
                ref.updateSetting(bloodPressureEnabledSetting, value),
          ),
          SwitchListTile(
            key: const Key('onboarding-feature-medicine'),
            title: Text('medications'.tr()),
            secondary: const Icon(Icons.medication_outlined),
            value: settings.medicineFeatureEnabled,
            onChanged: (value) =>
                ref.updateSetting(medicineFeatureEnabledSetting, value),
          ),
          if (settings.medicineFeatureEnabled)
            SwitchListTile(
              key: const Key('onboarding-shift-missed-doses'),
              title: Text('shiftMissedDoseTimes'.tr()),
              subtitle: Text('onboardingShiftMissedHint'.tr()),
              secondary: const Icon(Icons.update),
              value: settings.shiftMissedDoseTimes,
              onChanged: (value) =>
                  ref.updateSetting(shiftMissedDoseTimesSetting, value),
            ),
          SwitchListTile(
            key: const Key('onboarding-feature-weight'),
            title: Text('weight'.tr()),
            secondary: const Icon(Icons.scale_outlined),
            value: settings.weightInput,
            onChanged: (value) => ref.updateSetting(weightInputSetting, value),
          ),
          SwitchListTile(
            key: const Key('onboarding-feature-bluetooth'),
            title: Text('bluetoothMeasurements'.tr()),
            secondary: const Icon(Icons.bluetooth),
            value: settings.bluetoothMeasurementsEnabled,
            onChanged: ref.setBluetoothMeasurementsEnabled,
          ),
        ],
      ),
    );
  }
}

class _LanguageMenuButton extends StatelessWidget {
  const _LanguageMenuButton({
    required this.languageKey,
    required this.onSelect,
  });

  final String languageKey;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    String label(String key) => key == 'system'
        ? 'system'.tr()
        : getDisplayLanguage(localeFromLanguageKey(key)!);
    return SafaehAnchoredDropdownChip<String>(
      icon: Icons.language,
      label: label(languageKey),
      selected: languageKey,
      options: [
        for (final key in languageSettingOptions)
          SafaehDropdownOption(value: key, label: label(key)),
      ],
      onSelected: onSelect,
    );
  }
}

class _ThemeCycleButton extends StatelessWidget {
  const _ThemeCycleButton({required this.themeMode, required this.onPressed});

  final ThemeMode themeMode;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final icon = switch (themeMode) {
      ThemeMode.system => Icons.brightness_auto,
      ThemeMode.light => Icons.light_mode_outlined,
      ThemeMode.dark => Icons.dark_mode_outlined,
    };
    return IconButton(
      tooltip: 'theme'.tr(),
      onPressed: onPressed,
      icon: Icon(icon),
    );
  }
}

class _OnboardingPage extends StatelessWidget {
  const _OnboardingPage({required this.page});

  final int page;

  @override
  Widget build(BuildContext context) {
    final title = switch (page) {
      0 => 'onboardingWelcomeTitle'.tr(),
      1 => 'onboardingAddTitle'.tr(),
      _ => 'onboardingTrendsTitle'.tr(),
    };
    final body = switch (page) {
      0 => 'onboardingWelcomeBody'.tr(),
      1 => 'onboardingAddBody'.tr(),
      _ => 'onboardingTrendsBody'.tr(),
    };
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 28),
      child: Column(
        children: [
          Expanded(
            child: Center(
              child: switch (page) {
                0 => const _WelcomeHero(),
                1 => const _AddHero(),
                _ => const _TrendsHero(),
              },
            ),
          ),
          Text(
            title,
            style: theme.textTheme.headlineMedium?.copyWith(
              color: theme.colorScheme.onSurface,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 10),
          Text(
            body,
            style: theme.textTheme.bodyLarge?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

class _WelcomeHero extends StatelessWidget {
  const _WelcomeHero();

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return SizedBox(
      width: 280,
      height: 280,
      child: Stack(
        alignment: Alignment.center,
        clipBehavior: Clip.none,
        children: [
          Container(
            width: 260,
            height: 260,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: colors.primaryContainer.withValues(alpha: 0.45),
            ),
          ),
          Container(
            width: 176,
            height: 176,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: colors.primaryContainer,
            ),
            child: Icon(
              Symbols.heart_plus,
              size: 72,
              color: colors.onPrimaryContainer,
            ),
          ),
          const Positioned(
            left: 0,
            top: 36,
            child: _FloatingChip(
              icon: Icons.add_chart_outlined,
              labelKey: 'addMeasurement',
            ),
          ),
          const Positioned(
            right: 0,
            top: 72,
            child: _FloatingChip(
              icon: Icons.insights_outlined,
              labelKey: 'statistics',
            ),
          ),
          const Positioned(
            bottom: 8,
            child: _FloatingChip(
              icon: Icons.ios_share_outlined,
              labelKey: 'exportImport',
            ),
          ),
        ],
      ),
    );
  }
}

class _AddHero extends StatelessWidget {
  const _AddHero();

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Stack(
      alignment: Alignment.center,
      children: [
        Container(
          width: 260,
          height: 260,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: colors.secondaryContainer.withValues(alpha: 0.55),
          ),
        ),
        Material(
          color: colors.surface,
          elevation: 8,
          shadowColor: colors.shadow.withValues(alpha: 0.3),
          borderRadius: BorderRadius.circular(28),
          child: SizedBox(
            width: 220,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _ReadingRow(label: 'sysShort'.tr(), value: '120'),
                  const SizedBox(height: 12),
                  _ReadingRow(label: 'diaShort'.tr(), value: '80'),
                  const SizedBox(height: 12),
                  _ReadingRow(label: 'pulShort'.tr(), value: '72'),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _ReadingRow extends StatelessWidget {
  const _ReadingRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: Theme.of(
              context,
            ).textTheme.titleSmall?.copyWith(color: colors.onSurfaceVariant),
          ),
        ),
        Text(
          value,
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(color: colors.onSurface),
        ),
      ],
    );
  }
}

class _TrendsHero extends ConsumerWidget {
  const _TrendsHero();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = Theme.of(context).colorScheme;
    final settings = ref.watch(appSettingsProvider);
    return Stack(
      alignment: Alignment.center,
      children: [
        Container(
          width: 260,
          height: 260,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: colors.tertiaryContainer.withValues(alpha: 0.55),
          ),
        ),
        Material(
          color: colors.surface,
          elevation: 8,
          shadowColor: colors.shadow.withValues(alpha: 0.3),
          borderRadius: BorderRadius.circular(24),
          child: SizedBox(
            width: 240,
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'statistics'.tr(),
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ),
                      Icon(
                        Icons.ios_share_outlined,
                        color: colors.primary,
                        size: 20,
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    height: 72,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        _TrendBar(color: settings.sysColor, height: 68),
                        const SizedBox(width: 10),
                        _TrendBar(color: settings.diaColor, height: 48),
                        const SizedBox(width: 10),
                        _TrendBar(color: settings.pulColor, height: 36),
                        const SizedBox(width: 10),
                        _TrendBar(color: settings.sysColor, height: 58),
                        const SizedBox(width: 10),
                        _TrendBar(color: settings.diaColor, height: 42),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _TrendBar extends StatelessWidget {
  const _TrendBar({required this.color, required this.height});

  final Color color;
  final double height;

  @override
  Widget build(BuildContext context) => Expanded(
    child: Align(
      alignment: Alignment.bottomCenter,
      child: Container(
        height: height,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    ),
  );
}

class _FloatingChip extends StatelessWidget {
  const _FloatingChip({required this.icon, required this.labelKey});

  final IconData icon;
  final String labelKey;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Material(
      color: colors.surface,
      elevation: 6,
      shadowColor: colors.shadow.withValues(alpha: 0.25),
      borderRadius: BorderRadius.circular(999),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: colors.primary),
            const SizedBox(width: 6),
            Text(
              labelKey.tr(),
              style: Theme.of(context).textTheme.labelMedium,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

class _PageDots extends StatelessWidget {
  const _PageDots({required this.current, required this.count});

  final int current;
  final int count;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (var i = 0; i < count; i++) ...[
          if (i > 0) const SizedBox(width: 8),
          AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOut,
            height: 8,
            width: i == current ? 22 : 8,
            decoration: BoxDecoration(
              color: i == current ? colors.primary : colors.outlineVariant,
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ],
      ],
    );
  }
}
