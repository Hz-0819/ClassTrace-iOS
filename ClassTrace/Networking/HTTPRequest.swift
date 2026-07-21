import Foundation

enum HTTPMethod: String, Sendable {
    case get = "GET"
    case post = "POST"
    case patch = "PATCH"
    case delete = "DELETE"
}

struct HTTPRequest: Sendable {
    let method: HTTPMethod
    let path: String
    var query: [URLQueryItem] = []
    var body: Data?
    var headers: [String: String] = [:]
    var idempotencyKey: String?

    static func json<Body: Encodable>(
        method: HTTPMethod,
        path: String,
        body: Body,
        idempotencyKey: String? = nil,
        encoder: JSONEncoder = JSONEncoder()
    ) throws -> HTTPRequest {
        HTTPRequest(
            method: method,
            path: path,
            body: try encoder.encode(body),
            headers: ["Content-Type": "application/json"],
            idempotencyKey: idempotencyKey
        )
    }
}
