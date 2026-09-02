import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_cdp_flutter_sdk/src/utils/route_screen_name.dart';

void main() {
  group('sanitizeScreenName', () {
    test('returns trimmed usable names', () {
      expect(sanitizeScreenName('  /profile  '), '/profile');
      expect(sanitizeScreenName('Home'), 'Home');
      expect(sanitizeScreenName('checkout/payment'), 'checkout/payment');
    });

    test('returns null for null / empty / whitespace', () {
      expect(sanitizeScreenName(null), isNull);
      expect(sanitizeScreenName(''), isNull);
      expect(sanitizeScreenName('   '), isNull);
    });

    test('rejects Flutter technical dumps', () {
      expect(
        sanitizeScreenName(
          '_PageBasedMaterialPageRoute<void>(/profile, null)',
        ),
        isNull,
      );
      expect(
        sanitizeScreenName('MaterialPageRoute<dynamic>(null)'),
        isNull,
      );
      expect(
        sanitizeScreenName('ModalBottomSheetRoute<void>(...)'),
        isNull,
      );
      expect(sanitizeScreenName('PopupRoute<dynamic>'), isNull);
      expect(sanitizeScreenName('DialogRoute<Object?>'), isNull);
    });

    test('rejects private class dumps with parentheses', () {
      expect(
        sanitizeScreenName('_SomeInternalRoute(foo)'),
        isNull,
      );
    });
  });

  group('resolveRouteScreenName', () {
    test('uses RouteSettings.name when usable', () {
      final route = MaterialPageRoute<void>(
        settings: const RouteSettings(name: '/profile/personal-details'),
        builder: (_) => const SizedBox(),
      );
      expect(resolveRouteScreenName(route), '/profile/personal-details');
    });

    test('returns null when settings.name is null (never toString)', () {
      final route = MaterialPageRoute<void>(
        builder: (_) => const SizedBox(),
      );
      expect(route.settings.name, isNull);
      expect(resolveRouteScreenName(route), isNull);
      // Ensure we would have gotten a technical dump from toString:
      expect(route.toString(), contains('MaterialPageRoute'));
    });

    test('returns null when settings.name is a technical dump', () {
      final bad = MaterialPageRoute<void>(
        settings: const RouteSettings(
          name: '_PageBasedMaterialPageRoute<void>(...)',
        ),
        builder: (_) => const SizedBox(),
      );
      expect(resolveRouteScreenName(bad), isNull);
    });
  });
}
