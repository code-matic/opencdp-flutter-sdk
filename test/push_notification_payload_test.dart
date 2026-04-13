import 'package:flutter_test/flutter_test.dart';
import 'package:open_cdp_flutter_sdk/src/utils/push_notification_payload.dart';

void main() {
  group('OpenCDPPushPayload.parseCustomData', () {
    test('parses JSON string', () {
      final data = <String, dynamic>{
        'custom_data': '{"screen":"home","id":"1"}',
      };
      expect(OpenCDPPushPayload.parseCustomData(data), {
        'screen': 'home',
        'id': '1',
      });
    });

    test('returns null for invalid JSON', () {
      final data = <String, dynamic>{'custom_data': '{not-json'};
      expect(OpenCDPPushPayload.parseCustomData(data), isNull);
    });

    test('accepts embedded map', () {
      final data = <String, dynamic>{
        'custom_data': <String, dynamic>{'a': 'b'},
      };
      expect(OpenCDPPushPayload.parseCustomData(data), {'a': 'b'});
    });
  });

  group('OpenCDPPushPayload.parseActions', () {
    test('parses JSON array string', () {
      final data = <String, dynamic>{
        'actions':
            '[{"action_id":"view","label":"View","link":"myapp://x"}]',
      };
      final actions = OpenCDPPushPayload.parseActions(data);
      expect(actions, hasLength(1));
      expect(actions.single.actionId, 'view');
      expect(actions.single.label, 'View');
      expect(actions.single.link, 'myapp://x');
    });

    test('skips invalid entries and caps at 3', () {
      final data = <String, dynamic>{
        'actions':
            '[{"action_id":"a","label":"A"},{"label":"no id"},{"action_id":"b","label":"B"},{"action_id":"c","label":"C"},{"action_id":"d","label":"D"}]',
      };
      final actions = OpenCDPPushPayload.parseActions(data);
      expect(actions.map((e) => e.actionId).toList(), ['a', 'b', 'c']);
    });

    test('supports camelCase actionId', () {
      final data = <String, dynamic>{
        'actions': '[{"actionId":"x","label":"Go"}]',
      };
      final actions = OpenCDPPushPayload.parseActions(data);
      expect(actions.single.actionId, 'x');
    });
  });
}
