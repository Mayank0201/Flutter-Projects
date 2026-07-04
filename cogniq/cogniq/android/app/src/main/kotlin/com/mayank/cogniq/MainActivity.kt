package com.mayank.cogniq

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.mayank.cogniq/install_marker"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "hasMarker" -> {
                    val file = File(context.noBackupFilesDir, "install_marker")
                    result.success(file.exists())
                }
                "createMarker" -> {
                    val file = File(context.noBackupFilesDir, "install_marker")
                    file.createNewFile()
                    result.success(true)
                }
                else -> result.notImplemented()
            }
        }
    }
}
