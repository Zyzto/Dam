import 'dart:io';

import 'package:blood_pressure_app/core/widgets/toast.dart';
import 'package:blood_pressure_app/data_util/consistent_future_builder.dart';
import 'package:blood_pressure_app/logging.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path/path.dart';
import 'package:safaeh/safaeh.dart';
import 'package:sqflite/sqflite.dart';

/// Screen that shows app version and debug options.
class VersionScreen extends StatefulWidget {
  /// Screen that shows app version and debug options.
  const VersionScreen({super.key});

  @override
  State<VersionScreen> createState() => _VersionScreenState();
}

class _VersionScreenState extends State<VersionScreen> with Loggable {
  @override
  Widget build(BuildContext context) => Scaffold(
      appBar: AppBar(
        title: Text('version'.tr()),
        actions: [
          IconButton(
            onPressed: () async {
              final packageInfo = await PackageInfo.fromPlatform();
              await Clipboard.setData(ClipboardData(
                  text: 'Blood pressure monitor\n'
                      '${packageInfo.packageName}\n'
                      '${packageInfo.version} - ${packageInfo.buildNumber}',
              ),);
            },
            tooltip: 'export'.tr(),
            icon: const Icon(Icons.copy),
          ),
        ],
        backgroundColor: Theme.of(context).primaryColor,
      ),
      body: Padding(
        padding: const EdgeInsets.all(10.0),
        child: ListView(
          children: [
            // Debug info
            ConsistentFutureBuilder<PackageInfo>(
              future: PackageInfo.fromPlatform(),
              onData: (context, packageInfo) => Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('packageNameOf'.tr(namedArgs: {'name': packageInfo.packageName})),
                    Text('versionOf'.tr(namedArgs: {'version': packageInfo.version})),
                    Text('buildNumberOf'.tr(namedArgs: {'buildNumber': packageInfo.buildNumber})),
                  ],
                ),
            ),
            ListTile(
              title: Text('logs'.tr()),
              trailing: Icon(safaehChevronEnd(context)),
              onTap: () {
                Navigator.of(context).push(MaterialPageRoute<void>(
                  builder: (_) => LogViewer(
                    labels: LogViewerLabels(
                      title: 'logs'.tr(),
                      filterHint: 'searchSettings'.tr(),
                    ),
                  ),
                ));
              },
            ),
            FutureBuilder(future: Future(() async {
              final dbPath = await getDatabasesPath();
              return join(dbPath, 'blood_pressure.db');
            }), builder: (context, snapshot) {
              if (snapshot.data == null || !File(snapshot.data!).existsSync()) {
                return SizedBox.shrink();
              }
              return ListTile(
                onTap: () async {
                  try {
                    await FilePicker.saveFile(
                      fileName: 'blood_pressure.db',
                      bytes: File(snapshot.data!).readAsBytesSync(),
                      type: FileType.any, // application/vnd.sqlite3
                    );
                  } catch(e) {
                    if (!context.mounted) return;
                    context.showError('ERR: $e');
                  }
                },
                title: const Text('rescue legacy db'),
              );
            }),
            ListTile(
              title: Text('Test log messages'),
              trailing: Icon(safaehChevronEnd(context)),
              onTap: () {
                logDebug('test finest');
                logDebug('test finer');
                logDebug('test fine');
                logInfo('test info');
                logWarning('test warning');
                logSevere('test severe');
                logSevere('test shout');
              },
            )
          ],
        ),
      ),
    );
}
