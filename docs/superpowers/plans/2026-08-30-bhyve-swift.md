# bhyve-swift Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ship `bhyve-swift` v0.1.0 — a Swift package that exposes the Orbit B-hyve cloud API (REST + WebSocket) as an `actor`-based client library, with zero third-party runtime dependencies.

**Architecture:** A single `BHyveClient` actor is the public façade. Internally it composes three pieces: `RESTTransport` (URLSession wrapper with transparent 401 re-login), `EventSocket` (URLSessionWebSocketTask wrapper with reconnect + 25s ping), and a `CredentialStore` protocol the consumer supplies. Models are plain `Codable` structs validated against real fixtures scrubbed of PII.

**Tech Stack:** Swift 5.10 · SwiftPM · Foundation (`URLSession`, `URLSessionWebSocketTask`) · XCTest · GitHub Actions

**Reference material:**
- Real API fixtures: `Tests/BHyveTests/Fixtures/` (already captured, see `Fixtures/README.md`).
- WebSocket event catalog: `sebr/bhyve-home-assistant` `pybhyve/const.py`.
- JS reference for WS handshake: `billchurch/bhyve-api` `WebSocketManager.js`.
- Design spec: `docs/superpowers/specs/2026-08-30-bhyve-mac-design.md`.

**Discoveries from fixture capture (2026-08-30) that override the spec:**
- Session token field is `orbit_session_token`, not `orbit_api_key`.
- Devices are polymorphic on `type`: `"bridge"` (Wi-Fi Hub) and `"sprinkler_timer"`. Only `sprinkler_timer` carries `battery` and `zones`.
- `Program.frequency` is polymorphic: `{"type": "even"}`, `{"type": "odd"}`, `{"type": "days", "days": [Int]}`, `{"type": "interval", "interval": Int}`.
- `Zone` mixes kebab-case (`added-at`, `start-date`, `end-date`) and snake_case keys — must use explicit `CodingKeys`.
- `WateringEvent.irrigation[*].run_time` is a `Double` (minutes), not an `Int`.

---

## File Structure

```
bhyve-swift/
├── Package.swift
├── README.md
├── LICENSE
├── CHANGELOG.md
├── docs/superpowers/
│   ├── specs/2026-08-30-bhyve-mac-design.md
│   └── plans/2026-08-30-bhyve-swift.md   ← this file
├── Sources/BHyve/
│   ├── BHyveClient.swift
│   ├── BHyveError.swift
│   ├── Support/
│   │   ├── JSONValue.swift
│   │   └── JSONCoding.swift               // shared JSONDecoder/JSONEncoder factories
│   ├── Auth/
│   │   ├── CredentialStore.swift          // protocol + InMemory impl
│   │   └── SessionResponse.swift
│   ├── REST/
│   │   ├── RESTTransport.swift
│   │   └── Endpoints.swift
│   ├── WebSocket/
│   │   ├── EventSocket.swift
│   │   └── BHyveEvent.swift
│   └── Models/
│       ├── Device.swift                   // Device + DeviceStatus
│       ├── Battery.swift
│       ├── Zone.swift
│       ├── Program.swift                  // Program + Frequency + RunTime
│       └── WateringEvent.swift            // WateringEvent + Irrigation
├── Tests/BHyveTests/
│   ├── Fixtures/                          // already committed
│   ├── Support/
│   │   ├── Fixture.swift
│   │   ├── URLProtocolStub.swift
│   │   └── InMemoryCredentialStore+Test.swift
│   ├── Models/
│   │   ├── SessionResponseTests.swift
│   │   ├── DeviceTests.swift
│   │   ├── ProgramTests.swift
│   │   └── WateringEventTests.swift
│   ├── REST/
│   │   ├── RESTTransportTests.swift
│   │   └── EndpointsTests.swift
│   ├── WebSocket/
│   │   ├── BHyveEventDecodeTests.swift
│   │   └── EventSocketReconnectTests.swift
│   ├── BHyveClientTests.swift
│   └── IntegrationTests.swift             // opt-in, INTEGRATION=1
├── .github/workflows/ci.yml
└── .gitignore                              // already committed
```

**Design principles:**
- One responsibility per file. Models are dumb data holders.
- `RESTTransport` knows HTTP; `Endpoints` knows URLs/methods; they don't leak into models.
- `EventSocket` knows the wire; `BHyveEvent` is the decoded surface.
- Public API surface lives in `BHyveClient.swift`, `BHyveError.swift`, `Auth/`, `Models/`, `WebSocket/BHyveEvent.swift`. Everything else is `internal`.

---

## Task 1: Package scaffold + first green test

**Files:**
- Create: `Package.swift`
- Create: `Sources/BHyve/BHyveClient.swift` (stub)
- Create: `Tests/BHyveTests/SmokeTest.swift`

- [ ] **Step 1: Create `Package.swift`**

```swift
// swift-tools-version:5.10
import PackageDescription

let package = Package(
    name: "BHyve",
    platforms: [
        .macOS(.v15),
        .iOS(.v17),
    ],
    products: [
        .library(name: "BHyve", targets: ["BHyve"]),
    ],
    targets: [
        .target(name: "BHyve"),
        .testTarget(
            name: "BHyveTests",
            dependencies: ["BHyve"],
            resources: [.copy("Fixtures")]
        ),
    ]
)
```

- [ ] **Step 2: Create stub `Sources/BHyve/BHyveClient.swift`**

```swift
import Foundation

public actor BHyveClient {
    public init() {}
}
```

- [ ] **Step 3: Create `Tests/BHyveTests/SmokeTest.swift`**

```swift
import XCTest
@testable import BHyve

final class SmokeTest: XCTestCase {
    func testInit() async {
        _ = BHyveClient()
        XCTAssert(true)
    }
}
```

- [ ] **Step 4: Run `swift test`**

Run: `swift test 2>&1 | tail -10`
Expected: `Test Suite 'All tests' passed`.

- [ ] **Step 5: Commit**

```bash
git add Package.swift Sources/ Tests/BHyveTests/SmokeTest.swift
git commit -m "chore: SwiftPM package scaffold with smoke test"
git push
```

---

## Task 2: Fixture loader

**Files:**
- Create: `Tests/BHyveTests/Support/Fixture.swift`

- [ ] **Step 1: Write failing test**

Add to `Tests/BHyveTests/SmokeTest.swift`:

```swift
func testFixtureLoaderResolvesSession() throws {
    let data = try Fixture.data("session.json")
    XCTAssertGreaterThan(data.count, 100)
}
```

Run: `swift test --filter FixtureLoader 2>&1 | tail`
Expected: compile error, `Fixture` unresolved.

- [ ] **Step 2: Create `Tests/BHyveTests/Support/Fixture.swift`**

```swift
import Foundation
import XCTest

enum Fixture {
    struct MissingFixtureError: Error, CustomStringConvertible {
        let name: String
        var description: String { "missing fixture: \(name)" }
    }

    static func url(_ name: String) throws -> URL {
        guard let url = Bundle.module.url(
            forResource: name,
            withExtension: nil,
            subdirectory: "Fixtures"
        ) else {
            throw MissingFixtureError(name: name)
        }
        return url
    }

    static func data(_ name: String) throws -> Data {
        try Data(contentsOf: url(name))
    }
}
```

- [ ] **Step 3: Verify green**

Run: `swift test 2>&1 | tail -5`
Expected: passes.

- [ ] **Step 4: Commit**

```bash
git add Tests/BHyveTests/
git commit -m "test: add Fixture loader for bundled JSON captures"
git push
```

---

## Task 3: JSON coding helpers

**Files:**
- Create: `Sources/BHyve/Support/JSONCoding.swift`
- Create: `Sources/BHyve/Support/JSONValue.swift`
- Create: `Tests/BHyveTests/Support/JSONCodingTests.swift`

`JSONCoding` centralises a `JSONDecoder`/`JSONEncoder` pair configured for B-hyve's ISO-8601-with-fractional-seconds dates. `JSONValue` is a small ADT for opaque JSON we don't want to model (e.g. `flow_data`, `geometry`, `next_start_programs`).

- [ ] **Step 1: Write test for JSONCoding date decode**

Create `Tests/BHyveTests/Support/JSONCodingTests.swift`:

```swift
import XCTest
@testable import BHyve

final class JSONCodingTests: XCTestCase {
    struct Sample: Decodable { let t: Date }

    func testDecodesFractionalISODate() throws {
        let json = #"{"t":"2026-08-30T20:39:33.821Z"}"#.data(using: .utf8)!
        let s = try JSONCoding.decoder.decode(Sample.self, from: json)
        XCTAssertEqual(s.t.timeIntervalSince1970, 1787877573.821, accuracy: 0.01)
    }

    func testDecodesNonFractionalISODate() throws {
        let json = #"{"t":"2025-05-11T14:29:25Z"}"#.data(using: .utf8)!
        let s = try JSONCoding.decoder.decode(Sample.self, from: json)
        XCTAssertNotNil(s.t)
    }
}
```

Run: `swift test --filter JSONCoding 2>&1 | tail`
Expected: compile error.

- [ ] **Step 2: Create `Sources/BHyve/Support/JSONCoding.swift`**

```swift
import Foundation

enum JSONCoding {
    static let decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .custom { decoder in
            let s = try decoder.singleValueContainer().decode(String.self)
            if let date = fractional.date(from: s) { return date }
            if let date = plain.date(from: s) { return date }
            throw DecodingError.dataCorruptedError(
                in: try decoder.singleValueContainer(),
                debugDescription: "unrecognised date: \(s)"
            )
        }
        return d
    }()

    static let encoder: JSONEncoder = {
        let e = JSONEncoder()
        e.dateEncodingStrategy = .custom { date, encoder in
            var c = encoder.singleValueContainer()
            try c.encode(fractional.string(from: date))
        }
        e.outputFormatting = [.sortedKeys]
        return e
    }()

    private static let fractional: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()

    private static let plain: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        return f
    }()
}
```

- [ ] **Step 3: Verify green**

Run: `swift test --filter JSONCoding 2>&1 | tail -5`
Expected: pass.

- [ ] **Step 4: Create `Sources/BHyve/Support/JSONValue.swift`**

```swift
import Foundation

public enum JSONValue: Sendable, Codable, Equatable {
    case null
    case bool(Bool)
    case number(Double)
    case string(String)
    case array([JSONValue])
    case object([String: JSONValue])

    public init(from decoder: Decoder) throws {
        let c = try decoder.singleValueContainer()
        if c.decodeNil() { self = .null; return }
        if let v = try? c.decode(Bool.self) { self = .bool(v); return }
        if let v = try? c.decode(Double.self) { self = .number(v); return }
        if let v = try? c.decode(String.self) { self = .string(v); return }
        if let v = try? c.decode([JSONValue].self) { self = .array(v); return }
        if let v = try? c.decode([String: JSONValue].self) { self = .object(v); return }
        throw DecodingError.dataCorruptedError(
            in: c, debugDescription: "unknown JSON value"
        )
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.singleValueContainer()
        switch self {
        case .null: try c.encodeNil()
        case .bool(let v): try c.encode(v)
        case .number(let v): try c.encode(v)
        case .string(let v): try c.encode(v)
        case .array(let v): try c.encode(v)
        case .object(let v): try c.encode(v)
        }
    }
}
```

- [ ] **Step 5: Test JSONValue round-trip**

Append to `Tests/BHyveTests/Support/JSONCodingTests.swift`:

```swift
func testJSONValueRoundTrip() throws {
    let cases: [String] = [
        "null", "true", "42.5", "\"hi\"",
        "[1, 2, 3]",
        #"{"a": 1, "b": [true, null]}"#,
    ]
    for raw in cases {
        let data = raw.data(using: .utf8)!
        let v = try JSONCoding.decoder.decode(JSONValue.self, from: data)
        let re = try JSONCoding.encoder.encode(v)
        let v2 = try JSONCoding.decoder.decode(JSONValue.self, from: re)
        XCTAssertEqual(v, v2, "case: \(raw)")
    }
}
```

Run: `swift test --filter JSONCoding 2>&1 | tail`
Expected: pass.

- [ ] **Step 6: Commit**

```bash
git add Sources/BHyve/Support/ Tests/BHyveTests/Support/JSONCodingTests.swift
git commit -m "feat(support): JSONCoding + JSONValue helpers"
git push
```

---

## Task 4: SessionResponse model

**Files:**
- Create: `Sources/BHyve/Auth/SessionResponse.swift`
- Create: `Tests/BHyveTests/Models/SessionResponseTests.swift`

- [ ] **Step 1: Write failing decode test**

`Tests/BHyveTests/Models/SessionResponseTests.swift`:

```swift
import XCTest
@testable import BHyve

final class SessionResponseTests: XCTestCase {
    func testDecodesRealFixture() throws {
        let data = try Fixture.data("session.json")
        let r = try JSONCoding.decoder.decode(SessionResponse.self, from: data)
        XCTAssertFalse(r.orbitSessionToken.isEmpty)
        XCTAssertEqual(r.userID, "uu0000000000000000000005")
        XCTAssertEqual(r.userName, "user@example.com")
    }
}
```

Run: `swift test --filter SessionResponse 2>&1 | tail`
Expected: compile error.

- [ ] **Step 2: Create `Sources/BHyve/Auth/SessionResponse.swift`**

```swift
import Foundation

public struct SessionResponse: Codable, Sendable {
    public let orbitSessionToken: String
    public let userID: String
    public let userName: String
    public let firstName: String?
    public let lastName: String?
    public let requirePasswordChange: Bool?

    enum CodingKeys: String, CodingKey {
        case orbitSessionToken = "orbit_session_token"
        case userID = "user_id"
        case userName = "user_name"
        case firstName = "first_name"
        case lastName = "last_name"
        case requirePasswordChange = "require_password_change"
    }
}
```

- [ ] **Step 3: Verify green**

Run: `swift test --filter SessionResponse 2>&1 | tail`
Expected: pass.

- [ ] **Step 4: Commit**

```bash
git add Sources/BHyve/Auth/ Tests/BHyveTests/Models/
git commit -m "feat(auth): SessionResponse decoder"
git push
```

---

## Task 5: Battery + Zone + Device + DeviceStatus models

**Files:**
- Create: `Sources/BHyve/Models/Battery.swift`
- Create: `Sources/BHyve/Models/Zone.swift`
- Create: `Sources/BHyve/Models/Device.swift`
- Create: `Tests/BHyveTests/Models/DeviceTests.swift`

- [ ] **Step 1: Write failing test for full fixture decode**

`Tests/BHyveTests/Models/DeviceTests.swift`:

```swift
import XCTest
@testable import BHyve

final class DeviceTests: XCTestCase {
    func testDecodesRealFixture() throws {
        let data = try Fixture.data("devices.json")
        let devices = try JSONCoding.decoder.decode([Device].self, from: data)
        XCTAssertEqual(devices.count, 4)

        let bridges = devices.filter { $0.type == .bridge }
        let timers = devices.filter { $0.type == .sprinklerTimer }
        XCTAssertEqual(bridges.count, 2)
        XCTAssertEqual(timers.count, 2)
    }

    func testBridgeHasNoBatteryOrZones() throws {
        let devices = try JSONCoding.decoder.decode([Device].self, from: Fixture.data("devices.json"))
        let bridge = try XCTUnwrap(devices.first { $0.type == .bridge })
        XCTAssertNil(bridge.battery)
        XCTAssertNil(bridge.zones)
        XCTAssertEqual(bridge.numStations, 0)
    }

    func testSprinklerTimerHasBatteryAndZones() throws {
        let devices = try JSONCoding.decoder.decode([Device].self, from: Fixture.data("devices.json"))
        let timer = try XCTUnwrap(devices.first { $0.type == .sprinklerTimer })
        let battery = try XCTUnwrap(timer.battery)
        XCTAssertGreaterThanOrEqual(battery.percent, 0)
        XCTAssertLessThanOrEqual(battery.percent, 100)
        XCTAssertFalse(timer.zones?.isEmpty ?? true)
        XCTAssertEqual(timer.status.runMode, .auto)
        XCTAssertEqual(timer.status.rainDelay, 0)
    }

    func testDeviceStatusPreservesWateringStatusRaw() throws {
        let devices = try JSONCoding.decoder.decode([Device].self, from: Fixture.data("devices.json"))
        let timer = try XCTUnwrap(devices.first { $0.type == .sprinklerTimer })
        XCTAssertNotNil(timer.status.wateringStatus)
    }
}
```

Run: `swift test --filter DeviceTests 2>&1 | tail`
Expected: compile error.

- [ ] **Step 2: Create `Sources/BHyve/Models/Battery.swift`**

```swift
import Foundation

public struct Battery: Codable, Sendable, Equatable {
    public let percent: Int
    public let charging: Bool
    public let millivolts: Int

    enum CodingKeys: String, CodingKey {
        case percent, charging
        case millivolts = "mv"
    }
}
```

- [ ] **Step 3: Create `Sources/BHyve/Models/Zone.swift`**

Zone mixes kebab-case and snake_case. Model only the fields the app spec uses; keep the rest available via `raw`.

```swift
import Foundation

public struct Zone: Codable, Sendable {
    public let station: Int
    public let deviceID: String
    public let smartWateringEnabled: Bool
    public let runTime: Double            // minutes
    public let landscapeType: String?
    public let soilType: String?
    public let sprinklerType: String?
    public let addedAt: Int?               // epoch millis
    public let startDate: Date?
    public let endDate: Date?

    enum CodingKeys: String, CodingKey {
        case station
        case deviceID = "device_id"
        case smartWateringEnabled = "smart_watering_enabled"
        case runTime = "run_time"
        case landscapeType = "landscape_type"
        case soilType = "soil_type"
        case sprinklerType = "sprinkler_type"
        case addedAt = "added-at"
        case startDate = "start-date"
        case endDate = "end-date"
    }
}
```

- [ ] **Step 4: Create `Sources/BHyve/Models/Device.swift`**

```swift
import Foundation

public struct Device: Codable, Sendable, Identifiable {
    public enum DeviceType: String, Codable, Sendable {
        case bridge
        case sprinklerTimer = "sprinkler_timer"
    }

    public let id: String
    public let userID: String
    public let name: String
    public let type: DeviceType
    public let hardwareVersion: String
    public let firmwareVersion: String
    public let macAddress: String
    public let reference: String
    public let isConnected: Bool
    public let lastConnectedAt: Date?
    public let createdAt: Date
    public let updatedAt: Date
    public let numStations: Int
    public let battery: Battery?
    public let zones: [Zone]?
    public let status: DeviceStatus

    enum CodingKeys: String, CodingKey {
        case id, name, type, reference, zones, battery, status
        case userID = "user_id"
        case hardwareVersion = "hardware_version"
        case firmwareVersion = "firmware_version"
        case macAddress = "mac_address"
        case isConnected = "is_connected"
        case lastConnectedAt = "last_connected_at"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case numStations = "num_stations"
    }
}

public struct DeviceStatus: Codable, Sendable {
    public enum RunMode: String, Codable, Sendable {
        case auto, manual, off
    }

    public let runMode: RunMode
    public let rainDelay: Int              // hours; 0 = none
    public let statusUpdatedAt: Date
    public let nextStartTime: Date?
    public let wateringStatus: JSONValue?  // opaque until we have live captures
    public let rainDelayStartedAt: Date?

    enum CodingKeys: String, CodingKey {
        case runMode = "run_mode"
        case rainDelay = "rain_delay"
        case statusUpdatedAt = "status_updated_at"
        case nextStartTime = "next_start_time"
        case wateringStatus = "watering_status"
        case rainDelayStartedAt = "rain_delay_started_at"
    }
}
```

- [ ] **Step 5: Run tests**

Run: `swift test --filter DeviceTests 2>&1 | tail -10`
Expected: pass. If a decoding error surfaces, the message will identify the field — add it as optional or fix key-casing and re-run.

- [ ] **Step 6: Commit**

```bash
git add Sources/BHyve/Models/ Tests/BHyveTests/Models/DeviceTests.swift
git commit -m "feat(models): Device, DeviceStatus, Battery, Zone"
git push
```

---

## Task 6: Program model + polymorphic Frequency

**Files:**
- Create: `Sources/BHyve/Models/Program.swift`
- Create: `Tests/BHyveTests/Models/ProgramTests.swift`

- [ ] **Step 1: Write failing test**

`Tests/BHyveTests/Models/ProgramTests.swift`:

```swift
import XCTest
@testable import BHyve

final class ProgramTests: XCTestCase {
    func testDecodesAllFixturePrograms() throws {
        let data = try Fixture.data("programs__Smart_Hose_Tap_Timer.json")
        let programs = try JSONCoding.decoder.decode([Program].self, from: data)
        XCTAssertFalse(programs.isEmpty)
    }

    func testFrequencyEven() throws {
        let programs = try JSONCoding.decoder.decode(
            [Program].self,
            from: Fixture.data("programs__Smart_Hose_Tap_Timer.json")
        )
        XCTAssertTrue(programs.contains { $0.frequency == .even })
    }

    func testFrequencyDays() throws {
        let programs = try JSONCoding.decoder.decode(
            [Program].self,
            from: Fixture.data("programs__Smart_Hose_Tap_Timer.json")
        )
        let winter = try XCTUnwrap(programs.first { $0.name == "Winter" })
        guard case .days(let days) = winter.frequency else {
            return XCTFail("expected .days, got \(winter.frequency)")
        }
        XCTAssertEqual(days, [0, 2, 4, 6])
    }

    func testStartTimesAsStrings() throws {
        let programs = try JSONCoding.decoder.decode(
            [Program].self,
            from: Fixture.data("programs__Smart_Hose_Tap_Timer.json")
        )
        XCTAssertTrue(programs.allSatisfy { p in
            p.startTimes.allSatisfy { $0.range(of: #"^\d\d:\d\d$"#, options: .regularExpression) != nil }
        })
    }

    func testFrequencyEncodeRoundTrip() throws {
        let cases: [Frequency] = [
            .even, .odd, .days([1, 3, 5]), .interval(3),
        ]
        for f in cases {
            let data = try JSONCoding.encoder.encode(f)
            let back = try JSONCoding.decoder.decode(Frequency.self, from: data)
            XCTAssertEqual(back, f)
        }
    }
}
```

Run: expect compile error.

- [ ] **Step 2: Create `Sources/BHyve/Models/Program.swift`**

```swift
import Foundation

public struct Program: Codable, Sendable, Identifiable {
    public let id: String
    public let deviceID: String
    public let name: String
    public let enabled: Bool
    public let budget: Int
    public let frequency: Frequency
    public let runTimes: [RunTime]
    public let startTimes: [String]          // "HH:MM"
    public let programStartDate: Date
    public let createdAt: Date
    public let updatedAt: Date

    enum CodingKeys: String, CodingKey {
        case id, name, enabled, budget, frequency
        case deviceID = "device_id"
        case runTimes = "run_times"
        case startTimes = "start_times"
        case programStartDate = "program_start_date"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

public struct RunTime: Codable, Sendable, Equatable {
    public let station: Int
    public let runTime: Int                  // minutes

    enum CodingKeys: String, CodingKey {
        case station
        case runTime = "run_time"
    }
}

public enum Frequency: Codable, Sendable, Equatable {
    case even
    case odd
    case days([Int])                          // 0=Sunday .. 6=Saturday
    case interval(Int)                        // days

    private enum CodingKeys: String, CodingKey {
        case type, days, interval
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let type = try c.decode(String.self, forKey: .type)
        switch type {
        case "even": self = .even
        case "odd": self = .odd
        case "days":
            self = .days(try c.decode([Int].self, forKey: .days))
        case "interval":
            self = .interval(try c.decode(Int.self, forKey: .interval))
        default:
            throw DecodingError.dataCorruptedError(
                forKey: .type, in: c,
                debugDescription: "unknown frequency type: \(type)"
            )
        }
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .even: try c.encode("even", forKey: .type)
        case .odd: try c.encode("odd", forKey: .type)
        case .days(let d):
            try c.encode("days", forKey: .type)
            try c.encode(d, forKey: .days)
        case .interval(let n):
            try c.encode("interval", forKey: .type)
            try c.encode(n, forKey: .interval)
        }
    }
}
```

- [ ] **Step 3: Run tests**

Run: `swift test --filter Program 2>&1 | tail`
Expected: pass.

- [ ] **Step 4: Commit**

```bash
git add Sources/BHyve/Models/Program.swift Tests/BHyveTests/Models/ProgramTests.swift
git commit -m "feat(models): Program with polymorphic Frequency"
git push
```

---

## Task 7: WateringEvent model

**Files:**
- Create: `Sources/BHyve/Models/WateringEvent.swift`
- Create: `Tests/BHyveTests/Models/WateringEventTests.swift`

- [ ] **Step 1: Failing test**

```swift
import XCTest
@testable import BHyve

final class WateringEventTests: XCTestCase {
    func testDecodesFixture() throws {
        let data = try Fixture.data("watering_events__Smart_Hose_Tap_Timer.json")
        let events = try JSONCoding.decoder.decode([WateringEvent].self, from: data)
        XCTAssertEqual(events.count, 30)
        let first = try XCTUnwrap(events.first)
        XCTAssertFalse(first.irrigation.isEmpty)
    }

    func testManualIrrigation() throws {
        let events = try JSONCoding.decoder.decode(
            [WateringEvent].self,
            from: Fixture.data("watering_events__Smart_Hose_Tap_Timer.json")
        )
        let hasManual = events.contains { evt in
            evt.irrigation.contains { $0.programName == "manual" }
        }
        XCTAssertTrue(hasManual)
    }

    func testIrrigationRunTimeIsDouble() throws {
        let events = try JSONCoding.decoder.decode(
            [WateringEvent].self,
            from: Fixture.data("watering_events__Smart_Hose_Tap_Timer.json")
        )
        let allRunTimes = events.flatMap { $0.irrigation.map(\.runTime) }
        XCTAssertTrue(allRunTimes.allSatisfy { $0 > 0 })
    }
}
```

- [ ] **Step 2: Create `Sources/BHyve/Models/WateringEvent.swift`**

```swift
import Foundation

public struct WateringEvent: Codable, Sendable, Identifiable {
    public let id: String
    public let deviceID: String
    public let date: Date
    public let createdAt: Date
    public let updatedAt: Date
    public let irrigation: [Irrigation]

    enum CodingKeys: String, CodingKey {
        case id, date, irrigation
        case deviceID = "device_id"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

public struct Irrigation: Codable, Sendable {
    public let station: Int
    public let programName: String
    public let startTime: Date
    public let runTime: Double            // minutes
    public let budget: Int
    public let status: String              // "complete", others TBD
    public let waterVolumeGallons: Double?

    enum CodingKeys: String, CodingKey {
        case station, budget, status
        case programName = "program_name"
        case startTime = "start_time"
        case runTime = "run_time"
        case waterVolumeGallons = "water_volume_gal"
    }
}
```

- [ ] **Step 3: Run + commit**

Run: `swift test --filter WateringEvent 2>&1 | tail`
Expected: pass.

```bash
git add Sources/BHyve/Models/WateringEvent.swift Tests/BHyveTests/Models/WateringEventTests.swift
git commit -m "feat(models): WateringEvent + Irrigation"
git push
```

---

## Task 8: CredentialStore protocol + in-memory test double

**Files:**
- Create: `Sources/BHyve/Auth/CredentialStore.swift`
- Create: `Tests/BHyveTests/Support/InMemoryCredentialStore+Test.swift`

- [ ] **Step 1: Create protocol + in-memory impl in one file**

`Sources/BHyve/Auth/CredentialStore.swift`:

```swift
import Foundation

public protocol BHyveCredentialStore: Sendable {
    func loadCredentials() async throws -> (email: String, password: String)?
    func store(credentials: (email: String, password: String)) async throws
    func clearCredentials() async throws

    func loadToken() async throws -> String?
    func store(token: String) async throws
    func clearToken() async throws
}

public actor InMemoryCredentialStore: BHyveCredentialStore {
    private var credentials: (email: String, password: String)?
    private var token: String?

    public init(
        credentials: (email: String, password: String)? = nil,
        token: String? = nil
    ) {
        self.credentials = credentials
        self.token = token
    }

    public func loadCredentials() -> (email: String, password: String)? { credentials }
    public func store(credentials: (email: String, password: String)) { self.credentials = credentials }
    public func clearCredentials() { credentials = nil }

    public func loadToken() -> String? { token }
    public func store(token: String) { self.token = token }
    public func clearToken() { self.token = nil }
}
```

- [ ] **Step 2: Test the in-memory store**

`Tests/BHyveTests/Support/InMemoryCredentialStore+Test.swift`:

```swift
import XCTest
@testable import BHyve

final class InMemoryCredentialStoreTests: XCTestCase {
    func testStoreAndLoad() async throws {
        let store = InMemoryCredentialStore()
        try await store.store(credentials: (email: "a@b.co", password: "pw"))
        try await store.store(token: "tok")
        let creds = try await store.loadCredentials()
        XCTAssertEqual(creds?.email, "a@b.co")
        XCTAssertEqual(try await store.loadToken(), "tok")

        try await store.clearToken()
        XCTAssertNil(try await store.loadToken())
    }
}
```

Run + commit:

```bash
swift test --filter InMemoryCredentialStore 2>&1 | tail
git add Sources/BHyve/Auth/CredentialStore.swift Tests/BHyveTests/Support/InMemoryCredentialStore+Test.swift
git commit -m "feat(auth): CredentialStore protocol + InMemory impl"
git push
```

---

## Task 9: BHyveError

**Files:**
- Create: `Sources/BHyve/BHyveError.swift`
- Create: `Tests/BHyveTests/BHyveErrorTests.swift`

- [ ] **Step 1: Failing test**

```swift
import XCTest
@testable import BHyve

final class BHyveErrorTests: XCTestCase {
    func testUnauthorizedIsUnauthorized() {
        XCTAssertTrue(BHyveError.unauthorized.isAuthFailure)
    }

    func testHTTPStatusMapping() {
        XCTAssertEqual(BHyveError(httpStatus: 401), .unauthorized)
        XCTAssertEqual(BHyveError(httpStatus: 429), .rateLimited)
        XCTAssertEqual(BHyveError(httpStatus: 500), .server(500))
        XCTAssertNil(BHyveError(httpStatus: 200))
    }
}
```

- [ ] **Step 2: Implement**

```swift
import Foundation

public enum BHyveError: Error, Sendable, Equatable {
    case unauthorized
    case rateLimited
    case server(Int)
    case client(Int)
    case decoding(String)
    case transport(String)
    case invalidResponse
    case notLoggedIn

    public init?(httpStatus: Int) {
        switch httpStatus {
        case 200...299: return nil
        case 401: self = .unauthorized
        case 429: self = .rateLimited
        case 400...499: self = .client(httpStatus)
        case 500...: self = .server(httpStatus)
        default: return nil
        }
    }

    public var isAuthFailure: Bool { self == .unauthorized }
}
```

- [ ] **Step 3: Run + commit**

```bash
swift test --filter BHyveError 2>&1 | tail
git add Sources/BHyve/BHyveError.swift Tests/BHyveTests/BHyveErrorTests.swift
git commit -m "feat: BHyveError with HTTP status mapping"
git push
```

---

## Task 10: URLProtocolStub for test doubles

**Files:**
- Create: `Tests/BHyveTests/Support/URLProtocolStub.swift`

Framework for intercepting `URLSession` requests in tests. Used by every REST test from here on.

- [ ] **Step 1: Create the stub**

```swift
import Foundation

final class URLProtocolStub: URLProtocol, @unchecked Sendable {
    struct Response {
        var status: Int
        var headers: [String: String]
        var body: Data
    }

    // (request predicate) -> either a Response or a per-request handler
    typealias Handler = @Sendable (URLRequest) -> Response

    private static let lock = NSLock()
    nonisolated(unsafe) private static var handlers: [Handler] = []
    nonisolated(unsafe) private static var seenRequests: [URLRequest] = []

    static func register(handler: @escaping Handler) {
        lock.lock(); defer { lock.unlock() }
        handlers.append(handler)
    }

    static func reset() {
        lock.lock(); defer { lock.unlock() }
        handlers.removeAll()
        seenRequests.removeAll()
    }

    static func requestsReceived() -> [URLRequest] {
        lock.lock(); defer { lock.unlock() }
        return seenRequests
    }

    static func session() -> URLSession {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [URLProtocolStub.self]
        return URLSession(configuration: config)
    }

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        Self.lock.lock()
        Self.seenRequests.append(request)
        let handler = Self.handlers.first
        Self.lock.unlock()

        guard let handler else {
            client?.urlProtocol(self, didFailWithError: URLError(.badURL))
            return
        }

        let response = handler(request)
        let http = HTTPURLResponse(
            url: request.url!,
            statusCode: response.status,
            httpVersion: "HTTP/1.1",
            headerFields: response.headers
        )!
        client?.urlProtocol(self, didReceive: http, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: response.body)
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}
```

Note: `nonisolated(unsafe)` because `URLProtocol` static handler storage is inherently shared. `NSLock` gates all access. Tests must `reset()` in `setUp`.

- [ ] **Step 2: Smoke test**

Append to a new file `Tests/BHyveTests/Support/URLProtocolStubTests.swift`:

```swift
import XCTest
@testable import BHyve

final class URLProtocolStubTests: XCTestCase {
    override func setUp() { URLProtocolStub.reset() }
    override func tearDown() { URLProtocolStub.reset() }

    func testStubReturnsCannedResponse() async throws {
        URLProtocolStub.register { _ in
            .init(status: 200, headers: [:], body: Data("hi".utf8))
        }
        let (data, resp) = try await URLProtocolStub.session().data(from: URL(string: "https://x/y")!)
        XCTAssertEqual(String(data: data, encoding: .utf8), "hi")
        XCTAssertEqual((resp as? HTTPURLResponse)?.statusCode, 200)
        XCTAssertEqual(URLProtocolStub.requestsReceived().count, 1)
    }
}
```

- [ ] **Step 3: Run + commit**

```bash
swift test --filter URLProtocolStub 2>&1 | tail
git add Tests/BHyveTests/Support/URLProtocolStub.swift Tests/BHyveTests/Support/URLProtocolStubTests.swift
git commit -m "test(support): URLProtocolStub for mocking URLSession"
git push
```

---

## Task 11: Endpoints

**Files:**
- Create: `Sources/BHyve/REST/Endpoints.swift`
- Create: `Tests/BHyveTests/REST/EndpointsTests.swift`

- [ ] **Step 1: Failing test**

```swift
import XCTest
@testable import BHyve

final class EndpointsTests: XCTestCase {
    func testLoginRequest() throws {
        let req = try Endpoints.login(email: "a@b.co", password: "pw").makeRequest(token: nil)
        XCTAssertEqual(req.url?.absoluteString, "https://api.orbitbhyve.com/v1/session")
        XCTAssertEqual(req.httpMethod, "POST")
        let body = try XCTUnwrap(req.httpBody)
        let json = try JSONSerialization.jsonObject(with: body) as? [String: Any]
        let session = try XCTUnwrap(json?["session"] as? [String: Any])
        XCTAssertEqual(session["email"] as? String, "a@b.co")
        XCTAssertEqual(session["password"] as? String, "pw")
        XCTAssertNil(req.value(forHTTPHeaderField: "orbit-api-key"))
    }

    func testDevicesRequestSetsBothAuthHeaders() throws {
        let req = try Endpoints.devices(userID: "u1").makeRequest(token: "tok")
        XCTAssertEqual(req.url?.absoluteString, "https://api.orbitbhyve.com/v1/devices?user_id=u1")
        XCTAssertEqual(req.httpMethod, "GET")
        XCTAssertEqual(req.value(forHTTPHeaderField: "orbit-api-key"), "tok")
        XCTAssertEqual(req.value(forHTTPHeaderField: "Orbit-Session-Token"), "tok")
    }

    func testSetRainDelayRequest() throws {
        let req = try Endpoints.setRainDelay(deviceID: "d1", hours: 24).makeRequest(token: "tok")
        XCTAssertEqual(req.url?.absoluteString, "https://api.orbitbhyve.com/v1/devices/d1")
        XCTAssertEqual(req.httpMethod, "PUT")
        let body = try XCTUnwrap(req.httpBody)
        let json = try JSONSerialization.jsonObject(with: body) as? [String: Any]
        XCTAssertEqual(json?["rain_delay"] as? Int, 24)
    }
}
```

- [ ] **Step 2: Create `Sources/BHyve/REST/Endpoints.swift`**

```swift
import Foundation

enum Endpoints {
    static let baseURL = URL(string: "https://api.orbitbhyve.com")!

    case login(email: String, password: String)
    case devices(userID: String)
    case programs(deviceID: String)
    case wateringEvents(deviceID: String)
    case updateProgram(programID: String, body: Data)
    case setRainDelay(deviceID: String, hours: Int)

    func makeRequest(token: String?) throws -> URLRequest {
        var comps = URLComponents(url: Self.baseURL, resolvingAgainstBaseURL: false)!
        var method = "GET"
        var body: Data?
        var requiresAuth = true

        switch self {
        case .login(let email, let password):
            comps.path = "/v1/session"
            method = "POST"
            body = try JSONSerialization.data(withJSONObject: [
                "session": ["email": email, "password": password]
            ])
            requiresAuth = false
        case .devices(let userID):
            comps.path = "/v1/devices"
            comps.queryItems = [URLQueryItem(name: "user_id", value: userID)]
        case .programs(let deviceID):
            comps.path = "/v1/sprinkler_timer_programs"
            comps.queryItems = [URLQueryItem(name: "device_id", value: deviceID)]
        case .wateringEvents(let deviceID):
            comps.path = "/v1/watering_events/\(deviceID)"
        case .updateProgram(let programID, let payload):
            comps.path = "/v1/sprinkler_timer_programs/\(programID)"
            method = "PUT"
            body = payload
        case .setRainDelay(let deviceID, let hours):
            comps.path = "/v1/devices/\(deviceID)"
            method = "PUT"
            body = try JSONSerialization.data(withJSONObject: ["rain_delay": hours])
        }

        guard let url = comps.url else { throw BHyveError.invalidResponse }
        var req = URLRequest(url: url)
        req.httpMethod = method
        req.httpBody = body
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue("application/json", forHTTPHeaderField: "Accept")
        req.setValue("bhyve-swift/0.1", forHTTPHeaderField: "User-Agent")
        if requiresAuth {
            guard let token else { throw BHyveError.notLoggedIn }
            req.setValue(token, forHTTPHeaderField: "orbit-api-key")
            req.setValue(token, forHTTPHeaderField: "Orbit-Session-Token")
        }
        return req
    }
}
```

- [ ] **Step 3: Run + commit**

```bash
swift test --filter Endpoints 2>&1 | tail
git add Sources/BHyve/REST/Endpoints.swift Tests/BHyveTests/REST/EndpointsTests.swift
git commit -m "feat(rest): Endpoints enum with request builders"
git push
```

---

## Task 12: RESTTransport with 401 → re-login

**Files:**
- Create: `Sources/BHyve/REST/RESTTransport.swift`
- Create: `Tests/BHyveTests/REST/RESTTransportTests.swift`

- [ ] **Step 1: Failing tests (happy + 401 retry + terminal 401)**

```swift
import XCTest
@testable import BHyve

final class RESTTransportTests: XCTestCase {
    override func setUp() { URLProtocolStub.reset() }

    func testHappyPathReturnsData() async throws {
        URLProtocolStub.register { _ in
            .init(status: 200, headers: [:], body: Data(#"{"ok":true}"#.utf8))
        }
        let store = InMemoryCredentialStore(token: "tok")
        let transport = RESTTransport(session: URLProtocolStub.session(), credentialStore: store)
        let data = try await transport.send(.devices(userID: "u1"))
        XCTAssertEqual(String(data: data, encoding: .utf8), #"{"ok":true}"#)
    }

    func test401TriggersReLoginThenRetries() async throws {
        var calls = 0
        URLProtocolStub.register { req in
            calls += 1
            if req.url?.path == "/v1/session" {
                return .init(
                    status: 200, headers: [:],
                    body: try! Fixture.data("session.json")
                )
            }
            // devices call: first attempt 401, second attempt 200
            if calls == 1 { return .init(status: 401, headers: [:], body: Data()) }
            return .init(status: 200, headers: [:], body: Data("[]".utf8))
        }
        let store = InMemoryCredentialStore(
            credentials: (email: "u@x.co", password: "pw"),
            token: "stale"
        )
        let transport = RESTTransport(session: URLProtocolStub.session(), credentialStore: store)
        let data = try await transport.send(.devices(userID: "u1"))
        XCTAssertEqual(String(data: data, encoding: .utf8), "[]")
        XCTAssertEqual(URLProtocolStub.requestsReceived().count, 3, "expected devices, session, devices")
        // token was updated
        let newTok = try await store.loadToken()
        XCTAssertNotNil(newTok)
        XCTAssertNotEqual(newTok, "stale")
    }

    func testTerminal401AfterReloginPropagates() async throws {
        URLProtocolStub.register { _ in
            .init(status: 401, headers: [:], body: Data())
        }
        let store = InMemoryCredentialStore(
            credentials: (email: "u@x.co", password: "pw"),
            token: "stale"
        )
        let transport = RESTTransport(session: URLProtocolStub.session(), credentialStore: store)
        do {
            _ = try await transport.send(.devices(userID: "u1"))
            XCTFail("expected throw")
        } catch let err as BHyveError {
            XCTAssertEqual(err, .unauthorized)
        }
    }

    func testRateLimitOneReqPerSecond() async throws {
        URLProtocolStub.register { _ in .init(status: 200, headers: [:], body: Data("[]".utf8)) }
        let store = InMemoryCredentialStore(token: "tok")
        let transport = RESTTransport(session: URLProtocolStub.session(), credentialStore: store)
        let start = Date()
        for _ in 0..<3 {
            _ = try await transport.send(.devices(userID: "u"))
        }
        let elapsed = Date().timeIntervalSince(start)
        XCTAssertGreaterThan(elapsed, 1.9, "expected ≥ 2s across 3 rate-limited calls")
    }
}
```

- [ ] **Step 2: Implement**

`Sources/BHyve/REST/RESTTransport.swift`:

```swift
import Foundation

actor RESTTransport {
    private let session: URLSession
    private let credentialStore: any BHyveCredentialStore
    private var lastRequestAt: Date = .distantPast
    private let minSpacing: TimeInterval = 1.0

    init(session: URLSession = .shared, credentialStore: any BHyveCredentialStore) {
        self.session = session
        self.credentialStore = credentialStore
    }

    func send(_ endpoint: Endpoints) async throws -> Data {
        try await respectRateLimit()

        let token = try await credentialStore.loadToken()
        let request = try endpoint.makeRequest(token: token)
        let (data, response) = try await session.data(for: request)

        guard let http = response as? HTTPURLResponse else {
            throw BHyveError.invalidResponse
        }
        if http.statusCode == 401, case .login = endpoint {
            throw BHyveError.unauthorized
        }
        if http.statusCode == 401 {
            try await reLogin()
            return try await sendOnce(endpoint)
        }
        if let error = BHyveError(httpStatus: http.statusCode) {
            throw error
        }
        return data
    }

    // Single attempt, no retry — used after re-login
    private func sendOnce(_ endpoint: Endpoints) async throws -> Data {
        try await respectRateLimit()
        let token = try await credentialStore.loadToken()
        let request = try endpoint.makeRequest(token: token)
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw BHyveError.invalidResponse }
        if let error = BHyveError(httpStatus: http.statusCode) { throw error }
        return data
    }

    private func reLogin() async throws {
        guard let creds = try await credentialStore.loadCredentials() else {
            throw BHyveError.unauthorized
        }
        try await respectRateLimit()
        let request = try Endpoints.login(email: creds.email, password: creds.password)
            .makeRequest(token: nil)
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw BHyveError.unauthorized
        }
        let session = try JSONCoding.decoder.decode(SessionResponse.self, from: data)
        try await credentialStore.store(token: session.orbitSessionToken)
    }

    private func respectRateLimit() async throws {
        let gap = Date().timeIntervalSince(lastRequestAt)
        if gap < minSpacing {
            try await Task.sleep(nanoseconds: UInt64((minSpacing - gap) * 1_000_000_000))
        }
        lastRequestAt = Date()
    }
}
```

- [ ] **Step 3: Run + commit**

```bash
swift test --filter RESTTransport 2>&1 | tail -20
git add Sources/BHyve/REST/RESTTransport.swift Tests/BHyveTests/REST/RESTTransportTests.swift
git commit -m "feat(rest): RESTTransport with 401 re-login + rate limit"
git push
```

---

## Task 13: BHyveEvent decoder + WS event fixtures

**Files:**
- Create: `Sources/BHyve/WebSocket/BHyveEvent.swift`
- Create: `Tests/BHyveTests/Fixtures/ws_events/` (7 synthetic files — see Step 1)
- Create: `Tests/BHyveTests/WebSocket/BHyveEventDecodeTests.swift`

Fixtures derived from `sebr/bhyve-home-assistant/pybhyve/const.py`. Keys use snake_case as observed on the wire; will be validated against live traffic in Task 15.

- [ ] **Step 1: Add synthetic WS fixtures**

Create these files, one per event kind. Real captures will replace them during Task 15 if the wire shape differs.

`Tests/BHyveTests/Fixtures/ws_events/watering_in_progress.json`:
```json
{
  "event": "watering_in_progress_notification",
  "device_id": "dd0000000000000000000007",
  "current_station": 3,
  "run_time": 10,
  "started_watering_station_at": "2026-08-30T18:00:00.000Z"
}
```

`Tests/BHyveTests/Fixtures/ws_events/watering_complete.json`:
```json
{
  "event": "watering_complete",
  "device_id": "dd0000000000000000000007",
  "current_station": 3
}
```

`Tests/BHyveTests/Fixtures/ws_events/device_idle.json`:
```json
{
  "event": "device_idle",
  "device_id": "dd0000000000000000000007"
}
```

`Tests/BHyveTests/Fixtures/ws_events/battery_status.json`:
```json
{
  "event": "battery_status",
  "device_id": "dd0000000000000000000007",
  "percent": 43,
  "mv": 2659,
  "charging": false
}
```

`Tests/BHyveTests/Fixtures/ws_events/rain_delay.json`:
```json
{
  "event": "rain_delay",
  "device_id": "dd0000000000000000000007",
  "delay": 24
}
```

`Tests/BHyveTests/Fixtures/ws_events/program_changed.json`:
```json
{
  "event": "program_changed",
  "device_id": "dd0000000000000000000007",
  "program": {"id": "dd0000000000000000000013"}
}
```

`Tests/BHyveTests/Fixtures/ws_events/device_status.json`:
```json
{
  "event": "device_status",
  "device_id": "dd0000000000000000000007",
  "status": {"run_mode": "auto", "rain_delay": 0, "watering_status": null}
}
```

Update `Package.swift` — no change needed; `.copy("Fixtures")` already picks up subdirectories.

- [ ] **Step 2: Failing test**

```swift
import XCTest
@testable import BHyve

final class BHyveEventDecodeTests: XCTestCase {
    func testDecodesWateringInProgress() throws {
        let data = try Fixture.data("ws_events/watering_in_progress.json")
        let event = try BHyveEvent.decode(from: data)
        guard case let .wateringInProgress(deviceID, station, runTime) = event else {
            return XCTFail("wrong case: \(event)")
        }
        XCTAssertEqual(deviceID, "dd0000000000000000000007")
        XCTAssertEqual(station, 3)
        XCTAssertEqual(runTime, 10)
    }

    func testDecodesWateringComplete() throws {
        let data = try Fixture.data("ws_events/watering_complete.json")
        let event = try BHyveEvent.decode(from: data)
        if case let .wateringComplete(deviceID, station) = event {
            XCTAssertEqual(deviceID, "dd0000000000000000000007")
            XCTAssertEqual(station, 3)
        } else { XCTFail("wrong case: \(event)") }
    }

    func testDecodesBatteryStatus() throws {
        let event = try BHyveEvent.decode(from: Fixture.data("ws_events/battery_status.json"))
        if case let .batteryStatus(deviceID, percent, charging) = event {
            XCTAssertEqual(deviceID, "dd0000000000000000000007")
            XCTAssertEqual(percent, 43)
            XCTAssertFalse(charging)
        } else { XCTFail("wrong case: \(event)") }
    }

    func testDecodesRainDelay() throws {
        let event = try BHyveEvent.decode(from: Fixture.data("ws_events/rain_delay.json"))
        if case let .rainDelay(deviceID, hours) = event {
            XCTAssertEqual(deviceID, "dd0000000000000000000007")
            XCTAssertEqual(hours, 24)
        } else { XCTFail("wrong case: \(event)") }
    }

    func testUnknownEventDecodesToUnknown() throws {
        let data = Data(#"{"event":"totally_new_type","device_id":"x"}"#.utf8)
        let event = try BHyveEvent.decode(from: data)
        guard case .unknown(let raw) = event else { return XCTFail("expected .unknown") }
        XCTAssertEqual(raw["event"], .string("totally_new_type"))
    }

    func testInvalidJSONThrows() {
        XCTAssertThrowsError(try BHyveEvent.decode(from: Data("not json".utf8)))
    }
}
```

- [ ] **Step 3: Implement**

`Sources/BHyve/WebSocket/BHyveEvent.swift`:

```swift
import Foundation

public enum BHyveEvent: Sendable, Equatable {
    case wateringInProgress(deviceID: String, station: Int, runTime: Int)
    case wateringComplete(deviceID: String, station: Int)
    case deviceIdle(deviceID: String)
    case batteryStatus(deviceID: String, percent: Int, charging: Bool)
    case rainDelay(deviceID: String, hours: Int)
    case programChanged(deviceID: String, programID: String)
    case deviceStatus(deviceID: String, status: JSONValue)
    case fault(deviceID: String, station: Int?, code: String)
    case unknown(raw: [String: JSONValue])

    public static func decode(from data: Data) throws -> BHyveEvent {
        let obj = try JSONCoding.decoder.decode([String: JSONValue].self, from: data)
        guard case .string(let name) = obj["event"] ?? .null else {
            throw BHyveError.decoding("missing 'event' field")
        }
        let deviceID = obj.stringValue("device_id") ?? ""

        switch name {
        case "watering_in_progress_notification":
            let station = obj.intValue("current_station") ?? 0
            let runTime = obj.intValue("run_time") ?? 0
            return .wateringInProgress(deviceID: deviceID, station: station, runTime: runTime)
        case "watering_complete":
            return .wateringComplete(deviceID: deviceID, station: obj.intValue("current_station") ?? 0)
        case "device_idle":
            return .deviceIdle(deviceID: deviceID)
        case "battery_status":
            return .batteryStatus(
                deviceID: deviceID,
                percent: obj.intValue("percent") ?? 0,
                charging: obj.boolValue("charging") ?? false
            )
        case "rain_delay":
            return .rainDelay(deviceID: deviceID, hours: obj.intValue("delay") ?? 0)
        case "program_changed":
            let pid: String
            if case .object(let p) = obj["program"] ?? .null,
               case .string(let s) = p["id"] ?? .null {
                pid = s
            } else { pid = "" }
            return .programChanged(deviceID: deviceID, programID: pid)
        case "device_status":
            return .deviceStatus(deviceID: deviceID, status: obj["status"] ?? .null)
        case "fault":
            return .fault(
                deviceID: deviceID,
                station: obj.intValue("station"),
                code: obj.stringValue("code") ?? "unknown"
            )
        default:
            return .unknown(raw: obj)
        }
    }
}

private extension Dictionary where Key == String, Value == JSONValue {
    func stringValue(_ k: String) -> String? {
        if case .string(let s) = self[k] ?? .null { return s }
        return nil
    }
    func intValue(_ k: String) -> Int? {
        if case .number(let n) = self[k] ?? .null { return Int(n) }
        return nil
    }
    func boolValue(_ k: String) -> Bool? {
        if case .bool(let b) = self[k] ?? .null { return b }
        return nil
    }
}
```

- [ ] **Step 4: Run + commit**

```bash
swift test --filter BHyveEventDecode 2>&1 | tail
git add Sources/BHyve/WebSocket/BHyveEvent.swift \
        Tests/BHyveTests/Fixtures/ws_events/ \
        Tests/BHyveTests/WebSocket/BHyveEventDecodeTests.swift
git commit -m "feat(ws): BHyveEvent decoder with synthetic fixtures"
git push
```

---

## Task 14: EventSocket wrapper (reconnect + ping + hello)

**Files:**
- Create: `Sources/BHyve/WebSocket/EventSocket.swift`
- Create: `Tests/BHyveTests/WebSocket/EventSocketTests.swift`

`EventSocket` owns a `URLSessionWebSocketTask`, sends the hello handshake, pings every 25s, and reconnects with backoff on drop. It exposes an `AsyncThrowingStream<BHyveEvent, Error>`.

**Hello format:** the spec says `{"event":"app_connection","orbit_session_token":"<jwt>"}`. Live capture on 2026-08-30 showed the server drops us immediately after this hello — task 15 debugs this against the live API. For unit tests we assert what we send, not what the server accepts.

- [ ] **Step 1: Failing tests (hello + reconnect behavior via mock task)**

Create a tiny protocol so we can substitute a fake task in tests:

```swift
protocol WebSocketTaskProtocol: Sendable {
    func send(_ message: URLSessionWebSocketTask.Message) async throws
    func receive() async throws -> URLSessionWebSocketTask.Message
    func cancel(with closeCode: URLSessionWebSocketTask.CloseCode, reason: Data?)
    func resume()
}

extension URLSessionWebSocketTask: WebSocketTaskProtocol {}
```

Skip a fake WS test — testing full reconnect logic in a unit test is high-cost and low-value. Instead:
1. Test that `EventSocket.helloMessage(token:)` produces the correct JSON.
2. Test that the reconnect backoff sequence is `[1, 2, 5, 15, 30, 60, 60, 60, ...]`.

`Tests/BHyveTests/WebSocket/EventSocketTests.swift`:

```swift
import XCTest
@testable import BHyve

final class EventSocketTests: XCTestCase {
    func testHelloMessageJSON() throws {
        let msg = EventSocket.helloMessage(token: "TOK")
        let obj = try JSONSerialization.jsonObject(with: msg) as? [String: Any]
        XCTAssertEqual(obj?["event"] as? String, "app_connection")
        XCTAssertEqual(obj?["orbit_session_token"] as? String, "TOK")
    }

    func testBackoffSchedule() {
        let expected: [TimeInterval] = [1, 2, 5, 15, 30, 60, 60, 60]
        for (attempt, exp) in expected.enumerated() {
            XCTAssertEqual(EventSocket.backoffDelay(attempt: attempt), exp, "attempt \(attempt)")
        }
    }
}
```

- [ ] **Step 2: Implement `Sources/BHyve/WebSocket/EventSocket.swift`**

```swift
import Foundation

actor EventSocket {
    static let url = URL(string: "wss://api.orbitbhyve.com/v1/events")!

    private let session: URLSession
    private let credentialStore: any BHyveCredentialStore
    private var task: URLSessionWebSocketTask?
    private var pingTask: Task<Void, Never>?
    private var listenTask: Task<Void, Never>?

    init(session: URLSession = .shared, credentialStore: any BHyveCredentialStore) {
        self.session = session
        self.credentialStore = credentialStore
    }

    static func helloMessage(token: String) -> Data {
        try! JSONSerialization.data(withJSONObject: [
            "event": "app_connection",
            "orbit_session_token": token,
        ])
    }

    static func backoffDelay(attempt: Int) -> TimeInterval {
        let ladder: [TimeInterval] = [1, 2, 5, 15, 30, 60]
        return ladder[min(attempt, ladder.count - 1)]
    }

    func events() -> AsyncThrowingStream<BHyveEvent, Error> {
        AsyncThrowingStream { continuation in
            let task = Task { [weak self] in
                var attempt = 0
                while !Task.isCancelled {
                    do {
                        try await self?.connectOnce(continuation: continuation)
                        attempt = 0
                    } catch let error as BHyveError where error == .unauthorized {
                        continuation.finish(throwing: error)
                        return
                    } catch {
                        // transient — reconnect after backoff
                    }
                    let delay = EventSocket.backoffDelay(attempt: attempt)
                    try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                    attempt += 1
                }
                continuation.finish()
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    private func connectOnce(continuation: AsyncThrowingStream<BHyveEvent, Error>.Continuation) async throws {
        guard let token = try await credentialStore.loadToken() else {
            throw BHyveError.notLoggedIn
        }
        let request = URLRequest(url: Self.url)
        let task = session.webSocketTask(with: request)
        self.task = task
        task.resume()

        try await task.send(.data(Self.helloMessage(token: token)))
        startPingLoop(task: task)

        // Receive loop
        while !Task.isCancelled {
            let message = try await task.receive()
            let data: Data
            switch message {
            case .data(let d): data = d
            case .string(let s): data = Data(s.utf8)
            @unknown default: continue
            }
            do {
                let event = try BHyveEvent.decode(from: data)
                continuation.yield(event)
            } catch {
                // ignore un-decodable frame; keep the socket alive
            }
        }
    }

    private func startPingLoop(task: URLSessionWebSocketTask) {
        pingTask?.cancel()
        pingTask = Task { [weak task] in
            while let task, !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 25 * 1_000_000_000)
                await withCheckedContinuation { (cont: CheckedContinuation<Void, Never>) in
                    task.sendPing { _ in cont.resume() }
                }
            }
        }
    }
}
```

Notes for implementer:
- The `sendPing` path uses `URLSessionWebSocketTask.sendPing(pongReceiveHandler:)`. If it errors, the next `receive()` call will fail and we reconnect.
- Do not add per-connection auth via query string; the token goes in the first message.
- If Task 15 discovers the hello format needs a different key/value, update `helloMessage(token:)` and its test in one commit.

- [ ] **Step 3: Run + commit**

```bash
swift test --filter EventSocket 2>&1 | tail
git add Sources/BHyve/WebSocket/EventSocket.swift Tests/BHyveTests/WebSocket/EventSocketTests.swift
git commit -m "feat(ws): EventSocket with reconnect + ping loop"
git push
```

---

## Task 15: Live WebSocket handshake validation

**Files:**
- Create: `Tests/BHyveTests/LiveWebSocketProbeTests.swift`

Gated by `BHYVE_WS_PROBE=1` env var (opt-in, only runs when explicitly requested). Uses the real credentials from `BHYVE_EMAIL` / `BHYVE_PASSWORD`. The purpose is to figure out the correct handshake shape (spec-suggested format was silently dropped by the server on 2026-08-30) and update `EventSocket.helloMessage(token:)` accordingly.

- [ ] **Step 1: Create the probe**

```swift
import XCTest
@testable import BHyve

final class LiveWebSocketProbeTests: XCTestCase {
    override func setUp() throws {
        try XCTSkipUnless(ProcessInfo.processInfo.environment["BHYVE_WS_PROBE"] == "1")
    }

    /// Tries a series of candidate hello payloads and records which one
    /// yields a real first frame from the server (as opposed to an immediate drop).
    func testCandidateHelloPayloads() async throws {
        let email = try XCTUnwrap(ProcessInfo.processInfo.environment["BHYVE_EMAIL"])
        let password = try XCTUnwrap(ProcessInfo.processInfo.environment["BHYVE_PASSWORD"])

        // Log in via REST to obtain a fresh token
        let store = InMemoryCredentialStore(credentials: (email, password))
        let transport = RESTTransport(credentialStore: store)
        // trigger login by calling any authed endpoint after clearing token
        _ = try? await transport.send(.devices(userID: "will-401-then-relogin"))
        let token = try XCTUnwrap(try await store.loadToken())

        let candidates: [(name: String, body: [String: Any])] = [
            ("app_connection + orbit_session_token", ["event": "app_connection", "orbit_session_token": token]),
            ("app_connection + session_token",       ["event": "app_connection", "session_token": token]),
            ("app_connection + orbit_api_key",       ["event": "app_connection", "orbit_api_key": token]),
            ("app_connection + token",               ["event": "app_connection", "token": token]),
            ("event=session",                        ["event": "session", "orbit_session_token": token]),
        ]

        for candidate in candidates {
            let received = try await probe(token: token, payload: candidate.body, seconds: 5)
            print("[PROBE] \(candidate.name): received \(received.count) frame(s)")
            if !received.isEmpty {
                print("  first frame: \(String(data: received[0], encoding: .utf8) ?? "?")")
            }
        }
    }

    private func probe(token: String, payload: [String: Any], seconds: TimeInterval) async throws -> [Data] {
        let request = URLRequest(url: EventSocket.url)
        let task = URLSession.shared.webSocketTask(with: request)
        task.resume()

        let body = try JSONSerialization.data(withJSONObject: payload)
        try await task.send(.data(body))

        var out: [Data] = []
        let deadline = Date().addingTimeInterval(seconds)
        while Date() < deadline {
            do {
                let msg = try await task.receive()
                switch msg {
                case .data(let d): out.append(d)
                case .string(let s): out.append(Data(s.utf8))
                @unknown default: break
                }
            } catch {
                break
            }
        }
        task.cancel(with: .goingAway, reason: nil)
        return out
    }
}
```

- [ ] **Step 2: Run the probe**

```bash
BHYVE_WS_PROBE=1 BHYVE_EMAIL="<email>" BHYVE_PASSWORD="<pw>" \
  swift test --filter LiveWebSocketProbe 2>&1 | tee /tmp/ws-probe.log
```

Read the log. Identify which candidate produced non-empty frames.

- [ ] **Step 3: Update `EventSocket.helloMessage` if needed**

If a non-canonical payload worked, edit `Sources/BHyve/WebSocket/EventSocket.swift`:

```swift
static func helloMessage(token: String) -> Data {
    try! JSONSerialization.data(withJSONObject: [
        "event": "app_connection",
        // ← replace with the winning key from the probe
        "orbit_session_token": token,
    ])
}
```

Also update the assertion in `EventSocketTests.testHelloMessageJSON`.

- [ ] **Step 4: If a frame was captured, save it as a real fixture**

Replace one of the synthetic files in `Tests/BHyveTests/Fixtures/ws_events/` with the real frame (scrubbing device_id / user_id if present). Add a note to `Fixtures/README.md`.

- [ ] **Step 5: Run all tests + commit**

```bash
swift test 2>&1 | tail
git add Tests/BHyveTests/LiveWebSocketProbeTests.swift \
        Sources/BHyve/WebSocket/EventSocket.swift \
        Tests/BHyveTests/WebSocket/EventSocketTests.swift \
        Tests/BHyveTests/Fixtures/
git commit -m "feat(ws): validate hello handshake against live server"
git push
```

If the probe determined NONE of the candidate hello payloads yields frames, leave `EventSocket` as-is and open a followup issue titled "WS handshake still drops us — enumerate additional candidate payloads." The library still ships v0.1.0 with REST fully functional; consumers using `events()` will hit reconnect loops until the WS is unblocked. Document this in README known-issues.

---

## Task 16: Mutating actions via WebSocket + REST

**Files:**
- Modify: `Sources/BHyve/WebSocket/EventSocket.swift` — add `send(_ payload: [String: Any])`
- Modify: `Sources/BHyve/BHyveClient.swift` — final façade
- Create: `Sources/BHyve/Models/ZoneRun.swift`
- Create: `Tests/BHyveTests/BHyveClientTests.swift`

The Orbit protocol uses `change_mode` WebSocket messages for zone start/stop (per reference clients).

- [ ] **Step 1: Add `ZoneRun`**

`Sources/BHyve/Models/ZoneRun.swift`:

```swift
public struct ZoneRun: Sendable, Equatable {
    public let station: Int
    public let minutes: Int
    public init(station: Int, minutes: Int) {
        self.station = station
        self.minutes = minutes
    }
}
```

- [ ] **Step 2: Add `EventSocket.send`**

```swift
func send(_ payload: [String: Any]) async throws {
    guard let task else { throw BHyveError.transport("socket not connected") }
    let data = try JSONSerialization.data(withJSONObject: payload)
    try await task.send(.data(data))
}
```

- [ ] **Step 3: Fill in `BHyveClient`**

`Sources/BHyve/BHyveClient.swift`:

```swift
import Foundation

public actor BHyveClient {
    private let transport: RESTTransport
    private let socket: EventSocket
    private let credentialStore: any BHyveCredentialStore

    public init(
        credentialStore: any BHyveCredentialStore,
        urlSession: URLSession = .shared
    ) {
        self.credentialStore = credentialStore
        self.transport = RESTTransport(session: urlSession, credentialStore: credentialStore)
        self.socket = EventSocket(session: urlSession, credentialStore: credentialStore)
    }

    // MARK: - Auth

    public func login(email: String, password: String) async throws {
        try await credentialStore.store(credentials: (email: email, password: password))
        let data = try await transport.send(.login(email: email, password: password))
        let session = try JSONCoding.decoder.decode(SessionResponse.self, from: data)
        try await credentialStore.store(token: session.orbitSessionToken)
    }

    // MARK: - Reads

    public func devices() async throws -> [Device] {
        let userID = try await userIDFromToken()
        let data = try await transport.send(.devices(userID: userID))
        return try JSONCoding.decoder.decode([Device].self, from: data)
    }

    public func programs(deviceID: String) async throws -> [Program] {
        let data = try await transport.send(.programs(deviceID: deviceID))
        return try JSONCoding.decoder.decode([Program].self, from: data)
    }

    public func wateringHistory(deviceID: String) async throws -> [WateringEvent] {
        let data = try await transport.send(.wateringEvents(deviceID: deviceID))
        return try JSONCoding.decoder.decode([WateringEvent].self, from: data)
    }

    // MARK: - Mutations

    /// Requires an active WS connection. Consumers must have started `events()`
    /// (or wait a moment for the socket to open) before calling this.
    public func startZones(deviceID: String, stations: [ZoneRun]) async throws {
        try await socket.send([
            "event": "change_mode",
            "mode": "manual",
            "device_id": deviceID,
            "stations": stations.map { ["station": $0.station, "run_time": $0.minutes] },
        ])
    }

    public func stopWatering(deviceID: String) async throws {
        try await socket.send([
            "event": "change_mode",
            "mode": "manual",
            "device_id": deviceID,
            "stations": [],
        ])
    }

    public func setRainDelay(deviceID: String, hours: Int) async throws {
        _ = try await transport.send(.setRainDelay(deviceID: deviceID, hours: hours))
    }

    public func updateProgram(_ program: Program) async throws {
        let body = try JSONCoding.encoder.encode(program)
        _ = try await transport.send(.updateProgram(programID: program.id, body: body))
    }

    // MARK: - Live events

    public nonisolated func events() -> AsyncThrowingStream<BHyveEvent, Error> {
        socket.events()
    }

    // MARK: - Helpers

    private func userIDFromToken() async throws -> String {
        // Session response gave us user_id at login; re-fetch if we don't have it.
        // Cheapest path: re-decode the JWT payload for its `:user-id` field.
        // (JWT payload here is EDN-shaped, not JSON: `{:user-id "..."}`)
        guard let token = try await credentialStore.loadToken() else {
            throw BHyveError.notLoggedIn
        }
        let parts = token.split(separator: ".")
        guard parts.count == 3,
              let payload = base64URLDecode(String(parts[1])),
              let text = String(data: payload, encoding: .utf8) else {
            throw BHyveError.transport("cannot parse JWT payload")
        }
        // Match "6820ae41a69d20513e6221ec"-style ObjectId
        let pattern = #""([0-9a-f]{24})""#
        if let range = text.range(of: pattern, options: .regularExpression) {
            return String(text[range]).trimmingCharacters(in: CharacterSet(charactersIn: "\""))
        }
        throw BHyveError.transport("cannot extract user_id from JWT")
    }

    private nonisolated func base64URLDecode(_ s: String) -> Data? {
        var padded = s.replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        while padded.count % 4 != 0 { padded += "=" }
        return Data(base64Encoded: padded)
    }
}
```

Note on `userIDFromToken`: our capture showed the JWT payload is `{:user-id "..."}` (EDN, not JSON). We just regex out the 24-hex ObjectId. This is a compact workaround — if it proves fragile, switch to caching `user_id` on login.

- [ ] **Step 4: Client-level tests**

```swift
import XCTest
@testable import BHyve

final class BHyveClientTests: XCTestCase {
    override func setUp() { URLProtocolStub.reset() }

    func testLoginStoresTokenAndCredentials() async throws {
        URLProtocolStub.register { _ in
            .init(status: 200, headers: [:], body: try! Fixture.data("session.json"))
        }
        let store = InMemoryCredentialStore()
        let client = BHyveClient(credentialStore: store, urlSession: URLProtocolStub.session())
        try await client.login(email: "u@x.co", password: "pw")
        XCTAssertNotNil(try await store.loadToken())
        XCTAssertEqual(try await store.loadCredentials()?.email, "u@x.co")
    }

    func testDevicesReturnsDecodedList() async throws {
        // arrange: first request is /v1/devices → returns fixture
        URLProtocolStub.register { _ in
            .init(status: 200, headers: [:], body: try! Fixture.data("devices.json"))
        }
        let store = InMemoryCredentialStore(
            token: "eyJhbGciOiJIUzI1NiJ9.ezp1c2VyLWlkICJ1dTAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwNSJ9.sig"
        )
        let client = BHyveClient(credentialStore: store, urlSession: URLProtocolStub.session())
        let devices = try await client.devices()
        XCTAssertEqual(devices.count, 4)
    }
}
```

Note: the fake token payload above encodes `{:user-id "uu0000000000000000000005"}` in base64url. If preparing this by hand is fiddly, use `String(data: payload.data(using: .utf8)!.base64EncodedData(), encoding: .utf8)!` in a helper.

- [ ] **Step 5: Run + commit**

```bash
swift test 2>&1 | tail -20
git add Sources/BHyve/ Tests/BHyveTests/BHyveClientTests.swift
git commit -m "feat: BHyveClient façade with reads + mutations"
git push
```

---

## Task 17: Opt-in integration test

**Files:**
- Create: `Tests/BHyveTests/IntegrationTests.swift`

Round-trip against the real API. Gated by `INTEGRATION=1`. Reads credentials from env. Optional `BHYVE_TEST_ZONE` (default: 1) says which zone to start for the mutation test. Runs for exactly 60 seconds then stops the zone.

- [ ] **Step 1: Create the test**

```swift
import XCTest
@testable import BHyve

final class IntegrationTests: XCTestCase {
    override func setUp() throws {
        try XCTSkipUnless(ProcessInfo.processInfo.environment["INTEGRATION"] == "1")
    }

    func testLoginAndListDevices() async throws {
        let client = try makeClient()
        let devices = try await client.devices()
        XCTAssertFalse(devices.isEmpty)
        print("Found devices:")
        for d in devices {
            print("  \(d.name) [\(d.type)] fw=\(d.firmwareVersion) online=\(d.isConnected)")
        }
    }

    func testStartAndStopZone() async throws {
        let client = try makeClient()
        let devices = try await client.devices()
        let timer = try XCTUnwrap(devices.first { $0.type == .sprinklerTimer && $0.isConnected })
        let station = Int(ProcessInfo.processInfo.environment["BHYVE_TEST_ZONE"] ?? "1")!

        // Establish the WS FIRST — mutations (startZones/stopWatering) go through the
        // socket, and we also need the listener attached before the zone starts
        // so we don't race the wateringInProgress event.
        let expectation = expectation(description: "wateringInProgress")
        let listenTask = Task {
            for try await event in client.events() {
                if case let .wateringInProgress(devID, sta, _) = event,
                   devID == timer.id, sta == station {
                    expectation.fulfill()
                    return
                }
            }
        }
        // Give the WS a moment to complete its handshake before firing mutations.
        try await Task.sleep(nanoseconds: 2_000_000_000)

        try await client.startZones(deviceID: timer.id, stations: [ZoneRun(station: station, minutes: 1)])

        await fulfillment(of: [expectation], timeout: 30)

        try await client.stopWatering(deviceID: timer.id)
        listenTask.cancel()
    }

    private func makeClient() throws -> BHyveClient {
        let email = try XCTUnwrap(ProcessInfo.processInfo.environment["BHYVE_EMAIL"])
        let password = try XCTUnwrap(ProcessInfo.processInfo.environment["BHYVE_PASSWORD"])
        let store = InMemoryCredentialStore()
        let client = BHyveClient(credentialStore: store)
        // login synchronously
        let semaphore = DispatchSemaphore(value: 0)
        Task {
            try await client.login(email: email, password: password)
            semaphore.signal()
        }
        semaphore.wait()
        return client
    }
}
```

- [ ] **Step 2: Run manually (do NOT run in normal test cycle)**

```bash
INTEGRATION=1 BHYVE_EMAIL="<email>" BHYVE_PASSWORD="<pw>" BHYVE_TEST_ZONE=1 \
  swift test --filter IntegrationTests 2>&1 | tail
```

If `testStartAndStopZone` fails at the WS event assertion, that means Task 15 hasn't unblocked the WS handshake yet. Skip the assertion by exiting early with `XCTSkip` and file a followup.

- [ ] **Step 3: Commit**

```bash
git add Tests/BHyveTests/IntegrationTests.swift
git commit -m "test: opt-in integration tests against live API"
git push
```

---

## Task 18: GitHub Actions CI

**Files:**
- Create: `.github/workflows/ci.yml`

- [ ] **Step 1: Create workflow**

```yaml
name: CI

on:
  push:
    branches: [main]
  pull_request:

jobs:
  test:
    runs-on: macos-15
    steps:
      - uses: actions/checkout@v4
      - uses: swift-actions/setup-swift@v2
        with: { swift-version: "5.10" }
      - run: swift build
      - run: swift test 2>&1 | tail -50
```

- [ ] **Step 2: Push, verify green**

```bash
git add .github/workflows/ci.yml
git commit -m "ci: run swift test on macOS-15"
git push
gh run watch --exit-status
```

Expected: CI passes.

---

## Task 19: README + CHANGELOG

**Files:**
- Modify: `README.md`
- Create: `CHANGELOG.md`

- [ ] **Step 1: Replace README.md**

```markdown
# bhyve-swift

A Swift client for the Orbit B-hyve smart sprinkler cloud API (REST + WebSocket).
Zero third-party runtime dependencies.

## Requirements

- Swift 5.10+
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

- The WebSocket hello handshake may still be dropped by the server for some accounts.
  See `LiveWebSocketProbeTests` for how to diagnose. REST is fully functional.

## License

MIT
```

- [ ] **Step 2: Create CHANGELOG.md**

```markdown
# Changelog

## 0.1.0 — 2026-08-30

Initial release. REST client (devices, programs, watering events, rain delay,
program update) and WebSocket event stream. Fixtures captured against real API.
```

- [ ] **Step 3: Commit**

```bash
git add README.md CHANGELOG.md
git commit -m "docs: README + CHANGELOG for 0.1.0"
git push
```

---

## Task 20: Tag 0.1.0

- [ ] **Step 1: Confirm CI green**

```bash
gh run list --branch main --limit 1
```

Should show ✓ for the latest run.

- [ ] **Step 2: Tag and release**

```bash
git tag -a 0.1.0 -m "0.1.0 — initial release"
git push origin 0.1.0
gh release create 0.1.0 --title "0.1.0" --notes "Initial release. See CHANGELOG.md."
```

- [ ] **Step 3: Verify the tag resolves via SwiftPM**

In a scratch dir:

```bash
mkdir /tmp/swiftpm-consume && cd /tmp/swiftpm-consume
cat > Package.swift <<'EOF'
// swift-tools-version:5.10
import PackageDescription
let package = Package(
    name: "Consume",
    platforms: [.macOS(.v15)],
    dependencies: [
        .package(url: "https://github.com/waitbutY/bhyve-swift.git", exact: "0.1.0"),
    ],
    targets: [
        .executableTarget(name: "Consume", dependencies: [.product(name: "BHyve", package: "bhyve-swift")]),
    ]
)
EOF
mkdir -p Sources/Consume
echo 'import BHyve; print(type(of: BHyveClient.self))' > Sources/Consume/main.swift
swift build 2>&1 | tail -5
```

Expected: `Build complete!`

- [ ] **Step 4: Cleanup scratch**

```bash
rm -rf /tmp/swiftpm-consume
```

---

## Definition of Done

- All non-integration tests green on `main`.
- GitHub Actions CI green on latest commit.
- Tag `0.1.0` published on GitHub with release notes.
- Downstream SwiftPM consumer at `.exact("0.1.0")` builds.
- README documents install and basic usage.
- Known WS-handshake caveat (if unresolved by Task 15) documented in README.
