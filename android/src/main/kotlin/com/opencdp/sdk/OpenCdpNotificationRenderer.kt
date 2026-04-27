package com.opencdp.sdk

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.os.Build
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat
import org.json.JSONArray
import org.json.JSONObject
import kotlin.math.abs

internal object OpenCdpNotificationRenderer {
    fun showActionableNotification(
        context: Context,
        data: Map<String, Any?>,
        channelName: String,
        channelDescription: String
    ): Boolean {
        val channelId = data["android_channel_id"]?.toString()?.ifBlank { "cdp_default" } ?: "cdp_default"
        val title = data["title"]?.toString()?.ifBlank { "New message" } ?: "New message"
        val body = data["body"]?.toString() ?: ""
        val payloadJson = JSONObject(data).toString()
        val deliveryMessageId = data["delivery_message_id"]?.toString().orEmpty()
        val notificationId = if (deliveryMessageId.isNotBlank()) {
            abs(deliveryMessageId.hashCode())
        } else {
            (System.currentTimeMillis() % Int.MAX_VALUE).toInt()
        }

        ensureChannel(context, channelId, channelName, channelDescription)

        val openIntent = Intent(context, OpenCdpNotificationActionReceiver::class.java).apply {
            action = OpenCdpNotificationContracts.ACTION_OPEN
            putExtra(OpenCdpNotificationContracts.EXTRA_PAYLOAD_JSON, payloadJson)
            putExtra(OpenCdpNotificationContracts.EXTRA_NOTIFICATION_ID, notificationId)
        }
        val openPendingIntent = PendingIntent.getBroadcast(
            context,
            notificationId,
            openIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        val smallIcon = if (context.applicationInfo.icon != 0) {
            context.applicationInfo.icon
        } else {
            android.R.drawable.ic_dialog_info
        }

        val builder = NotificationCompat.Builder(context, channelId)
            .setSmallIcon(smallIcon)
            .setContentTitle(title)
            .setContentText(body)
            .setPriority(NotificationCompat.PRIORITY_HIGH)
            .setAutoCancel(true)
            .setContentIntent(openPendingIntent)

        parseActions(data["actions"]).take(3).forEachIndexed { index, action ->
            val clickIntent = Intent(context, OpenCdpNotificationActionReceiver::class.java).apply {
                action = OpenCdpNotificationContracts.ACTION_CLICK
                putExtra(OpenCdpNotificationContracts.EXTRA_PAYLOAD_JSON, payloadJson)
                putExtra(OpenCdpNotificationContracts.EXTRA_ACTION_ID, action.actionId)
                putExtra(OpenCdpNotificationContracts.EXTRA_ACTION_LINK, action.link)
                putExtra(OpenCdpNotificationContracts.EXTRA_NOTIFICATION_ID, notificationId)
            }
            val clickPendingIntent = PendingIntent.getBroadcast(
                context,
                notificationId + index + 1,
                clickIntent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
            builder.addAction(0, action.label, clickPendingIntent)
        }

        NotificationManagerCompat.from(context).notify(notificationId, builder.build())
        return true
    }

    private fun ensureChannel(context: Context, channelId: String, channelName: String, channelDescription: String) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val manager = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        val existing = manager.getNotificationChannel(channelId)
        if (existing != null) return
        val channel = NotificationChannel(
            channelId,
            channelName,
            NotificationManager.IMPORTANCE_HIGH
        ).apply {
            description = channelDescription
        }
        manager.createNotificationChannel(channel)
    }

    private fun parseActions(raw: Any?): List<ActionItem> {
        val array = when (raw) {
            is String -> {
                val t = raw.trim()
                if (t.isEmpty()) return emptyList()
                try {
                    JSONArray(t)
                } catch (_: Throwable) {
                    return emptyList()
                }
            }
            is List<*> -> JSONArray(raw)
            else -> return emptyList()
        }

        val out = mutableListOf<ActionItem>()
        for (i in 0 until array.length()) {
            val item = array.optJSONObject(i) ?: continue
            val actionId = item.optString("action_id", "").trim()
            val label = item.optString("label", "").trim()
            if (actionId.isEmpty() || label.isEmpty()) continue
            val link = item.optString("link", "").trim().ifEmpty { null }
            out.add(ActionItem(actionId = actionId, label = label, link = link))
        }
        return out
    }

    private data class ActionItem(
        val actionId: String,
        val label: String,
        val link: String?
    )
}

