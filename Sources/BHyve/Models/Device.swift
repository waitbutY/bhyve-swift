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

    public init(
        id: String,
        userID: String,
        name: String,
        type: DeviceType,
        hardwareVersion: String,
        firmwareVersion: String,
        macAddress: String,
        reference: String,
        isConnected: Bool,
        lastConnectedAt: Date?,
        createdAt: Date,
        updatedAt: Date,
        numStations: Int?,
        battery: Battery?,
        zones: [Zone]?,
        status: DeviceStatus
    ) {
        self.id = id
        self.userID = userID
        self.name = name
        self.type = type
        self.hardwareVersion = hardwareVersion
        self.firmwareVersion = firmwareVersion
        self.macAddress = macAddress
        self.reference = reference
        self.isConnected = isConnected
        self.lastConnectedAt = lastConnectedAt
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.numStations = numStations
        self.battery = battery
        self.zones = zones
        self.status = status
    }

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

    public init(
        runMode: RunMode,
        rainDelay: Int,
        statusUpdatedAt: Date,
        nextStartTime: Date?,
        wateringStatus: JSONValue?,
        rainDelayStartedAt: Date?
    ) {
        self.runMode = runMode
        self.rainDelay = rainDelay
        self.statusUpdatedAt = statusUpdatedAt
        self.nextStartTime = nextStartTime
        self.wateringStatus = wateringStatus
        self.rainDelayStartedAt = rainDelayStartedAt
    }

    enum CodingKeys: String, CodingKey {
        case runMode = "run_mode"
        case rainDelay = "rain_delay"
        case statusUpdatedAt = "status_updated_at"
        case nextStartTime = "next_start_time"
        case wateringStatus = "watering_status"
        case rainDelayStartedAt = "rain_delay_started_at"
    }
}
