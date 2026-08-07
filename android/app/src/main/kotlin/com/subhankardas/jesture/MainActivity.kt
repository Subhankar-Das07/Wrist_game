package com.subhankardas.jesture

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine

class MainActivity : FlutterActivity() {

    private lateinit var handLandmarkerService: HandLandmarkerService

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        handLandmarkerService = HandLandmarkerService(this)
        handLandmarkerService.register(flutterEngine)
    }

    override fun onDestroy() {
        super.onDestroy()
        if (::handLandmarkerService.isInitialized) {
            handLandmarkerService.destroy()
        }
    }
}
