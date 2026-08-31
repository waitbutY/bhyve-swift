import Foundation

public struct Zone: Codable, Sendable {
    public let station: Int
    public let deviceID: String?
    public let smartWateringEnabled: Bool?
    public let runTime: Double?
    public let landscapeType: String?
    public let soilType: String?
    public let sprinklerType: String?
    public let addedAt: Int?
    public let startDate: Date?
    public let endDate: Date?

    enum CodingKeys: String, CodingKey {
        case station
        case deviceID = "device_id"
        case smartWateringEnabled = "smart_watering_enabled"
        case runTime = "run_time"
        case landscapeType = "landscape_type"
        case soilType = "soil_type"
        case sprinklerType = "sprinkler_type"
        case addedAt = "added-at"
        case startDate = "start-date"
        case endDate = "end-date"
    }
}
