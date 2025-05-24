package com.example.student_app

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import android.view.WindowManager
import android.os.Bundle
import android.app.NotificationChannel
import android.app.NotificationManager
import android.content.Context
import android.graphics.Color
import android.os.Build
import android.media.AudioAttributes
import android.net.Uri

class MainActivity : FlutterActivity() {
    private val CHANNEL = "flutter.native/screenProtection"

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        
        // Always enable FLAG_SECURE to prevent screenshots and screen recording app-wide
        window.addFlags(WindowManager.LayoutParams.FLAG_SECURE)
        
        // Create notification channels for Android O and above
        createNotificationChannels()
    }

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
            // Note: We're commenting this out to enforce app-wide screenshot protection
            // window.clearFlags(WindowManager.LayoutParams.FLAG_SECURE)
        }
    }
    
    private fun createNotificationChannels() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val notificationManager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            
            // Chat messages channel - High importance
            val chatChannel = NotificationChannel(
                "chat_channel",
                "Chat Messages",
                NotificationManager.IMPORTANCE_HIGH
            ).apply {
                description = "Notifications for new chat messages"
                enableLights(true)
                lightColor = Color.BLUE
                enableVibration(true)
                vibrationPattern = longArrayOf(0, 100, 200, 300)
                setShowBadge(true)
                
                // Add sound
                val audioAttributes = AudioAttributes.Builder()
                    .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
                    .setUsage(AudioAttributes.USAGE_NOTIFICATION)
                    .build()
                setSound(Uri.parse("android.resource://${packageName}/raw/notification_sound"), audioAttributes)
            }
            
            // General notifications channel - Default importance
            val generalChannel = NotificationChannel(
                "general_channel",
                "General Notifications",
                NotificationManager.IMPORTANCE_DEFAULT
            ).apply {
                description = "General app notifications"
                setShowBadge(true)
            }
            
            // Register the channels
            notificationManager.createNotificationChannel(chatChannel)
            notificationManager.createNotificationChannel(generalChannel)
        }
    }
}
