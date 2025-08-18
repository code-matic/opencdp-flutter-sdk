import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:open_cdp_flutter_sdk/open_cdp_flutter_sdk.dart';
import 'package:open_cdp_flutter_sdk/src/constants/endpoints.dart';
import 'package:open_cdp_flutter_sdk/src/utils/http_client.dart';

/// A test HTTP client that records requests and can simulate failures.
class TestHttpClient extends CDPHttpClient {
  final List<Map<String, dynamic>> requests = [];
  bool shouldFail = false;

  /// Creates a new test HTTP client.
  TestHttpClient()
      : super(
          baseUrl: 'https://test.api.opencdp.com',
          apiKey: 'test_key',
        );

  /// Records the request and returns a success response unless [shouldFail] is true.
  @override
  Future<Map<String, dynamic>> post(String endpoint, Map<String, dynamic> body,
      {String? identifier}) async {
    if (shouldFail) {
      throw CDPException('API call failed');
    }
    requests.add({
      'endpoint': endpoint,
      'body': body,
      'identifier': identifier,
    });
    return {'success': true};
  }

  /// Cleans up resources.
  @override
  void dispose() {}
}

/// Helper class for initializing the SDK in tests.
class TestSDKHelper {
  /// Initializes the SDK with the given configuration and HTTP client.
  ///
  /// [autoTrackScreens] enables automatic screen tracking if true.
  /// [trackApplicationLifecycleEvents] enables lifecycle event tracking if true.
  /// [autoTrackDeviceAttributes] enables automatic device attribute tracking if true.
  /// [sendToCustomerIo] enables sending data to Customer.io if true.
  /// [httpClient] is an optional HTTP client to use. If not provided, a new one is created.
  static Future<OpenCDPSDK> initializeSDK({
    bool autoTrackScreens = false,
    bool trackApplicationLifecycleEvents = false,
    bool autoTrackDeviceAttributes = false,
    bool sendToCustomerIo = false,
    CDPHttpClient? httpClient,
  }) async {
    OpenCDPSDK.resetForTest();
    await OpenCDPSDK.initialize(
      config: OpenCDPConfig(
        cdpApiKey: 'test_key',
        debug: true,
        autoTrackScreens: autoTrackScreens,
        trackApplicationLifecycleEvents: trackApplicationLifecycleEvents,
        autoTrackDeviceAttributes: autoTrackDeviceAttributes,
        sendToCustomerIo: sendToCustomerIo,
      ),
      httpClient: httpClient,
    );
    return OpenCDPSDK.instance;
  }
}

void main() {
  late TestHttpClient httpClient;
  late OpenCDPSDK sdk;

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    // Mock shared_preferences
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/shared_preferences'),
      (MethodCall methodCall) async {
        if (methodCall.method == 'getAll') {
          return <String, dynamic>{'flutter.device_id': 'test_device_id'};
        } else if (methodCall.method == 'setString' ||
            methodCall.method == 'setValue') {
          return true;
        }
        return null;
      },
    );
    // Mock package_info_plus
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('dev.fluttercommunity.plus/package_info'),
      (MethodCall methodCall) async {
        if (methodCall.method == 'getAll') {
          return <String, dynamic>{
            'appName': 'TestApp',
            'packageName': 'com.example.test',
            'version': '1.0.0',
            'buildNumber': '1',
          };
        }
        return null;
      },
    );
    // Mock device_info_plus
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('dev.fluttercommunity.plus/device_info'),
      (MethodCall methodCall) async {
        if (methodCall.method == 'getAndroidDeviceInfo') {
          return {
            'id': 'test_device_id',
            'manufacturer': 'Test Manufacturer',
            'model': 'Test Model',
            'version': {'release': '1.0', 'sdkInt': 30},
          };
        }
        return null;
      },
    );
  });

  setUp(() async {
    httpClient = TestHttpClient();
    OpenCDPSDK.resetForTest();
    sdk = await TestSDKHelper.initializeSDK(httpClient: httpClient);
  });

  tearDown(() {
    httpClient.dispose();
  });

  group('OpenCDPSDK', () {
    test('track should use device ID before user identification', () async {
      const eventName = 'app_opened';
      await sdk.track(eventName: eventName);

      expect(httpClient.requests.length, 1);
      final request = httpClient.requests.first;
      expect(request['body']['identifier'], 'test_device_id');
    });

    test('identify should make correct API call', () async {
      const identifier = 'user_123';
      final properties = {
        'name': 'John Doe',
        'email': 'john@example.com',
      };

      await sdk.identify(
        identifier: identifier,
        properties: properties,
      );

      expect(httpClient.requests.length, 1);
      final request = httpClient.requests.first;
      expect(request['endpoint'], CDPEndpoints.identify);
      expect(request['body']['identifier'], identifier);
      expect(request['body']['properties'], properties);
      expect(request['identifier'], identifier);
    });

    test('track should make correct API call', () async {
      const identifier = 'user_123';
      const eventName = 'button_clicked';
      final properties = {
        'button_name': 'increment',
        'count': 5,
      };

      await sdk.identify(identifier: identifier);
      await sdk.track(
        eventName: eventName,
        properties: properties,
      );

      expect(httpClient.requests.length, 2);
      final request = httpClient.requests.last;
      expect(request['endpoint'], CDPEndpoints.track);
      expect(request['body']['identifier'], identifier);
      expect(request['body']['eventName'], eventName);
      expect(request['body']['properties'], properties);
      expect(request['identifier'], identifier);
    });

    // test('update should make correct API call', () async {
    //   const identifier = 'user_123';
    //   final properties = {
    //     'last_clicked': DateTime.now().toIso8601String(),
    //     'total_clicks': 10,
    //   };

    //   await sdk.identify(identifier: identifier);
    //   await sdk.update(
    //     properties: properties,
    //   );

    //   expect(httpClient.requests.length, 2);
    //   final request = httpClient.requests.last;
    //   expect(request['endpoint'], CDPEndpoints.update);
    //   expect(request['body']['identifier'], identifier);
    //   expect(request['body']['properties'], properties);
    //   expect(request['identifier'], identifier);
    // });

    test('registerDeviceToken should make correct API call', () async {
      const identifier = 'user_123';
      const fcmToken = 'fcm_token';
      const apnToken = 'apn_token';

      await sdk.identify(identifier: identifier);
      await sdk.registerDeviceToken(
        fcmToken: fcmToken,
        apnToken: apnToken,
      );

      expect(httpClient.requests.length, 2);
      final request = httpClient.requests.last;
      expect(request['endpoint'], CDPEndpoints.registerDevice);
      expect(request['body']['identifier'], identifier);
      expect(request['body']['fcmToken'], fcmToken);
      expect(request['body']['apnToken'], apnToken);
      expect(request['identifier'], identifier);
    });

    test('should throw exception when identifying with empty identifier', () {
      expect(
        () => sdk.identify(identifier: ''),
        throwsException,
      );
    });

    test('should throw exception when tracking with empty event name', () {
      expect(
        () => sdk.track(eventName: ''),
        throwsException,
      );
    });

    test('should handle API failures gracefully', () async {
      httpClient.shouldFail = true;
      await sdk.identify(identifier: 'user_123');
      expect(
        () => sdk.track(eventName: 'test_event'),
        throwsException,
      );
    });

    test('should track screen views when auto tracking is enabled', () async {
      final sdk = await TestSDKHelper.initializeSDK(
          autoTrackScreens: true, httpClient: httpClient);
      expect(sdk.screenTracker, isNotNull);
    });

    test('should track lifecycle events when enabled', () async {
      final sdk = await TestSDKHelper.initializeSDK(
        trackApplicationLifecycleEvents: true,
        httpClient: httpClient,
      );
      await sdk.trackLifecycleEvent(
        eventName: 'app_opened',
        properties: {'timestamp': DateTime.now().toIso8601String()},
      );
      expect(httpClient.requests.length, 1);
      final request = httpClient.requests.first;
      expect(request['body']['eventName'], 'app_opened');
    });

    test('should track device attributes when enabled', () async {
      final sdk = await TestSDKHelper.initializeSDK(
        autoTrackDeviceAttributes: true,
        httpClient: httpClient,
      );
      await sdk.identify(identifier: 'user_123');
      expect(httpClient.requests.length,
          3); // identify + device attributes + update
      final request = httpClient.requests.last;
      expect(request['body']['properties']['device_manufacturer'],
          'Test Manufacturer');
    });
  });
}
