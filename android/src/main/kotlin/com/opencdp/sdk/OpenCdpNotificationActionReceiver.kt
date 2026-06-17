package com.opencdp.sdk

import android.app.NotificationManager
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import org.json.JSONObject
import java.time.Instant

class OpenCdpNotificationActionReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        val payloadJson = intent.getStringExtra(OpenCdpNotificationContracts.EXTRA_PAYLOAD_JSON) ?: return
        val payload = try {
            JSONObject(payloadJson)
        } catch (_: Throwable) {
            return
        }
        val actionId = intent.getStringExtra(OpenCdpNotificationContracts.EXTRA_ACTION_ID)?.trim()?.ifEmpty { null }
        val action = intent.action
        val status = if (action == OpenCdpNotificationContracts.ACTION_CLICK) "clicked" else "opened"
        val actionLink = intent.getStringExtra(OpenCdpNotificationContracts.EXTRA_ACTION_LINK)
        val notificationId = intent.getIntExtra(OpenCdpNotificationContracts.EXTRA_NOTIFICATION_ID, -1)

        trackAsync(context, payload, status, actionId)
        openApp(context, payloadJson, actionId, actionLink)
        if (notificationId >= 0) {
            val nm = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            nm.cancel(notificationId)
        }
    }

    private fun openApp(context: Context, payloadJson: String, actionId: String?, actionLink: String?) {
        val launchIntent = context.packageManager.getLaunchIntentForPackage(context.packageName) ?: return
        launchIntent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP or Intent.FLAG_ACTIVITY_SINGLE_TOP)
        launchIntent.putExtra("opencdp_payload_json", payloadJson)
        if (!actionId.isNullOrBlank()) {
            launchIntent.putExtra("opencdp_action_id", actionId)
        }
        val deepLink = actionLink ?: try {
            JSONObject(payloadJson).optString("link", "")
        } catch (_: Throwable) {
            ""
        }
        if (deepLink.isNotBlank()) {
            launchIntent.putExtra("opencdp_link", deepLink)
        }
        context.startActivity(launchIntent)
    }

    private fun trackAsync(context: Context, payload: JSONObject, status: String, actionId: String?) {
        Thread {
            try {
                val prefs = context.getSharedPreferences(
                    OpenCdpNotificationContracts.PREFS_NAME,
                    Context.MODE_PRIVATE,
                )
                val apiKey = prefs.getString(OpenCdpNotificationContracts.API_KEY_KEY, null)
                if (apiKey.isNullOrBlank()) return@Thread

                val deliveryMessageId = payload.optString("delivery_message_id", "").trim()
                if (deliveryMessageId.isEmpty()) return@Thread

                val personIdFromPayload = payload.optString("person_id", "").trim()
                val storedUserId = prefs.getString(OpenCdpNotificationContracts.USER_ID_KEY, null)?.trim()
                val personId = if (personIdFromPayload.isNotEmpty()) personIdFromPayload else (storedUserId ?: "")
                if (personId.isEmpty()) return@Thread

                val body = JSONObject().apply {
                    put("message_id", deliveryMessageId)
                    put("person_id", personId)
                    put("send_context", payload.optString("delivery_send_context", "transactional"))
                    put("send_context_id", payload.optString("delivery_send_context_id", ""))
                    put("status", status)
                    put("ts", Instant.now().toString())
                    if (status == "clicked" && !actionId.isNullOrBlank()) {
                        put("props", JSONObject().put("action_id", actionId))
                    }
                }

                val baseUrls = OpenCdpPushDeliveryClient.resolveGatewayHosts(prefs)
                OpenCdpPushDeliveryClient.postDeliveryMetric(apiKey, body, baseUrls)
            } catch (_: Throwable) {
                // best-effort background tracking
            }
        }.start()
    }
}
