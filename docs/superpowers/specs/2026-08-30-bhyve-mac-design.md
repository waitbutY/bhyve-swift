# B-hyve macOS Control App — Design

**Date:** 2026-08-30
**Status:** Approved for planning
**Owner:** waitbutY

## Purpose

A native macOS menu bar app plus a WidgetKit widget for controlling and monitoring Orbit B-hyve smart sprinkler controllers from a single B-hyve account. Replaces day-to-day use of the official B-hyve mobile app on the desktop.

## Goals

- Glanceable status of all controllers on the account (idle / watering / rain-delayed, battery %, firmware version).
- One-click manual zone control from the menu bar.
- Sequential multi-zone runs (client-side queueing).
- Edit existing programs (start times, days-of-week, per-zone durations, budget); no create/delete in v1.
- Quick-set rain delays (24 / 48 / 72 h) from menu bar or widget.
- Native notifications for watering events, low battery, and connectivity loss.
- 14 days of watering history per device.
- Interactive widgets: stop watering, set rain delay, start a zone directly from the desktop widget.

## Non-goals (v1)

- iOS / iPadOS targets.
- Multiple B-hyve accounts.
- Creating or deleting programs.
- Smart-watering (water-sense) configuration.
- Flood sensor support.
- Sparkle auto-update, notarization, App Store distribution.
- Home Assistant / HomeKit bridging.
- Resuming a multi-zone queue across app restarts.

## Constraints

- **Platform:** macOS 15 Sequoia minimum (enables interactive widgets and native desktop widgets).
- **Account:** single B-hyve account, credentials in macOS Keychain.
- **Transport:** direct to Orbit's undocumented cloud API — REST + WebSocket. No MQTT bridge, no self-hosted infrastructure.
- **Dependencies:** zero third-party runtime dependencies. `URLSession` + `URLSessionWebSocketTask` for all networking.
- **Distribution:** personal use, unsigned or Developer ID signed by the user's personal team. No notarization pipeline.

## Architecture

### Repositories

Two repos under `github.com/waitbutY`:

1. **`bhyve-swift`** — public Swift package. Reusable client library for the B-hyve API. Zero third-party deps. macOS 15 / iOS 17 minimums for reusability.
2. **`bhyve-mac`** — the macOS app. Consumes `bhyve-swift` via SPM pinned by version. Single Xcode project, two targets.

### Target layout (`bhyve-mac`)

- **`BhyveMenuBar`** — LSUIElement app (no dock icon). Menu bar item + popover. Owns the WebSocket and authoritative in-memory state. Sole writer of the shared snapshot.
- **`BhyveWidget`** — Widget extension. Reads the shared snapshot; interactive widget buttons invoke App Intents.

### State sharing

- App Group container `group.com.waitbutY.bhyve` holds `snapshot.json` (latest state) and shared Keychain items.
- Keychain access group `group.com.waitbutY.bhyve` so widget App Intents can read credentials without going through the app.

### Data flow

```
              ┌────────────────┐
   REST ─────►│                │────► snapshot.json ────► Widget TimelineProvider
              │  BhyveMenuBar  │                    │
 WebSocket ──►│  (authority)   │                    └──► WidgetCenter.reloadAllTimelines()
              │                │
              └────────────────┘
                       ▲
                       │ App Intent (StopWatering, SetRainDelay, StartZone)
              ┌────────┴───────┐
              │  BhyveWidget   │────► BHyveClient (short-lived) ────► API
              └────────────────┘
```

- Menu bar app hydrates state from REST on launch, then keeps a persistent WebSocket. Each event updates in-memory `AppState` → debounced 250 ms → writes `snapshot.json` atomically → reloads widget timelines.
- Every 15 minutes, opportunistic REST reconciliation to correct any WebSocket drift (min 5 min between full refreshes).
- Widget's `TimelineProvider` reads `snapshot.json`. If stale (>30 min) or missing, falls back to a one-shot REST call.
- Widget buttons invoke App Intents that construct a short-lived `BHyveClient` (reads token from shared Keychain), execute the mutation, and reload timelines.

## `bhyve-swift` package

### Layout

```
bhyve-swift/
├── Package.swift
├── README.md
├── LICENSE                        // MIT
├── CHANGELOG.md
├── Sources/BHyve/
│   ├── BHyveClient.swift          // actor, public façade
│   ├── Auth/
│   │   ├── CredentialStore.swift  // protocol
│   │   └── SessionToken.swift
│   ├── REST/
│   │   ├── RESTTransport.swift    // URLSession wrapper, 401 → re-auth
│   │   └── Endpoints.swift        // enum-case per endpoint
│   ├── WebSocket/
│   │   ├── EventSocket.swift      // reconnect + ping loop
│   │   └── Events.swift           // decoded event enum
│   └── Models/
│       ├── Device.swift
│       ├── Zone.swift
│       ├── Program.swift
│       ├── WateringEvent.swift
│       └── Battery.swift
└── Tests/BHyveTests/
    ├── Fixtures/                  // captured JSON responses + WS frames
    ├── RESTTransportTests.swift
    ├── EventSocketTests.swift
    └── ClientIntegrationTests.swift  // opt-in, INTEGRATION=1
```

### Public API

```swift
public actor BHyveClient {
    public init(credentialStore: any BHyveCredentialStore,
                urlSession: URLSession = .shared)

    public func login(email: String, password: String) async throws
    public func devices() async throws -> [Device]
    public func programs(userID: String) async throws -> [Program]
    public func wateringHistory(deviceID: String, since: Date? = nil) async throws -> [WateringEvent]

    public func startZones(deviceID: String, stations: [ZoneRun]) async throws
    public func stopWatering(deviceID: String) async throws
    public func setRainDelay(deviceID: String, hours: Int) async throws
    public func updateProgram(_ program: Program) async throws

    public func events() -> AsyncThrowingStream<BHyveEvent, Error>
}

public struct ZoneRun: Sendable {
    public let station: Int
    public let minutes: Int
}

public enum BHyveEvent: Sendable {
    case wateringInProgress(deviceID: String, station: Int, runTime: Int)
    case wateringComplete(deviceID: String, station: Int)
    case deviceIdle(deviceID: String)
    case batteryStatus(deviceID: String, percent: Int, charging: Bool)
    case rainDelay(deviceID: String, hours: Int)
    case programChanged(deviceID: String, programID: String)
    case fault(deviceID: String, station: Int, code: String)
}

public protocol BHyveCredentialStore: Sendable {
    func loadCredentials() async throws -> (email: String, password: String)?
    func loadToken() async throws -> String?
    func store(token: String) async throws
    func clearToken() async throws
}
```

### Behavior contracts

- `BHyveClient` is an actor. All session state (token, user ID) is serialized.
- REST calls 401 → transparent single retry after re-`login()` using cached credentials from `CredentialStore`. If re-login also fails, error propagates.
- `events()` returns a stream that never completes normally. On socket drop it reconnects with exponential backoff (1s, 2s, 5s, 15s, 30s, 60s, then 60s indefinitely — no attempt cap). Errors are surfaced only for terminal auth failures.
- Ping every 25 s (per observed server behavior), driven by a `Task` internal to `EventSocket`.
- No global state, no singletons.

### API endpoints used

- `POST /v1/session` — login. Response includes `orbit_api_key` (JWT) and `user_id`.
- `GET /v1/devices?user_id={userID}` — device list with `battery`, `firmware_version`, `hardware_version`, `zones`, `status.watering_status`, `status.rain_delay`, `status.next_start_time`, `status.next_start_programs`.
- `GET /v1/watering_events/{deviceID}` — history.
- `GET /v1/sprinkler_timer_programs?device_id={deviceID}` — programs.
- `PUT /v1/sprinkler_timer_programs/{programID}` — update program.
- `PUT /v1/devices/{deviceID}` — set `rain_delay` (hours).
- `wss://api.orbitbhyve.com/v1/events` — WebSocket. First message: `{"event":"app_connection","orbit_session_token":"<jwt>"}`.
- WebSocket `change_mode`: manual zone start (`stations: [{station, run_time}]`) or stop (`stations: []`).

Auth headers on REST: both `orbit-api-key` and `Orbit-Session-Token` set to the JWT.

## `bhyve-mac` app

### Layout

```
bhyve-mac/
├── BhyveMac.xcodeproj
├── README.md
├── LICENSE                          // MIT
├── CHANGELOG.md
├── App/                             // BhyveMenuBar target
│   ├── BhyveMenuBarApp.swift        // @main, MenuBarExtra scene
│   ├── AppState.swift               // @Observable, owns BHyveClient
│   ├── EventPump.swift              // consumes client.events()
│   ├── SnapshotWriter.swift         // atomic JSON write
│   ├── Notifications.swift          // UNUserNotificationCenter glue
│   ├── Keychain.swift               // BHyveCredentialStore impl
│   └── Views/
│       ├── MenuBarPopover.swift
│       ├── DeviceRow.swift
│       ├── ZoneControls.swift       // start/stop + duration picker
│       ├── ProgramEditor.swift      // edit existing only
│       ├── RainDelayMenu.swift      // 24/48/72h quick-set
│       ├── HistoryView.swift
│       └── LoginView.swift
├── Widget/                          // BhyveWidget target
│   ├── BhyveWidgetBundle.swift
│   ├── StatusWidget.swift           // TimelineProvider + view
│   ├── SnapshotReader.swift
│   └── Intents/
│       ├── StopWateringIntent.swift
│       ├── SetRainDelayIntent.swift
│       ├── StartZoneIntent.swift
│       └── WidgetConfigurationIntent.swift  // device picker
├── Shared/                          // linked into both targets
│   ├── Snapshot.swift               // Codable state model
│   ├── AppGroup.swift               // container URL, constants
│   └── SharedKeychain.swift         // access-group-scoped
└── Tests/
    ├── AppStateTests.swift
    ├── SnapshotRoundTripTests.swift
    └── IntentTests.swift
```

### Snapshot model

```swift
public struct Snapshot: Codable, Sendable {
    public let generatedAt: Date
    public let account: AccountRef
    public let devices: [DeviceSnapshot]
    public let programs: [ProgramSnapshot]
    public let recentHistory: [WateringEventSnapshot]  // last 14 days
}

public struct DeviceSnapshot: Codable, Sendable {
    public let id: String
    public let name: String
    public let firmwareVersion: String
    public let hardwareVersion: String
    public let isBridged: Bool
    public let battery: BatteryState?      // nil for AC-powered
    public let zones: [ZoneSnapshot]
    public let watering: ActiveWatering?   // nil if idle
    public let rainDelayUntil: Date?
    public let nextScheduledRun: ScheduledRun?
    public let isOnline: Bool
}
```

Written to `{groupContainer}/snapshot.json` atomically: write `snapshot.json.tmp` → `rename()`. Widget reader retries decode once on failure.

### Snapshot readers

Only three sites read the snapshot, all in the widget target:

1. `Widget/SnapshotReader.swift` — reads + decodes, retries once on transient decode failure.
2. `Widget/StatusWidget.swift` — `TimelineProvider.timeline(for:in:)` calls `SnapshotReader.load()`. On stale (>30 min) or missing, falls back to `BHyveClient.devices()` REST call.
3. `Widget/Intents/WidgetConfigurationIntent.swift` — enumerates devices for the widget's "which device?" picker.

The menu bar app never reads `snapshot.json`. It is the sole writer; `AppState` in memory is authoritative and is hydrated from REST on launch. App Intents also do not read the snapshot — they receive `deviceID` (and station/hours) as intent parameters baked into the widget entry at timeline generation.

### Menu bar UI

Popover contents:

- **Header:** connection status dot (green / yellow / red), account email, gear button → settings sheet.
- **Per-device card**, stacked vertically:
  - Device name, battery % (if battery-powered), firmware version (small, tappable to copy).
  - Rain-delay indicator if active, with "Cancel" button.
  - Zone list: name + "Start" button + adjacent duration stepper (defaulting to the device's configured preset), or "Stop" if running.
  - "Queue zones" mode: check multiple zones with durations → "Run queue" — runs sequentially, sending the next `startZones` on `wateringComplete`.
  - "Programs" disclosure: existing programs with enable/disable toggle, budget %, tap to open program editor sheet.
  - "History" disclosure: last 14 days grouped by day.
  - Rain-delay menu: 24 h / 48 h / 72 h / Custom / Cancel.
- **Footer:** "Refresh" (forces REST re-fetch), version string.

### Widget UI

- **Small:** one device — icon + name + status ("Idle" / "Zone 3, 12m left" / "Rain delay 2d"). If watering, a "Stop" button.
- **Medium:** small + next scheduled run + "Rain delay 24h" button.
- **Large:** all devices as compact rows with status + battery. Tap opens app.
- **Configuration intent** lets user pick the device for small/medium widgets.

### App Intents

- `StopWateringIntent(deviceID:)` → `client.stopWatering`.
- `SetRainDelayIntent(deviceID:, hours:)` → `client.setRainDelay`.
- `StartZoneIntent(deviceID:, station:, minutes:)` → `client.startZones`.

Each intent constructs a short-lived `BHyveClient` with shared Keychain store, executes, and reloads widget timelines. Destructive actions (`StopWateringIntent`) show a confirmation dialog. Failed intents return a dialog result string surfaced by the widget.

### Notifications

Triggered from WebSocket events, delivered by the menu bar app via `UNUserNotificationCenter`:

- `wateringInProgress` → "Watering started: {Device} zone {N} ({minutes})".
- `wateringComplete` → "Watering complete: {Device} zone {N}".
- `batteryStatus` where percent < 20 → "Low battery: {Device} ({N}%)".
- Socket disconnected > 5 min → "B-hyve offline".
- `rainDelay` set by device (not user-initiated) → "Rain delay set: {N}h".

Each category individually toggleable in settings.

### Auth & credentials

- Credentials in Keychain with access group `group.com.waitbutY.bhyve`.
- Token stored alongside credentials. On 401, `BHyveClient` transparently re-logs in and retries once.
- First-launch login is a sheet in the menu bar popover. Settings has "sign out" and "change credentials."

### Error handling

- REST errors during user-initiated actions: inline error banner in popover with retry.
- Background reconciliation errors: silent log; three consecutive failures → connection dot yellow.
- WebSocket disconnect: connection dot yellow, backoff reconnect. Notification after 5 continuous minutes offline.
- Auth failure after re-auth: connection dot red, popover shows "Sign in again," snapshot preserved but marked stale.
- App Intent errors: return dialog result string; widget renders "Failed — open app."

### Multi-zone queue

- Queue state lives in `AppState` (menu bar only, not persisted to snapshot).
- Sends first `startZones` immediately; on `wateringComplete` for that zone, sends the next.
- Manual stop or app quit mid-queue clears the queue. No cross-restart resume.
- Queue state visible in popover ("Running: Zone 2 of 4").

### Rate limiting

- Cap REST calls to one per second in `RESTTransport`.
- Debounce user-driven mutations (e.g., budget slider drag) to at most one send per 500 ms.
- WebSocket ping fixed at 25 s.

## Testing

### `bhyve-swift`

- **Unit (default in CI):**
  - `RESTTransportTests` — mock `URLProtocol`, feed captured JSON. Covers happy path, 401-retry, malformed response.
  - `EventSocketTests` — decode captured WebSocket frames (one per event type). Round-trip assertions.
  - `AuthTests` — verify `CredentialStore` mock is called, transparent re-login on 401.
- **Integration (opt-in, `INTEGRATION=1`):**
  - Real login → list devices → start/stop `BHYVE_TEST_ZONE` → assert WebSocket delivers `wateringInProgress` + `wateringComplete`.
  - Skipped in CI. Run manually before tagging releases.

### `bhyve-mac`

- `AppStateTests` — feed synthetic `BHyveEvent`s into `AppState`, assert derived UI state (running zones, next scheduled runs, connection status).
- `SnapshotRoundTripTests` — encode → decode `Snapshot`, no data loss; verify atomic write path.
- `IntentTests` — invoke each App Intent with fake `BHyveClient`, assert correct API method + params; verify error dialog string.
- No UI snapshot tests in v1.

### CI

- Both repos on GitHub Actions under `waitbutY`.
- `bhyve-swift`: `swift test` on macOS-latest per push/PR. Release workflow tags + publishes DocC.
- `bhyve-mac`: `xcodebuild -scheme BhyveMenuBar test` + `xcodebuild -scheme BhyveWidget build` on macOS-latest with Xcode 16.

## Distribution

Personal use, unsigned or Developer ID signed by the user's personal team. `bhyve-mac` README documents:

- Xcode → set Team → Product → Archive → export as Developer ID for local install without Gatekeeper griping, or ad-hoc sign + right-click-open the first time.
- Interactive widgets require the app to have been launched at least once so the widget extension is registered.

No notarization, no Sparkle auto-update, no App Store.

## Versioning

- `bhyve-swift` — SemVer, tagged releases. App pins via `.upToNextMinor`.
- `bhyve-mac` — bumped freely; no external consumers.

## Open questions

None blocking implementation. During build, expect to discover:

- Exact JWT lifetime (empirical; handle via existing 401 retry).
- Whether concurrent WebSocket connections per account are allowed (may affect whether widget can hold its own socket — v1 avoids this by funneling live data through the menu bar app only).
- Full accepted-key schema for `updateProgram` PUT payload (crib from `sebr/bhyve-home-assistant` and verify).

## References

- `sebr/bhyve-home-assistant` — most complete open-source B-hyve client, especially `pybhyve/client.py` (REST) and `const.py` (WebSocket event catalog).
- `billchurch/bhyve-api` — Node.js client; `WebSocketManager.js` is a useful ping/reconnect reference.
- `billchurch/bhyve-mqtt` — MQTT bridge; not used but referenced as prior art.
