# OpenCDP SDK Parity Tracker

> **Base SDK:** [opencdp-flutter-sdk](..) v3.1.1  
> **Last updated:** 2026-07-06  
> **Plan:** See `.cursor/plans/sdk_feature_parity_20bcd05f.plan.md`

Use this doc to track parity work across all SDKs. Update checkboxes as work completes.

---

## Legend

| Marker | Meaning |
|--------|---------|
| `[ ]` | Not started |
| `[>]` | In progress |
| `[x]` | Done |
| `[-]` | N/A — already complete or out of scope |

---

## Overall progress

| Area | Status | Notes |
|------|--------|-------|
| Client SDKs (Flutter / Android / iOS / RN) | `[x]` | Full mobile parity + RN v2 native wrapper |
| Canonical contract spec | `[x]` | `SDK_CONTRACT.md` + vectors | `SDK_CONTRACT.md` + JSON vectors |
| Python SDK | `[x]` | Aligned + 7 tests passing | Largest gap — full alignment |
| Go SDK | `[x]` | Payloads, failover, URL | Payload names + failover |
| PHP SDK | `[x]` | Failover + concurrency | Failover + concurrency |
| Node SDK | `[x]` | Failover + URL + close() | Failover + URL default + `close()` |
| Contract tests (CI) | `[ ]` | Shared vectors per server SDK |
| Unified documentation | `[x]` | Feature matrix + E2E guide on docs.opencdp.io |

**Phases:** 5/5 complete · **Server features:** ~10/12 complete · **Mobile polish:** 5/5 complete

---

## Manual E2E — big-picture push (T1-5)

Run on physical devices using [PUSH_NOTIFICATION_V2_INTEGRATION.md](../PUSH_NOTIFICATION_V2_INTEGRATION.md) native port checklist.

| Check | Android | iOS |
|-------|:-------:|:---:|
| Big-picture display (`image_url`) | `[ ]` device | `[ ]` device |
| Action buttons + icons | `[ ]` device | N/A |
| Failed image → text-only fallback | `[ ]` device | `[ ]` device |
| Delivery/open metrics after image attach | `[ ]` device | `[ ]` device |
| NSE + `mutable-content: 1` | N/A | `[ ]` device |

Code parity verified in unit tests; device sign-off pending QA.

---

## Phase checklist

### Phase 0 — Canonical contract

- [x] **P0-1** Create `SDK_CONTRACT.md` (endpoints, payloads, config mapping)
- [x] **P0-2** Add JSON conformance vectors (`identify`, `track`, `registerDevice`)
- [x] **P0-3** Document gateway failover rules (`io` → `com` → `xyz`)
- [ ] **P0-4** Confirm Authorization header format with gateway team

### Phase 1 — Python SDK

- [x] **P1-1** Default endpoint → `https://api.opencdp.io/gateway/data-gateway`
- [x] **P1-2** Add fallback gateways (`.xyz`, `.io`) + failover logic
- [x] **P1-3** Paths → `/v1/persons/identify`, `/track`, `/registerDevice`
- [x] **P1-4** Paths → `/v1/send/email`, `/push`, `/sms` + `/v1/health/ping`
- [x] **P1-5** Payloads → `identifier`, `properties`, `eventName`
- [x] **P1-6** Add `fail_on_exception` config
- [x] **P1-7** Add configurable `timeout`
- [x] **P1-8** Add `cdp_fallback_endpoints` config
- [x] **P1-9** Add input validation + typed errors
- [x] **P1-10** Rewrite tests to match canonical contract

### Phase 2 — Go SDK

- [x] **P2-1** Default primary URL → `api.opencdp.io`
- [x] **P2-2** Add fallback gateways + failover
- [x] **P2-3** Add `cdpFallbackEndpoints` config
- [x] **P2-4** JSON fields → `identifier`, `properties`, `eventName`
- [x] **P2-5** Device payload → camelCase (`deviceId`, `fcmToken`, etc.)
- [x] **P2-6** Wire Customer.io `Region` in integration
- [x] **P2-7** Verify / align Authorization header
- [x] **P2-8** Contract tests pass

### Phase 3 — PHP SDK

- [x] **P3-1** Default primary URL → `api.opencdp.io`
- [x] **P3-2** Add fallback gateways + failover
- [x] **P3-3** Add `cdpFallbackEndpoints` config
- [x] **P3-4** Add `maxConcurrentRequests`
- [x] **P3-5** Contract tests pass

### Phase 3 — Node SDK

- [x] **P3-N1** Default primary URL → `api.opencdp.io`
- [x] **P3-N2** Add fallback gateways + failover
- [x] **P3-N3** Add `cdpFallbackEndpoints` config
- [x] **P3-N4** Add `close()` for connection cleanup
- [x] **P3-N5** Contract tests pass

### Phase 4 — Contract tests + docs

- [ ] **P4-1** Contract test runner in Go CI
- [ ] **P4-2** Contract test runner in Node CI
- [ ] **P4-3** Contract test runner in PHP CI
- [x] **P4-4** Contract test runner in Python CI
- [x] **P4-5** Unified feature matrix doc (client vs server) — `openCDP-docs/integrations/mobile/feature-matrix.md`
- [x] **P4-6** Per-SDK quick-start links — `openCDP-docs/integrations/mobile/e2e-guide.md`
- [ ] **P4-7** Python legacy path deprecation notes

### Phase 5 — Mobile polish (optional)

- [x] **P5-1** iOS: real Customer.io wrapper (optional `CioDataPipelines` / `OpenCDP/CustomerIO` pod)
- [x] **P5-2** iOS: wire `throwErrorsBack` through public APIs
- [x] **P5-3** iOS: expose `CDPInAppManager` helpers publicly
- [x] **P5-4** iOS: add `removeInAppListener`
- [x] **P5-5** Android/iOS: README lifecycle event name alignment

### Tier 2 — Capability parity (2026-07-06)

- [x] **T2-1** Anonymous screen replay (Android + iOS)
- [x] **T2-2/T2-3** Push API aliases + native push setup helpers
- [x] **T2-4** Debug failover tools (Android + iOS)
- [x] **T2-5/T2-6** CIO config expansion; Flutter CIO `registerDeviceToken` dual-write; in-app API alignment
- [x] **T3-1** API mapping table in `SDK_CONTRACT.md`
- [x] **T3-2** Android unit test compile (removed unused mockito imports)
- [x] **T3-3/T3-4** README defaults + parity tracker updates

---

### React Native SDK (2026-07-06)

- [x] **RN-0** Native Android/iOS modules wrapping OpenCDP SDKs
- [x] **RN-1** Core CDP via native (initialize, identify, track, clearIdentity)
- [x] **RN-2** Device registration + push v2 handlers
- [x] **RN-3** In-app sync, listeners, metrics
- [x] **RN-4** Auto-tracking + Customer.io config passthrough + debug tools
- [x] **RN-5** Expo config plugin + example dev client
- [x] **RN-6** SDK_CONTRACT + parity tracker RN column

---

## Client SDKs — baseline (no work required)

Flutter is the reference. Android, iOS, and React Native v2 match for core client features.

| ID | Feature | Flutter | Android | iOS | RN |
|----|---------|:-------:|:-------:|:---:|:--:|
| CL-01 | Initialize + reinitialize | `[-]` | `[-]` | `[-]` | `[x]` |
| CL-02 | identify / track / clearIdentity | `[-]` | `[-]` | `[-]` | `[x]` |
| CL-03 | Screen + lifecycle auto-tracking | `[-]` | `[-]` | `[-]` | `[x]` native |
| CL-04 | registerDeviceToken | `[-]` | `[-]` | `[-]` | `[x]` |
| CL-05 | Push v2 metrics | `[-]` | `[-]` | `[-]` | `[x]` |
| CL-06 | Android actionable push | `[-]` | `[-]` | `[-]` | `[x]` |
| CL-07 | iOS NSE background delivery | `[-]` | `[-]` | `[-]` | `[x]` native |
| CL-08 | In-app sync + SSE + polling | `[-]` | `[-]` | `[-]` | `[x]` native |
| CL-09 | In-app impression / click / dismiss | `[-]` | `[-]` | `[-]` | `[x]` |
| CL-10 | Gateway failover | `[-]` | `[-]` | `[-]` | `[x]` native |
| CL-11 | Offline POST queue | `[-]` | `[-]` | `[-]` | `[x]` native |
| CL-12 | Native credential bridge | `[-]` | `[-]` | `[-]` | `[x]` native |
| CL-13 | Customer.io dual-write | `[-]` | `[-]` | `[x]` | `[x]` native |
| CL-14 | Big-picture push (`image_url`) | `[-]` | `[x]` | `[x]` | `[x]` native |
| CL-15 | Action button icons (Android) | `[-]` | `[x]` | `[-]` | `[x]` native |
| CL-16 | Hybrid FCM dedup (Android) | `[-]` | `[x]` | `[-]` | `[x]` native |
| CL-17 | NSE image before metrics + session helper | `[-]` | `[-]` | `[x]` | `[x]` native |
| CL-18 | Anonymous screen replay | `[-]` | `[x]` | `[x]` | `[x]` native |
| CL-19 | Debug failover / queue tools | `[-]` | `[x]` | `[x]` | `[x]` |
| CL-20 | Turnkey push setup helpers | `[-]` | `[x]` | `[x]` | `[x]` |
| CL-21 | `throwErrorsBack` wired | `[-]` | `[-]` | `[x]` | `[x]` native |
| CL-22 | `removeInAppListener` | `[-]` | `[-]` | `[x]` | `[x]` |
| CL-23 | Flutter `autoTrackDeviceAttributes` on init | `[x]` | `[-]` | `[-]` | `[x]` native |

### Legacy client SDK matrix (Flutter / Android / iOS only)

| ID | Feature | Flutter | Android | iOS |
|----|---------|:-------:|:-------:|:---:|
| CL-01 | Initialize + reinitialize | `[-]` | `[-]` | `[-]` |
| CL-02 | identify / track / clearIdentity | `[-]` | `[-]` | `[-]` |
| CL-03 | Screen + lifecycle auto-tracking | `[-]` | `[-]` | `[-]` |
| CL-04 | registerDeviceToken | `[-]` | `[-]` | `[-]` |
| CL-05 | Push v2 metrics | `[-]` | `[-]` | `[-]` |
| CL-06 | Android actionable push | `[-]` | `[-]` | `[-]` |
| CL-07 | iOS NSE background delivery | `[-]` | `[-]` | `[-]` |
| CL-08 | In-app sync + SSE + polling | `[-]` | `[-]` | `[-]` |
| CL-09 | In-app impression / click / dismiss | `[-]` | `[-]` | `[-]` |
| CL-10 | Gateway failover | `[-]` | `[-]` | `[-]` |
| CL-11 | Offline POST queue | `[-]` | `[-]` | `[-]` |
| CL-12 | Native credential bridge | `[-]` | `[-]` | `[-]` |
| CL-13 | Customer.io dual-write | `[-]` | `[-]` | `[x]` optional pod |
| CL-14 | Big-picture push (`image_url`) | `[-]` | `[x]` | `[x]` |
| CL-15 | Action button icons (Android) | `[-]` | `[x]` | `[-]` |
| CL-16 | Hybrid FCM dedup (Android) | `[-]` | `[x]` | `[-]` |
| CL-17 | NSE image before metrics + session helper | `[-]` | `[-]` | `[x]` |
| CL-18 | Anonymous screen replay | `[-]` | `[x]` | `[x]` |
| CL-19 | Debug failover / queue tools | `[-]` | `[x]` | `[x]` |
| CL-20 | Turnkey push setup helpers | `[-]` | `[x]` | `[x]` |
| CL-21 | `throwErrorsBack` wired | `[-]` | `[-]` | `[x]` |
| CL-22 | `removeInAppListener` | `[-]` | `[-]` | `[x]` |
| CL-23 | Flutter `autoTrackDeviceAttributes` on init | `[x]` | `[-]` | `[-]` |

---

## Server SDK feature matrix

Track each shared feature per SDK. Mark `[x]` when implemented and tested.

| ID | Feature | Go | Node | PHP | Python |
|----|---------|:--:|:----:|:---:|:------:|
| SRV-01 | Primary gateway `api.opencdp.io` | `[x]` | `[x]` | `[x]` | `[x]` |
| SRV-02 | Fallback gateways `.com` + `.xyz` | `[x]` | `[x]` | `[x]` | `[x]` |
| SRV-03 | Gateway failover (multi-host retry) | `[x]` | `[x]` | `[x]` | `[x]` |
| SRV-04 | `cdpFallbackEndpoints` config | `[x]` | `[x]` | `[x]` | `[x]` |
| SRV-05 | Paths `/v1/persons/*` | `[-]` | `[-]` | `[-]` | `[x]` |
| SRV-06 | Paths `/v1/send/*` + `/v1/health/ping` | `[-]` | `[-]` | `[-]` | `[x]` |
| SRV-07 | Payload `identifier` + `properties` | `[x]` | `[-]` | `[-]` | `[x]` |
| SRV-08 | Payload `eventName` on track | `[x]` | `[-]` | `[-]` | `[x]` |
| SRV-09 | registerDevice camelCase fields | `[x]` | `[-]` | `[-]` | `[x]` |
| SRV-10 | `failOnException` config | `[-]` | `[-]` | `[-]` | `[x]` |
| SRV-11 | Configurable timeout | `[-]` | `[-]` | `[-]` | `[x]` |
| SRV-12 | Input validation | `[-]` | `[-]` | `[-]` | `[x]` |
| SRV-13 | Typed SDK errors | `[-]` | `[-]` | `[-]` | `[x]` |
| SRV-14 | Customer.io region wired | `[ ]` | `[-]` | `[-]` | `[ ]` |
| SRV-15 | Auth header aligned | `[ ]` | `[ ]` | `[ ]` | `[ ]` |
| SRV-16 | `maxConcurrentRequests` | `[-]` | `[-]` | `[x]` | `[ ]` |
| SRV-17 | `close()` / connection cleanup | `[-]` | `[x]` | `[-]` | `[-]` |
| SRV-18 | Contract tests in CI | `[ ]` | `[ ]` | `[ ]` | `[x]` |

### Server-only features (keep — do not port to Flutter)

| ID | Feature | Go | Node | PHP | Python |
|----|---------|:--:|:----:|:---:|:------:|
| SRV-S01 | `ping` / health check | `[-]` | `[-]` | `[-]` | `[x]` |
| SRV-S02 | `sendEmail` | `[-]` | `[-]` | `[-]` | `[ ]` path fix |
| SRV-S03 | `sendPush` | `[-]` | `[-]` | `[-]` | `[ ]` path fix |
| SRV-S04 | `sendSms` | `[-]` | `[-]` | `[-]` | `[ ]` path fix |

---

## Explicitly out of scope

| ID | Item | Status |
|----|------|--------|
| OOS-01 | `update()` user properties | `[-]` deferred |
| OOS-02 | Identity alias / merge | `[-]` deferred |
| OOS-03 | Consent / GDPR controls | `[-]` deferred |
| OOS-04 | Built-in deep link routing | `[-]` host app responsibility |
| OOS-05 | In-app / push metrics on server SDKs | `[-]` client-only |
| OOS-06 | sendEmail/Push/Sms on Flutter | `[-]` server-only |

---

## Success criteria (check when all done)

- [x] **SC-1** Python uses `/v1/persons/*` and `api.opencdp.com` default
- [x] **SC-2** Go / Node / PHP / Python send `{ identifier, properties, eventName }`
- [x] **SC-3** All four server SDKs support gateway failover `com` → `xyz` → `io`
- [ ] **SC-4** Contract test vectors pass in all server SDK CI pipelines
- [x] **SC-5** Feature matrix doc published (client vs server) — docs.opencdp.io mobile hub

---

## How to update this doc

1. Change `[ ]` → `[>]` when you start an item.
2. Change `[>]` or `[ ]` → `[x]` when implemented **and** tested.
3. Use `[-]` only for items that are N/A or already complete at start.
4. Update the **Overall progress** summary counts at the top when a phase completes.