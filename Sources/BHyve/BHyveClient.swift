import Foundation

public actor BHyveClient {
    private let transport: RESTTransport
    private let socket: EventSocket
    private let credentialStore: any BHyveCredentialStore

    public init(
        credentialStore: any BHyveCredentialStore,
        urlSession: URLSession = .shared
    ) {
        self.credentialStore = credentialStore
        self.transport = RESTTransport(session: urlSession, credentialStore: credentialStore)
        self.socket = EventSocket(session: urlSession, credentialStore: credentialStore)
    }

    // MARK: - Auth

    public func login(email: String, password: String) async throws {
        try await credentialStore.store(credentials: (email: email, password: password))
        let data = try await transport.send(.login(email: email, password: password))
        let session = try JSONCoding.decoder.decode(SessionResponse.self, from: data)
        try await credentialStore.store(token: session.orbitApiKey)
    }

    // MARK: - Reads

    public func devices() async throws -> [Device] {
        let userID = try await userIDFromToken()
        let data = try await transport.send(.devices(userID: userID))
        return try JSONCoding.decoder.decode([Device].self, from: data)
    }

    public func programs(deviceID: String) async throws -> [Program] {
        let data = try await transport.send(.programs(deviceID: deviceID))
        return try JSONCoding.decoder.decode([Program].self, from: data)
    }

    public func wateringHistory(deviceID: String) async throws -> [WateringEvent] {
        let data = try await transport.send(.wateringEvents(deviceID: deviceID))
        return try JSONCoding.decoder.decode([WateringEvent].self, from: data)
    }

    // MARK: - Mutations

    /// Requires an active WS connection. Consumers must have started `events()`
    /// (or wait a moment for the socket to open) before calling this.
    public func startZones(deviceID: String, stations: [ZoneRun]) async throws {
        let stationPayload: [[String: Any]] = stations.map {
            ["station": $0.station, "run_time": $0.minutes]
        }
        let payload: [String: Any] = [
            "event": "change_mode",
            "mode": "manual",
            "device_id": deviceID,
            "stations": stationPayload,
        ]
        try await socket.send(Self.jsonString(payload))
    }

    public func stopWatering(deviceID: String) async throws {
        let payload: [String: Any] = [
            "event": "change_mode",
            "mode": "manual",
            "device_id": deviceID,
            "stations": [] as [[String: Any]],
        ]
        try await socket.send(Self.jsonString(payload))
    }

    private static func jsonString(_ payload: [String: Any]) throws -> String {
        let data = try JSONSerialization.data(withJSONObject: payload)
        return String(data: data, encoding: .utf8)!
    }

    public func setRainDelay(deviceID: String, hours: Int) async throws {
        _ = try await transport.send(.setRainDelay(deviceID: deviceID, hours: hours))
    }

    public func updateProgram(_ program: Program) async throws {
        let body = try JSONCoding.encoder.encode(program)
        _ = try await transport.send(.updateProgram(programID: program.id, body: body))
    }

    // MARK: - Live events

    public nonisolated func events() -> AsyncThrowingStream<BHyveEvent, Error> {
        socket.events()
    }

    // MARK: - Helpers

    private func userIDFromToken() async throws -> String {
        guard let token = try await credentialStore.loadToken() else {
            throw BHyveError.notLoggedIn
        }
        let parts = token.split(separator: ".")
        guard parts.count == 3,
              let payload = base64URLDecode(String(parts[1])),
              let text = String(data: payload, encoding: .utf8) else {
            throw BHyveError.transport("cannot parse JWT payload")
        }
        let pattern = #""([0-9a-f]{24})""#
        if let range = text.range(of: pattern, options: .regularExpression) {
            return String(text[range]).trimmingCharacters(in: CharacterSet(charactersIn: "\""))
        }
        throw BHyveError.transport("cannot extract user_id from JWT")
    }

    private nonisolated func base64URLDecode(_ s: String) -> Data? {
        var padded = s.replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        while padded.count % 4 != 0 { padded += "=" }
        return Data(base64Encoded: padded)
    }
}
