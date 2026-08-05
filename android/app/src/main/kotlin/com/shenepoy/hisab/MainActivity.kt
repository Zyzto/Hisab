package com.shenepoy.hisab

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        NotificationBridge.register(flutterEngine, applicationContext)
        ReceiptOcrBridge.register(flutterEngine, applicationContext)
        GalleryThumbBridge.register(flutterEngine, applicationContext)
        CameraLensesBridge.register(flutterEngine, applicationContext)
    }
}
