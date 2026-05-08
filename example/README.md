# OpenCDP Flutter SDK — Example / Test App

A focused harness for verifying the messaging end-to-end loop:

```
Dashboard test send → Product API queues delivery → Data Gateway sync → SDK polls →
Test app renders (modal/banner/inline/inbox) → impression / click / dismiss tracked

Test app fires event → Data Gateway ingests → triggers campaigns / transactionals →
delivery flows back through whatever channel (push, email, sms, in-app)
```

## What it does

- Boots into a config screen so you can plug in any data-gateway URL, API key,
  and test person id without rebuilding.
- Initializes `OpenCDPSDK` with `enableInAppMessages: true` and identifies the
  person you provided.
- Lets you switch logical screens (`home`, `cart`, `profile`, `inbox`) so you
  can exercise backend page rules.
- Renders the four built-in render types:
  - `modal` — full-screen dialog with CTAs
  - `banner` — top overlay banner with primary CTA + dismiss
  - `inline` and `inbox_card` — appended to the inline list on screen
- Tracks impressions, CTA clicks, and dismisses through the SDK's
  `CDPInAppManager`.
- **Events tab** — fire arbitrary `track()` events to drive campaigns,
  broadcasts (via segment recompute) and transactional sends.

## Run it

```bash
cd open_cdp_flutter_sdk/example
flutter pub get
flutter run
```

In the config screen:

1. **CDP endpoint** — use your local data-gateway base URL, e.g.
   `http://localhost:3001/data-gateway` (when running the CDP backend locally),
   or a staging gateway like `https://api.opencdp.io/gateway/data-gateway`.
2. **CDP API key** — workspace-scoped key from the dashboard.
3. **Test person id** — anything stable; this is what gets sent to
   `OpenCDPSDK.identify(...)` and used for in-app delivery scoping.
4. **Poll interval** — how often the SDK polls the in-app sync endpoint.

After "Initialize & continue" the home screen starts polling. Trigger a
**Test in-app message** from the dashboard editor, or queue an in-app
campaign action targeting the test user, and the message should appear within
a poll cycle.

## Testing tips

- Hit **Sync now** to skip the wait and pull immediately.
- **Reset local state** clears the SDK's per-process delivery cache
  (impressions, dismisses, dispatched ids). Useful after switching identity
  or when you want to re-evaluate previously dispatched messages.
- Switch tabs to trigger a sync with a different `screen` value — useful when
  validating `page_rules.include` / `page_rules.exclude`.
- Watch the console — the SDK logs every sync/track call when `debug: true`.

## Triggering events (Events tab)

The fifth bottom tab opens an event harness that calls
`OpenCDPSDK.instance.track(eventName, properties)` under the hood. Use it to
drive any flow that listens for events on the backend:

- **Campaigns** — workflows whose trigger node is "When event X occurs" (with
  optional property conditions).
- **Transactionals** — event-bound sends (e.g. `purchase` → order receipt).
- **Broadcasts** — indirectly, since events update segment membership.

It includes:

- **Presets** for the most common events (`signup`, `login`, `view_product`,
  `add_to_cart`, `purchase`, `subscription_renewed`) pre-loaded with realistic
  properties — fire-and-forget with one tap.
- **Custom event composer** — type an event name and add property rows. Values
  are auto-typed: `true`/`false` → bool, numbers → number, `{…}`/`[…]` → JSON,
  otherwise string.
- **History** — every fired event with timestamp and the exact payload sent,
  so you can correlate with what shows up in the dashboard / inbox.

Typical loop: configure an event-triggered campaign on the dashboard pointing
at your test person, switch to the **Events** tab, fire the trigger event,
then switch back to **Home/Cart/Profile/Inbox** and watch the in-app message
arrive on the next sync (or hit **Sync now**).

## Where the SDK code lives

- Manager: `lib/src/in_app/in_app_manager.dart`
- Models:  `lib/src/models/in_app_message.dart`
- Public API: `lib/open_cdp_flutter_sdk.dart`
