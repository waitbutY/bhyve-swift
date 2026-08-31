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

    public init(
        station: Int,
        deviceID: String? = nil,
        smartWateringEnabled: Bool? = nil,
        runTime: Double? = nil,
        landscapeType: String? = nil,
        soilType: String? = nil,
        sprinklerType: String? = nil,
        addedAt: Int? = nil,
        startDate: Date? = nil,
        endDate: Date? = nil
    ) {
        self.station = station
        self.deviceID = deviceID
        self.smartWateringEnabled = smartWateringEnabled
        self.runTime = runTime
        self.landscapeType = landscapeType
        self.soilType = soilType
        self.sprinklerType = sprinklerType
        self.addedAt = addedAt
        self.startDate = startDate
        self.endDate = endDate
    }

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
