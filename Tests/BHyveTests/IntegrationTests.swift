import XCTest
@testable import BHyve

final class IntegrationTests: XCTestCase {
    override func setUpWithError() throws {
        try XCTSkipUnless(ProcessInfo.processInfo.environment["INTEGRATION"] == "1")
    }

    func testLoginAndListDevices() async throws {
        let client = try await makeClient()
        let devices = try await client.devices()
        XCTAssertFalse(devices.isEmpty)
        print("Found devices:")
        for d in devices {
            print("  \(d.name) [\(d.type)] fw=\(d.firmwareVersion) online=\(d.isConnected)")
        }
    }

    func testStartAndStopZone() async throws {
        let client = try await makeClient()
        let devices = try await client.devices()
        let timer = try XCTUnwrap(devices.first { $0.type == .sprinklerTimer && $0.isConnected })
        let station = Int(ProcessInfo.processInfo.environment["BHYVE_TEST_ZONE"] ?? "1")!

        let expectation = expectation(description: "wateringInProgress")
        let listenTask = Task {
            for try await event in client.events() {
                if case let .wateringInProgress(devID, sta, _) = event,
                   devID == timer.id, sta == station {
                    expectation.fulfill()
                    return
                }
            }
        }
        try await Task.sleep(nanoseconds: 2_000_000_000)

        try await client.startZones(deviceID: timer.id, stations: [ZoneRun(station: station, minutes: 1)])

        await fulfillment(of: [expectation], timeout: 30)

        try await client.stopWatering(deviceID: timer.id)
        listenTask.cancel()
    }

    private func makeClient() async throws -> BHyveClient {
        let email = try XCTUnwrap(ProcessInfo.processInfo.environment["BHYVE_EMAIL"])
        let password = try XCTUnwrap(ProcessInfo.processInfo.environment["BHYVE_PASSWORD"])
        let store = InMemoryCredentialStore()
        let client = BHyveClient(credentialStore: store)
        try await client.login(email: email, password: password)
        return client
    }
}
