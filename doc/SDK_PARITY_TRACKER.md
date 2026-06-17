# OpenCDP SDK Parity Tracker

> **Base SDK:** [opencdp-flutter-sdk](..) v3.1.1  
> **Last updated:** 2026-06-11  
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
| Client SDKs (Flutter / Android / iOS) | `[-]` | Core parity achieved — optional iOS polish only |
| Canonical contract spec | `[x]` | `SDK_CONTRACT.md` + vectors | `SDK_CONTRACT.md` + JSON vectors |
| Python SDK | `[x]` | Aligned + 7 tests passing | Largest gap — full alignment |
| Go SDK | `[x]` | Payloads, failover, URL | Payload names + failover |
| PHP SDK | `[x]` | Failover + concurrency | Failover + concurrency |
| Node SDK | `[x]` | Failover + URL + close() | Failover + URL default + `close()` |
| Contract tests (CI) | `[ ]` | Shared vectors per server SDK |
| Unified documentation | `[ ]` | Feature matrix + quick-starts |

**Phases:** 3/5 complete (0,1,2,3 done; 4-5 partial) · **Server features:** ~10/12 complete · **Mobile polish:** 0/5 complete

---

## Phase checklist

### Phase 0 — Canonical contract

- [x] **P0-1** Create `SDK_CONTRACT.md` (endpoints, payloads, config mapping)
- [x] **P0-2** Add JSON conformance vectors (`identify`, `track`, `registerDevice`)
- [x] **P0-3** Document gateway failover rules (`com` → `xyz` → `io`)
- [ ] **P0-4** Confirm Authorization header format with gateway team

### Phase 1 — Python SDK

- [x] **P1-1** Default endpoint → `https://api.opencdp.com/gateway/data-gateway`
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

- [x] **P2-1** Default primary URL → `api.opencdp.com`
- [x] **P2-2** Add fallback gateways + failover
- [x] **P2-3** Add `cdpFallbackEndpoints` config
- [x] **P2-4** JSON fields → `identifier`, `properties`, `eventName`
- [x] **P2-5** Device payload → camelCase (`deviceId`, `fcmToken`, etc.)
- [x] **P2-6** Wire Customer.io `Region` in integration
- [x] **P2-7** Verify / align Authorization header
- [x] **P2-8** Contract tests pass

### Phase 3 — PHP SDK

- [x] **P3-1** Default primary URL → `api.opencdp.com`
- [x] **P3-2** Add fallback gateways + failover
- [x] **P3-3** Add `cdpFallbackEndpoints` config
- [x] **P3-4** Add `maxConcurrentRequests`
- [x] **P3-5** Contract tests pass

### Phase 3 — Node SDK

- [x] **P3-N1** Default primary URL → `api.opencdp.com`
- [x] **P3-N2** Add fallback gateways + failover
- [x] **P3-N3** Add `cdpFallbackEndpoints` config
- [x] **P3-N4** Add `close()` for connection cleanup
- [x] **P3-N5** Contract tests pass

### Phase 4 — Contract tests + docs

- [ ] **P4-1** Contract test runner in Go CI
- [ ] **P4-2** Contract test runner in Node CI
- [ ] **P4-3** Contract test runner in PHP CI
- [x] **P4-4** Contract test runner in Python CI
- [ ] **P4-5** Unified feature matrix doc (client vs server)
- [ ] **P4-6** Per-SDK quick-start links
- [ ] **P4-7** Python legacy path deprecation notes

### Phase 5 — Mobile polish (optional)

- [ ] **P5-1** iOS: real Customer.io wrapper (replace no-op stub)
- [ ] **P5-2** iOS: wire `throwErrorsBack` through public APIs
- [ ] **P5-3** iOS: expose `CDPInAppManager` helpers publicly
- [ ] **P5-4** iOS: add `removeInAppListener`
- [ ] **P5-5** Android/iOS: README lifecycle event name alignment

---

## Client SDKs — baseline (no work required)

Flutter is the reference. Android and iOS match for core client features.

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
| CL-13 | Customer.io dual-write | `[-]` | `[-]` | `[ ]` stub only |

---

## Server SDK feature matrix

Track each shared feature per SDK. Mark `[x]` when implemented and tested.

| ID | Feature | Go | Node | PHP | Python |
|----|---------|:--:|:----:|:---:|:------:|
| SRV-01 | Primary gateway `api.opencdp.com` | `[x]` | `[x]` | `[x]` | `[x]` |
| SRV-02 | Fallback gateways `.xyz` + `.io` | `[x]` | `[x]` | `[x]` | `[x]` |
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
- [ ] **SC-5** Feature matrix doc published (client vs server)

---

## How to update this doc

1. Change `[ ]` → `[>]` when you start an item.
2. Change `[>]` or `[ ]` → `[x]` when implemented **and** tested.
3. Use `[-]` only for items that are N/A or already complete at start.
4. Update the **Overall progress** summary counts at the top when a phase completes.