import Foundation

struct APISuccessEnvelope<Value: Decodable>: Decodable {
    let data: Value
    let requestId: String
}

struct APIErrorEnvelope: Decodable {
    struct Payload: Decodable {
        let code: String
        let message: String
        let details: [String: JSONValue]?
    }

    let error: Payload
    let requestId: String
}

enum JSONValue: Decodable, Sendable {
    case string(String)
    case number(Double)
    case bool(Bool)
    case object([String: JSONValue])
    case array([JSONValue])
    case null

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if container.decodeNil() { self = .null }
        else if let value = try? container.decode(Bool.self) { self = .bool(value) }
        else if let value = try? container.decode(Double.self) { self = .number(value) }
        else if let value = try? container.decode(String.self) { self = .string(value) }
        else if let value = try? container.decode([String: JSONValue].self) { self = .object(value) }
        else { self = .array(try container.decode([JSONValue].self)) }
    }
}

struct PageMeta: Decodable, Sendable {
    let page: Int
    let pageSize: Int
    let total: Int
    let hasMore: Bool
}

struct Page<Value: Decodable>: Decodable {
    let data: [Value]
    let meta: PageMeta
    let requestId: String
}

