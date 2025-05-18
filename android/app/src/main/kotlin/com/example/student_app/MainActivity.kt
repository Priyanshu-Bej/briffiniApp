package com.example.student_app

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import android.view.WindowManager
import android.os.Bundle

class MainActivity : FlutterActivity() {
    private val CHANNEL = "flutter.native/screenProtection"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            if (call.method == "preventScreenshots") {
                val enable = call.arguments as Boolean
                toggleSecureScreen(enable)
                result.success(true)
            } else {
                result.notImplemented()
            }
        }
    }

    private fun toggleSecureScreen(secure: Boolean) {
        if (secure) {
            // Prevent screenshots and screen recording
            window.addFlags(WindowManager.LayoutParams.FLAG_SECURE)
        } else {
            // Allow screenshots and screen recording
            window.clearFlags(WindowManager.LayoutParams.FLAG_SECURE)
        }
    }
}
