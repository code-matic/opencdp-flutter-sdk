import 'package:flutter_test/flutter_test.dart';
import 'package:open_cdp_flutter_sdk/src/constants/endpoints.dart';
import 'package:open_cdp_flutter_sdk/src/utils/cdp_gateway_urls.dart';

void main() {
  group('CdpGatewayUrls', () {
    test('resolveAllBaseUrls uses primary then default fallbacks', () {
      final urls = CdpGatewayUrls.resolveAllBaseUrls();
      expect(urls.first, CDPEndpoints.baseUrl);
      expect(urls, contains(CDPEndpoints.backupBaseUrlXyz));
      expect(urls, contains(CDPEndpoints.backupBaseUrlCom));
      expect(urls.length, 3);
    });

    test('resolveAllBaseUrls deduplicates custom primary and fallbacks', () {
      final urls = CdpGatewayUrls.resolveAllBaseUrls(
        primaryOverride: '${CDPEndpoints.baseUrl}/',
        fallbackOverrides: [
          CDPEndpoints.backupBaseUrlXyz,
          CDPEndpoints.baseUrl,
        ],
      );
      expect(urls.length, 2);
      expect(urls.first, CDPEndpoints.baseUrl);
    });

    test('clampRequestTimeout enforces bounds', () {
      expect(
        CdpGatewayUrls.clampRequestTimeout(const Duration(seconds: 1)),
        CdpGatewayUrls.minRequestTimeout,
      );
      expect(
        CdpGatewayUrls.clampRequestTimeout(const Duration(seconds: 200)),
        CdpGatewayUrls.maxRequestTimeout,
      );
      expect(
        CdpGatewayUrls.clampRequestTimeout(const Duration(seconds: 45)),
        const Duration(seconds: 45),
      );
    });
  });
}
