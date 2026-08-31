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
