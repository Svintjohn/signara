package com.signara.landmarks

import android.app.Activity
import android.content.Context
import android.graphics.Bitmap
import android.graphics.Matrix
import android.os.Handler
import android.os.Looper
import android.os.SystemClock
import android.util.Size
import android.view.Surface
import androidx.camera.core.CameraSelector
import androidx.camera.core.ImageAnalysis
import androidx.camera.core.ImageProxy
import androidx.camera.core.Preview
import androidx.camera.lifecycle.ProcessCameraProvider
import androidx.core.content.ContextCompat
import androidx.lifecycle.LifecycleOwner
import com.google.mediapipe.framework.image.BitmapImageBuilder
import com.google.mediapipe.tasks.core.BaseOptions
import com.google.mediapipe.tasks.vision.core.RunningMode
import com.google.mediapipe.tasks.vision.handlandmarker.HandLandmarker
import com.google.mediapipe.tasks.vision.handlandmarker.HandLandmarkerResult
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.view.TextureRegistry
import java.util.concurrent.ExecutorService
import java.util.concurrent.Executors

/**
 * Camera preview goes to Flutter as a Texture. Hand landmarks go over an
 * EventChannel. Camera frames never cross into Dart.
 *
 * UNTESTED: written without an Android toolchain. Expect small compile fixes.
 *
 * Needs `hand_landmarker.task` in the APP's android/app/src/main/assets/.
 */
class SignaraLandmarksPlugin :
    FlutterPlugin,
    MethodChannel.MethodCallHandler,
    EventChannel.StreamHandler,
    ActivityAware {

    private lateinit var appContext: Context
    private lateinit var textures: TextureRegistry
    private lateinit var methods: MethodChannel
    private lateinit var events: EventChannel

    private var activity: Activity? = null
    private var sink: EventChannel.EventSink? = null
    private val main = Handler(Looper.getMainLooper())

    private var executor: ExecutorService? = null
    private var provider: ProcessCameraProvider? = null
    private var textureEntry: TextureRegistry.SurfaceTextureEntry? = null
    private var landmarker: HandLandmarker? = null

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        appContext = binding.applicationContext
        textures = binding.textureRegistry
        methods = MethodChannel(binding.binaryMessenger, "signara_landmarks/methods")
        events = EventChannel(binding.binaryMessenger, "signara_landmarks/events")
        methods.setMethodCallHandler(this)
        events.setStreamHandler(this)
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        stopCamera()
        methods.setMethodCallHandler(null)
        events.setStreamHandler(null)
    }

    override fun onAttachedToActivity(binding: ActivityPluginBinding) {
        activity = binding.activity
    }

    override fun onDetachedFromActivityForConfigChanges() {
        activity = null
    }

    override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) {
        activity = binding.activity
    }

    override fun onDetachedFromActivity() {
        activity = null
    }

    override fun onListen(arguments: Any?, eventSink: EventChannel.EventSink?) {
        sink = eventSink
    }

    override fun onCancel(arguments: Any?) {
        sink = null
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "start" -> {
                val front = call.argument<Boolean>("front") ?: false
                val w = call.argument<Int>("width") ?: 640
                val h = call.argument<Int>("height") ?: 480
                startCamera(front, w, h, result)
            }
            "stop" -> {
                stopCamera()
                result.success(null)
            }
            else -> result.notImplemented()
        }
    }

    private fun startCamera(front: Boolean, w: Int, h: Int, result: MethodChannel.Result) {
        val act = activity
        val owner = act as? LifecycleOwner
        if (act == null || owner == null) {
            result.error("NO_ACTIVITY", "Activity is not a LifecycleOwner", null)
            return
        }
        stopCamera()

        try {
            landmarker = createLandmarker()
        } catch (e: Exception) {
            result.error("MODEL", "Could not load hand_landmarker.task: ${e.message}", null)
            return
        }

        val entry = textures.createSurfaceTexture()
        textureEntry = entry
        val exec = Executors.newSingleThreadExecutor()
        executor = exec

        val future = ProcessCameraProvider.getInstance(act)
        future.addListener({
            try {
                val cp = future.get()
                provider = cp

                val preview = Preview.Builder()
                    .setTargetResolution(Size(w, h))
                    .build()
                preview.setSurfaceProvider { request ->
                    val res = request.resolution
                    entry.surfaceTexture().setDefaultBufferSize(res.width, res.height)
                    val surface = Surface(entry.surfaceTexture())
                    request.provideSurface(surface, ContextCompat.getMainExecutor(act)) {
                        surface.release()
                    }
                }

                val analysis = ImageAnalysis.Builder()
                    .setTargetResolution(Size(w, h))
                    .setBackpressureStrategy(ImageAnalysis.STRATEGY_KEEP_ONLY_LATEST)
                    .setOutputImageFormat(ImageAnalysis.OUTPUT_IMAGE_FORMAT_RGBA_8888)
                    .build()
                analysis.setAnalyzer(exec) { proxy -> analyze(proxy) }

                val selector = if (front) {
                    CameraSelector.DEFAULT_FRONT_CAMERA
                } else {
                    CameraSelector.DEFAULT_BACK_CAMERA
                }

                cp.unbindAll()
                cp.bindToLifecycle(owner, selector, preview, analysis)
                result.success(entry.id())
            } catch (e: Exception) {
                result.error("CAMERA", e.message, null)
            }
        }, ContextCompat.getMainExecutor(act))
    }

    private fun createLandmarker(): HandLandmarker {
        val base = BaseOptions.builder()
            .setModelAssetPath("hand_landmarker.task")
            .build()
        val options = HandLandmarker.HandLandmarkerOptions.builder()
            .setBaseOptions(base)
            .setRunningMode(RunningMode.LIVE_STREAM)
            .setNumHands(2)
            .setResultListener { r, _ -> onResult(r) }
            .setErrorListener { e ->
                main.post { sink?.error("LANDMARKER", e.message, null) }
            }
            .build()
        return HandLandmarker.createFromOptions(appContext, options)
    }

    private fun analyze(proxy: ImageProxy) {
        try {
            val bmp = proxy.toBitmap()
            val deg = proxy.imageInfo.rotationDegrees
            val upright = if (deg != 0) {
                val m = Matrix().apply { postRotate(deg.toFloat()) }
                Bitmap.createBitmap(bmp, 0, 0, bmp.width, bmp.height, m, true)
            } else {
                bmp
            }
            landmarker?.detectAsync(
                BitmapImageBuilder(upright).build(),
                SystemClock.uptimeMillis()
            )
        } finally {
            proxy.close()
        }
    }

    private fun onResult(r: HandLandmarkerResult) {
        val hands = r.landmarks().mapIndexed { i, points ->
            val label = r.handedness().getOrNull(i)?.firstOrNull()?.categoryName() ?: "?"
            mapOf(
                "handedness" to label,
                "xyz" to points.flatMap {
                    listOf(it.x().toDouble(), it.y().toDouble(), it.z().toDouble())
                }
            )
        }
        val payload = mapOf(
            "ts" to r.timestampMs(),
            "inferMs" to (SystemClock.uptimeMillis() - r.timestampMs()),
            "hands" to hands
        )
        main.post { sink?.success(payload) }
    }

    private fun stopCamera() {
        provider?.unbindAll()
        provider = null
        landmarker?.close()
        landmarker = null
        executor?.shutdown()
        executor = null
        textureEntry?.release()
        textureEntry = null
    }
}
