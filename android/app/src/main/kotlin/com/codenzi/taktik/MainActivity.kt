package com.codenzi.taktik

import android.os.Build
import android.os.Bundle
import androidx.core.view.WindowCompat
import androidx.core.view.WindowInsetsControllerCompat
import io.flutter.embedding.android.FlutterActivity

class MainActivity : FlutterActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        // Android 15+ ve SDK 35 için zorunlu edge-to-edge desteği
        enableEdgeToEdge()
        super.onCreate(savedInstanceState)
    }

    private fun enableEdgeToEdge() {
        // Tüm Android sürümleri için edge-to-edge desteği
        WindowCompat.setDecorFitsSystemWindows(window, false)

        // Window insets controller ile daha fazla kontrol
        val windowInsetsController = WindowCompat.getInsetsController(window, window.decorView)
        windowInsetsController?.let { controller ->
            // Status bar ve navigation bar'ı şeffaf yap
            controller.systemBarsBehavior = WindowInsetsControllerCompat.BEHAVIOR_SHOW_TRANSIENT_BARS_BY_SWIPE
            // Karanlık içerik için açık iconlar
            controller.isAppearanceLightStatusBars = false
            controller.isAppearanceLightNavigationBars = false
        }

        // Window flags ayarları
        window.statusBarColor = android.graphics.Color.TRANSPARENT
        window.navigationBarColor = android.graphics.Color.TRANSPARENT

        // Android 10+ için navigation bar divider'ını kaldır
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            window.navigationBarDividerColor = android.graphics.Color.TRANSPARENT
        }

        // Android 11+ için navigation bar contrast enforcement'ı devre dışı bırak
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            window.isNavigationBarContrastEnforced = false
        }
    }
}
