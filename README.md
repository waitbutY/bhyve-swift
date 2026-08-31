# bhyve-swift

A Swift client for the Orbit B-hyve smart sprinkler cloud API (REST + WebSocket).
Zero third-party runtime dependencies.

## Requirements

- Swift 6.0+
- macOS 15+ or iOS 17+

## Install (SwiftPM)

```swift
.package(url: "https://github.com/waitbutY/bhyve-swift.git", .upToNextMinor(from: "0.1.0"))
```

## Usage

```swift
import BHyve

let store = InMemoryCredentialStore()
let client = BHyveClient(credentialStore: store)

try await client.login(email: "you@example.com", password: "…")

for device in try await client.devices() {
    print("\(device.name) — battery: \(device.battery?.percent ?? -1)%")
}

try await client.startZones(deviceID: someID, stations: [ZoneRun(station: 1, minutes: 5)])

for try await event in client.events() {
    print("event: \(event)")
}
```

## Known issues (0.1.x)

- The WebSocket hello handshake at `wss://api.orbitbhyve.com/v1/events` is currently
  dropped by the server regardless of payload shape — see [#1](https://github.com/waitbutY/bhyve-swift/issues/1).
  `client.events()` will reconnect-loop indefinitely without emitting frames, and
  the WebSocket-based mutations (`startZones`, `stopWatering`) will fail. REST
  (`devices`, `programs`, `wateringHistory`, `setRainDelay`, `updateProgram`) is
  fully functional. See `LiveWebSocketProbeTests` for how to diagnose additional
  candidate hello payloads.

## License

MIT
