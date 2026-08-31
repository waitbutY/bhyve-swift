import Foundation

public struct Battery: Codable, Sendable, Equatable {
    public let percent: Int
    public let charging: Bool
    public let millivolts: Int

    public init(percent: Int, charging: Bool, millivolts: Int) {
        self.percent = percent
        self.charging = charging
        self.millivolts = millivolts
    }

    enum CodingKeys: String, CodingKey {
        case percent, charging
        case millivolts = "mv"
    }
}
