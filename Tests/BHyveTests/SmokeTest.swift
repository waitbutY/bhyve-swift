import XCTest
@testable import BHyve

final class SmokeTest: XCTestCase {
    func testInit() async {
        _ = BHyveClient(credentialStore: InMemoryCredentialStore())
        XCTAssert(true)
    }

    func testFixtureLoaderResolvesSession() throws {
        let data = try Fixture.data("session.json")
        XCTAssertGreaterThan(data.count, 100)
    }
}
