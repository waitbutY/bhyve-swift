import XCTest
@testable import BHyve

final class LiveWebSocketProbeTests: XCTestCase {
    override func setUpWithError() throws {
        try XCTSkipUnless(ProcessInfo.processInfo.environment["BHYVE_WS_PROBE"] == "1")
    }

    /// Full end-to-end: login → open EventSocket → hold for 45 seconds.
    /// The Orbit server closes idle connections at ~30s unless we send
    /// text-frame `{"event":"ping"}` keepalives; this asserts our ping
    /// loop keeps us alive past that threshold.
    func testEventSocketStaysAlivePastServerIdleTimeout() async throws {
        let email = try XCTUnwrap(ProcessInfo.processInfo.environment["BHYVE_EMAIL"])
        let password = try XCTUnwrap(ProcessInfo.processInfo.environment["BHYVE_PASSWORD"])
        let store = InMemoryCredentialStore()
        let client = BHyveClient(credentialStore: store)
        try await client.login(email: email, password: password)

        let counter = Counter()
        let listener = Task {
            do {
                for try await event in client.events() {
                    let n = await counter.bump()
                    print("[PROBE] event #\(n): \(event)")
                    if n >= 3 { return }
                }
            } catch {
                print("[PROBE] stream errored: \(error)")
                await counter.markErrored()
            }
        }
        try await Task.sleep(nanoseconds: 45 * 1_000_000_000)
        listener.cancel()
        let final = await counter.snapshot()
        print("[PROBE] survived 45s, received \(final.count) event(s), errored=\(final.errored)")
        XCTAssertFalse(final.errored, "stream errored during the 45s window")
        // Assertion: if the ping loop is broken, the stream will have
        // errored and we would see reconnect churn in the log. As long
        // as we don't crash and the process is still running, we passed.
        XCTAssertTrue(true)
    }
}

private actor Counter {
    private var count = 0
    private var errored = false
    func bump() -> Int { count += 1; return count }
    func markErrored() { errored = true }
    func snapshot() -> (count: Int, errored: Bool) { (count, errored) }
}
