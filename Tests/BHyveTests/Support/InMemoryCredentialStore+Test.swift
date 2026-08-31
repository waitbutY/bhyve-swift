import XCTest
@testable import BHyve

final class InMemoryCredentialStoreTests: XCTestCase {
    func testStoreAndLoad() async throws {
        let store = InMemoryCredentialStore()
        await store.store(credentials: (email: "a@b.co", password: "pw"))
        await store.store(token: "tok")
        let creds = await store.loadCredentials()
        XCTAssertEqual(creds?.email, "a@b.co")
        let token = await store.loadToken()
        XCTAssertEqual(token, "tok")

        await store.clearToken()
        let cleared = await store.loadToken()
        XCTAssertNil(cleared)
    }
}
