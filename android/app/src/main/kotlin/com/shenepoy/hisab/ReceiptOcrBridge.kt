package com.shenepoy.hisab

import android.content.Context
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.Canvas
import android.graphics.ColorMatrix
import android.graphics.ColorMatrixColorFilter
import android.graphics.Matrix
import android.graphics.Paint
import android.os.Handler
import android.os.Looper
import android.util.Log
import com.googlecode.tesseract.android.TessBaseAPI
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.FileOutputStream
import java.util.concurrent.Executors
import java.util.concurrent.atomic.AtomicBoolean
import kotlin.math.max

/**
 * MethodChannel bridge for on-device receipt OCR via Tesseract4Android.
 *
 * Registered by [MainActivity.configureFlutterEngine].
 */
object ReceiptOcrBridge {
    private const val TAG = "ReceiptOcrBridge"
    private const val METHOD_CHANNEL = "hisab/receipt_ocr"
    private const val LANGS = "eng+ara"
    private const val MIN_LONG_SIDE = 1800

    private val mainHandler = Handler(Looper.getMainLooper())
    private val executor = Executors.newSingleThreadExecutor()

    @Volatile
    private var tess: TessBaseAPI? = null

    @Volatile
    private var initializedLangs: String? = null

    private val cancelRequested = AtomicBoolean(false)

    fun register(engine: FlutterEngine, context: Context) {
        MethodChannel(engine.dartExecutor.binaryMessenger, METHOD_CHANNEL)
            .setMethodCallHandler { call, result -> handleMethod(call, result, context) }
    }

    private fun handleMethod(
        call: MethodCall,
        result: MethodChannel.Result,
        context: Context,
    ) {
        when (call.method) {
            "recognize" -> {
                val path = call.argument<String>("path")
                val languages = call.argument<String>("languages") ?: LANGS
                if (path.isNullOrBlank()) {
                    result.error("invalid_args", "Missing image path", null)
                    return
                }
                cancelRequested.set(false)
                executor.execute {
                    try {
                        val text = recognizeBlocking(context, path, languages)
                        mainHandler.post {
                            if (cancelRequested.get()) {
                                result.error("cancelled", "OCR cancelled", null)
                            } else {
                                result.success(text)
                            }
                        }
                    } catch (e: Exception) {
                        Log.e(TAG, "OCR failed", e)
                        mainHandler.post {
                            if (cancelRequested.get()) {
                                result.error("cancelled", "OCR cancelled", null)
                            } else {
                                result.error("ocr_failed", e.message, null)
                            }
                        }
                    }
                }
            }

            "cancel" -> {
                cancelRequested.set(true)
                try {
                    tess?.stop()
                } catch (e: Exception) {
                    Log.w(TAG, "stop() failed", e)
                }
                result.success(null)
            }

            else -> result.notImplemented()
        }
    }

    private fun recognizeBlocking(
        context: Context,
        path: String,
        languages: String,
    ): String {
        val dataPath = ensureTessdata(context)
        if (cancelRequested.get()) {
            throw CancellationException("cancelled")
        }
        val image = File(path)
        if (!image.isFile) {
            throw IllegalArgumentException("Image not found: $path")
        }

        // Build preprocessed variants (gray/contrast/upscale + 180° — receipts
        // are often photographed upside-down). Score across PSM × lang × image.
        val variants = buildPreprocessedVariants(context, image)
        try {
            val modes = intArrayOf(
                TessBaseAPI.PageSegMode.PSM_SINGLE_COLUMN,
                TessBaseAPI.PageSegMode.PSM_SINGLE_BLOCK,
                TessBaseAPI.PageSegMode.PSM_AUTO,
            )
            // eng alone often beats eng+ara on Latin KSA restaurant slips.
            val langPasses = linkedSetOf("eng", languages, "eng+ara")
            var best = ""
            var bestScore = -1
            // Stop early once we have store+total-like cues (keeps phone UX snappy).
            val goodEnough = 2500
            outer@ for (variant in variants) {
                if (cancelRequested.get()) {
                    throw CancellationException("cancelled")
                }
                for (lang in langPasses) {
                    if (cancelRequested.get()) {
                        throw CancellationException("cancelled")
                    }
                    val langApi = ensureApi(dataPath, lang)
                    for (mode in modes) {
                        if (cancelRequested.get()) {
                            throw CancellationException("cancelled")
                        }
                        langApi.pageSegMode = mode
                        langApi.setImage(variant)
                        val text = (langApi.getUTF8Text() ?: "").trim()
                        langApi.clear()
                        val score = scoreOcrText(text)
                        if (score > bestScore) {
                            bestScore = score
                            best = text
                        }
                        if (bestScore >= goodEnough) break@outer
                    }
                }
            }
            Log.i(TAG, "OCR best score=$bestScore chars=${best.length} variants=${variants.size}")
            return best
        } finally {
            for (f in variants) {
                if (f.absolutePath != image.absolutePath) {
                    f.delete()
                }
            }
        }
    }

    /**
     * Grayscale + contrast + optional upscale; also a 180° copy.
     * Returns PNG temps (lossless for Tess) plus the original as last resort.
     */
    private fun buildPreprocessedVariants(context: Context, source: File): List<File> {
        val decoded = decodeBitmap(source) ?: return listOf(source)
        val prepared = enhanceForOcr(decoded)
        val out = ArrayList<File>(3)
        try {
            out.add(writePng(context, prepared, "ocr0"))
            // Upside-down phone photos are common; cheap second pass.
            val flipped = rotateBitmap(prepared, 180f)
            out.add(writePng(context, flipped, "ocr180"))
            if (flipped !== prepared) flipped.recycle()
        } catch (e: Exception) {
            Log.w(TAG, "preprocess failed, using original", e)
        } finally {
            if (!decoded.isRecycled) decoded.recycle()
            if (!prepared.isRecycled && prepared !== decoded) prepared.recycle()
        }
        if (out.isEmpty()) out.add(source)
        return out
    }

    private fun decodeBitmap(file: File): Bitmap? {
        val bounds = BitmapFactory.Options().apply { inJustDecodeBounds = true }
        BitmapFactory.decodeFile(file.absolutePath, bounds)
        var sample = 1
        val longSide = max(bounds.outWidth, bounds.outHeight)
        // Cap decode RAM: aim ≤ ~2400 on long side.
        while (longSide / sample > 2800) {
            sample *= 2
        }
        val opts = BitmapFactory.Options().apply {
            inSampleSize = sample
            inPreferredConfig = Bitmap.Config.ARGB_8888
        }
        return BitmapFactory.decodeFile(file.absolutePath, opts)
    }

    private fun enhanceForOcr(src: Bitmap): Bitmap {
        var bmp = src
        val longSide = max(bmp.width, bmp.height)
        if (longSide in 1 until MIN_LONG_SIDE) {
            val scale = MIN_LONG_SIDE.toFloat() / longSide
            val w = (bmp.width * scale).toInt().coerceAtLeast(1)
            val h = (bmp.height * scale).toInt().coerceAtLeast(1)
            val scaled = Bitmap.createScaledBitmap(bmp, w, h, true)
            if (scaled !== bmp && bmp !== src) bmp.recycle()
            bmp = scaled
        }
        val out = Bitmap.createBitmap(bmp.width, bmp.height, Bitmap.Config.ARGB_8888)
        val canvas = Canvas(out)
        val paint = Paint(Paint.ANTI_ALIAS_FLAG or Paint.FILTER_BITMAP_FLAG)
        val gray = ColorMatrix().apply { setSaturation(0f) }
        // Mild contrast boost — helps faded thermal paper without crushing ink.
        val contrast = 1.35f
        val translate = (-0.5f * contrast + 0.5f) * 255f
        val contrastMatrix = ColorMatrix(
            floatArrayOf(
                contrast, 0f, 0f, 0f, translate,
                0f, contrast, 0f, 0f, translate,
                0f, 0f, contrast, 0f, translate,
                0f, 0f, 0f, 1f, 0f,
            ),
        )
        gray.postConcat(contrastMatrix)
        paint.colorFilter = ColorMatrixColorFilter(gray)
        canvas.drawBitmap(bmp, 0f, 0f, paint)
        if (bmp !== src && !bmp.isRecycled) bmp.recycle()
        return out
    }

    private fun rotateBitmap(src: Bitmap, degrees: Float): Bitmap {
        val m = Matrix().apply { postRotate(degrees) }
        return Bitmap.createBitmap(src, 0, 0, src.width, src.height, m, true)
    }

    private fun writePng(context: Context, bmp: Bitmap, tag: String): File {
        val file = File(context.cacheDir, "receipt_ocr_${tag}_${System.currentTimeMillis()}.png")
        FileOutputStream(file).use { fos ->
            bmp.compress(Bitmap.CompressFormat.PNG, 100, fos)
        }
        return file
    }

    /** Prefer text that looks like a receipt over merely the longest blob. */
    private fun scoreOcrText(text: String): Int {
        if (text.isEmpty()) return -1
        var score = (text.length / 2).coerceAtMost(2000)
        val lower = text.lowercase()
        for (kw in listOf(
            "total", "amount due", "amount to pay", "vat", "vta", "sst",
            "subtotal", "sub total", "invoice", "payment", "net ttl",
            "roadhouse", "familymart", "sushiart", "asian foods",
            "ضريبة", "إجمالي", "المبلغ", "فاتورة", "صافي",
        )) {
            if (lower.contains(kw)) score += 500
        }
        // Prefer real money amounts (xx.xx) over OCR junk.
        val moneyHits = Regex("""\d+[.,]\d{2}""").findAll(text).count()
        score += moneyHits * 80
        // Penalize dense Arabic mojibake-only blobs with almost no Latin/money.
        val latin = Regex("""[A-Za-z]{3,}""").findAll(text).count()
        if (latin == 0 && moneyHits < 2) score -= 800
        return score
    }

    @Synchronized
    private fun ensureApi(dataPath: String, languages: String): TessBaseAPI {
        val existing = tess
        if (existing != null && initializedLangs == languages) {
            return existing
        }
        existing?.recycle()
        tess = null
        initializedLangs = null

        val api = TessBaseAPI()
        if (!api.init(dataPath, languages)) {
            api.recycle()
            throw IllegalStateException("TessBaseAPI.init failed for $languages")
        }
        tess = api
        initializedLangs = languages
        return api
    }

    private fun ensureTessdata(context: Context): String {
        val root = context.filesDir
        val tessDir = File(root, "tessdata")
        if (!tessDir.exists() && !tessDir.mkdirs()) {
            throw IllegalStateException("Cannot create tessdata dir")
        }
        for (lang in listOf("eng", "ara")) {
            val out = File(tessDir, "$lang.traineddata")
            if (out.exists() && out.length() > 0L) continue
            val assetPath = "flutter_assets/assets/tessdata/$lang.traineddata"
            context.assets.open(assetPath).use { input ->
                FileOutputStream(out).use { output -> input.copyTo(output) }
            }
            Log.i(TAG, "Copied tessdata $lang (${out.length()} bytes)")
        }
        return root.absolutePath
    }

    private class CancellationException(message: String) : Exception(message)
}
