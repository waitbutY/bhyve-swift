import Foundation

public enum BHyveError: Error, Sendable, Equatable {
    case unauthorized
    case rateLimited
    case server(Int)
    case client(Int)
    case decoding(String)
    case transport(String)
    case invalidResponse
    case notLoggedIn

    public init?(httpStatus: Int) {
        switch httpStatus {
        case 200...299: return nil
        case 401: self = .unauthorized
        case 429: self = .rateLimited
        case 400...499: self = .client(httpStatus)
        case 500...: self = .server(httpStatus)
        default: return nil
        }
    }

    public var isAuthFailure: Bool { self == .unauthorized }
}
