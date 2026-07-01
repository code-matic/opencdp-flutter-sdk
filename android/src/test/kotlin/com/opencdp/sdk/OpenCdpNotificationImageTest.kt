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
}
