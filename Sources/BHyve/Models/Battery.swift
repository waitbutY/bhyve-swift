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

    // Some timers omit `charging` from the REST payload.
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        percent = try c.decode(Int.self, forKey: .percent)
        charging = try c.decodeIfPresent(Bool.self, forKey: .charging) ?? false
        millivolts = try c.decode(Int.self, forKey: .millivolts)
    }
}
