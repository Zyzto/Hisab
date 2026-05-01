package com.shenepoy.hisab

import android.content.ContentValues
import android.content.Context
import android.content.Intent
import android.database.sqlite.SQLiteDatabase
import android.database.sqlite.SQLiteOpenHelper
import android.service.notification.NotificationListenerService
import android.service.notification.StatusBarNotification
import android.util.Log

/**
 * Captures transaction-related notifications from whitelisted senders.
 *
 * Runs as a system service — persists even when the app is killed.
 * Stores captured notifications in a lightweight SQLite database that
 * the Flutter MethodChannel bridge reads on app resume.
 */
class TransactionNotificationListener : NotificationListenerService() {

    companion object {
        private const val TAG = "TxnNotifListener"
        const val PREFS_NAME = "scanner_prefs"
        const val KEY_ENABLED = "scanner_enabled"
        const val KEY_SENDERS = "scanner_senders"
    }

    override fun onNotificationPosted(sbn: StatusBarNotification?) {
        if (sbn == null) return
        val prefs = getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        if (!prefs.getBoolean(KEY_ENABLED, false)) return

        val pkg = sbn.packageName ?: return
        val allowedSenders = prefs.getStringSet(KEY_SENDERS, emptySet()) ?: emptySet()

        // If whitelist is non-empty, only capture from listed packages.
        if (allowedSenders.isNotEmpty() && pkg !in allowedSenders) return

        val extras = sbn.notification?.extras ?: return
        val title = extras.getCharSequence("android.title")?.toString() ?: ""
        val text = extras.getCharSequence("android.text")?.toString() ?: ""
        val bigText = extras.getCharSequence("android.bigText")?.toString() ?: ""

        val body = bigText.ifEmpty { text }
        if (body.isBlank()) return

        // Quick heuristic: skip if no digits at all (no amount to extract).
        if (!body.any { it.isDigit() }) return

        Log.d(TAG, "Captured notification from $pkg: ${body.take(80)}...")

        val db = NotificationDbHelper.getInstance(this).writableDatabase
        val values = ContentValues().apply {
            put("sender_package", pkg)
            put("sender_title", title)
            put("body", body)
            put("posted_at", sbn.postTime)
            put("captured_at", System.currentTimeMillis())
            put("is_flushed", 0)
        }
        db.insert("captured_notifications", null, values)

        // Notify Flutter if engine is alive.
        NotificationBridge.onNewNotification(this)
    }

    override fun onNotificationRemoved(sbn: StatusBarNotification?) {
        // No-op: we don't care when notifications are dismissed.
    }
}

/**
 * Lightweight SQLite database for queuing captured notifications.
 * Read by [NotificationBridge] when Flutter requests pending items.
 */
class NotificationDbHelper private constructor(context: Context) :
    SQLiteOpenHelper(context, DB_NAME, null, DB_VERSION) {

    companion object {
        private const val DB_NAME = "scanner_notifications.db"
        private const val DB_VERSION = 1

        @Volatile
        private var instance: NotificationDbHelper? = null

        fun getInstance(context: Context): NotificationDbHelper {
            return instance ?: synchronized(this) {
                instance ?: NotificationDbHelper(context.applicationContext).also {
                    instance = it
                }
            }
        }
    }

    override fun onCreate(db: SQLiteDatabase) {
        db.execSQL(
            """
            CREATE TABLE captured_notifications (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                sender_package TEXT NOT NULL,
                sender_title TEXT,
                body TEXT NOT NULL,
                posted_at INTEGER NOT NULL,
                captured_at INTEGER NOT NULL,
                is_flushed INTEGER NOT NULL DEFAULT 0
            )
            """.trimIndent()
        )
    }

    override fun onUpgrade(db: SQLiteDatabase, oldVersion: Int, newVersion: Int) {
        // Future migrations go here.
    }
}
