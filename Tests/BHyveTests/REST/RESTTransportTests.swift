import XCTest
@testable import BHyve

/// Thread-safe counter used by `URLProtocolStub` handlers, whose closures must be @Sendable.
private final class Counter: @unchecked Sendable {
    private let lock = NSLock()
    private var value = 0
    func increment() -> Int {
        lock.lock(); defer { lock.unlock() }
        value += 1
        return value
    }
}

final class RESTTransportTests: XCTestCase {
    override func setUp() { URLProtocolStub.reset() }

    func testHappyPathReturnsData() async throws {
        URLProtocolStub.register { _ in
            .init(status: 200, headers: [:], body: Data(#"{"ok":true}"#.utf8))
        }
        let store = InMemoryCredentialStore(token: "tok")
        let transport = RESTTransport(session: URLProtocolStub.session(), credentialStore: store)
        let data = try await transport.send(.devices(userID: "u1"))
        XCTAssertEqual(String(data: data, encoding: .utf8), #"{"ok":true}"#)
    }

    func test401TriggersReLoginThenRetries() async throws {
        let calls = Counter()
        URLProtocolStub.register { req in
            let n = calls.increment()
            if req.url?.path == "/v1/session" {
                return .init(
                    status: 200, headers: [:],
                    body: try! Fixture.data("session.json")
                )
            }
            if n == 1 { return .init(status: 401, headers: [:], body: Data()) }
            return .init(status: 200, headers: [:], body: Data("[]".utf8))
        }
        let store = InMemoryCredentialStore(
            credentials: (email: "u@x.co", password: "pw"),
            token: "stale"
        )
        let transport = RESTTransport(session: URLProtocolStub.session(), credentialStore: store)
        let data = try await transport.send(.devices(userID: "u1"))
        XCTAssertEqual(String(data: data, encoding: .utf8), "[]")
        XCTAssertEqual(URLProtocolStub.requestsReceived().count, 3, "expected devices, session, devices")
        let newTok = await store.loadToken()
        XCTAssertNotNil(newTok)
        XCTAssertNotEqual(newTok, "stale")
    }

    func testTerminal401AfterReloginPropagates() async throws {
        URLProtocolStub.register { _ in
            .init(status: 401, headers: [:], body: Data())
        }
        let store = InMemoryCredentialStore(
            credentials: (email: "u@x.co", password: "pw"),
            token: "stale"
        )
        let transport = RESTTransport(session: URLProtocolStub.session(), credentialStore: store)
        do {
            _ = try await transport.send(.devices(userID: "u1"))
            XCTFail("expected throw")
        } catch let err as BHyveError {
            XCTAssertEqual(err, .unauthorized)
        }
    }

    func testRateLimitOneReqPerSecond() async throws {
        URLProtocolStub.register { _ in .init(status: 200, headers: [:], body: Data("[]".utf8)) }
        let store = InMemoryCredentialStore(token: "tok")
        let transport = RESTTransport(session: URLProtocolStub.session(), credentialStore: store)
        let start = Date()
        for _ in 0..<3 {
            _ = try await transport.send(.devices(userID: "u"))
        }
        let elapsed = Date().timeIntervalSince(start)
        XCTAssertGreaterThan(elapsed, 1.9, "expected ≥ 2s across 3 rate-limited calls")
    }
}
