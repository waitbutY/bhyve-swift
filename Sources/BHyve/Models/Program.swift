import Foundation

public struct Program: Codable, Sendable, Identifiable {
    public let id: String
    public let deviceID: String
    public let name: String
    public let enabled: Bool
    public let budget: Int
    public let frequency: Frequency
    public let runTimes: [RunTime]
    public let startTimes: [String]
    public let programStartDate: Date
    public let createdAt: Date
    public let updatedAt: Date

    public init(
        id: String,
        deviceID: String,
        name: String,
        enabled: Bool,
        budget: Int,
        frequency: Frequency,
        runTimes: [RunTime],
        startTimes: [String],
        programStartDate: Date,
        createdAt: Date,
        updatedAt: Date
    ) {
        self.id = id
        self.deviceID = deviceID
        self.name = name
        self.enabled = enabled
        self.budget = budget
        self.frequency = frequency
        self.runTimes = runTimes
        self.startTimes = startTimes
        self.programStartDate = programStartDate
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    enum CodingKeys: String, CodingKey {
        case id, name, enabled, budget, frequency
        case deviceID = "device_id"
        case runTimes = "run_times"
        case startTimes = "start_times"
        case programStartDate = "program_start_date"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

public struct RunTime: Codable, Sendable, Equatable {
    public let station: Int
    public let runTime: Int

    public init(station: Int, runTime: Int) {
        self.station = station
        self.runTime = runTime
    }

    enum CodingKeys: String, CodingKey {
        case station
        case runTime = "run_time"
    }
}

public enum Frequency: Codable, Sendable, Equatable {
    case even
    case odd
    case days([Int])
    case interval(Int)

    private enum CodingKeys: String, CodingKey {
        case type, days, interval
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let type = try c.decode(String.self, forKey: .type)
        switch type {
        case "even": self = .even
        case "odd": self = .odd
        case "days":
            self = .days(try c.decode([Int].self, forKey: .days))
        case "interval":
            self = .interval(try c.decode(Int.self, forKey: .interval))
        default:
            throw DecodingError.dataCorruptedError(
                forKey: .type, in: c,
                debugDescription: "unknown frequency type: \(type)"
            )
        }
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .even: try c.encode("even", forKey: .type)
        case .odd: try c.encode("odd", forKey: .type)
        case .days(let d):
            try c.encode("days", forKey: .type)
            try c.encode(d, forKey: .days)
        case .interval(let n):
            try c.encode("interval", forKey: .type)
            try c.encode(n, forKey: .interval)
        }
    }
}
