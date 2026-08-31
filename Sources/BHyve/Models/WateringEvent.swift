import Foundation

public struct WateringEvent: Codable, Sendable, Identifiable {
    public let id: String
    public let deviceID: String
    public let date: Date
    public let createdAt: Date
    public let updatedAt: Date
    public let irrigation: [Irrigation]

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

    enum CodingKeys: String, CodingKey {
        case station, budget, status
        case programName = "program_name"
        case startTime = "start_time"
        case runTime = "run_time"
        case waterVolumeGallons = "water_volume_gal"
    }
}
