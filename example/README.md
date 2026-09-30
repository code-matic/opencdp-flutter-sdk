# OpenCDP Flutter SDK — Example

Config → identify → **In-App** lab (slots + sync) / **Events** tab.

```bash
cd example && flutter pub get && flutter run
```

## In-App tab

- Screen chips → `setCurrentScreen` (page rules)
- **Sync** / **Reset**
- `OpenCDPInAppInlineSlot(slotId: 'lab_inline')` + `OpenCDPInAppInboxSlot`
- Modal/banner: overlays from `OpenCDPInAppHost` in `main.dart`

| Render type   | Where                          |
|---------------|--------------------------------|
| `modal`       | Overlay dialog                 |
| `banner`      | Top overlay                    |
| `inline`      | Inline section (`lab_inline`)  |
| `inbox_card`  | Inbox section                  |

## Events tab

`track()` presets / custom events for campaign triggers.
