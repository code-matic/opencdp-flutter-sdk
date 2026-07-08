package com.opencdp.sdk

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.graphics.Bitmap
import android.os.Build
import android.util.Log
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat
import androidx.core.graphics.drawable.IconCompat
import org.json.JSONArray
import org.json.JSONObject
import kotlin.math.abs

internal object OpenCdpNotificationRenderer {
    private const val TAG = "OpenCdpPush"

    /**
     * Renders and posts an actionable notification.
     *
     * IMPORTANT (threading): this function performs synchronous network I/O
     * (image + action-icon downloads) and must NOT be called from the main
     * thread. If invoked from FirebaseMessagingService#onMessageReceived,
     * wrap the call site in goAsync() + a background dispatcher/coroutine,
     * or dispatch through WorkManager, so it doesn't run on FCM's main
     * thread or blow past the ~10s background execution budget.
     */
    fun showActionableNotification(
        context: Context,
        data: Map<String, Any?>,
        channelName: String,
        channelDescription: String
    ): Boolean {
        // --- Runtime permission check (Android 13+) ---
        if (!NotificationManagerCompat.from(context).areNotificationsEnabled()) {
            Log.w(TAG, "showActionableNotification: notifications are disabled for this app, skipping post")
            return false
        }

        val channelId = data["android_channel_id"]?.toString()?.ifBlank { "cdp_default" } ?: "cdp_default"
        val title = data["title"]?.toString()?.ifBlank { "New message" } ?: "New message"
        val body = data["body"]?.toString() ?: ""
        val payloadJson = JSONObject(data).toString()
        val deliveryMessageId = data["delivery_message_id"]?.toString().orEmpty()

        // safeAbs guards against Int.MIN_VALUE, whose abs() overflows back to itself.
        val notificationId = if (deliveryMessageId.isNotBlank()) {
            safeAbs(deliveryMessageId.hashCode())
        } else {
            safeAbs((System.currentTimeMillis() % Int.MAX_VALUE).toInt())
        }

        Log.d(
            TAG,
            "showActionableNotification: title=$title body=$body channelId=$channelId " +
                "notificationId=$notificationId image_url=${data["image_url"]} " +
                "delivery_message_id=$deliveryMessageId",
        )

        ensureChannel(context, channelId, channelName, channelDescription)
        cancelHybridFcmDuplicates(context, title, body, deliveryMessageId)

        val openIntent = Intent(context, OpenCdpNotificationActionReceiver::class.java).apply {
            setAction(OpenCdpNotificationContracts.ACTION_OPEN)
            putExtra(OpenCdpNotificationContracts.EXTRA_PAYLOAD_JSON, payloadJson)
            putExtra(OpenCdpNotificationContracts.EXTRA_NOTIFICATION_ID, notificationId)
        }
        // Distinct request-code namespace (see below) so this never collides
        // with per-action PendingIntents for a *different* notificationId.
        val openPendingIntent = PendingIntent.getBroadcast(
            context,
            requestCode(notificationId, slot = 0),
            openIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        // NOTE: applicationInfo.icon is the full-color launcher icon. Status-bar
        // small icons are supposed to be a flat white/transparent silhouette
        // (API 21+ guideline) or it commonly renders as a gray/white blob on
        // stock Android. Prefer a dedicated monochrome drawable resource, e.g.:
        //   R.drawable.ic_stat_notify
        // Falling back to applicationInfo.icon only if the SDK truly has no
        // notification-specific icon resource available.
        val smallIcon = resolveSmallIcon(context)

        val builder = NotificationCompat.Builder(context, channelId)
            .setSmallIcon(smallIcon)
            .setContentTitle(title)
            .setContentText(body)
            .setPriority(NotificationCompat.PRIORITY_HIGH)
            .setAutoCancel(true)
            .setContentIntent(openPendingIntent)

        OpenCdpNotificationImage.parseImageUrl(data["image_url"])?.let { imageUrl ->
            val fullBitmap = OpenCdpNotificationImage.downloadBitmap(imageUrl)
            if (fullBitmap == null) {
                Log.w(TAG, "image download failed or returned null for url=$imageUrl notificationId=$notificationId")
            } else {
                val thumbnail = OpenCdpNotificationImage.createSquareThumbnail(fullBitmap, 256)
                Log.d(TAG, "bigPicture applied for notificationId=$notificationId")

                val style = NotificationCompat.BigPictureStyle()
                    .bigPicture(fullBitmap)
                    // Hide the large icon when expanded — bigPicture fills that space.
                    .bigLargeIcon(null as Bitmap?)
                    .setSummaryText(body)

                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                    // API 31+: promote big picture as right-side thumbnail when collapsed;
                    // setSmallIcon keeps the app icon in the header on the left.
                    style.showBigPictureWhenCollapsed(true)
                } else {
                    // API 24–30: platform cannot place big-picture thumbnail on the right.
                    // Fallback: left-side preview via largeIcon.
                    builder.setLargeIcon(thumbnail)
                }

                builder.setStyle(style)
                // Do NOT recycle fullBitmap/thumbnail after notify() returns.
                // notify() marshals bigPicture synchronously across the Binder call,
                // but collapsed-state bitmaps are commonly rendered lazily by SystemUI
                // on some OEM skins — recycling races that lazy read. Let GC reclaim.
            }
        }

        val actions = parseActions(data["actions"])
        Log.d(TAG, "action buttons count=${actions.size} for notificationId=$notificationId")
        actions.take(3).forEachIndexed { index, actionItem ->
            val clickIntent = Intent(context, OpenCdpNotificationActionReceiver::class.java).apply {
                setAction(OpenCdpNotificationContracts.ACTION_CLICK)
                putExtra(OpenCdpNotificationContracts.EXTRA_PAYLOAD_JSON, payloadJson)
                putExtra(OpenCdpNotificationContracts.EXTRA_ACTION_ID, actionItem.actionId)
                putExtra(OpenCdpNotificationContracts.EXTRA_ACTION_LINK, actionItem.link)
                putExtra(OpenCdpNotificationContracts.EXTRA_NOTIFICATION_ID, notificationId)
            }
            // slot = index + 1 keeps this in the same per-notification request-code
            // namespace as openPendingIntent (slot 0), so it can never collide with
            // another notification's base id or another notification's actions.
            val clickPendingIntent = PendingIntent.getBroadcast(
                context,
                requestCode(notificationId, slot = index + 1),
                clickIntent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )

            val iconBitmap = actionItem.iconUrl?.let { iconUrl ->
                OpenCdpNotificationImage.parseImageUrl(iconUrl)?.let { normalizedUrl ->
                    val bmp = OpenCdpNotificationImage.downloadScaledBitmap(normalizedUrl, 128)
                    if (bmp == null) {
                        Log.w(TAG, "action icon download failed for url=$normalizedUrl notificationId=$notificationId")
                    }
                    bmp
                }
            }

            if (iconBitmap != null) {
                val action = NotificationCompat.Action.Builder(
                    IconCompat.createWithBitmap(iconBitmap),
                    actionItem.label,
                    clickPendingIntent,
                ).build()
                builder.addAction(action)
            } else {
                builder.addAction(0, actionItem.label, clickPendingIntent)
            }
        }

        val notification = builder.build()
        val nm = NotificationManagerCompat.from(context)
        try {
            if (deliveryMessageId.isNotBlank()) {
                nm.notify(deliveryMessageId, notificationId, notification)
            } else {
                nm.notify(notificationId, notification)
            }
            Log.d(
                TAG,
                "notification posted id=$notificationId tag=${deliveryMessageId.ifBlank { null }}",
            )
        } catch (e: SecurityException) {
            Log.w(TAG, "notification post failed (permission revoked?): ${e.message}")
            return false
        }

        return true
    }

    /**
     * Cancels FCM auto-posted plain notifications before posting the SDK rich
     * notification. Hybrid payloads (`notification` + `data`) otherwise show
     * duplicate tray entries.
     */
    private fun cancelHybridFcmDuplicates(
        context: Context,
        title: String,
        body: String,
        deliveryMessageId: String,
    ) {
        val nm = NotificationManagerCompat.from(context)
        val trimmedTitle = title.trim()
        val trimmedBody = body.trim()

        try {
            nm.cancel(0)
            if (deliveryMessageId.isNotBlank()) {
                nm.cancel(deliveryMessageId, 0)
            }
        } catch (e: Throwable) {
            Log.w(TAG, "cancelHybridFcmDuplicates: cancel id=0 failed: ${e.message}")
        }

        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.M) return

        val manager = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        for (active in manager.activeNotifications) {
            val extras = active.notification.extras ?: continue
            val activeTitle = extras.getCharSequence(Notification.EXTRA_TITLE)
                ?.toString()
                ?.trim()
                .orEmpty()
            if (activeTitle.isEmpty() || activeTitle != trimmedTitle) continue

            val activeText = extras.getCharSequence(Notification.EXTRA_TEXT)
                ?.toString()
                ?.trim()
                .orEmpty()
            val activeBigText = extras.getCharSequence(Notification.EXTRA_BIG_TEXT)
                ?.toString()
                ?.trim()
                .orEmpty()
            val bodyMatches = trimmedBody.isEmpty() ||
                activeText == trimmedBody ||
                activeBigText == trimmedBody
            if (!bodyMatches) continue

            Log.d(
                TAG,
                "cancelHybridFcmDuplicates: canceling duplicate id=${active.id} tag=${active.tag}",
            )
            nm.cancel(active.tag, active.id)
        }
    }

    /**
     * abs() on Int.MIN_VALUE overflows back to Int.MIN_VALUE. Guard against
     * that so notificationId (and anything derived from it) is always >= 0.
     */
    private fun safeAbs(value: Int): Int {
        val a = abs(value)
        return if (a < 0) 0 else a
    }

    /**
     * Namespaces PendingIntent request codes per-notification so that a
     * given notification's "open" intent (slot 0) and its action intents
     * (slot 1..3) can never collide with another notification's codes,
     * even if notificationId + smallOffset values happen to overlap.
     *
     * Combines notificationId and slot into a single stable-but-unique int
     * via a simple mix; collisions are only theoretically possible via
     * hash collisions on deliveryMessageId itself, same as before.
     */
    private fun requestCode(notificationId: Int, slot: Int): Int {
        return safeAbs(notificationId * 31 + slot)
    }

    private fun resolveSmallIcon(context: Context): Int {
        val packageName = context.packageName
        val candidates = listOf("ic_stat_opencdp_notify", "ic_notification")
        for (name in candidates) {
            val resId = context.resources.getIdentifier(name, "drawable", packageName)
            if (resId != 0) return resId
        }
        return when {
            context.applicationInfo.icon != 0 -> context.applicationInfo.icon
            else -> android.R.drawable.ic_dialog_info
        }
    }

    private fun ensureChannel(context: Context, channelId: String, channelName: String, channelDescription: String) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val manager = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        val existing = manager.getNotificationChannel(channelId)
        if (existing != null) {
            // Channel name/description can be updated in place (importance,
            // sound, etc. cannot be changed once created -- that's an OS
            // restriction). Re-creating with the same id updates the mutable
            // fields without needing to delete/recreate the channel.
            if (existing.name != channelName || existing.description != channelDescription) {
                existing.name = channelName
                existing.description = channelDescription
                manager.createNotificationChannel(existing)
                Log.d(TAG, "updated existing channel id=$channelId name/description")
            }
            return
        }
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
                } catch (e: Throwable) {
                    Log.w(TAG, "parseActions: failed to parse actions JSON string: ${e.message}")
                    return emptyList()
                }
            }
            is List<*> -> JSONArray(raw)
            else -> return emptyList()
        }

        val out = mutableListOf<ActionItem>()
        for (i in 0 until array.length()) {
            val item = array.optJSONObject(i)
            if (item == null) {
                Log.w(TAG, "parseActions: skipping non-object entry at index=$i")
                continue
            }
            val actionId = item.optString("action_id", "").trim()
            val label = item.optString("label", "").trim()
            if (actionId.isEmpty() || label.isEmpty()) {
                Log.w(TAG, "parseActions: skipping entry at index=$i with missing action_id/label")
                continue
            }
            val link = item.optString("link", "").trim().ifEmpty { null }
            val iconUrl = item.optString("icon", "").trim().ifEmpty { null }
            out.add(
                ActionItem(
                    actionId = actionId,
                    label = label,
                    link = link,
                    iconUrl = iconUrl,
                ),
            )
        }
        return out
    }

    private data class ActionItem(
        val actionId: String,
        val label: String,
        val link: String?,
        val iconUrl: String?,
    )
}
