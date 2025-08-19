import 'dart:async';
import 'dart:io';

import 'package:customer_io/customer_io.dart' as cio;
import 'package:device_info_plus/device_info_plus.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';

import 'package:open_cdp_flutter_sdk/src/constants/endpoints.dart';
import 'package:open_cdp_flutter_sdk/src/models/config.dart';
import 'package:open_cdp_flutter_sdk/src/models/event_type.dart';
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
    final client = httpClient ??
        CDPHttpClient(
          baseUrl: config.baseUrl,
          apiKey: config.cdpApiKey,
          debug: config.debug,
        );

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
  String get _currentIdentifierUnsafe {
    return _userId ?? _deviceId ?? 'unknown';
  }

  /// Validate identifier
  bool _validateIdentifier(String identifier) {
    if (identifier.trim().isEmpty) {
      if (config.debug) {
        debugPrint('[CDP] Identifier cannot be empty');
      }
      return false;
    }
    return true;
  }

  /// Validate event name
  bool _validateEventName(String eventName) {
    if (eventName.trim().isEmpty) {
      if (config.debug) {
        debugPrint('[CDP] Event name cannot be empty');
      }
      return false;
    }
    return true;
  }

  /// Implementation of user identification
  Future<void> identifyUser({
    required String identifier,
    Map<String, dynamic> properties = const {},
  }) async {
    try {
      if (!_ensureInitialized()) {
        return;
      }
      if (!_validateIdentifier(identifier)) {
        return;
      }
      final normalizedProps = properties;
      final response = await httpClient.post(
        CDPEndpoints.identify,
        {
          'identifier': identifier,
          'properties': normalizedProps,
        },
        identifier: identifier,
      );

      if (response == null) {
        if (config.debug) {
          debugPrint('[CDP] Failed to identify user: request returned null');
        }
        return;
      }

      _userId = identifier;
      await prefs.setString('user_id', identifier);

      // Track in Customer.io if enabled
      if (config.sendToCustomerIo) {
        cio.CustomerIO.instance.identify(
          userId: identifier,
          traits: normalizedProps,
        );
      }

      // Track device attributes if enabled
      if (config.autoTrackDeviceAttributes) {
        // await registerDevice(fcmToken: 'noAPNStoken', apnToken: 'noAPNStoken');
      }
    } catch (e) {
      // rethrow;
      if (config.debug) {
        debugPrint('[CDP] Error identifying user: $e');
      }
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

      final response = await httpClient.post(
        CDPEndpoints.track,
        {
          'identifier': _currentIdentifier,
          'eventName': eventName,
          'properties': normalizedProps,
        },
        identifier: _currentIdentifier,
      );

      if (response == null) {
        if (config.debug) {
          debugPrint('[CDP] Failed to track event: request returned null');
        }
        return;
      }

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
          if (config.debug) {
            debugPrint('[CDP] Customer.io track error: $e');
          }
        }
      }
    } catch (e) {
      if (config.debug) {
        debugPrint('[CDP] Error tracking event: $e');
      }
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
        deviceId = androidInfo.id;
        deviceAttributes.addAll({
          'device_manufacturer': androidInfo.manufacturer,
          'device_model': androidInfo.model,
          'os_version': androidInfo.version.release,
          'os_sdk': androidInfo.version.sdkInt.toString(),
        });
      } else if (Platform.isIOS) {
        final iosInfo = await _deviceInfo.iosInfo;
        platform = 'ios';
        deviceId = iosInfo.identifierForVendor ?? '';
        deviceAttributes.addAll({
          'device_manufacturer': 'Apple',
          'device_model': iosInfo.model,
          'os_version': iosInfo.systemVersion,
          'os_name': iosInfo.systemName,
        });
      } else {
        platform = 'web';
        deviceId = 'web-${DateTime.now().millisecondsSinceEpoch}';
      }

      final response = await httpClient.post(
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

      if (response == null) {
        if (config.debug) {
          debugPrint('[CDP] Failed to register device: request returned null');
        }
        return;
      }
    } catch (e) {
      if (config.debug) {
        debugPrint('[CDP] Error registering device: $e');
      }
    }
  }

  /// Track device attributes automatically
  // Future<void> _trackDeviceAttributes() async {
  //   try {
  //     if (_packageInfo == null) return;

  //     final deviceAttributes = {
  //       'app_version': _packageInfo!.version,
  //       'app_build': _packageInfo!.buildNumber,
  //       'app_package': _packageInfo!.packageName,
  //     };

  //     if (Platform.isAndroid) {
  //       final androidInfo = await _deviceInfo.androidInfo;
  //       deviceAttributes.addAll({
  //         'device_manufacturer': androidInfo.manufacturer,
  //         'device_model': androidInfo.model,
  //         'os_version': androidInfo.version.release,
  //         'os_sdk': androidInfo.version.sdkInt.toString(),
  //       });
  //     } else if (Platform.isIOS) {
  //       final iosInfo = await _deviceInfo.iosInfo;
  //       deviceAttributes.addAll({
  //         'device_manufacturer': 'Apple',
  //         'device_model': iosInfo.model,
  //         'os_version': iosInfo.systemVersion,
  //         'os_name': iosInfo.systemName,
  //       });
  //     }

  //     if (_userId != null) {
  //       final response = await httpClient.post(
  //         CDPEndpoints.update,
  //         {
  //           'identifier': _currentIdentifierUnsafe,
  //           'properties': deviceAttributes,
  //         },
  //         identifier: _currentIdentifierUnsafe,
  //       );

  //       if (response == null && config.debug) {
  //         debugPrint(
  //             '[CDP] Failed to track device attributes: request returned null');
  //       }
  //     }
  //   } catch (e) {
  //     if (config.debug) {
  //       debugPrint('[CDP] Error tracking device attributes: $e');
  //     }
  //   }
  // }

  /// Dispose the SDK instance
  void dispose() {
    httpClient.dispose();
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

      // Finally clear Customer.io identity if enabled
      if (config.sendToCustomerIo) {
        try {
          cio.CustomerIO.instance.clearIdentify();
        } catch (e) {
          if (config.debug) {
            debugPrint('[CDP] Customer.io clear identity error: $e');
          }
        }
      }

      if (config.debug) {
        debugPrint('[CDP] Identity cleared successfully');
      }
    } catch (e) {
      if (config.debug) {
        debugPrint('[CDP] Error clearing identity: $e');
      }
    }
  }
}
