package com.opencdp.sdk

import android.content.Context
import android.content.SharedPreferences
import android.util.Log
import org.json.JSONArray
import org.json.JSONObject
import java.io.OutputStreamWriter
import java.net.HttpURLConnection
import java.net.URL
import kotlin.math.pow
import kotlin.random.Random

/**
 * Native push delivery POST with primary-first gateway failover (mirrors Dart
 * [PushNotificationTracker] host loop, without persistent queue).
 */
internal object OpenCdpPushDeliveryClient {
    private const val TAG = "OpenCDP"
    private const val CONNECT_TIMEOUT_MS = 8000
    private const val READ_TIMEOUT_MS = 8000
    private const val MAX_RETRIES = 3
    private const val BASE_RETRY_DELAY_MS = 1000L

    fun resolveGatewayHosts(prefs: SharedPreferences): List<String> {
        parseBaseUrlsJson(prefs.getString(OpenCdpNotificationContracts.BASE_URLS_KEY, null))
            ?.let { if (it.isNotEmpty()) return dedupeHosts(it) }

        val single = prefs.getString(OpenCdpNotificationContracts.BASE_URL_KEY, null)
            ?.trim()
            ?.takeIf { it.isNotEmpty() }
        if (single != null) {
            return dedupeHosts(listOf(single) + OpenCdpNotificationContracts.DEFAULT_FALLBACK_URLS)
        }

        return OpenCdpNotificationContracts.DEFAULT_GATEWAY_HOSTS
    }

    fun parseBaseUrlsJson(json: String?): List<String>? {
        if (json.isNullOrBlank()) return null
        return try {
            val array = JSONArray(json)
            buildList {
                for (i in 0 until array.length()) {
                    val value = array.optString(i, "").trim()
                    if (value.isNotEmpty()) add(value)
                }
            }
        } catch (_: Throwable) {
            null
        }
    }

    fun dedupeHosts(hosts: List<String>): List<String> {
        val seen = LinkedHashSet<String>()
        for (host in hosts) {
            val normalized = normalizeRoot(host)
            if (normalized.isNotEmpty()) seen.add(normalized)
        }
        return seen.toList()
    }

    fun normalizeRoot(url: String): String {
        val trimmed = url.trim()
        if (trimmed.isEmpty()) return trimmed
        return if (trimmed.endsWith("/")) trimmed.dropLast(1) else trimmed
    }

    fun postDeliveryMetric(
        apiKey: String,
        body: JSONObject,
        baseUrls: List<String>,
    ): Boolean {
        val hosts = if (baseUrls.isEmpty()) {
            OpenCdpNotificationContracts.DEFAULT_GATEWAY_HOSTS
        } else {
            dedupeHosts(baseUrls)
        }

        var retryCount = 0
        while (retryCount <= MAX_RETRIES) {
            for (root in hosts) {
                try {
                    val status = postOnce(apiKey, body, root)
                    if (status in 200..299) {
                        Log.d(TAG, "Push metric sent via $root (status=$status)")
                        return true
                    }
                    Log.w(
                        TAG,
                        "Push metric non-2xx on $root ($status), trying next host.",
                    )
                } catch (e: Throwable) {
                    Log.w(TAG, "Push metric failed on $root: ${e.message}")
                }
            }

            if (retryCount == MAX_RETRIES) break

            val delayMs = (BASE_RETRY_DELAY_MS * 2.0.pow(retryCount.toDouble())).toLong() +
                Random.nextLong(BASE_RETRY_DELAY_MS)
            try {
                Thread.sleep(delayMs)
            } catch (_: InterruptedException) {
                Thread.currentThread().interrupt()
                break
            }
            retryCount++
        }

        Log.w(TAG, "Push metric failed on all gateway hosts after retries")
        return false
    }

    fun resolveGatewayHosts(context: Context): List<String> {
        val prefs = context.getSharedPreferences(
            OpenCdpNotificationContracts.PREFS_NAME,
            Context.MODE_PRIVATE,
        )
        return resolveGatewayHosts(prefs)
    }

    private fun postOnce(apiKey: String, body: JSONObject, root: String): Int {
        val normalized = normalizeRoot(root)
        val url = "$normalized${OpenCdpNotificationContracts.DELIVERY_PATH}"
        val connection = (URL(url).openConnection() as HttpURLConnection).apply {
            requestMethod = "POST"
            connectTimeout = CONNECT_TIMEOUT_MS
            readTimeout = READ_TIMEOUT_MS
            doOutput = true
            setRequestProperty("Content-Type", "application/json")
            setRequestProperty("Authorization", apiKey)
        }

        try {
            OutputStreamWriter(connection.outputStream).use { it.write(body.toString()) }
            val code = connection.responseCode
            try {
                if (code in 200..299) {
                    connection.inputStream?.close()
                } else {
                    connection.errorStream?.close()
                }
            } catch (_: Throwable) {
                // ignore drain failures
            }
            return code
        } finally {
            connection.disconnect()
        }
    }
}
