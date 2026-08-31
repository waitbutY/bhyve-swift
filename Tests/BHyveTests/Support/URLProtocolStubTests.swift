import XCTest
@testable import BHyve

final class URLProtocolStubTests: XCTestCase {
    override func setUp() { URLProtocolStub.reset() }
    override func tearDown() { URLProtocolStub.reset() }

    func testStubReturnsCannedResponse() async throws {
        URLProtocolStub.register { _ in
            .init(status: 200, headers: [:], body: Data("hi".utf8))
        }
        let (data, resp) = try await URLProtocolStub.session().data(from: URL(string: "https://x/y")!)
        XCTAssertEqual(String(data: data, encoding: .utf8), "hi")
        XCTAssertEqual((resp as? HTTPURLResponse)?.statusCode, 200)
        XCTAssertEqual(URLProtocolStub.requestsReceived().count, 1)
    }
}
