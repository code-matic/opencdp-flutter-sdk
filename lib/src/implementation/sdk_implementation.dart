import 'dart:async';
import 'dart:io';

import 'package:customer_io/customer_io.dart' as cio;
import 'package:device_info_plus/device_info_plus.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:meta/meta.dart';

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

  /// Private constructor
  OpenCDPSDKImplementation._({
    required this.config,
    required this.httpClient,
  }) {
    _init();
  }

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

    return OpenCDPSDKImplementation._(
      config: config,
      httpClient: client,
    );
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

    // Track device attributes if enabled
    if (config.autoTrackDeviceAttributes) {
      await _trackDeviceAttributes();
    }
  }

  /// Get the current identifier (userId if identified, deviceId if not)
  String get _currentIdentifier {
    return _userId ?? _deviceId ?? 'unknown';
  }

  /// Validate identifier
  void _validateIdentifier(String identifier) {
    if (identifier.trim().isEmpty) {
      throw Exception('Identifier cannot be empty');
    }
  }

  /// Validate event name
  void _validateEventName(String eventName) {
    if (eventName.trim().isEmpty) {
      throw Exception('Event name cannot be empty');
    }
  }

  /// Implementation of user identification
  Future<void> identifyUser({
    required String identifier,
    Map<String, dynamic> properties = const {},
  }) async {
    _validateIdentifier(identifier);
    final normalizedProps = properties;

    try {
      await httpClient.post(
        CDPEndpoints.identify,
        {
          'identifier': identifier,
          'properties': normalizedProps,
        },
        identifier: identifier,
      );

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
        await _trackDeviceAttributes();
      }
    } catch (e) {
      rethrow;
    }
  }

  /// Implementation of event tracking
  Future<void> trackEvent({
    required String eventName,
    Map<String, dynamic> properties = const {},
    EventType type = EventType.custom,
  }) async {
    _validateEventName(eventName);
    final normalizedProps = properties;

    try {
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
      }
    } catch (e) {
      rethrow;
    }
  }

  /// Implementation of user properties update
  Future<void> updateUserProperties({
    required Map<String, dynamic> properties,
  }) async {
    try {
      await httpClient.post(
        CDPEndpoints.update,
        {
          'identifier': _currentIdentifier,
          'properties': properties,
        },
        identifier: _currentIdentifier,
      );

      // Update in Customer.io if enabled
      if (config.sendToCustomerIo) {
        cio.CustomerIO.instance.identify(
          userId: _currentIdentifier,
          traits: properties,
        );
      }
    } catch (e) {
      rethrow;
    }
  }

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

      // Register device in Customer.io if enabled
      if (config.sendToCustomerIo) {
        if (fcmToken != null) {
          cio.CustomerIO.instance.registerDeviceToken(deviceToken: fcmToken);
        }
        if (apnToken != null) {
          cio.CustomerIO.instance.registerDeviceToken(deviceToken: apnToken);
        }
      }
    } catch (e) {
      rethrow;
    }
  }

  /// Track device attributes automatically
  Future<void> _trackDeviceAttributes() async {
    if (_packageInfo == null) return;

    final deviceAttributes = {
      'app_version': _packageInfo!.version,
      'app_build': _packageInfo!.buildNumber,
      'app_package': _packageInfo!.packageName,
    };

    if (Platform.isAndroid) {
      final androidInfo = await _deviceInfo.androidInfo;
      deviceAttributes.addAll({
        'device_manufacturer': androidInfo.manufacturer,
        'device_model': androidInfo.model,
        'os_version': androidInfo.version.release,
        'os_sdk': androidInfo.version.sdkInt.toString(),
      });
    } else if (Platform.isIOS) {
      final iosInfo = await _deviceInfo.iosInfo;
      deviceAttributes.addAll({
        'device_manufacturer': 'Apple',
        'device_model': iosInfo.model,
        'os_version': iosInfo.systemVersion,
        'os_name': iosInfo.systemName,
      });
    }

    if (_userId != null) {
      await updateUserProperties(
        properties: deviceAttributes,
      );
    }
  }

  /// Dispose the SDK instance
  void dispose() {
    httpClient.dispose();
  }

  /// Set a custom HTTP client
  void setHttpClient(dynamic client) {
    httpClient = client;
  }
}
