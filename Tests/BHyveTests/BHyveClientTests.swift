import XCTest
@testable import BHyve

final class BHyveClientTests: XCTestCase {
    override func setUp() { URLProtocolStub.reset() }

    func testLoginStoresTokenAndCredentials() async throws {
        URLProtocolStub.register { _ in
            .init(status: 200, headers: [:], body: try! Fixture.data("session.json"))
        }
        let store = InMemoryCredentialStore()
        let client = BHyveClient(credentialStore: store, urlSession: URLProtocolStub.session())
        try await client.login(email: "u@x.co", password: "pw")
        let token = await store.loadToken()
        XCTAssertNotNil(token)
        let creds = await store.loadCredentials()
        XCTAssertEqual(creds?.email, "u@x.co")
    }

    func testDevicesReturnsDecodedList() async throws {
        URLProtocolStub.register { _ in
            .init(status: 200, headers: [:], body: try! Fixture.data("devices.json"))
        }
        // JWT payload `{:user-id "6820ae41a69d20513e6221ec"}` base64url-encoded.
        let payload = Data(#"{:user-id "6820ae41a69d20513e6221ec"}"#.utf8)
        let b64 = payload.base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
        let token = "header.\(b64).sig"
        let store = InMemoryCredentialStore(token: token)
        let client = BHyveClient(credentialStore: store, urlSession: URLProtocolStub.session())
        let devices = try await client.devices()
        XCTAssertEqual(devices.count, 4)
    }
}
