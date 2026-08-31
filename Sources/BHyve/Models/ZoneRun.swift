import Foundation

public struct ZoneRun: Sendable, Equatable {
    public let station: Int
    public let minutes: Int
    public init(station: Int, minutes: Int) {
        self.station = station
        self.minutes = minutes
    }
}
