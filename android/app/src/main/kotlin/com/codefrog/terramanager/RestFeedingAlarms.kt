package com.codefrog.terramanager

import android.app.AlarmManager
import android.app.Notification
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.Build
import org.json.JSONObject

internal data class RestFeedingAlarm(
    val at: Long,
    val pauseFrom: Long,
    val pauseUntil: Long,
    val body: String,
    val payload: String,
) {
    fun deliveryAt(now: Long): Long {
        val candidate = maxOf(at, now)
        return if (candidate >= pauseFrom && candidate < pauseUntil) pauseUntil else candidate
    }

    fun encode(): String = JSONObject()
        .put("at", at)
        .put("pauseFrom", pauseFrom)
        .put("pauseUntil", pauseUntil)
        .put("body", body)
        .put("payload", payload)
        .toString()

    companion object {
        fun decode(value: String): RestFeedingAlarm {
            val json = JSONObject(value)
            return RestFeedingAlarm(
                json.getLong("at"),
                json.getLong("pauseFrom"),
                json.getLong("pauseUntil"),
                json.getString("body"),
                json.getString("payload"),
            )
        }
    }
}

/** Delivers one-shot alerts with a rest window even when Flutter is stopped. */
internal object RestFeedingAlarms {
    private const val preferences = "rest_feeding_alarms"
    private const val notificationId = "id"
    private const val notificationChannel = "feeding_reminders_v1"
    const val openAction = "com.codefrog.terramanager.OPEN_REST_FEEDING_ALARM"
    const val openPayload = "feedingAlarmPayload"

    private fun store(context: Context) =
        context.getSharedPreferences(preferences, Context.MODE_PRIVATE)

    fun pendingIds(context: Context): List<Int> =
        store(context).all.keys.mapNotNull { it.toIntOrNull() }

    private fun load(context: Context, id: Int): RestFeedingAlarm? =
        store(context).getString(id.toString(), null)?.let { stored ->
            runCatching { RestFeedingAlarm.decode(stored) }.getOrNull()
        }

    private fun alarmManager(context: Context): AlarmManager =
        requireNotNull(context.getSystemService(AlarmManager::class.java))

    private fun pendingIntent(context: Context, id: Int): PendingIntent =
        PendingIntent.getBroadcast(
            context,
            id,
            Intent(context, RestFeedingAlarmReceiver::class.java).putExtra(notificationId, id),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )

    private fun arm(context: Context, id: Int, at: Long) {
        alarmManager(context).setAndAllowWhileIdle(
            AlarmManager.RTC_WAKEUP, at, pendingIntent(context, id),
        )
    }

    fun schedule(context: Context, id: Int, alarm: RestFeedingAlarm) {
        require(id > 0 && alarm.pauseFrom < alarm.pauseUntil)
        val prefs = store(context)
        val key = id.toString()
        val previous = prefs.getString(key, null)
        check(prefs.edit().putString(key, alarm.encode()).commit())
        try {
            arm(context, id, alarm.deliveryAt(System.currentTimeMillis() + 1000))
        } catch (error: RuntimeException) {
            prefs.edit().putString(key, previous).commit()
            throw error
        }
    }

    fun cancel(context: Context, id: Int) {
        check(store(context).edit().remove(id.toString()).commit())
        cancelAlarm(context, id)
    }

    fun cancelAll(context: Context) {
        val ids = pendingIds(context)
        check(store(context).edit().clear().commit())
        ids.forEach { cancelAlarm(context, it) }
    }

    private fun cancelAlarm(context: Context, id: Int) {
        val intent = pendingIntent(context, id)
        alarmManager(context).cancel(intent)
        intent.cancel()
    }

    fun restore(context: Context) {
        val now = System.currentTimeMillis() + 1000
        for (id in pendingIds(context)) {
            val alarm = load(context, id) ?: continue
            arm(context, id, alarm.deliveryAt(now))
        }
    }

    fun deliver(context: Context, intent: Intent) {
        val id = intent.getIntExtra(notificationId, 0)
        val alarm = load(context, id) ?: return
        val now = System.currentTimeMillis()
        val at = alarm.deliveryAt(now)
        if (at > now) {
            // Inexact alarms due before the pause may be delivered inside it.
            arm(context, id, at)
            return
        }
        if (!store(context).edit().remove(id.toString()).commit()) return

        val open = PendingIntent.getActivity(
            context,
            id,
            Intent(context, MainActivity::class.java)
                .setAction(openAction)
                .addFlags(Intent.FLAG_ACTIVITY_CLEAR_TOP or Intent.FLAG_ACTIVITY_SINGLE_TOP)
                .putExtra(openPayload, alarm.payload),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
        @Suppress("DEPRECATION")
        val notification = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            Notification.Builder(context, notificationChannel)
        } else {
            Notification.Builder(context)
        }
        try {
            requireNotNull(context.getSystemService(NotificationManager::class.java)).notify(
                id,
                notification
                    .setSmallIcon(R.drawable.ic_feeding_notification)
                    .setContentTitle("TerraManager")
                    .setContentText(alarm.body)
                    .setVisibility(Notification.VISIBILITY_PRIVATE)
                    .setContentIntent(open)
                    .setAutoCancel(true)
                    .build(),
            )
        } catch (_: SecurityException) {
            // Notification permission may have been revoked after scheduling.
        }
    }
}

class RestFeedingAlarmReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) =
        RestFeedingAlarms.deliver(context, intent)
}

class RestFeedingBootReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) =
        RestFeedingAlarms.restore(context)
}
