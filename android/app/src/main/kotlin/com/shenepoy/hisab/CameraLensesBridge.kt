package com.shenepoy.hisab

import android.content.Context
import android.hardware.camera2.CameraCharacteristics
import android.hardware.camera2.CameraManager
import android.os.Build
import android.util.Log
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import kotlin.math.atan
import kotlin.math.hypot

/**
 * Exposes Camera2 lens metadata so Flutter can pick Samsung-style front
 * wide vs 1× cameras (separate IDs with different sensor crops / FOV).
 *
 * Registered by [MainActivity.configureFlutterEngine].
 */
object CameraLensesBridge {
    private const val TAG = "CameraLensesBridge"
    private const val METHOD_CHANNEL = "hisab/camera_lenses"

    fun register(engine: FlutterEngine, context: Context) {
        MethodChannel(engine.dartExecutor.binaryMessenger, METHOD_CHANNEL)
            .setMethodCallHandler { call, result -> handle(call, result, context) }
    }

    private fun handle(
        call: MethodCall,
        result: MethodChannel.Result,
        context: Context,
    ) {
        when (call.method) {
            "listLenses" -> {
                try {
                    result.success(listLenses(context))
                } catch (e: Exception) {
                    Log.w(TAG, "listLenses failed", e)
                    result.error("lens_error", e.message, null)
                }
            }
            else -> result.notImplemented()
        }
    }

    private fun listLenses(context: Context): List<Map<String, Any>> {
        val manager = context.getSystemService(Context.CAMERA_SERVICE) as CameraManager
        val out = ArrayList<Map<String, Any>>()
        for (id in manager.cameraIdList) {
            val chars = manager.getCameraCharacteristics(id)
            val facing = chars.get(CameraCharacteristics.LENS_FACING) ?: continue
            val facingStr = when (facing) {
                CameraCharacteristics.LENS_FACING_FRONT -> "front"
                CameraCharacteristics.LENS_FACING_BACK -> "back"
                CameraCharacteristics.LENS_FACING_EXTERNAL -> "external"
                else -> continue
            }

            val focals =
                chars.get(CameraCharacteristics.LENS_INFO_AVAILABLE_FOCAL_LENGTHS)
            val focal = focals?.firstOrNull()?.toDouble() ?: 0.0
            val sensor = chars.get(CameraCharacteristics.SENSOR_INFO_PHYSICAL_SIZE)
            val sensorW = sensor?.width?.toDouble() ?: 0.0
            val sensorH = sensor?.height?.toDouble() ?: 0.0

            var minZoom = 1.0
            var maxZoom = 1.0
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
                val range = chars.get(CameraCharacteristics.CONTROL_ZOOM_RATIO_RANGE)
                if (range != null) {
                    minZoom = range.lower.toDouble()
                    maxZoom = range.upper.toDouble()
                }
            } else {
                val maxDigital =
                    chars.get(CameraCharacteristics.SCALER_AVAILABLE_MAX_DIGITAL_ZOOM)
                if (maxDigital != null && maxDigital > 1f) {
                    maxZoom = maxDigital.toDouble()
                }
            }

            // Horizontal FOV (degrees) from sensor width + focal length.
            val hfovDeg =
                if (focal > 0.01 && sensorW > 0.01) {
                    Math.toDegrees(2.0 * atan(sensorW / (2.0 * focal)))
                } else {
                    0.0
                }
            val diagMm = hypot(sensorW, sensorH)

            out.add(
                mapOf(
                    "id" to id,
                    "facing" to facingStr,
                    "minZoom" to minZoom,
                    "maxZoom" to maxZoom,
                    "focalMm" to focal,
                    "sensorWmm" to sensorW,
                    "sensorHmm" to sensorH,
                    "sensorDiagMm" to diagMm,
                    "hfovDeg" to hfovDeg,
                ),
            )
        }
        return out
    }
}
