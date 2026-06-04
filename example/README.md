# OpenCDP Flutter SDK — Example / Test App

A focused harness for verifying messaging end-to-end:

```
Dashboard test send → Product API queues delivery → Data Gateway
  → SDK delivers to test app → renders (modal/banner/inline/inbox)
  → impression / click / dismiss tracked

Test app fires event → Data Gateway ingests → triggers campaigns / transactionals
  → delivery flows back through push, email, sms, in-app, etc.
```

## What it does

- Boots into a config screen so you can plug in any data-gateway URL, API key,
  test person id, and profile fields without rebuilding.
- Initializes `OpenCDPSDK` with `enableInAppMessages: true` and identifies
  the person you provided.
- Lets you switch logical screens (`home`, `cart`, `profile`, `inbox`) so you
  can exercise backend page rules.
- Renders the four built-in render types:
  - `modal` — full-screen dialog with CTAs
  - `banner` — top overlay banner with primary CTA + dismiss
  - `inline` and `inbox_card` — appended to the inline list on screen
- Tracks impressions, CTA clicks, and dismisses through `CDPInAppManager`.
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
   or a staging gateway.
2. **CDP API key** — workspace-scoped key from the dashboard.
3. **Test person id** — stable id passed to `OpenCDPSDK.identify(...)`.
4. **Profile** — optional first name, last name, email (identify properties).

After **Initialize & continue**, in-app messages for that user are delivered
automatically. Trigger a **Test in-app message** from the dashboard or queue a
campaign — the message should appear shortly.

## Testing tips

- Hit **Sync now** to refresh messages immediately.
- **Reset local state** clears the SDK's per-process delivery cache
  (impressions, dismisses, dispatched ids). Useful after switching identity
  or when you want to re-evaluate previously dispatched messages.
- Switch tabs to call `setCurrentScreen` with a different value — useful when
  validating `page_rules.include` / `page_rules.exclude`.
- Watch the console — the SDK logs errors when `debug: true`.

## Triggering events (Events tab)

The fifth bottom tab opens an event harness that calls
`OpenCDPSDK.instance.track(eventName, properties)` under the hood. Use it to
drive any flow that listens for events on the backend:

- **Campaigns** — workflows whose trigger node is "When event X occurs" (with
  optional property conditions).
- **Transactionals** — event-bound sends (e.g. `purchase` → order receipt).
- **Broadcasts** — indirectly, since events update segment membership.

It includes:

- **Presets** for common events (`signup`, `login`, `view_product`,
  `add_to_cart`, `purchase`, `subscription_renewed`) with realistic properties.
- **Custom event composer** — event name plus key/value rows (auto-typed values).
- **History** — every fired event with timestamp and payload.

Typical loop: configure an event-triggered campaign for your test person, fire
the trigger on the **Events** tab, then switch to **Home/Cart/Profile/Inbox**
and watch the in-app message arrive (or hit **Sync now**).

## Where the SDK code lives

- Manager: `lib/src/in_app/in_app_manager.dart`
- Models: `lib/src/models/in_app_message.dart`
- Docs: `doc/in_app_messaging.md`
- Public API: `lib/open_cdp_flutter_sdk.dart`
