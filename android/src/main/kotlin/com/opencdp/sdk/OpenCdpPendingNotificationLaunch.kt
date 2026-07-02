package com.opencdp.sdk

import android.content.Context
import org.json.JSONObject

/**
 * Persists SDK-rendered notification tap payloads so Dart can consume them on
 * cold/warm start. Native [OpenCdpNotificationActionReceiver] already posts
 * open/click metrics; Dart reads this for routing only.
 */
internal object OpenCdpPendingNotificationLaunch {
    private const val PREFS_NAME = "open_cdp_sdk_notification_launch"
    private const val KEY_PAYLOAD_JSON = "payload_json"
    private const val KEY_ACTION_ID = "action_id"
    private const val KEY_ACTION_LINK = "action_link"

    fun save(
        context: Context,
        payloadJson: String,
        actionId: String?,
        actionLink: String?,
    ) {
        context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            .edit()
            .putString(KEY_PAYLOAD_JSON, payloadJson)
            .putString(KEY_ACTION_ID, actionId?.trim()?.ifEmpty { null })
            .putString(KEY_ACTION_LINK, actionLink?.trim()?.ifEmpty { null })
            .apply()
    }

    fun consume(context: Context): Map<String, String?>? {
        val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        val payloadJson = prefs.getString(KEY_PAYLOAD_JSON, null)?.trim()?.ifEmpty { null }
            ?: return null
        val actionId = prefs.getString(KEY_ACTION_ID, null)?.trim()?.ifEmpty { null }
        val actionLink = prefs.getString(KEY_ACTION_LINK, null)?.trim()?.ifEmpty { null }
        prefs.edit()
            .remove(KEY_PAYLOAD_JSON)
            .remove(KEY_ACTION_ID)
            .remove(KEY_ACTION_LINK)
            .apply()
        return mapOf(
            "payload_json" to payloadJson,
            "action_id" to actionId,
            "action_link" to actionLink,
        )
    }

    fun parsePayloadMap(payloadJson: String): Map<String, Any?>? {
        return try {
            val json = JSONObject(payloadJson)
            val out = mutableMapOf<String, Any?>()
            json.keys().forEach { key ->
                out[key] = json.opt(key)
            }
            out
        } catch (_: Throwable) {
            null
        }
    }
}
