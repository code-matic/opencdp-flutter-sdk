import 'dart:async';
import 'dart:io';

import 'package:customer_io/customer_io.dart' as cio;
import 'package:device_info_plus/device_info_plus.dart';
import 'package:open_cdp_flutter_sdk/src/implementation/native_bridge.dart';
import 'package:open_cdp_flutter_sdk/src/models/metric_event.dart';
import 'package:open_cdp_flutter_sdk/src/models/in_app_message.dart';
import 'package:open_cdp_flutter_sdk/src/utils/hash_generator.dart';
import 'package:open_cdp_flutter_sdk/src/utils/push_notification_tracker.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';

import 'package:open_cdp_flutter_sdk/src/constants/endpoints.dart';
import 'package:open_cdp_flutter_sdk/src/models/config.dart';
import 'package:open_cdp_flutter_sdk/src/models/event_type.dart';
import 'package:open_cdp_flutter_sdk/src/models/validation_exception.dart';
import 'package:open_cdp_flutter_sdk/src/utils/http_client.dart';

/// Private implementation of the OpenCDP SDK
class OpenCDPSDKImplementation {
  final OpenCDPConfig config;
  @visibleForTesting
  CDPHttpClient httpClient;
  late SharedPreferences prefs;
  static String? _userId;
  static String? _deviceId;
  static final _deviceInfo = DeviceInfoPlugin();
  static PackageInfo? _packageInfo;
  bool _isInitialized = false;

  /// Private constructor
  OpenCDPSDKImplementation._({
    required this.config,
    required this.httpClient,
  });

  /// Factory constructor
  static Future<OpenCDPSDKImplementation> create({
    required OpenCDPConfig config,
    CDPHttpClient? httpClient,
  }) async {
    final CDPHttpClient client = httpClient ??
        (await CDPHttpClient.create(
          baseUrl: config.baseUrl,
          apiKey: config.cdpApiKey,
          debug: config.debug,
        ));

    _packageInfo = await PackageInfo.fromPlatform();

    final implementation = OpenCDPSDKImplementation._(
      config: config,
      httpClient: client,
    );

    await implementation._init();
    return implementation;
  }

  /// Get the current user ID
  String? get userId => _userId;

  Future<void> _init() async {
    prefs = await SharedPreferences.getInstance();
    _userId = prefs.getString('user_id');
    _deviceId = prefs.getString('device_id');

    // Get device ID if not already stored
    if (_deviceId == null) {
      if (Platform.isAndroid) {
        final androidInfo = await _deviceInfo.androidInfo;
        _deviceId = androidInfo.id;
      } else if (Platform.isIOS) {
        final iosInfo = await _deviceInfo.iosInfo;
        _deviceId = iosInfo.identifierForVendor;
      }
      if (_deviceId != null) {
        await prefs.setString('device_id', _deviceId!);
      }
    }

    _isInitialized = true;

    // // Track device attributes if enabled - moved after initialization
    // if (config.autoTrackDeviceAttributes) {
    //   await _trackDeviceAttributes();
    // }
  }

  /// Ensure SDK is initialized
  bool _ensureInitialized() {
    if (!_isInitialized) {
      if (config.debug) {
        debugPrint('[CDP] SDK not initialized. Call initialize() first.');
      }
      return false;
    }
    return true;
  }

  /// Get the current identifier (userId if identified, deviceId if not)
  String get _currentIdentifier {
    if (!_ensureInitialized()) {
      return 'unknown';
    }
    return _userId ?? _deviceId ?? 'unknown';
  }

  /// Get the current identifier without initialization check
  // String get _currentIdentifierUnsafe {
  //   return _userId ?? _deviceId ?? 'unknown';
  // }

  /// Validate identifier
  bool _validateIdentifier(String identifier) {
    if (identifier.trim().isEmpty) {
      const errorMessage = 'Identifier cannot be empty';
      if (config.throwErrorsBack) {
        throw CDPValidationException(errorMessage, 'identifier');
      }
      if (config.debug) {
        debugPrint('[CDP] $errorMessage');
      }
      return false;
    }
    // Check if identifier is an email address
    final emailRegex = RegExp(
      r'^[^\s@]+@[^\s@]+\.[^\s@]+$',
      caseSensitive: false,
    );
    if (emailRegex.hasMatch(identifier.trim())) {
      const errorMessage = 'Identifier cannot be an email address';
      if (config.throwErrorsBack) {
        throw CDPValidationException(errorMessage, 'identifier');
      }
      if (config.debug) {
        debugPrint('[CDP] $errorMessage');
      }
      return false;
    }
    return true;
  }

  /// Validate event name
  bool _validateEventName(String eventName) {
    if (eventName.trim().isEmpty) {
      const errorMessage = 'Event name cannot be empty';
      if (config.throwErrorsBack) {
        throw CDPValidationException(errorMessage, 'eventName');
      }
      if (config.debug) {
        debugPrint('[CDP] $errorMessage');
      }
      return false;
    }
    return true;
  }

  /// Validate customerIoId
  bool _validateCustomerIoId(String? customerIoId) {
    if (customerIoId == null) return true; // Optional, so null is valid

    if (customerIoId.trim().isEmpty) {
      const errorMessage = 'customerIoId cannot be empty if provided';
      if (config.throwErrorsBack) {
        throw CDPValidationException(errorMessage, 'customerIoId');
      }
      if (config.debug) {
        debugPrint('[CDP] $errorMessage');
      }
      return false;
    }
    return true;
  }

  /// Validate push token (FCM or APN)
  bool _validatePushToken(String? token, String tokenType) {
    if (token == null) return true; // Optional, so null is valid

    if (token.trim().isEmpty) {
      final errorMessage = '$tokenType cannot be empty if provided';
      if (config.throwErrorsBack) {
        throw CDPValidationException(errorMessage, tokenType);
      }
      if (config.debug) {
        debugPrint('[CDP] $errorMessage');
      }
      return false;
    }
    return true;
  }

  /// Standard error handling for SDK public methods
  void _handleError(String operation, dynamic error) {
    if (config.throwErrorsBack &&
        (error is CDPValidationException || error is CDPException)) {
      throw error;
    }

    if (config.debug) {
      debugPrint('[CDP] $operation: $error');
    }
  }

  /// Error handling for nested integrations (like Customer.io)
  /// Never rethrows - nested integrations should never block the main flow
  void _handleNestedError(String operation, dynamic error) {
    if (config.debug) {
      debugPrint('[CDP] $operation: $error');
    }
  }

  /// Implementation of user identification
  ///
  /// Identifies a user in the CDP and optionally in Customer.io.
  ///
  /// [identifier] - Unique user identifier (must NOT be an email address)
  /// [properties] - Optional user properties/traits
  /// [customerIoId] - Optional Customer.io-specific identifier for dual-write.
  ///   If provided, this ID is used for Customer.io while [identifier] is used
  ///   for CDP API calls and native storage. Useful for clients using email as
  ///   their Customer.io ID while maintaining a non-email identifier for CDP.
  Future<void> identifyUser({
    required String identifier,
    Map<String, dynamic> properties = const {},
    String? customerIoId,
  }) async {
    try {
      if (!_ensureInitialized()) {
        return;
      }
      if (!_validateIdentifier(identifier)) {
        return;
      }
      if (!_validateCustomerIoId(customerIoId)) {
        return;
      }
      final normalizedProps = properties;
      await httpClient.post(
        CDPEndpoints.identify,
        {
          'identifier': identifier,
          'properties': normalizedProps,
        },
        identifier: identifier,
      );

      // The response can't be null, so no need to check for null here.

      _userId = identifier;
      await prefs.setString('user_id', identifier);

      // Store in native storage for push notification handling in background
      // For iOS, we pass the app group
      // For Android, app group is not required
      await NativeBridge.saveUserIdToNative(
        userId: identifier,
        appGroup: config.appGroup,
      );

      // Track in Customer.io if enabled
      if (config.sendToCustomerIo) {
        try {
          // Use customer_io_id if provided and not empty, otherwise fall back to identifier
          final cioUserId =
              (customerIoId != null && customerIoId.trim().isNotEmpty)
                  ? customerIoId
                  : _currentIdentifier;
          cio.CustomerIO.instance.identify(
            userId: cioUserId,
            traits: normalizedProps,
          );
        } catch (e) {
          _handleNestedError('Customer.io identify error', e);
        }
      }
    } catch (e) {
      _handleError('Error identifying user', e);
    }
  }

  /// Implementation of event tracking
  Future<void> trackEvent({
    required String eventName,
    Map<String, dynamic> properties = const {},
    EventType type = EventType.custom,
  }) async {
    try {
      if (!_ensureInitialized()) {
        return;
      }
      if (!_validateEventName(eventName)) {
        return;
      }
      final normalizedProps = properties;

      await httpClient.post(
        CDPEndpoints.track,
        {
          'identifier': _currentIdentifier,
          'eventName': eventName,
          'properties': normalizedProps,
        },
        identifier: _currentIdentifier,
      );

      // Track in Customer.io if enabled
      if (config.sendToCustomerIo) {
        try {
          switch (type) {
            case EventType.screenView:
              cio.CustomerIO.instance.screen(
                title: eventName,
                properties: normalizedProps,
              );
              break;
            case EventType.custom:
            case EventType.lifecycle:
            case EventType.device:
              cio.CustomerIO.instance.track(
                name: eventName,
                properties: normalizedProps,
              );
              break;
          }
        } catch (e) {
          _handleNestedError('Customer.io track error', e);
        }
      }
    } catch (e) {
      _handleError('Error tracking event', e);
    }
  }

  // /// Implementation of user properties update
  // Future<void> updateUserProperties({
  //   required Map<String, dynamic> properties,
  // }) async {
  //   try {
  //     if (!_ensureInitialized()) {
  //       return;
  //     }
  //     final response = await httpClient.post(
  //       CDPEndpoints.update,
  //       {
  //         'identifier': _currentIdentifier,
  //         'properties': properties,
  //       },
  //       identifier: _currentIdentifier,
  //     );

  //     if (response == null) {
  //       if (config.debug) {
  //         debugPrint(
  //             '[CDP] Failed to update user properties: request returned null');
  //       }
  //       return;
  //     }

  //     // Update in Customer.io if enabled
  //     if (config.sendToCustomerIo) {
  //       try {
  //         cio.CustomerIO.instance.identify(
  //           userId: _currentIdentifier,
  //           traits: properties,
  //         );
  //       } catch (e) {
  //         if (config.debug) {
  //           debugPrint('[CDP] Customer.io update error: $e');
  //         }
  //       }
  //     }
  //   } catch (e) {
  //     if (config.debug) {
  //       debugPrint('[CDP] Error updating user properties: $e');
  //     }
  //   }
  // }

  /// Implementation of screen view tracking
  Future<void> trackScreenView({
    required String title,
    Map<String, dynamic> properties = const {},
  }) async {
    await trackEvent(
      eventName: 'screen_view',
      properties: {
        'screen': title,
        ...properties,
      },
      type: EventType.screenView,
    );
  }

  Future<List<InAppMessage>> syncInAppMessages({
    required String screen,
    required String sessionId,
    required String platform,
    required String appVersion,
    int limit = 10,
    String? personId,
  }) async {
    try {
      if (!_ensureInitialized()) {
        return [];
      }
      final response = await httpClient.get(
        CDPEndpoints.inAppSync,
        query: {
          'person_id': personId ?? _currentIdentifier,
          'screen': screen,
          'session_id': sessionId,
          'platform': platform,
          'app_version': appVersion,
          'limit': limit,
        },
      );

      final data = (response['data'] as Map<String, dynamic>?) ?? {};
      final rawMessages = (data['messages'] as List?) ?? [];
      return rawMessages
          .map((raw) => InAppMessage.fromJson((raw as Map).cast<String, dynamic>()))
          .toList();
    } catch (e) {
      _handleError('Error syncing in-app messages', e);
      return [];
    }
  }

  Future<void> trackInAppImpression({
    required String deliveryId,
    required String sessionId,
    required String screen,
    required String platform,
    required String appVersion,
    String? personId,
  }) async {
    await _trackInAppInteraction(
      endpoint: CDPEndpoints.inAppImpression(deliveryId),
      body: {
        'person_id': personId ?? _currentIdentifier,
        'session_id': sessionId,
        'screen': screen,
        'platform': platform,
        'app_version': appVersion,
        'ts': DateTime.now().toUtc().toIso8601String(),
      },
      operation: 'impression',
    );
  }

  Future<void> trackInAppClick({
    required String deliveryId,
    required String actionId,
    required String sessionId,
    required String screen,
    String? personId,
  }) async {
    await _trackInAppInteraction(
      endpoint: CDPEndpoints.inAppClick(deliveryId),
      body: {
        'person_id': personId ?? _currentIdentifier,
        'session_id': sessionId,
        'screen': screen,
        'action_id': actionId,
        'ts': DateTime.now().toUtc().toIso8601String(),
      },
      operation: 'click',
    );
  }

  Future<void> trackInAppDismiss({
    required String deliveryId,
    required String reason,
    required String sessionId,
    required String screen,
    String? personId,
  }) async {
    await _trackInAppInteraction(
      endpoint: CDPEndpoints.inAppDismiss(deliveryId),
      body: {
        'person_id': personId ?? _currentIdentifier,
        'session_id': sessionId,
        'screen': screen,
        'reason': reason,
        'ts': DateTime.now().toUtc().toIso8601String(),
      },
      operation: 'dismiss',
    );
  }

  Future<void> _trackInAppInteraction({
    required String endpoint,
    required Map<String, dynamic> body,
    required String operation,
  }) async {
    try {
      if (!_ensureInitialized()) {
        return;
      }
      await httpClient.post(endpoint, body, identifier: body['person_id'] as String?);
    } catch (e) {
      _handleError('Error tracking in-app $operation', e);
    }
  }

  /// Implementation of lifecycle event tracking
  Future<void> trackLifecycleEvent({
    required String eventName,
    Map<String, dynamic> properties = const {},
  }) async {
    await trackEvent(
      eventName: eventName,
      properties: properties,
      type: EventType.lifecycle,
    );
  }

  /// Implementation of device registration
  Future<void> registerDevice({
    String? fcmToken,
    String? apnToken,
  }) async {
    try {
      if (!_ensureInitialized()) {
        return;
      }
      if (!_validatePushToken(fcmToken, 'fcmToken')) {
        return;
      }
      if (!_validatePushToken(apnToken, 'apnToken')) {
        return;
      }
      // Get device attributes
      final deviceAttributes = <String, dynamic>{};

      if (_packageInfo != null) {
        deviceAttributes.addAll({
          'app_version': _packageInfo!.version,
          'app_build': _packageInfo!.buildNumber,
          'app_package': _packageInfo!.packageName,
        });
      }

      String platform;
      String deviceId;

      if (Platform.isAndroid) {
        final androidInfo = await _deviceInfo.androidInfo;
        platform = 'android';
        final getdeviceId =
            '${androidInfo.model}-${androidInfo.manufacturer}-$_currentIdentifier';
        //hash to make deviceId unique per user
        deviceId = generateMd5Hash(getdeviceId);

        deviceAttributes.addAll({
          'device_manufacturer': androidInfo.manufacturer,
          'device_model': androidInfo.model,
          'os_version': androidInfo.version.release,
          'os_sdk': androidInfo.version.sdkInt.toString(),
        });
      } else if (Platform.isIOS) {
        final iosInfo = await _deviceInfo.iosInfo;

        platform = 'ios';

        final getdeviceId =
            '${iosInfo.modelName}-${'Apple'}-$_currentIdentifier';
        deviceId = generateMd5Hash(getdeviceId);
        deviceAttributes.addAll({
          'device_manufacturer': 'Apple',
          'device_model': iosInfo.modelName,
          'os_version': iosInfo.systemVersion,
          'os_name': iosInfo.systemName,
        });
      } else {
        platform = 'web';
        deviceId = 'web-${DateTime.now().millisecondsSinceEpoch}';
      }

      await httpClient.post(
        CDPEndpoints.registerDevice,
        {
          'identifier': _currentIdentifier,
          'deviceId': deviceId,
          'name': deviceAttributes['device_manufacturer'],
          'platform': platform,
          'osVersion': deviceAttributes['os_version'],
          'model': deviceAttributes['device_model'],
          'fcmToken': fcmToken,
          'apnToken': apnToken,
          'appVersion': deviceAttributes['app_version'],
          'attributes': deviceAttributes,
        },
        identifier: _currentIdentifier,
      );
    } catch (e) {
      _handleError('Error registering device', e);
    }
  }

  /// Implementation of push notification tracking

  static Future<void> trackBackgroundPushNotificationMetric(
      MetricEvent event,
      String deliveryMessageId,
      String deliverySendContext,
      String deliverySendContextId,
      bool isBackground,
      {String? appGroup,
      String? apiKeyOverride,
      String? baseUrlOverride,
      String? actionId}) async {
    try {
      // Determine the API key based on context
      String? apiKey;
      if (isBackground) {
        // If provided directly, use the override
        if (apiKeyOverride != null && apiKeyOverride.isNotEmpty) {
          apiKey = apiKeyOverride;
        } else {
          // For background operations, get API key from native storage
          // This works for both iOS (with appGroup) and Android
          apiKey = await NativeBridge.getApiKeyFromNative(
            appGroup: appGroup, // Optional app group for iOS
          );
        }
      } else {
        // For non-background, we should be getting the apiKey from the instance that calls this
        apiKey = apiKeyOverride;
      }

      if (apiKey == null || apiKey.isEmpty) {
        debugPrint('[CDP] Missing API key for push tracking.');
        return;
      }

      String? resolvedBase = baseUrlOverride;
      if (resolvedBase == null || resolvedBase.trim().isEmpty) {
        if (isBackground) {
          resolvedBase = await NativeBridge.getBaseUrlFromNative(
            appGroup: appGroup,
          );
        }
      }
      if (resolvedBase == null || resolvedBase.trim().isEmpty) {
        resolvedBase = CDPEndpoints.baseUrl;
      }
      final String baseUrl = resolvedBase;

      // Get the user ID
      String? personId;
      if (isBackground) {
        // For background operations, get user ID from native storage
        personId = await NativeBridge.getUserIdFromNative(
          appGroup: appGroup, // Optional app group for iOS
        );
      } else {
        personId = _userId;
      }

      // For background operations, fire-and-forget might be more appropriate
      // to avoid keeping the background task alive unnecessarily
      if (isBackground) {
        PushNotificationTracker.sendMetricAndForget(
          apiKey,
          baseUrl,
          event,
          deliveryMessageId,
          deliverySendContext: deliverySendContext,
          deliverySendContextId: deliverySendContextId,
          personId: personId,
          isBackground: true,
          appGroup: appGroup,
          actionId: actionId,
        );
      } else {
        await PushNotificationTracker.sendMetric(
          apiKey,
          baseUrl,
          event,
          deliveryMessageId,
          deliverySendContext: deliverySendContext,
          deliverySendContextId: deliverySendContextId,
          personId: personId,
          isBackground: false,
          actionId: actionId,
        );
      }
    } catch (e, st) {
      debugPrint('[CDP] Error tracking push metric: $e\n$st');
    }
  }

  Future<void> trackPushNotificationMetric(
    MetricEvent event,
    String deliveryMessageId,
    bool isBackground,
    String deliverySendContext,
    String deliverySendContextId, {
    String? actionId,
  }) async {
    try {
      // Use the enhanced tracking with retries
      await PushNotificationTracker.sendMetric(
        config.cdpApiKey,
        config.baseUrl,
        event,
        deliveryMessageId,
        isBackground: isBackground,
        appGroup: config.appGroup,
        deliverySendContext: deliverySendContext,
        personId: _userId,
        deliverySendContextId: deliverySendContextId,
        actionId: actionId,
      );
    } catch (e, st) {
      debugPrint('[CDP] Error tracking push metric: $e\n$st');
    }
  }

  /// Dispose the SDK instance
  void dispose() {
    // Dispose HTTP client resources
    httpClient.dispose();

    // Reset instance state
    _isInitialized = false;

    // Note: We don't clear static variables here as that's handled by resetStaticVariables()
    // which should be called during reinitialization
  }

  /// Set a custom HTTP client
  void setHttpClient(dynamic client) {
    httpClient = client;
  }

  /// Clear the current identity and flush all pending requests
  ///
  /// This method:
  /// - Flushes any pending requests in the queue
  /// - Clears the stored user ID
  /// - Clears persistent storage
  /// - Returns immediately without making any new network requests
  Future<void> clearIdentity() async {
    try {
      if (!_ensureInitialized()) {
        return;
      }

      // First, flush the request queue to try to send any pending requests
      // for the current user before clearing everything
      await httpClient.clearIdentity();

      // Then clear user ID from memory and storage
      _userId = null;
      await prefs.remove('user_id');

      // Clear from native storage for background push notification handling
      // Works for both iOS and Android with the updated method
      await NativeBridge.clearUserIdFromNative(
        appGroup: config.appGroup,
      );

      await NativeBridge.clearBaseUrlFromNative(
        appGroup: config.appGroup,
      );

      // Finally clear Customer.io identity if enabled
      if (config.sendToCustomerIo) {
        try {
          cio.CustomerIO.instance.clearIdentify();
        } catch (e) {
          _handleNestedError('Customer.io clear identity error', e);
        }
      }

      if (config.debug) {
        debugPrint('[CDP] Identity cleared successfully');
      }
    } catch (e) {
      _handleError('Error clearing identity', e);
    }
  }

  /// Reset all static variables for reinitialization
  /// This should be called when reinitializing the SDK
  static void resetStaticVariables() {
    _userId = null;
    _deviceId = null;
    _packageInfo = null;

    // Also clear resources in the PushNotificationTracker
    PushNotificationTracker.dispose();
  }
}
