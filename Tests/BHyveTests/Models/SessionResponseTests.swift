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
