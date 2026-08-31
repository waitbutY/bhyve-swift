import XCTest
@testable import BHyve

final class LiveWebSocketProbeTests: XCTestCase {
    override func setUpWithError() throws {
        try XCTSkipUnless(ProcessInfo.processInfo.environment["BHYVE_WS_PROBE"] == "1")
    }

    /// Tries a series of candidate hello payloads and records which one
    /// yields a real first frame from the server (as opposed to an immediate drop).
    func testCandidateHelloPayloads() async throws {
        let email = try XCTUnwrap(ProcessInfo.processInfo.environment["BHYVE_EMAIL"])
        let password = try XCTUnwrap(ProcessInfo.processInfo.environment["BHYVE_PASSWORD"])

        var loginReq = try Endpoints.login(email: email, password: password).makeRequest(token: nil)
        loginReq.timeoutInterval = 15
        let (data, resp) = try await URLSession.shared.data(for: loginReq)
        let http = try XCTUnwrap(resp as? HTTPURLResponse)
        XCTAssertEqual(http.statusCode, 200, "login failed")
        let session = try JSONCoding.decoder.decode(SessionResponse.self, from: data)
        let token = session.orbitSessionToken
        print("[PROBE] got token, len=\(token.count)")

        let candidates: [(name: String, body: [String: Any])] = [
            ("app_connection + orbit_session_token", ["event": "app_connection", "orbit_session_token": token]),
            ("app_connection + session_token",       ["event": "app_connection", "session_token": token]),
            ("app_connection + orbit_api_key",       ["event": "app_connection", "orbit_api_key": token]),
            ("app_connection + token",               ["event": "app_connection", "token": token]),
            ("event=session",                        ["event": "session", "orbit_session_token": token]),
        ]

        for candidate in candidates {
            let received = try await probe(payload: candidate.body, seconds: 5)
            print("[PROBE] \(candidate.name): received \(received.count) frame(s)")
            if !received.isEmpty {
                print("  first frame: \(String(data: received[0], encoding: .utf8) ?? "?")")
            }
        }
    }

    private func probe(payload: [String: Any], seconds: TimeInterval) async throws -> [Data] {
        let request = URLRequest(url: EventSocket.url)
        let task = URLSession.shared.webSocketTask(with: request)
        task.resume()

        let body = try JSONSerialization.data(withJSONObject: payload)
        try await task.send(.data(body))

        var out: [Data] = []
        let deadline = Date().addingTimeInterval(seconds)
        while Date() < deadline {
            do {
                let msg = try await task.receive()
                switch msg {
                case .data(let d): out.append(d)
                case .string(let s): out.append(Data(s.utf8))
                @unknown default: break
                }
            } catch {
                break
            }
        }
        task.cancel(with: .goingAway, reason: nil)
        return out
    }
}

private func XCTUnwrapAsync<T>(_ value: T?, file: StaticString = #filePath, line: UInt = #line) async throws -> T {
    guard let v = value else {
        XCTFail("Expected non-nil value", file: file, line: line)
        throw XCTSkip("nil")
    }
    return v
}
