package com.opencdp.sdk

import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.util.Log
import java.net.HttpURLConnection
import java.net.URL

internal object OpenCdpNotificationImage {
    private const val TAG = "OpenCdpNotificationImage"
    private const val CONNECT_TIMEOUT_MS = 8_000
    private const val READ_TIMEOUT_MS = 8_000

    fun parseImageUrl(raw: Any?): String? {
        val url = raw?.toString()?.trim().orEmpty()
        if (url.isEmpty()) return null
        return normalizeImageUrl(url)
    }

    internal fun normalizeImageUrl(url: String): String {
        if (url.startsWith("http://") || url.startsWith("https://")) {
            return url
        }
        return "https://$url"
    }

    fun downloadScaledBitmap(imageUrl: String, maxDimensionPx: Int): Bitmap? {
        val bitmap = downloadBitmap(imageUrl) ?: return null
        return scaleBitmap(bitmap, maxDimensionPx)
    }

    fun createSquareThumbnail(bitmap: Bitmap, sizePx: Int): Bitmap {
        val crop = computeCenterSquareCrop(bitmap.width, bitmap.height)
        val cropped = Bitmap.createBitmap(bitmap, crop.x, crop.y, crop.size, crop.size)
        return scaleBitmap(cropped, sizePx)
    }

    internal data class SquareCropSpec(val x: Int, val y: Int, val size: Int)

    internal fun computeCenterSquareCrop(width: Int, height: Int): SquareCropSpec {
        val cropSize = minOf(width, height)
        return SquareCropSpec(
            x = (width - cropSize) / 2,
            y = (height - cropSize) / 2,
            size = cropSize,
        )
    }

    internal fun computeScaledDimensions(
        width: Int,
        height: Int,
        maxDimensionPx: Int,
    ): Pair<Int, Int> {
        if (width <= maxDimensionPx && height <= maxDimensionPx) {
            return width to height
        }
        val scale = minOf(
            maxDimensionPx.toFloat() / width,
            maxDimensionPx.toFloat() / height,
        )
        val newWidth = (width * scale).toInt().coerceAtLeast(1)
        val newHeight = (height * scale).toInt().coerceAtLeast(1)
        return newWidth to newHeight
    }

    private fun scaleBitmap(bitmap: Bitmap, maxDimensionPx: Int): Bitmap {
        val (newWidth, newHeight) = computeScaledDimensions(
            bitmap.width,
            bitmap.height,
            maxDimensionPx,
        )
        if (newWidth == bitmap.width && newHeight == bitmap.height) {
            return bitmap
        }
        return Bitmap.createScaledBitmap(bitmap, newWidth, newHeight, true)
    }

    fun downloadBitmap(imageUrl: String): Bitmap? {
        val normalizedUrl = normalizeImageUrl(imageUrl)
        Log.d(TAG, "download start: $normalizedUrl")
        return try {
            val connection = (URL(normalizedUrl).openConnection() as HttpURLConnection).apply {
                connectTimeout = CONNECT_TIMEOUT_MS
                readTimeout = READ_TIMEOUT_MS
                instanceFollowRedirects = true
                requestMethod = "GET"
                connect()
            }
            try {
                val code = connection.responseCode
                if (code !in 200..299) {
                    Log.w(TAG, "Image download failed: HTTP $code for $normalizedUrl")
                    return null
                }
                connection.inputStream.use { stream ->
                    BitmapFactory.decodeStream(stream)
                }?.also { bitmap ->
                    Log.d(
                        TAG,
                        "download success: $normalizedUrl " +
                            "size=${bitmap.byteCount} bytes " +
                            "dimensions=${bitmap.width}x${bitmap.height}",
                    )
                } ?: run {
                    Log.w(TAG, "Image decode failed for $normalizedUrl")
                    null
                }
            } finally {
                connection.disconnect()
            }
        } catch (e: Throwable) {
            Log.w(TAG, "Image download error for $normalizedUrl: ${e.message}")
            null
        }
    }
}
