import Foundation

public enum BHyveEvent: Sendable, Equatable {
    case wateringInProgress(deviceID: String, station: Int, runTime: Int)
    case wateringComplete(deviceID: String, station: Int)
    case deviceIdle(deviceID: String)
    case batteryStatus(deviceID: String, percent: Int, charging: Bool)
    case rainDelay(deviceID: String, hours: Int)
    case programChanged(deviceID: String, programID: String)
    case deviceStatus(deviceID: String, status: JSONValue)
    case fault(deviceID: String, station: Int?, code: String)
    case unknown(raw: [String: JSONValue])

    public static func decode(from data: Data) throws -> BHyveEvent {
        let obj = try JSONCoding.decoder.decode([String: JSONValue].self, from: data)
        guard case .string(let name) = obj["event"] ?? .null else {
            throw BHyveError.decoding("missing 'event' field")
        }
        let deviceID = obj.stringValue("device_id") ?? ""

        switch name {
        case "watering_in_progress_notification":
            let station = obj.intValue("current_station") ?? 0
            let runTime = obj.intValue("run_time") ?? 0
            return .wateringInProgress(deviceID: deviceID, station: station, runTime: runTime)
        case "watering_complete":
            return .wateringComplete(deviceID: deviceID, station: obj.intValue("current_station") ?? 0)
        case "device_idle":
            return .deviceIdle(deviceID: deviceID)
        case "battery_status":
            return .batteryStatus(
                deviceID: deviceID,
                percent: obj.intValue("percent") ?? 0,
                charging: obj.boolValue("charging") ?? false
            )
        case "rain_delay":
            return .rainDelay(deviceID: deviceID, hours: obj.intValue("delay") ?? 0)
        case "program_changed":
            let pid: String
            if case .object(let p) = obj["program"] ?? .null,
               case .string(let s) = p["id"] ?? .null {
                pid = s
            } else { pid = "" }
            return .programChanged(deviceID: deviceID, programID: pid)
        case "device_status":
            return .deviceStatus(deviceID: deviceID, status: obj["status"] ?? .null)
        case "fault":
            return .fault(
                deviceID: deviceID,
                station: obj.intValue("station"),
                code: obj.stringValue("code") ?? "unknown"
            )
        default:
            return .unknown(raw: obj)
        }
    }
}

private extension Dictionary where Key == String, Value == JSONValue {
    func stringValue(_ k: String) -> String? {
        if case .string(let s) = self[k] ?? .null { return s }
        return nil
    }
    func intValue(_ k: String) -> Int? {
        if case .number(let n) = self[k] ?? .null { return Int(n) }
        return nil
    }
    func boolValue(_ k: String) -> Bool? {
        if case .bool(let b) = self[k] ?? .null { return b }
        return nil
    }
}
