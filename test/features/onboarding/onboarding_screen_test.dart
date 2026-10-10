import 'package:blood_pressure_app/features/onboarding/onboarding_screen.dart';
import 'package:blood_pressure_app/features/settings/registry.dart';
import 'package:blood_pressure_app/l10n/app_locales.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_settings_framework/flutter_settings_framework.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../util.dart';

Future<Widget> _tourApp(Widget child) async {
  SharedPreferences.setMockInitialValues({});
  try {
    await EasyLocalization.ensureInitialized();
  } catch (_) {}
  EasyLocalization.logger.enableBuildModes = [];
  final settings = await initializeSettings(
    registry: createAppSettingsRegistry(),
    storage: MemoryStorage(),
  );
  return EasyLocalization(
    path: 'assets/translations',
    supportedLocales: appSupportedLocales,
    fallbackLocale: const Locale('en'),
    startLocale: const Locale('en'),
    child: ProviderScope(
      overrides: [
        settingsControllerProvider.overrideWithValue(settings.controller),
        settingsSearchIndexProvider.overrideWithValue(settings.searchIndex),
        settingsProvidersProvider.overrideWithValue(settings),
      ],
      child: MaterialApp(locale: const Locale('en'), home: child),
    ),
  );
}

Finder get _skip => find.byKey(const Key('onboarding-skip'));
Finder get _close => find.byKey(const Key('onboarding-close'));
Finder get _cta => find.byKey(const Key('onboarding-cta'));

String _ctaLabel(WidgetTester tester) {
  final button = tester.widget<FilledButton>(_cta);
  return (((button.child as Text).data) ?? '');
}

void main() {
  testWidgets('first-run shows Skip and Get started on the last page', (
    tester,
  ) async {
    await pumpApp(
      tester,
      await _tourApp(const OnboardingScreen(firstRun: true)),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.byType(OnboardingScreen), findsOneWidget);
    expect(_skip, findsOneWidget);
    expect(_close, findsNothing);
    expect(_ctaLabel(tester), anyOf('Next', 'onboardingNext'));

    await tester.tap(_cta);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(_ctaLabel(tester), anyOf('Next', 'onboardingNext'));

    await tester.tap(_cta);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    await tester.tap(_cta);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(_ctaLabel(tester), anyOf('Get started', 'onboardingGetStarted'));
    expect(_skip, findsOneWidget);
    expect(find.byKey(const Key('onboarding-shift-missed-doses')), findsOneWidget);

    await tester.tap(find.byKey(const Key('onboarding-feature-medicine')));
    await tester.pump();
    expect(find.byKey(const Key('onboarding-shift-missed-doses')), findsNothing);
  });

  testWidgets('replay shows Close and Done on the last page', (tester) async {
    await pumpApp(
      tester,
      await _tourApp(const OnboardingScreen(firstRun: false)),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(_skip, findsNothing);
    expect(_close, findsOneWidget);
    expect(_ctaLabel(tester), anyOf('Next', 'onboardingNext'));

    await tester.tap(_cta);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.tap(_cta);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.tap(_cta);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(_ctaLabel(tester), anyOf('Done', 'onboardingDone'));
    expect(_close, findsOneWidget);
  });
}
