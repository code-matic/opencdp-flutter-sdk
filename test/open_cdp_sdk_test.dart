import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:open_cdp_flutter_sdk/open_cdp_flutter_sdk.dart';
import 'package:open_cdp_flutter_sdk/src/constants/endpoints.dart';

class TestHttpClient {
  final List<Map<String, dynamic>> requests = [];

  Future<void> post(String endpoint, Map<String, dynamic> body,
      {String? identifier}) async {
    requests.add({
      'endpoint': endpoint,
      'body': body,
      'identifier': identifier,
    });
  }

  void dispose() {}
}

class TestSDKHelper {
  static Future<OpenCDPSDK> initializeSDK() async {
    // Initialize the SDK with test configuration
    await OpenCDPSDK.initialize(
      config: OpenCDPConfig(
        cdpApiKey: 'test_key',
        debug: true,
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
    const MethodChannel('plugins.flutter.io/shared_preferences')
        .setMockMethodCallHandler((MethodCall methodCall) async {
      if (methodCall.method == 'getAll') {
        return <String, dynamic>{};
      }
      return null;
    });
    // Mock package_info_plus
    const MethodChannel('dev.fluttercommunity.plus/package_info')
        .setMockMethodCallHandler((MethodCall methodCall) async {
      if (methodCall.method == 'getAll') {
        return <String, dynamic>{
          'appName': 'TestApp',
          'packageName': 'com.example.test',
          'version': '1.0.0',
          'buildNumber': '1',
        };
      }
      return null;
    });
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

    test('track should make correct API call', () async {
      const identifier = 'user_123';
      const eventName = 'button_clicked';
      final properties = {
        'button_name': 'increment',
        'count': 5,
      };

      await sdk.track(
        eventName: eventName,
        properties: properties,
      );

      expect(httpClient.requests.length, 1);
      final request = httpClient.requests.first;
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

      await sdk.update(
        properties: properties,
      );

      expect(httpClient.requests.length, 1);
      final request = httpClient.requests.first;
      expect(request['endpoint'], CDPEndpoints.update);
      expect(request['body']['identifier'], identifier);
      expect(request['body']['properties'], properties);
      expect(request['identifier'], identifier);
    });

    test('registerDeviceToken should make correct API call', () async {
      const identifier = 'user_123';
      const fcmToken = 'fcm_token';
      const apnToken = 'apn_token';

      await sdk.registerDeviceToken(
        fcmToken: fcmToken,
        apnToken: apnToken,
      );

      expect(httpClient.requests.length, 1);
      final request = httpClient.requests.first;
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
  });
}
