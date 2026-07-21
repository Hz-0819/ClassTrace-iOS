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
