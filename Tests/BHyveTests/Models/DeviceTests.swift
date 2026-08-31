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
        XCTAssertEqual(bridge.numStations ?? 0, 0)
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
