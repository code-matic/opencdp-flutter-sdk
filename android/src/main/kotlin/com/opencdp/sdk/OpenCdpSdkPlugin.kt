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
        private const val PREFS_NAME = "open_cdp_sdk_prefs"
        private const val API_KEY_KEY = "opencdpsdk_api_key"
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

            "opencdpsdk_get_api_key" -> {
                val apiKey = getApiKeyFromSharedPreferences()
                if (apiKey != null) {
                    result.success(apiKey)
                } else {
                    result.error("NOT_FOUND", "API key not found", null)
                }
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

    // Retrieve the API key from SharedPreferences
    private fun getApiKeyFromSharedPreferences(): String? {
        val sharedPreferences: SharedPreferences =
            context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        return sharedPreferences.getString(API_KEY_KEY, null)
    }
}
