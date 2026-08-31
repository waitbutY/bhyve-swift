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
