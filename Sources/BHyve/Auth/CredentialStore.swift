import Foundation

public protocol BHyveCredentialStore: Sendable {
    func loadCredentials() async throws -> (email: String, password: String)?
    func store(credentials: (email: String, password: String)) async throws
    func clearCredentials() async throws

    func loadToken() async throws -> String?
    func store(token: String) async throws
    func clearToken() async throws
}

public actor InMemoryCredentialStore: BHyveCredentialStore {
    private var credentials: (email: String, password: String)?
    private var token: String?

    public init(
        credentials: (email: String, password: String)? = nil,
        token: String? = nil
    ) {
        self.credentials = credentials
        self.token = token
    }

    public func loadCredentials() -> (email: String, password: String)? { credentials }
    public func store(credentials: (email: String, password: String)) { self.credentials = credentials }
    public func clearCredentials() { credentials = nil }

    public func loadToken() -> String? { token }
    public func store(token: String) { self.token = token }
    public func clearToken() { self.token = nil }
}
