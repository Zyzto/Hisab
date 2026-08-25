package com.shenepoy.hisab

import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Handler
import android.os.Looper
import android.provider.Settings
import android.util.Log
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/**
 * MethodChannel + EventChannel bridge between the native
 * [TransactionNotificationListener] and Flutter.
 *
 * Registered by [MainActivity.configureFlutterEngine].
 */
object NotificationBridge {

    private const val TAG = "NotificationBridge"
    private const val METHOD_CHANNEL = "com.shenepoy.hisab/scanner"
    private const val EVENT_CHANNEL = "com.shenepoy.hisab/scanner_events"

    private val SUGGESTED_SCANNER_PACKAGES = arrayOf(
        "sa.com.stcpay",
        "com.alrajhibank.retail",
        "com.alahli.mobile",
        "com.riyadbank.mobile",
        "com.anb.mobile",
        "com.sabb.mobile",
        "com.bsf.retail",
        "com.albilad",
        "com.alinma",
        "com.emiratesnbd.android",
        "com.adcb.bank",
        "ae.hsbc.hsbcmobilebanking",
        "com.google.android.apps.nbu.paisa.user",
        "com.phonepe.app",
        "net.one97.paytm",
        "com.paypal.android.p2pmobile",
        "com.revolut.revolut",
        "com.wise.android",
        "com.google.android.apps.messaging",
        "com.samsung.android.messaging",
        "com.android.mms",
        "com.google.android.gm",
    )

    @Volatile
    private var eventSink: EventChannel.EventSink? = null
    private val mainHandler = Handler(Looper.getMainLooper())

    fun register(engine: FlutterEngine, context: Context) {
        MethodChannel(engine.dartExecutor.binaryMessenger, METHOD_CHANNEL)
            .setMethodCallHandler { call, result -> handleMethod(call, result, context) }

        EventChannel(engine.dartExecutor.binaryMessenger, EVENT_CHANNEL)
            .setStreamHandler(object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                    eventSink = events
                }

                override fun onCancel(arguments: Any?) {
                    eventSink = null
                }
            })
    }

    /** Called by [TransactionNotificationListener] when a new notification is captured. */
    fun onNewNotification(context: Context) {
        mainHandler.post { eventSink?.success("new_notification") }
    }

    private fun handleMethod(call: MethodCall, result: MethodChannel.Result, context: Context) {
        when (call.method) {
            "isListenerEnabled" -> {
                result.success(isNotificationListenerEnabled(context))
            }

            "openListenerSettings" -> {
                val intent = Intent(Settings.ACTION_NOTIFICATION_LISTENER_SETTINGS)
                intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                context.startActivity(intent)
                result.success(null)
            }

            "setEnabled" -> {
                val enabled = call.argument<Boolean>("enabled") ?: false
                val prefs = context.getSharedPreferences(
                    TransactionNotificationListener.PREFS_NAME, Context.MODE_PRIVATE
                )
                prefs.edit().putBoolean(TransactionNotificationListener.KEY_ENABLED, enabled).apply()
                result.success(null)
            }

            "setSenders" -> {
                val senders = call.argument<List<String>>("senders") ?: emptyList()
                val prefs = context.getSharedPreferences(
                    TransactionNotificationListener.PREFS_NAME, Context.MODE_PRIVATE
                )
                prefs.edit().putStringSet(
                    TransactionNotificationListener.KEY_SENDERS, senders.toSet()
                ).apply()
                result.success(null)
            }

            "setRequireSenders" -> {
                val require = call.argument<Boolean>("require") ?: false
                val prefs = context.getSharedPreferences(
                    TransactionNotificationListener.PREFS_NAME, Context.MODE_PRIVATE
                )
                prefs.edit().putBoolean(
                    TransactionNotificationListener.KEY_REQUIRE_SENDERS, require
                ).apply()
                result.success(null)
            }

            "listInstalledApps" -> {
                result.success(listInstalledApps(context))
            }

            "getPendingNotifications" -> {
                result.success(getPending(context))
            }

            "markFlushed" -> {
                val ids = call.argument<List<Int>>("ids") ?: emptyList()
                markFlushed(context, ids)
                result.success(null)
            }

            "clearAll" -> {
                val db = NotificationDbHelper.getInstance(context).writableDatabase
                db.delete("captured_notifications", null, null)
                result.success(null)
            }

            else -> result.notImplemented()
        }
    }

    private fun listInstalledApps(context: Context): List<Map<String, Any?>> {
        val pm = context.packageManager
        val seen = HashSet<String>()
        val out = mutableListOf<Map<String, Any?>>()

        fun add(pkg: String, label: String) {
            if (!seen.add(pkg)) return
            out.add(mapOf("package" to pkg, "label" to label))
        }

        val intent = Intent(Intent.ACTION_MAIN).addCategory(Intent.CATEGORY_LAUNCHER)
        val resolved = pm.queryIntentActivities(intent, PackageManager.MATCH_DEFAULT_ONLY)
        for (info in resolved) {
            val pkg = info.activityInfo?.applicationInfo?.packageName ?: continue
            val label = try {
                info.loadLabel(pm)?.toString() ?: pkg
            } catch (_: Exception) {
                pkg
            }
            add(pkg, label)
        }

        // Bank / SMS packages may lack a launcher icon. Resolve them directly
        // when the manifest <queries> list makes them visible.
        for (pkg in SUGGESTED_SCANNER_PACKAGES) {
            try {
                val app = pm.getApplicationInfo(pkg, 0)
                val label = pm.getApplicationLabel(app)?.toString() ?: pkg
                add(pkg, label)
            } catch (_: Exception) {
                // Not installed or not visible to this package.
            }
        }

        out.sortBy { (it["label"] as? String)?.lowercase() ?: "" }
        return out
    }

    private fun isNotificationListenerEnabled(context: Context): Boolean {
        val cn = ComponentName(context, TransactionNotificationListener::class.java)
        val flat = Settings.Secure.getString(
            context.contentResolver, "enabled_notification_listeners"
        ) ?: return false
        val target = cn.flattenToString()
        return flat.split(":").any { it.trim() == target }
    }

    private fun getPending(context: Context): List<Map<String, Any?>> {
        val db = NotificationDbHelper.getInstance(context).readableDatabase
        val cursor = db.rawQuery(
            "SELECT id, sender_package, sender_title, body, posted_at, captured_at FROM captured_notifications WHERE is_flushed = 0 ORDER BY captured_at ASC LIMIT 200",
            null
        )
        val results = mutableListOf<Map<String, Any?>>()
        cursor.use {
            while (it.moveToNext()) {
                results.add(
                    mapOf(
                        "id" to it.getInt(0),
                        "sender_package" to it.getString(1),
                        "sender_title" to it.getString(2),
                        "body" to it.getString(3),
                        "posted_at" to it.getLong(4),
                        "captured_at" to it.getLong(5),
                    )
                )
            }
        }
        return results
    }

    private fun markFlushed(context: Context, ids: List<Int>) {
        if (ids.isEmpty()) return
        val db = NotificationDbHelper.getInstance(context).writableDatabase
        val placeholders = ids.joinToString(",") { "?" }
        db.execSQL(
            "UPDATE captured_notifications SET is_flushed = 1 WHERE id IN ($placeholders)",
            ids.map { it.toString() }.toTypedArray()
        )
    }
}
