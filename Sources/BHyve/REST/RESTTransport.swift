import Foundation

actor RESTTransport {
    private let session: URLSession
    private let credentialStore: any BHyveCredentialStore
    private var lastRequestAt: Date = .distantPast
    private let minSpacing: TimeInterval = 1.0

    init(session: URLSession = .shared, credentialStore: any BHyveCredentialStore) {
        self.session = session
        self.credentialStore = credentialStore
    }

    func send(_ endpoint: Endpoints) async throws -> Data {
        try await respectRateLimit()

        let token = try await credentialStore.loadToken()
        let request = try endpoint.makeRequest(token: token)
        let (data, response) = try await session.data(for: request)

        guard let http = response as? HTTPURLResponse else {
            throw BHyveError.invalidResponse
        }
        if http.statusCode == 401, case .login = endpoint {
            throw BHyveError.unauthorized
        }
        if http.statusCode == 401 {
            try await reLogin()
            return try await sendOnce(endpoint)
        }
        if let error = BHyveError(httpStatus: http.statusCode) {
            throw error
        }
        return data
    }

    private func sendOnce(_ endpoint: Endpoints) async throws -> Data {
        try await respectRateLimit()
        let token = try await credentialStore.loadToken()
        let request = try endpoint.makeRequest(token: token)
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw BHyveError.invalidResponse }
        if let error = BHyveError(httpStatus: http.statusCode) { throw error }
        return data
    }

    private func reLogin() async throws {
        guard let creds = try await credentialStore.loadCredentials() else {
            throw BHyveError.unauthorized
        }
        try await respectRateLimit()
        let request = try Endpoints.login(email: creds.email, password: creds.password)
            .makeRequest(token: nil)
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw BHyveError.unauthorized
        }
        let sessionResponse = try JSONCoding.decoder.decode(SessionResponse.self, from: data)
        try await credentialStore.store(token: sessionResponse.orbitApiKey)
    }

    private func respectRateLimit() async throws {
        let gap = Date().timeIntervalSince(lastRequestAt)
        if gap < minSpacing {
            try await Task.sleep(nanoseconds: UInt64((minSpacing - gap) * 1_000_000_000))
        }
        lastRequestAt = Date()
    }
}
