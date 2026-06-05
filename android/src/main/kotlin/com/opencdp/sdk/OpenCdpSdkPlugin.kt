package com.opencdp.sdk

import android.content.Context
import android.content.SharedPreferences
import androidx.annotation.NonNull
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result

/** OpenCdpSdkPlugin */
class OpenCdpSdkPlugin : FlutterPlugin, MethodCallHandler {
    private lateinit var channel: MethodChannel
    private lateinit var context: Context

    companion object {
        private const val PREFS_NAME = OpenCdpNotificationContracts.PREFS_NAME
        private const val API_KEY_KEY = OpenCdpNotificationContracts.API_KEY_KEY
        private const val USER_ID_KEY = OpenCdpNotificationContracts.USER_ID_KEY
        private const val BASE_URL_KEY = OpenCdpNotificationContracts.BASE_URL_KEY
        private const val BASE_URLS_KEY = OpenCdpNotificationContracts.BASE_URLS_KEY
    }

    override fun onAttachedToEngine(@NonNull binding: FlutterPlugin.FlutterPluginBinding) {
        // Get the application context
        context = binding.applicationContext

        // Define the communication channel (must match Dart + iOS)
        channel = MethodChannel(binding.binaryMessenger, "open_cdp_sdk")
        channel.setMethodCallHandler(this)
    }

    override fun onMethodCall(@NonNull call: MethodCall, @NonNull result: Result) {
        when (call.method) {
            "opencdpsdk_save_api_key" -> {
                val apiKey = call.argument<String>("apiKey")
                if (apiKey != null) {
                    saveApiKeyToSharedPreferences(apiKey)
                    result.success(null)
                } else {
                    result.error("INVALID_ARGS", "API key was null", null)
                }
            }
            
            "opencdpsdk_save_user_id" -> {
                val userId = call.argument<String>("userId")
                if (userId != null) {
                    saveUserIdToSharedPreferences(userId)
                    result.success(null)
                } else {
                    result.error("INVALID_ARGS", "User ID was null", null)
                }
            }

            "opencdpsdk_get_api_key" -> {
                val apiKey = getApiKeyFromSharedPreferences()
                if (apiKey != null) {
                    result.success(apiKey)
                } else {
                    result.error("NOT_FOUND", "API key not found", null)
                }
            }
            
            "opencdpsdk_get_user_id" -> {
                val userId = getUserIdFromSharedPreferences()
                if (userId != null) {
                    result.success(userId)
                } else {
                    result.error("NOT_FOUND", "User ID not found", null)
                }
            }
            
            "opencdpsdk_clear_api_key" -> {
                clearApiKeyFromSharedPreferences()
                result.success(null)
            }
            
            "opencdpsdk_clear_user_id" -> {
                clearUserIdFromSharedPreferences()
                result.success(null)
            }

            "opencdpsdk_save_base_url" -> {
                val baseUrl = call.argument<String>("baseUrl")
                if (baseUrl != null) {
                    saveBaseUrlToSharedPreferences(baseUrl)
                    result.success(null)
                } else {
                    result.error("INVALID_ARGS", "baseUrl was null", null)
                }
            }

            "opencdpsdk_get_base_url" -> {
                val baseUrl = getBaseUrlFromSharedPreferences()
                if (baseUrl != null) {
                    result.success(baseUrl)
                } else {
                    result.error("NOT_FOUND", "Base URL not found", null)
                }
            }

            "opencdpsdk_clear_base_url" -> {
                clearBaseUrlFromSharedPreferences()
                result.success(null)
            }

            "opencdpsdk_save_base_urls" -> {
                @Suppress("UNCHECKED_CAST")
                val baseUrls = call.argument<List<String>>("baseUrls")
                if (baseUrls != null) {
                    saveBaseUrlsToSharedPreferences(baseUrls)
                    result.success(null)
                } else {
                    result.error("INVALID_ARGS", "baseUrls was null", null)
                }
            }

            "opencdpsdk_get_base_urls" -> {
                val baseUrls = getBaseUrlsFromSharedPreferences()
                if (baseUrls != null) {
                    result.success(baseUrls)
                } else {
                    result.error("NOT_FOUND", "Base URLs not found", null)
                }
            }

            "opencdpsdk_clear_base_urls" -> {
                clearBaseUrlsFromSharedPreferences()
                result.success(null)
            }

            "opencdpsdk_show_actionable_notification" -> {
                val rawData = call.argument<Map<String, Any?>>("data")
                if (rawData == null) {
                    result.error("INVALID_ARGS", "data was null", null)
                    return
                }
                val channelName = call.argument<String>("channelName") ?: "CDP Notifications"
                val channelDescription = call.argument<String>("channelDescription")
                    ?: "Push notifications from CDP"
                val shown = OpenCdpNotificationRenderer.showActionableNotification(
                    context = context,
                    data = rawData,
                    channelName = channelName,
                    channelDescription = channelDescription
                )
                result.success(shown)
            }

            else -> result.notImplemented()
        }
    }

    override fun onDetachedFromEngine(@NonNull binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
    }

    // Save the API key in SharedPreferences
    private fun saveApiKeyToSharedPreferences(apiKey: String) {
        val sharedPreferences: SharedPreferences =
            context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        with(sharedPreferences.edit()) {
            putString(API_KEY_KEY, apiKey)
            apply()
        }
    }
    
    // Save the User ID in SharedPreferences
    private fun saveUserIdToSharedPreferences(userId: String) {
        val sharedPreferences: SharedPreferences =
            context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        with(sharedPreferences.edit()) {
            putString(USER_ID_KEY, userId)
            apply()
        }
    }

    // Retrieve the API key from SharedPreferences
    private fun getApiKeyFromSharedPreferences(): String? {
        val sharedPreferences: SharedPreferences =
            context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        return sharedPreferences.getString(API_KEY_KEY, null)
    }
    
    // Retrieve the User ID from SharedPreferences
    private fun getUserIdFromSharedPreferences(): String? {
        val sharedPreferences: SharedPreferences =
            context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        return sharedPreferences.getString(USER_ID_KEY, null)
    }
    
    // Clear the API key from SharedPreferences
    private fun clearApiKeyFromSharedPreferences() {
        val sharedPreferences: SharedPreferences =
            context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        with(sharedPreferences.edit()) {
            remove(API_KEY_KEY)
            apply()
        }
    }
    
    // Clear the User ID from SharedPreferences
    private fun clearUserIdFromSharedPreferences() {
        val sharedPreferences: SharedPreferences =
            context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        with(sharedPreferences.edit()) {
            remove(USER_ID_KEY)
            apply()
        }
    }

    private fun saveBaseUrlToSharedPreferences(baseUrl: String) {
        val sharedPreferences: SharedPreferences =
            context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        with(sharedPreferences.edit()) {
            putString(BASE_URL_KEY, baseUrl)
            apply()
        }
    }

    private fun getBaseUrlFromSharedPreferences(): String? {
        val sharedPreferences: SharedPreferences =
            context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        return sharedPreferences.getString(BASE_URL_KEY, null)
    }

    private fun clearBaseUrlFromSharedPreferences() {
        val sharedPreferences: SharedPreferences =
            context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        with(sharedPreferences.edit()) {
            remove(BASE_URL_KEY)
            apply()
        }
    }

    private fun saveBaseUrlsToSharedPreferences(baseUrls: List<String>) {
        val json = org.json.JSONArray(baseUrls).toString()
        val sharedPreferences: SharedPreferences =
            context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        with(sharedPreferences.edit()) {
            putString(BASE_URLS_KEY, json)
            apply()
        }
    }

    private fun getBaseUrlsFromSharedPreferences(): List<String>? {
        val sharedPreferences: SharedPreferences =
            context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        return OpenCdpPushDeliveryClient.parseBaseUrlsJson(
            sharedPreferences.getString(BASE_URLS_KEY, null),
        )
    }

    private fun clearBaseUrlsFromSharedPreferences() {
        val sharedPreferences: SharedPreferences =
            context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        with(sharedPreferences.edit()) {
            remove(BASE_URLS_KEY)
            apply()
        }
    }
}
