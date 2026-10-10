import 'package:blood_pressure_app/components/custom_banner.dart';
import 'package:blood_pressure_app/components/input_dialog.dart';
import 'package:blood_pressure_app/components/snack_bar_stable_fab_location.dart';
import 'package:blood_pressure_app/core/widgets/toast.dart';
import 'package:blood_pressure_app/features/settings/app_settings.dart';
import 'package:blood_pressure_app/features/settings/registry.dart';
import 'package:blood_pressure_app/features/settings/tiles/number_input_list_tile.dart';
import 'package:blood_pressure_app/model/blood_pressure/warn_values.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_settings_framework/flutter_settings_framework.dart';
import 'package:url_launcher/url_launcher.dart';

/// Screen containing warn value related information and settings.
class ConfigureWarnValuesScreen extends ConsumerWidget {
  /// Create screen containing warn value related information and settings.
  const ConfigureWarnValuesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(appSettingsProvider);
    return Scaffold(
      appBar: AppBar(forceMaterialTransparency: true),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: null,
        label: Text('determineWarnValues'.tr()),
        onPressed:() async {
          final age = (await showNumberInputDialog(context,
            hintText: 'age'.tr(),
          ))?.round();
          if (age != null) {
            await ref.updateSetting(
              sysWarnSetting,
              BloodPressureWarnValues.getUpperSysWarnValue(age),
            );
            await ref.updateSetting(
              diaWarnSetting,
              BloodPressureWarnValues.getUpperDiaWarnValue(age),
            );
          }
        },
      ),
      floatingActionButtonAnimator: FloatingActionButtonAnimator.noAnimation,
      floatingActionButtonLocation: const SnackBarStableFabLocation(
        base: FloatingActionButtonLocation.endFloat,
      ),
      body: ListView(
        children: [
          CustomBanner(
            content: Column(children: [
              Text('warnAboutTxt1'.tr()),
              const SizedBox(
                height: 5,
              ),
              InkWell(
                onTap: () async {
                  final url = Uri.parse(BloodPressureWarnValues.source);
                  if (await canLaunchUrl(url)) {
                    await launchUrl(url, mode: LaunchMode.externalApplication);
                  } else if (context.mounted) {
                    context.showError('errCantOpenURL'.tr(namedArgs: {
                      'url': BloodPressureWarnValues.source,
                    }));
                  }
                },
                child: SizedBox(
                  height: 48,
                  child: Center(
                    child: Text(
                      'warnAboutTxt2'.tr(),
                      style: const TextStyle(color: Colors.blue),
                    ),
                  ),
                ),
              ),
              const SizedBox(
                height: 5,
              ),
              Text('warnAboutTxt3'.tr()),
              const SizedBox(height: 10.0),
            ],),
          ),
          NumberInputListTile(
            label: 'sysWarn'.tr(),
            leading: const Icon(Icons.warning_amber_outlined),
            value: settings.sysWarn,
            onParsableSubmit: (double value) {
              ref.updateSetting(sysWarnSetting, value.round());
            },
          ),
          NumberInputListTile(
            label: 'diaWarn'.tr(),
            leading: const Icon(Icons.warning_amber_outlined),
            value: settings.diaWarn,
            onParsableSubmit: (double value) {
              ref.updateSetting(diaWarnSetting, value.round());
            },
          ),
        ],
      ) ,
    );
  }

}
