package com.opencdp.sdk

import android.graphics.Bitmap
import android.graphics.BitmapFactory
import java.net.HttpURLConnection
import java.net.URL

internal object OpenCdpNotificationImage {
    private const val CONNECT_TIMEOUT_MS = 8_000
    private const val READ_TIMEOUT_MS = 8_000

    fun parseImageUrl(raw: Any?): String? {
        val url = raw?.toString()?.trim().orEmpty()
        return url.ifEmpty { null }
    }

    fun downloadBitmap(imageUrl: String): Bitmap? {
        return try {
            val connection = (URL(imageUrl).openConnection() as HttpURLConnection).apply {
                connectTimeout = CONNECT_TIMEOUT_MS
                readTimeout = READ_TIMEOUT_MS
                instanceFollowRedirects = true
                requestMethod = "GET"
                connect()
            }
            try {
                if (connection.responseCode !in 200..299) return null
                connection.inputStream.use { stream ->
                    BitmapFactory.decodeStream(stream)
                }
            } finally {
                connection.disconnect()
            }
        } catch (_: Throwable) {
            null
        }
    }
}
