import Foundation

public struct WateringEvent: Codable, Sendable, Identifiable {
    public let id: String
    public let deviceID: String
    public let date: Date
    public let createdAt: Date
    public let updatedAt: Date
    public let irrigation: [Irrigation]

    public init(id: String, deviceID: String, date: Date, createdAt: Date, updatedAt: Date, irrigation: [Irrigation]) {
        self.id = id
        self.deviceID = deviceID
        self.date = date
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.irrigation = irrigation
    }

    enum CodingKeys: String, CodingKey {
        case id, date, irrigation
        case deviceID = "device_id"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

public struct Irrigation: Codable, Sendable {
    public let station: Int
    public let programName: String
    public let startTime: Date
    public let runTime: Double
    public let budget: Int
    public let status: String
    public let waterVolumeGallons: Double?

    public init(
        station: Int,
        programName: String,
        startTime: Date,
        runTime: Double,
        budget: Int,
        status: String,
        waterVolumeGallons: Double?
    ) {
        self.station = station
        self.programName = programName
        self.startTime = startTime
        self.runTime = runTime
        self.budget = budget
        self.status = status
        self.waterVolumeGallons = waterVolumeGallons
    }

    enum CodingKeys: String, CodingKey {
        case station, budget, status
        case programName = "program_name"
        case startTime = "start_time"
        case runTime = "run_time"
        case waterVolumeGallons = "water_volume_gal"
    }
}
