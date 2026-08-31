import Foundation

enum Endpoints {
    static let baseURL = URL(string: "https://api.orbitbhyve.com")!
    static let webOrigin = "https://techsupport.orbitbhyve.com"
    static let appID = "Bhyve Dashboard"
    static let userAgent = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) " +
        "AppleWebKit/537.36 (KHTML, like Gecko) Chrome/147.0.0.0 Safari/537.36"

    case login(email: String, password: String)
    case devices(userID: String)
    case programs(deviceID: String)
    case wateringEvents(deviceID: String)
    case updateProgram(programID: String, body: Data)
    case setRainDelay(deviceID: String, hours: Int)

    func makeRequest(token: String?) throws -> URLRequest {
        var comps = URLComponents(url: Self.baseURL, resolvingAgainstBaseURL: false)!
        var method = "GET"
        var body: Data?
        var requiresAuth = true

        switch self {
        case .login(let email, let password):
            comps.path = "/v1/session"
            method = "POST"
            body = try JSONSerialization.data(withJSONObject: [
                "session": ["email": email, "password": password]
            ])
            requiresAuth = false
        case .devices(let userID):
            comps.path = "/v1/devices"
            comps.queryItems = [URLQueryItem(name: "user_id", value: userID)]
        case .programs(let deviceID):
            comps.path = "/v1/sprinkler_timer_programs"
            comps.queryItems = [URLQueryItem(name: "device_id", value: deviceID)]
        case .wateringEvents(let deviceID):
            comps.path = "/v1/watering_events/\(deviceID)"
        case .updateProgram(let programID, let payload):
            comps.path = "/v1/sprinkler_timer_programs/\(programID)"
            method = "PUT"
            body = payload
        case .setRainDelay(let deviceID, let hours):
            comps.path = "/v1/devices/\(deviceID)"
            method = "PUT"
            body = try JSONSerialization.data(withJSONObject: ["rain_delay": hours])
        }

        guard let url = comps.url else { throw BHyveError.invalidResponse }
        var req = URLRequest(url: url)
        req.httpMethod = method
        req.httpBody = body
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue("application/json", forHTTPHeaderField: "Accept")
        req.setValue(Self.userAgent, forHTTPHeaderField: "User-Agent")
        req.setValue(Self.webOrigin, forHTTPHeaderField: "Origin")
        req.setValue("\(Self.webOrigin)/", forHTTPHeaderField: "Referer")
        req.setValue(Self.appID, forHTTPHeaderField: "orbit-app-id")
        if requiresAuth {
            guard let token else { throw BHyveError.notLoggedIn }
            req.setValue(token, forHTTPHeaderField: "orbit-api-key")
            req.setValue(token, forHTTPHeaderField: "Orbit-Session-Token")
        } else {
            req.setValue("null", forHTTPHeaderField: "orbit-api-key")
        }
        return req
    }
}
