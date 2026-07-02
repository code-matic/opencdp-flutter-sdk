package com.opencdp.sdk

import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.util.Log
import java.net.HttpURLConnection
import java.net.URL

internal object OpenCdpNotificationImage {
    private const val TAG = "OpenCdpNotificationImage"
    private const val CONNECT_TIMEOUT_MS = 15_000
    private const val READ_TIMEOUT_MS = 15_000
    private const val MAX_ATTEMPTS = 2
    private const val RETRY_DELAY_MS = 500L

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

    /**
     * Downloads and decodes a bitmap, retrying once on failure.
     *
     * Retry matters specifically for the background-push case: this is
     * frequently invoked within moments of the app being backgrounded
     * (see "Application backgrounded" -> broadcast received -> this call,
     * all within the same log burst), when the device's network/DNS stack
     * can still be settling after a Doze/App-Standby state transition.
     * A transient UnknownHostException/SocketTimeoutException right at
     * that moment is expected sometimes; a short retry absorbs it instead
     * of silently dropping the image for the whole notification.
     */
    fun downloadBitmap(imageUrl: String): Bitmap? {
        val normalizedUrl = normalizeImageUrl(imageUrl)
        var lastError: Throwable? = null

        for (attempt in 1..MAX_ATTEMPTS) {
            Log.d(TAG, "download start (attempt $attempt/$MAX_ATTEMPTS): $normalizedUrl")
            try {
                val result = attemptDownload(normalizedUrl)
                if (result != null) {
                    return result
                }
            } catch (e: Throwable) {
                lastError = e
                // Full exception type + stack trace -- e.message alone is often
                // null for network-layer exceptions (UnknownHostException,
                // some SocketTimeoutException cases), which is why prior logs
                // showed "...: null" with no actionable detail.
                Log.w(TAG, "Image download error (attempt $attempt/$MAX_ATTEMPTS) for $normalizedUrl", e)
            }

            if (attempt < MAX_ATTEMPTS) {
                try {
                    Thread.sleep(RETRY_DELAY_MS)
                } catch (_: InterruptedException) {
                    Thread.currentThread().interrupt()
                    break
                }
            }
        }

        if (lastError != null) {
            Log.w(TAG, "Image download failed after $MAX_ATTEMPTS attempts for $normalizedUrl: ${lastError.javaClass.simpleName}: ${lastError.message}")
        }
        return null
    }

    private fun attemptDownload(normalizedUrl: String): Bitmap? {
        val connection = (URL(normalizedUrl).openConnection() as HttpURLConnection).apply {
            connectTimeout = CONNECT_TIMEOUT_MS
            readTimeout = READ_TIMEOUT_MS
            instanceFollowRedirects = true
            requestMethod = "GET"
            setRequestProperty("Accept", "image/*")
            connect()
        }
        try {
            val code = connection.responseCode
            val contentType = connection.contentType
            Log.d(TAG, "response for $normalizedUrl: HTTP $code contentType=$contentType")

            if (code !in 200..299) {
                Log.w(TAG, "Image download failed: HTTP $code for $normalizedUrl")
                return null
            }

            return connection.inputStream.use { stream ->
                BitmapFactory.decodeStream(stream)
            }?.also { bitmap ->
                Log.d(
                    TAG,
                    "download success: $normalizedUrl " +
                        "size=${bitmap.byteCount} bytes " +
                        "dimensions=${bitmap.width}x${bitmap.height}",
                )
            } ?: run {
                Log.w(TAG, "Image decode failed for $normalizedUrl (HTTP $code contentType=$contentType, but BitmapFactory returned null)")
                null
            }
        } finally {
            connection.disconnect()
        }
    }
}
