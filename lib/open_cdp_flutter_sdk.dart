import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:customer_io/customer_io.dart' as cio;
import 'package:customer_io/customer_io_config.dart' as cio_config;
import 'package:customer_io/customer_io_enums.dart' as cio_enums;
import 'src/models/config.dart';
import 'src/constants/endpoints.dart';
import 'src/utils/http_client.dart';
import 'src/utils/screen_tracker.dart';

/// Main SDK class for Open CDP
class OpenCDPSDK {
  static OpenCDPSDK? _instance;
  static OpenCDPConfig? _config;
  static String? _userId;
  static final _deviceInfo = DeviceInfoPlugin();
  static PackageInfo? _packageInfo;
  static CDPScreenTracker? _screenTracker;

  /// Get the singleton instance of the SDK
  static OpenCDPSDK get instance {
    if (_instance == null) {
      throw StateError('SDK not initialized. Call initialize() first.');
    }
    return _instance!;
  }

  /// Get the current user ID
  String? get userId => _userId;

  /// Get the screen tracker if auto tracking is enabled
  CDPScreenTracker? get screenTracker => _screenTracker;

  /// Initialize the SDK with configuration
  static Future<void> initialize({required OpenCDPConfig config}) async {
    if (_instance != null) {
      throw StateError('SDK already initialized');
    }

    _config = config;
    _instance = OpenCDPSDK._();
    _packageInfo = await PackageInfo.fromPlatform();

    // Initialize Customer.io if configured
    if (config.sendToCustomerIo && config.customerIo != null) {
      final cioConfig = cio_config.CustomerIOConfig(
        cdpApiKey: config.customerIo!.apiKey,
        inAppConfig: config.customerIo!.inAppConfig,
        migrationSiteId: config.customerIo!.migrationSiteId,
        region: config.customerIo!.region == 'us'
            ? cio_enums.Region.us
            : cio_enums.Region.eu,
        autoTrackDeviceAttributes: config.customerIo!.autoTrackDeviceAttributes,
        pushConfig: config.customerIo!.pushConfig,
      );

      await cio.CustomerIO.initialize(config: cioConfig);
    }

    // Initialize screen tracker if auto tracking is enabled
    if (config.autoTrackScreens) {
      _screenTracker = CDPScreenTracker(
        sdk: _instance!,
        debug: config.debug,
      );
    }

    // Track device attributes if enabled
    if (config.autoTrackDeviceAttributes) {
      await _instance!._trackDeviceAttributes();
    }
  }

  final OpenCDPConfig config;
  final CDPHttpClient _httpClient;
  late SharedPreferences prefs;

  /// Private constructor
  OpenCDPSDK._()
      : _httpClient = CDPHttpClient(
          baseUrl: _config!.baseUrl,
          apiKey: _config!.cdpApiKey,
          debug: _config!.debug,
        ),
        config = _config! {
    _init();
  }

  Future<void> _init() async {
    prefs = await SharedPreferences.getInstance();
    _userId = prefs.getString('user_id');

    // Track device attributes if enabled
    if (config.autoTrackDeviceAttributes) {
      await _trackDeviceAttributes();
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
      await update(_userId!, deviceAttributes);
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

  /// Identify a user with optional traits
  Future<void> identify(String identifier,
      {Map<String, dynamic>? properties}) async {
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

      // Track device attributes if enabled
      if (config.autoTrackDeviceAttributes) {
        await _trackDeviceAttributes();
      }
    } catch (e) {
      rethrow;
    }
  }

  /// Track an event with optional properties
  Future<void> track(String identifier, String eventName,
      {Map<String, dynamic>? properties}) async {
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
    } catch (e) {
      rethrow;
    }
  }

  /// Update properties for a user
  Future<void> update(
      String identifier, Map<String, dynamic> properties) async {
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
    } catch (e) {
      rethrow;
    }
  }

  /// Track a screen view with optional properties
  Future<void> screen(String identifier, String title,
      {Map<String, dynamic> properties = const {}}) async {
    await track(
      identifier,
      'screen_view',
      properties: {
        'screen': title,
        ...properties,
      },
    );
  }

  /// Register a device token for push notifications
  Future<void> registerDeviceToken(String identifier, String token) async {
    _validateIdentifier(identifier);

    try {
      await _httpClient.post(
        CDPEndpoints.deviceToken,
        {
          'identifier': identifier,
          'token': token,
          'platform': defaultTargetPlatform.toString().split('.').last,
        },
        identifier: identifier,
      );
    } catch (e) {
      rethrow;
    }
  }

  /// Dispose the SDK instance
  void dispose() {
    _httpClient.dispose();
  }
}
