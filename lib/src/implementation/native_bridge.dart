import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class NativeBridge {
  static const MethodChannel _channel = MethodChannel('open_cdp_sdk');

  /// Save API key to native shared storage (Android: SharedPreferences, iOS: UserDefaults)
  /// On iOS, requires an app group
  /// On Android, the app group is not used
  static Future<void> saveApiKeyToNative({
    required String apiKey,
    String? appGroup,
  }) async {
    try {
      // Create a map that will include appGroup only if it's not null
      final Map<String, dynamic> args = {'apiKey': apiKey};
      if (appGroup != null) {
        args['appGroup'] = appGroup;
      }
      
      await _channel.invokeMethod('opencdpsdk_save_api_key', args);
      debugPrint('[CDP] API key saved to native storage');
    } on PlatformException catch (e) {
      debugPrint('[CDP] Failed to save API key to native: ${e.message}');
    }
  }

  /// Save user ID to native shared storage for background tasks
  /// On iOS, requires an app group
  /// On Android, the app group is not used
  static Future<void> saveUserIdToNative({
    required String userId,
    String? appGroup,
  }) async {
    try {
      // Create a map that will include appGroup only if it's not null
      final Map<String, dynamic> args = {'userId': userId};
      if (appGroup != null) {
        args['appGroup'] = appGroup;
      }

      await _channel.invokeMethod('opencdpsdk_save_user_id', args);
      debugPrint(
          '[CDP] User ID saved to native storage: ${userId.substring(0, min(5, userId.length))}...');
    } on PlatformException catch (e) {
      debugPrint('[CDP] Failed to save user ID to native: ${e.message}');
    }
  }

  /// Retrieve API key from native shared storage
  /// On iOS, requires an app group
  /// On Android, the app group is not used
  static Future<String?> getApiKeyFromNative({
    String? appGroup,
  }) async {
    try {
      // Create a map that will include appGroup only if it's not null
      final Map<String, dynamic> args = {};
      if (appGroup != null) {
        args['appGroup'] = appGroup;
      }
      
      final apiKey = await _channel.invokeMethod<String>(
        'opencdpsdk_get_api_key',
        args,
      );
      return apiKey;
    } on PlatformException catch (e) {
      debugPrint('[CDP] Failed to get API key from native: ${e.message}');
      return null;
    }
  }

  /// Retrieve user ID from native shared storage
  /// On iOS, requires an app group
  /// On Android, the app group is not used
  static Future<String?> getUserIdFromNative({
    String? appGroup,
  }) async {
    try {
      // Create a map that will include appGroup only if it's not null
      final Map<String, dynamic> args = {};
      if (appGroup != null) {
        args['appGroup'] = appGroup;
      }

      final userId = await _channel.invokeMethod<String>(
        'opencdpsdk_get_user_id',
        args,
      );
      return userId;
    } on PlatformException catch (e) {
      debugPrint('[CDP] Failed to get user ID from native: ${e.message}');
      return null;
    }
  }

  /// Clear API key from native shared storage
  /// This is important for reinitialization to ensure we're not using the old key
  /// On iOS, requires an app group
  /// On Android, the app group is not used
  static Future<void> clearApiKeyFromNative({
    String? appGroup,
  }) async {
    try {
      // Create a map that will include appGroup only if it's not null
      final Map<String, dynamic> args = {};
      if (appGroup != null) {
        args['appGroup'] = appGroup;
      }
      
      await _channel.invokeMethod('opencdpsdk_clear_api_key', args);
      debugPrint('[CDP] API key cleared from native storage');
    } on PlatformException catch (e) {
      debugPrint('[CDP] Failed to clear API key from native: ${e.message}');
    }
  }

  /// Clear user ID from native shared storage
  /// On iOS, requires an app group
  /// On Android, the app group is not used
  static Future<void> clearUserIdFromNative({
    String? appGroup,
  }) async {
    try {
      // Create a map that will include appGroup only if it's not null
      final Map<String, dynamic> args = {};
      if (appGroup != null) {
        args['appGroup'] = appGroup;
      }

      await _channel.invokeMethod('opencdpsdk_clear_user_id', args);
      debugPrint('[CDP] User ID cleared from native storage');
    } on PlatformException catch (e) {
      debugPrint('[CDP] Failed to clear user ID from native: ${e.message}');
    }
  }

  /// Helper function for string length safety
  static int min(int a, int b) => a < b ? a : b;
}
