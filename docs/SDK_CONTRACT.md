# OpenCDP SDK Contract

Canonical API contract for all OpenCDP SDKs. **Flutter SDK v3.1.1** is the reference implementation.

## Gateway URLs

| Role | URL |
|------|-----|
| Primary | `https://api.opencdp.com/gateway/data-gateway` |
| Fallback 1 | `https://api.opencdp.xyz/gateway/data-gateway` |
| Fallback 2 | `https://api.opencdp.io/gateway/data-gateway` |

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

## Conformance vectors

See [conformance_vectors.json](./conformance_vectors.json) for golden request bodies used in SDK tests.
