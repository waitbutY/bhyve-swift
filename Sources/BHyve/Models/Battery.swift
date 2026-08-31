import Foundation

public struct Battery: Codable, Sendable, Equatable {
    public let percent: Int
    public let charging: Bool
    public let millivolts: Int

    enum CodingKeys: String, CodingKey {
        case percent, charging
        case millivolts = "mv"
    }
}
