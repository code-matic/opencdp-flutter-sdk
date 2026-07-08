# OpenCDP SDK Contract

Canonical API contract for all OpenCDP SDKs. **Flutter SDK v3.1.1** is the reference implementation.

## Gateway URLs

| Role | URL |
|------|-----|
| Primary | `https://api.opencdp.io/gateway/data-gateway` |
| Fallback 1 | `https://api.opencdp.com/gateway/data-gateway` |
| Fallback 2 | `https://api.opencdp.xyz/gateway/data-gateway` |

- Trim whitespace; remove trailing slashes from base URLs.
- Deduplicate hosts; try primary first, then fallbacks on network error or non-2xx.
- Custom `cdpEndpoint` / `cdpFallbackEndpoints` override defaults.

## Authorization

```
Authorization: <cdp_api_key>
Content-Type: application/json
```

Raw API key (no `Bearer` prefix) — matches Flutter [`CDPHttpClient`](../../lib/src/utils/http_client.dart).

## Endpoints

| Method | Path | SDKs |
|--------|------|------|
| GET | `/v1/health/ping` | Server |
| POST | `/v1/persons/identify` | All |
| POST | `/v1/persons/track` | All |
| POST | `/v1/persons/registerDevice` | Client + Server |
| POST | `/v1/send/email` | Server |
| POST | `/v1/send/push` | Server |
| POST | `/v1/send/sms` | Server |

Client-only (not required on server SDKs): `/v1/message/delivery/push`, `/v1/in-app/messages/*`.

## Request payloads

### Identify

```json
{
  "identifier": "user_123",
  "properties": { "plan": "pro" }
}
```

- `identifier` must not be an email address.

### Track

```json
{
  "identifier": "user_123",
  "eventName": "purchase",
  "properties": { "amount": 99.9 }
}
```

### Register device

```json
{
  "identifier": "user_123",
  "deviceId": "abc-device-id",
  "platform": "android",
  "fcmToken": "token",
  "apnToken": null,
  "name": "Pixel",
  "osVersion": "14",
  "model": "Pixel 8",
  "appVersion": "1.0.0",
  "attributes": {}
}
```

## Config mapping

| Concept | Flutter | Node | Go | PHP | Python |
|---------|---------|------|-----|-----|--------|
| API key | `cdpApiKey` | `cdpApiKey` | `CDPAPIKey` | `cdpApiKey` | `cdp_api_key` |
| Primary endpoint | `cdpEndpoint` | `cdpEndpoint` | `CDPEndpoint` | `cdpEndpoint` | `cdp_endpoint` |
| Fallback endpoints | `cdpFallbackEndpoints` | `cdpFallbackEndpoints` | `CDPFallbackEndpoints` | `cdpFallbackEndpoints` | `cdp_fallback_endpoints` |
| Throw on error | `throwErrorsBack` | `failOnException` | `FailOnException` | `failOnException` | `fail_on_exception` |
| Timeout (ms) | `cdpRequestTimeout` | `timeout` | `Timeout` | `timeout` | `timeout_ms` |
| Debug | `debug` | `debug` | `Debug` | `debug` | `debug` |

## Customer.io dual-write

When enabled, mirror `identify`, `track`, and `registerDevice` to Customer.io. CIO failures must not fail the primary CDP request unless `failOnException` is true for validation errors only.

## Client API mapping (Flutter reference)

Capability parity across mobile SDKs — method names differ; behavior should match.

| Capability | Flutter | Android | iOS | React Native |
|------------|---------|---------|-----|--------------|
| Initialize | `OpenCDPSDK.initialize(config:)` | `OpenCDP.initialize(context, config)` | `OpenCDP.shared.initialize(config:)` | `OpenCDPSDK.initialize({ config })` |
| Identify | `OpenCDPSDK.instance.identify(...)` | `OpenCDP.identify(...)` | `OpenCDP.shared.identify(...)` throws when `throwErrorsBack` | `OpenCDPSDK.instance.identify(...)` |
| Current user | `OpenCDPSDK.instance.userId` | `OpenCDP.userId` | `OpenCDP.shared.currentUserId` | `OpenCDPSDK.instance.userId` |
| Track event | `OpenCDPSDK.instance.track(...)` | `OpenCDP.track(...)` | `OpenCDP.shared.track(...)` throws when `throwErrorsBack` | `OpenCDPSDK.instance.track(...)` |
| Screen view | `OpenCDPSDK.instance.trackScreenView(...)` | `OpenCDP.trackScreenView(...)` | `OpenCDP.shared.trackScreenView(...)` | `OpenCDPSDK.instance.trackScreenView(...)` |
| Register device | `OpenCDPSDK.instance.registerDeviceToken(...)` | `OpenCDP.registerDeviceToken(...)` | `OpenCDP.shared.registerDeviceToken(...)` throws when `throwErrorsBack` | `OpenCDPSDK.instance.registerDeviceToken(...)` |
| Clear identity | `OpenCDPSDK.instance.clearIdentity()` | `OpenCDP.clearIdentity()` | `OpenCDP.shared.clearIdentity()` | `OpenCDPSDK.instance.clearIdentity()` |
| Push delivery (fg) | `OpenCDPSDK.handleForegroundPushDelivery(data)` | `OpenCDP.handleForegroundPushDelivery(data)` / alias `handlePushDelivery` | `OpenCDP.shared.handleForegroundPushDelivery(data)` | `OpenCDPSDK.handleForegroundPushDelivery(data)` |
| Push delivery (bg) | `OpenCDPSDK.handleBackgroundPushDelivery(data)` | `OpenCDP.handleBackgroundPushDelivery(data)` | `OpenCDP.shared.handleBackgroundPushDelivery(data)` | `OpenCDPSDK.handleBackgroundPushDelivery(data)` |
| Push open | `OpenCDPSDK.handlePushNotificationOpen(data)` | `OpenCDP.handlePushOpen(data)` / alias `handlePushNotificationOpen` | `OpenCDP.shared.handlePushNotificationOpen(data)` | `OpenCDPSDK.handlePushNotificationOpen(data)` |
| Push action click | `OpenCDPSDK.handlePushActionClick(data, actionId)` | `OpenCDP.handlePushActionClick(data, actionId)` | `OpenCDP.shared.handlePushActionClick(data, actionId:)` | `OpenCDPSDK.handlePushActionClick(data, actionId)` |
| Android actionable UI | `OpenCDPSDK.showAndroidActionableNotification(...)` | `OpenCDP.showActionableNotification(...)` | N/A (use NSE + `OpenCdpPushExtensionHelper`) | `OpenCDPSDK.showActionableNotification(...)` |
| Pending launch (Android) | `OpenCDPSDK.handlePendingNotificationLaunch()` | `OpenCDP.handlePendingNotificationLaunch(context)` | N/A | `OpenCDPSDK.handlePendingNotificationLaunch()` |
| Turnkey push setup | `OpenCDPSDK.setupPushNotifications(...)` | `OpenCDPPushSetup` helpers | `OpenCDPPushSetup.setupPushNotifications(...)` | `OpenCDPSDK.setupPushNotifications(...)` |
| In-app listener | `OpenCDPSDK.instance.addInAppListener(...)` | `OpenCDP.addInAppListener(...)` | `OpenCDP.shared.addInAppListener(...)` | `OpenCDPSDK.instance.addInAppListener(...)` |
| Remove in-app listener | `OpenCDPSDK.instance.removeInAppListener(...)` | `OpenCDP.removeInAppListener(...)` | `OpenCDP.shared.removeInAppListener(...)` | `OpenCDPSDK.instance.removeInAppListener(...)` |
| Debug failover | `OpenCDPSDK.instance.debugTestHostFailover()` | `OpenCDP.debugTestHostFailover()` | `OpenCDP.shared.debugTestHostFailover()` (#if DEBUG) | `OpenCDPSDK.instance.debugTestHostFailover()` |
| Debug queue retry | `OpenCDPSDK.instance.debugTestQueueRetry()` | `OpenCDP.debugTestQueueRetry()` | `OpenCDP.shared.debugTestQueueRetry()` (#if DEBUG) | `OpenCDPSDK.instance.debugTestQueueRetry()` |
| Debug drain queue | `OpenCDPSDK.instance.debugDrainQueue()` | `OpenCDP.debugDrainQueue()` | `OpenCDP.shared.debugDrainQueue()` (#if DEBUG) | `OpenCDPSDK.instance.debugDrainQueue()` |
| Customer.io dual-write | `sendToCustomerIo` + `customerIo` config | `sendToCustomerIo` + `customerIoConfig` | `sendToCustomerIo` + `customerIo` (optional `OpenCDP/CustomerIO` pod) | `sendToCustomerIo` + `customerIo` / `customerIoConfig` (native) |

## Conformance vectors

See [conformance_vectors.json](./conformance_vectors.json) for golden request bodies used in SDK tests.
