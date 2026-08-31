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

## License

MIT
