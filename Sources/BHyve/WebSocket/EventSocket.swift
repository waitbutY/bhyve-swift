import Foundation

actor EventSocket {
    static let url = URL(string: "wss://api.orbitbhyve.com/v1/events")!
    static let origin = "https://techsupport.orbitbhyve.com"
    static let userAgent = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) " +
        "AppleWebKit/537.36 (KHTML, like Gecko) Chrome/147.0.0.0 Safari/537.36"

    private let session: URLSession
    private let credentialStore: any BHyveCredentialStore
    private var task: URLSessionWebSocketTask?
    private var pingTask: Task<Void, Never>?
    private var listenTask: Task<Void, Never>?

    init(session: URLSession = .shared, credentialStore: any BHyveCredentialStore) {
        self.session = session
        self.credentialStore = credentialStore
    }

    static func helloMessage(token: String) -> String {
        let data = try! JSONSerialization.data(withJSONObject: [
            "event": "app_connection",
            "orbit_session_token": token,
        ])
        return String(data: data, encoding: .utf8)!
    }

    static func backoffDelay(attempt: Int) -> TimeInterval {
        let ladder: [TimeInterval] = [1, 2, 5, 15, 30, 60]
        return ladder[min(attempt, ladder.count - 1)]
    }

    func send(_ payload: String) async throws {
        guard let task else { throw BHyveError.transport("socket not connected") }
        try await task.send(.string(payload))
    }

    nonisolated func events() -> AsyncThrowingStream<BHyveEvent, Error> {
        AsyncThrowingStream { continuation in
            let task = Task { [weak self] in
                var attempt = 0
                while !Task.isCancelled {
                    do {
                        try await self?.connectOnce(continuation: continuation)
                        attempt = 0
                    } catch let error as BHyveError where error == .unauthorized {
                        continuation.finish(throwing: error)
                        return
                    } catch {
                    }
                    let delay = EventSocket.backoffDelay(attempt: attempt)
                    try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                    attempt += 1
                }
                continuation.finish()
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    private func connectOnce(continuation: AsyncThrowingStream<BHyveEvent, Error>.Continuation) async throws {
        guard let token = try await credentialStore.loadToken() else {
            throw BHyveError.notLoggedIn
        }
        var request = URLRequest(url: Self.url)
        request.setValue(Self.origin, forHTTPHeaderField: "Origin")
        request.setValue(Self.userAgent, forHTTPHeaderField: "User-Agent")
        let task = session.webSocketTask(with: request)
        self.task = task
        task.resume()

        try await task.send(.string(Self.helloMessage(token: token)))
        startPingLoop(task: task)

        while !Task.isCancelled {
            let message = try await task.receive()
            let data: Data
            switch message {
            case .data(let d): data = d
            case .string(let s): data = Data(s.utf8)
            @unknown default: continue
            }
            do {
                let event = try BHyveEvent.decode(from: data)
                continuation.yield(event)
            } catch {
            }
        }
    }

    private func startPingLoop(task: URLSessionWebSocketTask) {
        pingTask?.cancel()
        pingTask = Task { [weak task] in
            while let task, !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 20 * 1_000_000_000)
                try? await task.send(.string(#"{"event":"ping"}"#))
            }
        }
    }
}
