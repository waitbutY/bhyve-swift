import XCTest
@testable import BHyve

final class BHyveErrorTests: XCTestCase {
    func testUnauthorizedIsUnauthorized() {
        XCTAssertTrue(BHyveError.unauthorized.isAuthFailure)
    }

    func testHTTPStatusMapping() {
        XCTAssertEqual(BHyveError(httpStatus: 401), .unauthorized)
        XCTAssertEqual(BHyveError(httpStatus: 429), .rateLimited)
        XCTAssertEqual(BHyveError(httpStatus: 500), .server(500))
        XCTAssertNil(BHyveError(httpStatus: 200))
    }
}
