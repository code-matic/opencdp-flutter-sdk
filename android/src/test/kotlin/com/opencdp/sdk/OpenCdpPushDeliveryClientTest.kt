package com.opencdp.sdk

import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertTrue

class OpenCdpPushDeliveryClientTest {

    @Test
    fun parseBaseUrlsJson_readsOrderedList() {
        val json = """["https://primary.test","https://backup.test"]"""
        val parsed = OpenCdpPushDeliveryClient.parseBaseUrlsJson(json)
        assertEquals(
            listOf("https://primary.test", "https://backup.test"),
            parsed,
        )
    }

    @Test
    fun dedupeHosts_preservesOrderAndStripsTrailingSlash() {
        val result = OpenCdpPushDeliveryClient.dedupeHosts(
            listOf(
                "https://primary.test/",
                "https://primary.test",
                "https://backup.test/",
            ),
        )
        assertEquals(
            listOf("https://primary.test", "https://backup.test"),
            result,
        )
    }

    @Test
    fun resolveGatewayHosts_usesSingleBaseUrlPlusDefaultsWhenListMissing() {
        val prefs = FakeSharedPreferences(
            mapOf(
                OpenCdpNotificationContracts.BASE_URL_KEY to "https://custom.test/gateway",
            ),
        )
        val hosts = OpenCdpPushDeliveryClient.resolveGatewayHosts(prefs)
        assertEquals("https://custom.test/gateway", hosts.first())
        assertTrue(hosts.size >= 3)
        assertTrue(hosts.contains(OpenCdpNotificationContracts.DEFAULT_FALLBACK_URLS.first()))
    }

    @Test
    fun resolveGatewayHosts_prefersStoredJsonList() {
        val prefs = FakeSharedPreferences(
            mapOf(
                OpenCdpNotificationContracts.BASE_URLS_KEY to
                    """["https://a.test","https://b.test"]""",
                OpenCdpNotificationContracts.BASE_URL_KEY to "https://ignored.test",
            ),
        )
        val hosts = OpenCdpPushDeliveryClient.resolveGatewayHosts(prefs)
        assertEquals(listOf("https://a.test", "https://b.test"), hosts)
    }
}

private class FakeSharedPreferences(
    private val values: Map<String, String>,
) : android.content.SharedPreferences {
    override fun getAll(): MutableMap<String, *> = values.toMutableMap()
    override fun getString(key: String?, defValue: String?): String? =
        if (key == null) defValue else values[key] ?: defValue
    override fun getStringSet(key: String?, defValues: MutableSet<String>?): MutableSet<String>? =
        defValues
    override fun getInt(key: String?, defValue: Int): Int = defValue
    override fun getLong(key: String?, defValue: Long): Long = defValue
    override fun getFloat(key: String?, defValue: Float): Float = defValue
    override fun getBoolean(key: String?, defValue: Boolean): Boolean = defValue
    override fun contains(key: String?): Boolean = key != null && values.containsKey(key)
    override fun edit(): android.content.SharedPreferences.Editor =
        throw UnsupportedOperationException()
    override fun registerOnSharedPreferenceChangeListener(
        listener: android.content.SharedPreferences.OnSharedPreferenceChangeListener?,
    ) = Unit
    override fun unregisterOnSharedPreferenceChangeListener(
        listener: android.content.SharedPreferences.OnSharedPreferenceChangeListener?,
    ) = Unit
}
