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
