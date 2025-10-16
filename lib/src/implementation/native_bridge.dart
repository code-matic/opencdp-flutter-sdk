import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class NativeBridge {
  static const MethodChannel _channel = MethodChannel('open_cdp_sdk');

  /// Save API key to native shared storage (Android: SharedPreferences, iOS: UserDefaults)
  static Future<void> saveApiKeyToNative({
    required String apiKey,
    required String appGroup,
  }) async {
    try {
      await _channel.invokeMethod('opencdpsdk_save_api_key', {
        'apiKey': apiKey,
        'appGroup': appGroup,
      });
    } on PlatformException catch (e) {
      debugPrint('[CDP] Failed to save API key to native: ${e.message}');
    }
  }

  /// Retrieve API key from native shared storage
  static Future<String?> getApiKeyFromNative({
    required String appGroup,
  }) async {
    try {
      final apiKey = await _channel.invokeMethod<String>(
        'opencdpsdk_get_api_key',
        {'appGroup': appGroup},
      );
      return apiKey;
    } on PlatformException catch (e) {
      debugPrint('[CDP] Failed to get API key from native: ${e.message}');
      return null;
    }
  }
  
  /// Clear API key from native shared storage
  /// This is important for reinitialization to ensure we're not using the old key
  static Future<void> clearApiKeyFromNative({
    required String appGroup,
  }) async {
    try {
      await _channel.invokeMethod('opencdpsdk_clear_api_key', {
        'appGroup': appGroup,
      });
      debugPrint('[CDP] API key cleared from native storage');
    } on PlatformException catch (e) {
      debugPrint('[CDP] Failed to clear API key from native: ${e.message}');
    }
  }
}
