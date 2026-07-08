package com.opencdp.sdk

import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertNull

class OpenCdpNotificationImageTest {

    @Test
    fun parseImageUrl_returnsTrimmedUrl() {
        assertEquals(
            "https://cdn.example.com/push.jpg",
            OpenCdpNotificationImage.parseImageUrl("  https://cdn.example.com/push.jpg  "),
        )
    }

    @Test
    fun parseImageUrl_returnsNullForBlankOrMissing() {
        assertNull(OpenCdpNotificationImage.parseImageUrl(null))
        assertNull(OpenCdpNotificationImage.parseImageUrl(""))
        assertNull(OpenCdpNotificationImage.parseImageUrl("   "))
    }

    @Test
    fun parseImageUrl_prependsHttpsWhenSchemeMissing() {
        assertEquals(
            "https://storage.googleapis.com/bucket/image.jpg",
            OpenCdpNotificationImage.parseImageUrl("storage.googleapis.com/bucket/image.jpg"),
        )
    }

    @Test
    fun normalizeImageUrl_preservesExistingScheme() {
        assertEquals(
            "https://cdn.example.com/push.jpg",
            OpenCdpNotificationImage.normalizeImageUrl("https://cdn.example.com/push.jpg"),
        )
        assertEquals(
            "http://cdn.example.com/push.jpg",
            OpenCdpNotificationImage.normalizeImageUrl("http://cdn.example.com/push.jpg"),
        )
    }

    @Test
    fun computeCenterSquareCrop_landscapeBitmap_cropsWidth() {
        val crop = OpenCdpNotificationImage.computeCenterSquareCrop(800, 400)

        assertEquals(200, crop.x)
        assertEquals(0, crop.y)
        assertEquals(400, crop.size)
    }

    @Test
    fun computeCenterSquareCrop_portraitBitmap_cropsHeight() {
        val crop = OpenCdpNotificationImage.computeCenterSquareCrop(300, 600)

        assertEquals(0, crop.x)
        assertEquals(150, crop.y)
        assertEquals(300, crop.size)
    }

    @Test
    fun computeCenterSquareCrop_squareBitmap_keepsFullImage() {
        val crop = OpenCdpNotificationImage.computeCenterSquareCrop(512, 512)

        assertEquals(0, crop.x)
        assertEquals(0, crop.y)
        assertEquals(512, crop.size)
    }

    @Test
    fun computeScaledDimensions_largeSquareBitmap_scalesToTargetSize() {
        val (width, height) = OpenCdpNotificationImage.computeScaledDimensions(512, 512, 256)

        assertEquals(256, width)
        assertEquals(256, height)
    }

    @Test
    fun computeScaledDimensions_smallSquareBitmap_keepsOriginalSize() {
        val (width, height) = OpenCdpNotificationImage.computeScaledDimensions(64, 64, 256)

        assertEquals(64, width)
        assertEquals(64, height)
    }

    @Test
    fun computeScaledDimensions_thumbnailPipeline_producesSquareAtTargetSize() {
        val crop = OpenCdpNotificationImage.computeCenterSquareCrop(800, 400)
        val (width, height) = OpenCdpNotificationImage.computeScaledDimensions(
            crop.size,
            crop.size,
            256,
        )

        assertEquals(256, width)
        assertEquals(256, height)
    }
}
