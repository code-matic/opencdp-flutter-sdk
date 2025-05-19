import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:customer_io/customer_io.dart' as cio;
import 'package:open_cdp_flutter_sdk/src/models/config.dart';
import 'package:open_cdp_flutter_sdk/src/models/event_type.dart';
import 'package:open_cdp_flutter_sdk/src/constants/endpoints.dart';
import 'package:open_cdp_flutter_sdk/src/utils/http_client.dart';

/// Private implementation of the OpenCDP SDK
class OpenCDPSDKImplementation {
  final OpenCDPConfig config;
  final CDPHttpClient _httpClient;
  late SharedPreferences prefs;
  static String? _userId;
  static final _deviceInfo = DeviceInfoPlugin();
  static PackageInfo? _packageInfo;

  /// Private constructor
  OpenCDPSDKImplementation._({
    required this.config,
    required CDPHttpClient httpClient,
  }) : _httpClient = httpClient {
    _init();
  }

  /// Factory constructor
  static Future<OpenCDPSDKImplementation> create({
    required OpenCDPConfig config,
  }) async {
    final httpClient = CDPHttpClient(
      baseUrl: config.baseUrl,
      apiKey: config.cdpApiKey,
      debug: config.debug,
    );

    _packageInfo = await PackageInfo.fromPlatform();

    return OpenCDPSDKImplementation._(
      config: config,
      httpClient: httpClient,
    );
  }

  /// Get the current user ID
  String? get userId => _userId;

  Future<void> _init() async {
    prefs = await SharedPreferences.getInstance();
    _userId = prefs.getString('user_id');

    // Track device attributes if enabled
    if (config.autoTrackDeviceAttributes) {
      await _trackDeviceAttributes();
    }
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
    final normalizedProps = properties ?? {};

    try {
      await _httpClient.post(
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
    required String identifier,
    required String eventName,
    Map<String, dynamic> properties = const {},
    EventType type = EventType.custom,
  }) async {
    _validateIdentifier(identifier);
    _validateEventName(eventName);
    final normalizedProps = properties ?? {};

    try {
      await _httpClient.post(
        CDPEndpoints.track,
        {
          'identifier': identifier,
          'eventName': eventName,
          'properties': normalizedProps,
        },
        identifier: identifier,
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
            // case EventType.lifecycle:
            // case EventType.device:
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
    required String identifier,
    Map<String, dynamic> properties = const {},
  }) async {
    _validateIdentifier(identifier);

    try {
      await _httpClient.post(
        CDPEndpoints.update,
        {
          'identifier': identifier,
          'properties': properties,
        },
        identifier: identifier,
      );

      // Update in Customer.io if enabled
      if (config.sendToCustomerIo) {
        cio.CustomerIO.instance.identify(
          userId: identifier,
          traits: properties,
        );
      }
    } catch (e) {
      rethrow;
    }
  }

  /// Implementation of screen view tracking
  Future<void> trackScreenView({
    required String identifier,
    required String title,
    Map<String, dynamic> properties = const {},
  }) async {
    await trackEvent(
      identifier: identifier,
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
    required String identifier,
    required String eventName,
    Map<String, dynamic> properties = const {},
  }) async {
    await trackEvent(
      identifier: identifier,
      eventName: eventName,
      properties: properties,
      type: EventType.lifecycle,
    );
  }

  // /// Implementation of device event tracking
  // Future<void> trackDeviceEvent({
  //   required String identifier,
  //   required String eventName,
  //   Map<String, dynamic> properties = const {},
  // }) async {
  //   await trackEvent(
  //     identifier: identifier,
  //     eventName: eventName,
  //     properties: properties,
  //     type: EventType.device,
  //   );
  // }

  /// Implementation of device registration
  Future<void> registerDevice({
    required String identifier,
    String? fcmToken,
    String? apnToken,
  }) async {
    _validateIdentifier(identifier);

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

      if (Platform.isAndroid) {
        final androidInfo = await _deviceInfo.androidInfo;
        deviceAttributes.addAll({
          'device_manufacturer': androidInfo.manufacturer,
          'device_model': androidInfo.model,
          'os_version': androidInfo.version.release,
          'os_sdk': androidInfo.version.sdkInt.toString(),
          'deviceId': androidInfo.id,
        });
      } else if (Platform.isIOS) {
        final iosInfo = await _deviceInfo.iosInfo;
        deviceAttributes.addAll({
          'device_manufacturer': 'Apple',
          'device_model': iosInfo.model,
          'os_version': iosInfo.systemVersion,
          'os_name': iosInfo.systemName,
          'deviceId': iosInfo.identifierForVendor,
        });
      }

      await _httpClient.post(
        CDPEndpoints.registerDevice,
        {
          'deviceId': deviceAttributes['deviceId'],
          'name': deviceAttributes['device_manufacturer'],
          'platform': defaultTargetPlatform.toString().split('.').last,
          'osVersion': deviceAttributes['os_version'],
          'model': deviceAttributes['device_model'],
          'fcmToken': fcmToken,
          'apnToken': apnToken,
          'appVersion': deviceAttributes['app_version'],
          'last_active_at': DateTime.now().toUtc().toIso8601String(),
          'attributes': deviceAttributes,
        },
        identifier: identifier,
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
        identifier: _userId!,
        properties: deviceAttributes,
      );
    }
  }

  /// Dispose the SDK instance
  void dispose() {
    _httpClient.dispose();
  }
}
