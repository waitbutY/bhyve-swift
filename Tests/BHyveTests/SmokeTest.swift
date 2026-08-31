import XCTest
@testable import BHyve

final class SmokeTest: XCTestCase {
    func testInit() async {
        _ = BHyveClient()
        XCTAssert(true)
    }
}
