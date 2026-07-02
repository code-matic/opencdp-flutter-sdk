import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:open_cdp_flutter_sdk/src/utils/cdp_gateway_urls.dart';

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

  /// Save the resolved data-gateway base URL (see [OpenCDPConfig.baseUrl]) for
  /// background push delivery requests (same host as identify/track).
  static Future<void> saveBaseUrlToNative({
    required String baseUrl,
    String? appGroup,
  }) async {
    try {
      final Map<String, dynamic> args = {'baseUrl': baseUrl};
      if (appGroup != null) {
        args['appGroup'] = appGroup;
      }
      await _channel.invokeMethod('opencdpsdk_save_base_url', args);
      debugPrint('[CDP] Base URL saved to native storage for push delivery');
    } on PlatformException catch (e) {
      debugPrint('[CDP] Failed to save base URL to native: ${e.message}');
    }
  }

  static Future<String?> getBaseUrlFromNative({
    String? appGroup,
  }) async {
    try {
      final Map<String, dynamic> args = {};
      if (appGroup != null) {
        args['appGroup'] = appGroup;
      }
      return await _channel.invokeMethod<String>(
        'opencdpsdk_get_base_url',
        args,
      );
    } on PlatformException catch (e) {
      debugPrint('[CDP] Failed to get base URL from native: ${e.message}');
      return null;
    }
  }

  static Future<void> clearBaseUrlFromNative({
    String? appGroup,
  }) async {
    try {
      final Map<String, dynamic> args = {};
      if (appGroup != null) {
        args['appGroup'] = appGroup;
      }
      await _channel.invokeMethod('opencdpsdk_clear_base_url', args);
      debugPrint('[CDP] Base URL cleared from native storage');
    } on PlatformException catch (e) {
      debugPrint('[CDP] Failed to clear base URL from native: ${e.message}');
    }
  }

  /// Save ordered gateway hosts (primary + fallbacks) for native push delivery.
  static Future<void> saveGatewayHostsToNative({
    required List<String> baseUrls,
    String? appGroup,
  }) async {
    try {
      final Map<String, dynamic> args = {'baseUrls': baseUrls};
      if (appGroup != null) {
        args['appGroup'] = appGroup;
      }
      await _channel.invokeMethod('opencdpsdk_save_base_urls', args);
      debugPrint(
        '[CDP] Gateway host list saved to native storage (${baseUrls.length} hosts)',
      );
    } on PlatformException catch (e) {
      debugPrint('[CDP] Failed to save gateway hosts to native: ${e.message}');
    }
  }

  static Future<List<String>?> getGatewayHostsFromNative({
    String? appGroup,
  }) async {
    try {
      final Map<String, dynamic> args = {};
      if (appGroup != null) {
        args['appGroup'] = appGroup;
      }
      final raw = await _channel.invokeMethod<List<dynamic>>(
        'opencdpsdk_get_base_urls',
        args,
      );
      if (raw == null || raw.isEmpty) return null;
      return raw.map((e) => '$e').where((s) => s.trim().isNotEmpty).toList();
    } on PlatformException catch (e) {
      debugPrint('[CDP] Failed to get gateway hosts from native: ${e.message}');
      return null;
    }
  }

  static Future<void> clearGatewayHostsFromNative({
    String? appGroup,
  }) async {
    try {
      final Map<String, dynamic> args = {};
      if (appGroup != null) {
        args['appGroup'] = appGroup;
      }
      await _channel.invokeMethod('opencdpsdk_clear_base_urls', args);
      debugPrint('[CDP] Gateway host list cleared from native storage');
    } on PlatformException catch (e) {
      debugPrint(
        '[CDP] Failed to clear gateway hosts from native: ${e.message}',
      );
    }
  }

  /// Reads persisted host list or derives from single primary URL / SDK defaults.
  static Future<List<String>> resolveGatewayHostsFromNative({
    String? appGroup,
  }) async {
    final stored = await getGatewayHostsFromNative(appGroup: appGroup);
    if (stored != null && stored.isNotEmpty) {
      return stored;
    }
    final primary = await getBaseUrlFromNative(appGroup: appGroup);
    return CdpGatewayUrls.resolveAllBaseUrls(primaryOverride: primary);
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

  /// Render an actionable Android notification from push `data`.
  ///
  /// Returns `true` when the native side attempts to display the notification.
  /// This is a no-op on iOS/web.
  static Future<bool> showAndroidActionableNotification({
    required Map<String, dynamic> data,
    String channelName = 'CDP Notifications',
    String channelDescription = 'Push notifications from CDP',
  }) async {
    if (kDebugMode) {
      debugPrint(
        '[CDP] showAndroidActionableNotification keys=${data.keys.toList()} '
        'channel=$channelName',
      );
    }
    try {
      final result = await _channel.invokeMethod<bool>(
        'opencdpsdk_show_actionable_notification',
        {
          'data': data,
          'channelName': channelName,
          'channelDescription': channelDescription,
        },
      );
      if (kDebugMode) {
        debugPrint(
          '[CDP] showAndroidActionableNotification method channel result: $result',
        );
      }
      return result ?? false;
    } on PlatformException catch (e) {
      debugPrint(
        '[CDP] Failed to show native Android actionable notification: ${e.message}',
      );
      return false;
    }
  }
}
