import XCTest
@testable import BHyve

final class JSONCodingTests: XCTestCase {
    struct Sample: Decodable { let t: Date }

    func testDecodesFractionalISODate() throws {
        let json = #"{"t":"2026-08-30T20:39:33.821Z"}"#.data(using: .utf8)!
        let s = try JSONCoding.decoder.decode(Sample.self, from: json)
        XCTAssertEqual(s.t.timeIntervalSince1970, 1788122373.821, accuracy: 0.01)
    }

    func testDecodesNonFractionalISODate() throws {
        let json = #"{"t":"2025-05-11T14:29:25Z"}"#.data(using: .utf8)!
        let s = try JSONCoding.decoder.decode(Sample.self, from: json)
        XCTAssertNotNil(s.t)
    }

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
}
