import XCTest
@testable import BHyve

final class EndpointsTests: XCTestCase {
    func testLoginRequest() throws {
        let req = try Endpoints.login(email: "a@b.co", password: "pw").makeRequest(token: nil)
        XCTAssertEqual(req.url?.absoluteString, "https://api.orbitbhyve.com/v1/session")
        XCTAssertEqual(req.httpMethod, "POST")
        let body = try XCTUnwrap(req.httpBody)
        let json = try JSONSerialization.jsonObject(with: body) as? [String: Any]
        let session = try XCTUnwrap(json?["session"] as? [String: Any])
        XCTAssertEqual(session["email"] as? String, "a@b.co")
        XCTAssertEqual(session["password"] as? String, "pw")
        XCTAssertNil(req.value(forHTTPHeaderField: "orbit-api-key"))
    }

    func testDevicesRequestSetsBothAuthHeaders() throws {
        let req = try Endpoints.devices(userID: "u1").makeRequest(token: "tok")
        XCTAssertEqual(req.url?.absoluteString, "https://api.orbitbhyve.com/v1/devices?user_id=u1")
        XCTAssertEqual(req.httpMethod, "GET")
        XCTAssertEqual(req.value(forHTTPHeaderField: "orbit-api-key"), "tok")
        XCTAssertEqual(req.value(forHTTPHeaderField: "Orbit-Session-Token"), "tok")
    }

    func testSetRainDelayRequest() throws {
        let req = try Endpoints.setRainDelay(deviceID: "d1", hours: 24).makeRequest(token: "tok")
        XCTAssertEqual(req.url?.absoluteString, "https://api.orbitbhyve.com/v1/devices/d1")
        XCTAssertEqual(req.httpMethod, "PUT")
        let body = try XCTUnwrap(req.httpBody)
        let json = try JSONSerialization.jsonObject(with: body) as? [String: Any]
        XCTAssertEqual(json?["rain_delay"] as? Int, 24)
    }
}
