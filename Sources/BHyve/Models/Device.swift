import Foundation

public struct Device: Codable, Sendable, Identifiable {
    public enum DeviceType: String, Codable, Sendable {
        case bridge
        case sprinklerTimer = "sprinkler_timer"
    }

    public let id: String
    public let userID: String
    public let name: String
    public let type: DeviceType
    public let hardwareVersion: String
    public let firmwareVersion: String
    public let macAddress: String
    public let reference: String
    public let isConnected: Bool
    public let lastConnectedAt: Date?
    public let createdAt: Date
    public let updatedAt: Date
    public let numStations: Int?
    public let battery: Battery?
    public let zones: [Zone]?
    public let status: DeviceStatus

    enum CodingKeys: String, CodingKey {
        case id, name, type, reference, zones, battery, status
        case userID = "user_id"
        case hardwareVersion = "hardware_version"
        case firmwareVersion = "firmware_version"
        case macAddress = "mac_address"
        case isConnected = "is_connected"
        case lastConnectedAt = "last_connected_at"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case numStations = "num_stations"
    }
}

public struct DeviceStatus: Codable, Sendable {
    public enum RunMode: String, Codable, Sendable {
        case auto, manual, off
    }

    public let runMode: RunMode
    public let rainDelay: Int
    public let statusUpdatedAt: Date
    public let nextStartTime: Date?
    public let wateringStatus: JSONValue?
    public let rainDelayStartedAt: Date?

    enum CodingKeys: String, CodingKey {
        case runMode = "run_mode"
        case rainDelay = "rain_delay"
        case statusUpdatedAt = "status_updated_at"
        case nextStartTime = "next_start_time"
        case wateringStatus = "watering_status"
        case rainDelayStartedAt = "rain_delay_started_at"
    }
}
