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
}
