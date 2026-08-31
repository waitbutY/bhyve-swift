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
