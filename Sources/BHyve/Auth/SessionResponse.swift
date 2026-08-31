import Foundation

public struct SessionResponse: Codable, Sendable {
    /// The value used to authenticate subsequent REST + WebSocket calls.
    /// The server only returns this when the login request includes
    /// `orbit-app-id: Bhyve Dashboard`; otherwise it returns
    /// `orbit_session_token` instead (a token that is *not* accepted by
    /// the WebSocket handshake).
    public let orbitApiKey: String
    public let userID: String
    public let userName: String
    public let firstName: String?
    public let lastName: String?
    public let requirePasswordChange: Bool?

    enum CodingKeys: String, CodingKey {
        case orbitApiKey = "orbit_api_key"
        case userID = "user_id"
        case userName = "user_name"
        case firstName = "first_name"
        case lastName = "last_name"
        case requirePasswordChange = "require_password_change"
    }
}
