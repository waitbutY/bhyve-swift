import Foundation

final class URLProtocolStub: URLProtocol, @unchecked Sendable {
    struct Response {
        var status: Int
        var headers: [String: String]
        var body: Data
    }

    typealias Handler = @Sendable (URLRequest) -> Response

    private static let lock = NSLock()
    nonisolated(unsafe) private static var handlers: [Handler] = []
    nonisolated(unsafe) private static var seenRequests: [URLRequest] = []

    static func register(handler: @escaping Handler) {
        lock.lock(); defer { lock.unlock() }
        handlers.append(handler)
    }

    static func reset() {
        lock.lock(); defer { lock.unlock() }
        handlers.removeAll()
        seenRequests.removeAll()
    }

    static func requestsReceived() -> [URLRequest] {
        lock.lock(); defer { lock.unlock() }
        return seenRequests
    }

    static func session() -> URLSession {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [URLProtocolStub.self]
        return URLSession(configuration: config)
    }

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        Self.lock.lock()
        Self.seenRequests.append(request)
        let handler = Self.handlers.first
        Self.lock.unlock()

        guard let handler else {
            client?.urlProtocol(self, didFailWithError: URLError(.badURL))
            return
        }

        let response = handler(request)
        let http = HTTPURLResponse(
            url: request.url!,
            statusCode: response.status,
            httpVersion: "HTTP/1.1",
            headerFields: response.headers
        )!
        client?.urlProtocol(self, didReceive: http, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: response.body)
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}
