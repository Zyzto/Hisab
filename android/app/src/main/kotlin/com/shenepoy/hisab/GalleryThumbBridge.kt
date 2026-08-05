package com.shenepoy.hisab

import android.content.ContentUris
import android.content.Context
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.net.Uri
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.provider.MediaStore
import android.util.Log
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.ByteArrayOutputStream
import java.util.concurrent.Executors
import kotlin.math.max

/**
 * Returns a small JPEG of the most recent gallery image (MediaStore).
 *
 * Registered by [MainActivity.configureFlutterEngine].
 */
object GalleryThumbBridge {
    private const val TAG = "GalleryThumbBridge"
    private const val METHOD_CHANNEL = "hisab/gallery_thumb"
    private const val MAX_EDGE = 256

    private val mainHandler = Handler(Looper.getMainLooper())
    private val executor = Executors.newSingleThreadExecutor()

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
            "latestThumb" -> {
                executor.execute {
                    try {
                        val bytes = loadLatestThumb(context)
                        mainHandler.post { result.success(bytes) }
                    } catch (e: SecurityException) {
                        Log.w(TAG, "latestThumb permission denied", e)
                        mainHandler.post { result.success(null) }
                    } catch (e: Exception) {
                        Log.e(TAG, "latestThumb failed", e)
                        mainHandler.post {
                            result.error("gallery_thumb_failed", e.message, null)
                        }
                    }
                }
            }
            else -> result.notImplemented()
        }
    }

    private fun loadLatestThumb(context: Context): ByteArray? {
        val collection =
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                MediaStore.Images.Media.getContentUri(MediaStore.VOLUME_EXTERNAL)
            } else {
                MediaStore.Images.Media.EXTERNAL_CONTENT_URI
            }

        val uri = latestImageUri(context, collection) ?: return null
        val sample = decodeSampleSize(context, uri)
        val bitmap = context.contentResolver.openInputStream(uri)?.use { input ->
            val opts = BitmapFactory.Options().apply { inSampleSize = sample }
            BitmapFactory.decodeStream(input, null, opts)
        } ?: return null

        return try {
            val scaled = scaleDown(bitmap, MAX_EDGE)
            val out = ByteArrayOutputStream()
            scaled.compress(Bitmap.CompressFormat.JPEG, 82, out)
            if (scaled !== bitmap) scaled.recycle()
            out.toByteArray()
        } finally {
            bitmap.recycle()
        }
    }

    private fun latestImageUri(context: Context, collection: Uri): Uri? {
        val projection = arrayOf(MediaStore.Images.Media._ID)
        val sort = "${MediaStore.Images.Media.DATE_ADDED} DESC"
        context.contentResolver.query(
            collection,
            projection,
            null,
            null,
            sort,
        ).use { cursor ->
            if (cursor == null || !cursor.moveToFirst()) return null
            val idCol = cursor.getColumnIndexOrThrow(MediaStore.Images.Media._ID)
            return ContentUris.withAppendedId(collection, cursor.getLong(idCol))
        }
    }

    private fun decodeSampleSize(context: Context, uri: Uri): Int {
        val bounds = BitmapFactory.Options().apply { inJustDecodeBounds = true }
        context.contentResolver.openInputStream(uri)?.use { input ->
            BitmapFactory.decodeStream(input, null, bounds)
        }
        val longest = max(bounds.outWidth, bounds.outHeight)
        if (longest <= 0 || longest <= MAX_EDGE * 2) return 1
        var sample = 1
        while (longest / (sample * 2) >= MAX_EDGE) {
            sample *= 2
        }
        return sample
    }

    private fun scaleDown(src: Bitmap, maxEdge: Int): Bitmap {
        val longest = max(src.width, src.height)
        if (longest <= maxEdge) return src
        val scale = maxEdge.toFloat() / longest
        val w = max(1, (src.width * scale).toInt())
        val h = max(1, (src.height * scale).toInt())
        return Bitmap.createScaledBitmap(src, w, h, true)
    }
}
