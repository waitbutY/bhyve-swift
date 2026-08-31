import XCTest
@testable import BHyve

final class SessionResponseTests: XCTestCase {
    func testDecodesRealFixture() throws {
        let data = try Fixture.data("session.json")
        let r = try JSONCoding.decoder.decode(SessionResponse.self, from: data)
        XCTAssertFalse(r.orbitApiKey.isEmpty)
        XCTAssertEqual(r.userID, "aa00000000000000000000aa")
        XCTAssertEqual(r.userName, "Test User")
    }
}
