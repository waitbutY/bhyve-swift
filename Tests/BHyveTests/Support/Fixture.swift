import Foundation
import XCTest

enum Fixture {
    struct MissingFixtureError: Error, CustomStringConvertible {
        let name: String
        var description: String { "missing fixture: \(name)" }
    }

    static func url(_ name: String) throws -> URL {
        guard let url = Bundle.module.url(
            forResource: name,
            withExtension: nil,
            subdirectory: "Fixtures"
        ) else {
            throw MissingFixtureError(name: name)
        }
        return url
    }

    static func data(_ name: String) throws -> Data {
        try Data(contentsOf: url(name))
    }
}
