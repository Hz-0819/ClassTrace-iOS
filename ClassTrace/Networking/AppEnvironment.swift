import Foundation

enum AppEnvironment {
    static var apiBaseURL: URL {
        guard
            let value = Bundle.main.object(forInfoDictionaryKey: "API_BASE_URL") as? String,
            let url = URL(string: value)
        else {
            preconditionFailure("API_BASE_URL is missing or invalid")
        }
        return url.appendingPathComponent("api/v1")
    }
}
