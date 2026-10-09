package com.shenepoy.janan

import android.Manifest
import android.app.LocaleManager
import android.appwidget.AppWidgetManager
import android.content.ComponentName
import android.content.pm.PackageManager
import android.os.Build
import android.os.LocaleList
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity: FlutterFragmentActivity() {
    companion object {
        private const val CHANNEL =
            "com.shenepoy.janan/bluetooth_foreground_service"
        private const val NOTIFICATION_PERMISSION_REQUEST = 4101
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            CHANNEL,
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "start" -> {
                    val text = call.argument<String>("text")
                        ?: "Scanning for Bluetooth devices"
                    try {
                        BluetoothScanForegroundService.start(this, text)
                        requestNotificationPermissionIfNeeded()
                        result.success(null)
                    } catch (_: RuntimeException) {
                        result.error("FOREGROUND_SERVICE_UNAVAILABLE", null, null)
                    }
                }
                "update" -> {
                    val text = call.argument<String>("text")
                        ?: "Scanning for Bluetooth devices"
                    try {
                        BluetoothScanForegroundService.update(this, text)
                        result.success(null)
                    } catch (_: RuntimeException) {
                        result.error("FOREGROUND_SERVICE_UNAVAILABLE", null, null)
                    }
                }
                "stop" -> {
                    try {
                        BluetoothScanForegroundService.stop(this)
                        result.success(null)
                    } catch (_: RuntimeException) {
                        result.error("FOREGROUND_SERVICE_UNAVAILABLE", null, null)
                    }
                }
                "finish" -> {
                    val text = call.argument<String>("text")
                    try {
                        BluetoothScanForegroundService.finish(this, text)
                        result.success(null)
                    } catch (_: RuntimeException) {
                        result.error("FOREGROUND_SERVICE_UNAVAILABLE", null, null)
                    }
                }
                else -> result.notImplemented()
            }
        }

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "com.shenepoy.janan/medication_widget",
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "update" -> {
                    val summary = call.argument<String>("summary") ?: "[]"
                    getSharedPreferences("medication_widget", MODE_PRIVATE)
                        .edit()
                        .putString("summary", summary)
                        .apply()
                    val manager = AppWidgetManager.getInstance(this)
                    val provider = ComponentName(this, MedicationHomeWidgetProvider::class.java)
                    val ids = manager.getAppWidgetIds(provider)
                    MedicationHomeWidgetProvider().onUpdate(this, manager, ids)
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "com.shenepoy.janan/app_locale",
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "set" -> {
                    val tag = call.argument<String>("tag").orEmpty()
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                        val locales = if (tag.isEmpty()) {
                            LocaleList.getEmptyLocaleList()
                        } else {
                            LocaleList.forLanguageTags(tag)
                        }
                        getSystemService(LocaleManager::class.java)
                            .applicationLocales = locales
                    }
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun requestNotificationPermissionIfNeeded() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU) return
        if (checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) ==
            PackageManager.PERMISSION_GRANTED
        ) return
        requestPermissions(
            arrayOf(Manifest.permission.POST_NOTIFICATIONS),
            NOTIFICATION_PERMISSION_REQUEST,
        )
    }
}
