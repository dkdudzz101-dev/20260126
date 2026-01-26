package com.jejuoreum.app

import android.app.NotificationChannel
import android.app.NotificationManager
import android.os.Build
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity

class MainActivity: FlutterActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        createNotificationChannels()
    }

    private fun createNotificationChannels() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val notificationManager = getSystemService(NOTIFICATION_SERVICE) as NotificationManager

            // 백그라운드 위치 서비스용 채널
            val locationChannel = NotificationChannel(
                "jeju_oreum_location",
                "위치 서비스",
                NotificationManager.IMPORTANCE_LOW
            ).apply {
                description = "오름 근처 자동 인증을 위한 위치 추적"
            }
            notificationManager.createNotificationChannel(locationChannel)

            // 스탬프 알림용 채널
            val stampChannel = NotificationChannel(
                "stamp_channel",
                "스탬프 알림",
                NotificationManager.IMPORTANCE_HIGH
            ).apply {
                description = "오름 스탬프 자동 인증 알림"
            }
            notificationManager.createNotificationChannel(stampChannel)
        }
    }
}
