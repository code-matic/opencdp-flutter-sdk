import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:open_cdp_flutter_sdk/open_cdp_flutter_sdk.dart';
import 'package:open_cdp_flutter_sdk/src/constants/endpoints.dart';

class TestHttpClient {
  final List<Map<String, dynamic>> requests = [];
  bool shouldFail = false;

  Future<void> post(String endpoint, Map<String, dynamic> body,
      {String? identifier}) async {
    if (shouldFail) {
      throw Exception('API call failed');
    }
    requests.add({
      'endpoint': endpoint,
      'body': body,
      'identifier': identifier,
    });
  }

  void dispose() {}
}

class TestSDKHelper {
  static Future<OpenCDPSDK> initializeSDK({
    bool autoTrackScreens = false,
    bool trackApplicationLifecycleEvents = false,
    bool autoTrackDeviceAttributes = false,
    bool sendToCustomerIo = false,
  }) async {
    await OpenCDPSDK.initialize(
      config: OpenCDPConfig(
        cdpApiKey: 'test_key',
        debug: true,
        autoTrackScreens: autoTrackScreens,
        trackApplicationLifecycleEvents: trackApplicationLifecycleEvents,
        autoTrackDeviceAttributes: autoTrackDeviceAttributes,
        sendToCustomerIo: sendToCustomerIo,
      ),
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
          return <String, dynamic>{};
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
    sdk = await TestSDKHelper.initializeSDK();
  });

  tearDown(() {
    httpClient.dispose();
  });

  group('OpenCDPSDK', () {
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

    test('track should use device ID before user identification', () async {
      const eventName = 'app_opened';
      await sdk.track(eventName: eventName);

      expect(httpClient.requests.length, 1);
      final request = httpClient.requests.first;
      expect(request['body']['identifier'], 'test_device_id');
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

    test('update should make correct API call', () async {
      const identifier = 'user_123';
      final properties = {
        'last_clicked': DateTime.now().toIso8601String(),
        'total_clicks': 10,
      };

      await sdk.identify(identifier: identifier);
      await sdk.update(
        properties: properties,
      );

      expect(httpClient.requests.length, 2);
      final request = httpClient.requests.last;
      expect(request['endpoint'], CDPEndpoints.update);
      expect(request['body']['identifier'], identifier);
      expect(request['body']['properties'], properties);
      expect(request['identifier'], identifier);
    });

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
      sdk = await TestSDKHelper.initializeSDK(autoTrackScreens: true);
      expect(sdk.screenTracker, isNotNull);
    });

    test('should track lifecycle events when enabled', () async {
      sdk = await TestSDKHelper.initializeSDK(
        trackApplicationLifecycleEvents: true,
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
      sdk = await TestSDKHelper.initializeSDK(
        autoTrackDeviceAttributes: true,
      );
      await sdk.identify(identifier: 'user_123');
      expect(httpClient.requests.length, 2); // identify + device attributes
      final request = httpClient.requests.last;
      expect(request['body']['properties']['device_manufacturer'],
          'Test Manufacturer');
    });
  });
}
