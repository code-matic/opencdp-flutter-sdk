import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:open_cdp_flutter_sdk/src/utils/http_client.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FailoverMockClient extends http.BaseClient {
  _FailoverMockClient(this.handlers);

  final List<Future<http.Response> Function(http.Request)> handlers;
  int callIndex = 0;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final index = callIndex;
    callIndex++;
    final handler = handlers[index.clamp(0, handlers.length - 1)];
    final response = await handler(request as http.Request);
    return http.StreamedResponse(
      Stream.value(response.bodyBytes),
      response.statusCode,
      headers: response.headers,
      request: request,
    );
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('CDPHttpClient failover', () {
    test('post tries backup host after primary non-2xx', () async {
      final mock = _FailoverMockClient([
        (_) async => http.Response('fail', 503),
        (_) async => http.Response('{"ok":true}', 200),
      ]);

      final client = await CDPHttpClient.create(
        baseUrls: ['https://primary.test', 'https://backup.test'],
        apiKey: 'key',
        client: mock,
      );

      final body = await client.post('/v1/persons/track', {'a': 1});
      expect(body['ok'], true);
      expect(mock.callIndex, 2);
      client.dispose();
    });

    test('get returns from second host when first host errors', () async {
      final mock = _FailoverMockClient([
        (_) async => http.Response('unavailable', 503),
        (_) async => http.Response('{"data":1}', 200),
      ]);

      final client = await CDPHttpClient.create(
        baseUrls: ['https://primary.test', 'https://backup.test'],
        apiKey: 'key',
        client: mock,
      );

      final body = await client.get('/v1/in-app/messages/sync');
      expect(body['data'], 1);
      expect(mock.callIndex, 2);
      client.dispose();
    });

    test('post queues when all hosts return non-2xx', () async {
      SharedPreferences.setMockInitialValues({});
      final mock = _FailoverMockClient([
        (_) async => http.Response('a', 500),
        (_) async => http.Response('b', 502),
      ]);

      final client = await CDPHttpClient.create(
        baseUrls: ['https://primary.test', 'https://backup.test'],
        apiKey: 'key',
        client: mock,
      );

      await expectLater(
        client.post('/v1/persons/identify', {'id': 'u1'}),
        throwsA(isA<CDPException>()),
      );
      expect(mock.callIndex, 2);
      client.dispose();
    });
  });
}
