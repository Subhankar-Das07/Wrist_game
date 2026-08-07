package com.subhankardas.jesture

import android.content.Context
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.ImageFormat
import android.graphics.Matrix
import android.graphics.Rect
import android.graphics.YuvImage
import android.os.Handler
import android.os.Looper
import android.util.Log
import com.google.mediapipe.framework.image.BitmapImageBuilder
import com.google.mediapipe.tasks.core.BaseOptions
import com.google.mediapipe.tasks.core.Delegate
import com.google.mediapipe.tasks.vision.core.RunningMode
import com.google.mediapipe.tasks.vision.handlandmarker.HandLandmarker
import com.google.mediapipe.tasks.vision.handlandmarker.HandLandmarkerResult
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.ByteArrayOutputStream
import java.util.concurrent.ExecutorService
import java.util.concurrent.Executors

/**
 * HandLandmarkerService — Ultra-Fast Direct Frame MediaPipe Fist Tracking
 *
 * Receives camera frames directly from Flutter's CameraController stream.
 * Eliminates native camera hardware conflicts and ensures 100% reliable detection.
 */
class HandLandmarkerService(
    private val context: Context
) : MethodChannel.MethodCallHandler {

    companion object {
        private const val TAG = "HandLandmarkerService"
        private const val MODEL_FILE = "hand_landmarker.task"
        // Landmark 9 = Middle finger MCP (center of fist / knuckle)
        private const val FIST_CENTER_LANDMARK = 9
        private const val CHANNEL_NAME = "com.example.jesture/hand_landmarker"
    }

    private var handLandmarker: HandLandmarker? = null
    private val executor: ExecutorService = Executors.newSingleThreadExecutor()
    private val mainHandler = Handler(Looper.getMainLooper())
    private var isDetecting = false

    fun register(flutterEngine: FlutterEngine) {
        val channel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL_NAME)
        channel.setMethodCallHandler(this)
        initHandLandmarker()
    }

    private fun initHandLandmarker() {
        // Try GPU delegate first for fastest performance
        try {
            initWithOptions(Delegate.GPU)
            Log.d(TAG, "MediaPipe HandLandmarker initialized with GPU delegate")
            return
        } catch (e: Exception) {
            Log.w(TAG, "GPU delegate unavailable, falling back to CPU: ${e.message}")
        }

        // Fallback to CPU
        try {
            initWithOptions(Delegate.CPU)
            Log.d(TAG, "MediaPipe HandLandmarker initialized with CPU delegate")
        } catch (e: Exception) {
            Log.e(TAG, "Failed to initialize HandLandmarker: ${e.message}")
        }
    }

    private fun initWithOptions(delegate: Delegate) {
        val baseOptions = BaseOptions.builder()
            .setModelAssetPath(MODEL_FILE)
            .setDelegate(delegate)
            .build()

        val options = HandLandmarker.HandLandmarkerOptions.builder()
            .setBaseOptions(baseOptions)
            .setNumHands(2)
            // Low thresholds for instant, rock-solid detection in any lighting
            .setMinHandDetectionConfidence(0.35f)
            .setMinHandPresenceConfidence(0.35f)
            .setMinTrackingConfidence(0.35f)
            .setRunningMode(RunningMode.IMAGE)
            .build()

        handLandmarker = HandLandmarker.createFromOptions(context, options)
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "detectHands" -> {
                val bytes = call.argument<ByteArray>("bytes")
                val width = call.argument<Int>("width") ?: 0
                val height = call.argument<Int>("height") ?: 0
                val rotation = call.argument<Int>("rotation") ?: 270

                if (bytes == null || width == 0 || height == 0) {
                    result.success(listOf(-1.0, -1.0, -1.0, -1.0))
                    return
                }

                if (isDetecting) {
                    // Skip frame if previous is still processing to avoid queueing
                    result.success(listOf(-1.0, -1.0, -1.0, -1.0))
                    return
                }

                isDetecting = true
                executor.execute {
                    try {
                        val coords = processFrame(bytes, width, height, rotation)
                        mainHandler.post {
                            result.success(coords)
                            isDetecting = false
                        }
                    } catch (e: Exception) {
                        Log.e(TAG, "Error in hand detection: ${e.message}")
                        mainHandler.post {
                            result.success(listOf(-1.0, -1.0, -1.0, -1.0))
                            isDetecting = false
                        }
                    }
                }
            }
            else -> result.notImplemented()
        }
    }

    private fun processFrame(bytes: ByteArray, width: Int, height: Int, rotation: Int): List<Double> {
        val landmarker = handLandmarker ?: return listOf(-1.0, -1.0, -1.0, -1.0)

        // Convert NV21 byte array to Bitmap
        val yuvImage = YuvImage(bytes, ImageFormat.NV21, width, height, null)
        val out = ByteArrayOutputStream()
        yuvImage.compressToJpeg(Rect(0, 0, width, height), 80, out)
        val jpegBytes = out.toByteArray()
        val bitmap = BitmapFactory.decodeByteArray(jpegBytes, 0, jpegBytes.size) ?: return listOf(-1.0, -1.0, -1.0, -1.0)

        // 1. ROTATE FIRST to orient upright
        // 2. FLIP HORIZONTALLY SECOND for front camera mirror
        val matrix = Matrix().apply {
            postRotate(rotation.toFloat())
            postScale(-1f, 1f, (bitmap.height / 2f), (bitmap.width / 2f))
        }
        val rotatedBitmap = Bitmap.createBitmap(bitmap, 0, 0, bitmap.width, bitmap.height, matrix, true)
        val mpImage = BitmapImageBuilder(rotatedBitmap).build()

        val detectionResult: HandLandmarkerResult = landmarker.detect(mpImage)

        var leftX = -1.0; var leftY = -1.0
        var rightX = -1.0; var rightY = -1.0

        val detectedHands = mutableListOf<Pair<Double, Double>>()

        for (landmarks in detectionResult.landmarks()) {
            val fist = landmarks.getOrNull(FIST_CENTER_LANDMARK) ?: continue
            detectedHands.add(Pair(fist.x().toDouble(), fist.y().toDouble()))
        }

        if (detectedHands.size == 1) {
            val (hx, hy) = detectedHands[0]
            if (hx < 0.5) {
                leftX = hx; leftY = hy
            } else {
                rightX = hx; rightY = hy
            }
        } else if (detectedHands.size >= 2) {
            detectedHands.sortBy { it.first }
            leftX = detectedHands[0].first
            leftY = detectedHands[0].second
            rightX = detectedHands[1].first
            rightY = detectedHands[1].second
        }

        return listOf(leftX, leftY, rightX, rightY)
    }

    fun destroy() {
        handLandmarker?.close()
        handLandmarker = null
        executor.shutdown()
    }
}
