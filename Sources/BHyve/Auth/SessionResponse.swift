import Foundation

public struct SessionResponse: Codable, Sendable {
    public let orbitSessionToken: String
    public let userID: String
    public let userName: String
    public let firstName: String?
    public let lastName: String?
    public let requirePasswordChange: Bool?

    enum CodingKeys: String, CodingKey {
        case orbitSessionToken = "orbit_session_token"
        case userID = "user_id"
        case userName = "user_name"
        case firstName = "first_name"
        case lastName = "last_name"
        case requirePasswordChange = "require_password_change"
    }
}
