import Foundation

protocol AccessTokenProviding: Sendable {
    func accessToken() async -> String?
    func refreshAccessToken(baseURL: URL) async throws -> String?
}

struct EmptyAccessTokenProvider: AccessTokenProviding {
    func accessToken() async -> String? { nil }
    func refreshAccessToken(baseURL: URL) async throws -> String? { nil }
}

enum HTTPClientError: LocalizedError {
    case invalidResponse
    case transport(Error)
    case server(status: Int, code: String, message: String, requestId: String?)
    case decoding(Error, requestId: String?)

    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            "服务器响应无效"
        case .transport:
            "网络连接失败，请检查网络后重试"
        case let .server(_, _, message, _):
            message
        case .decoding:
            "数据格式异常，请稍后重试"
        }
    }
}

actor HTTPClient {
    private let baseURL: URL
    private let session: URLSession
    private let tokenProvider: AccessTokenProviding
    private let decoder: JSONDecoder

    init(
        baseURL: URL,
        session: URLSession = .shared,
        tokenProvider: AccessTokenProviding = EmptyAccessTokenProvider()
    ) {
        self.baseURL = baseURL
        self.session = session
        self.tokenProvider = tokenProvider
        self.decoder = JSONDecoder()
        self.decoder.dateDecodingStrategy = .custom { decoder in
            let value = try decoder.singleValueContainer().decode(String.self)
            let fractional = ISO8601DateFormatter()
            fractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            if let date = fractional.date(from: value) { return date }
            let standard = ISO8601DateFormatter()
            if let date = standard.date(from: value) { return date }
            throw DecodingError.dataCorruptedError(in: try decoder.singleValueContainer(), debugDescription: "Invalid ISO-8601 date: \(value)")
        }
    }

    func send<Value: Decodable & Sendable>(_ request: HTTPRequest, as type: Value.Type = Value.self) async throws -> Value {
        if DemoMode.isEnabled {
            let data = try await DemoAPI.shared.response(for: request)
            return try decoder.decode(APISuccessEnvelope<Value>.self, from: data).data
        }
        try await perform(request, as: type, mayRefresh: true)
    }

    private func perform<Value: Decodable & Sendable>(_ request: HTTPRequest, as type: Value.Type, mayRefresh: Bool) async throws -> Value {
        var components = URLComponents(url: baseURL.appendingPathComponent(request.path), resolvingAgainstBaseURL: false)
        if !request.query.isEmpty { components?.queryItems = request.query }
        guard let url = components?.url else { throw HTTPClientError.invalidResponse }

        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = request.method.rawValue
        urlRequest.httpBody = request.body
        urlRequest.timeoutInterval = 30
        request.headers.forEach { urlRequest.setValue($1, forHTTPHeaderField: $0) }
        urlRequest.setValue(UUID().uuidString, forHTTPHeaderField: "x-request-id")
        if let key = request.idempotencyKey {
            urlRequest.setValue(key, forHTTPHeaderField: "Idempotency-Key")
        }
        if let token = await tokenProvider.accessToken() {
            urlRequest.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: urlRequest)
        } catch {
            throw HTTPClientError.transport(error)
        }

        guard let http = response as? HTTPURLResponse else {
            throw HTTPClientError.invalidResponse
        }
        if http.statusCode == 401, mayRefresh, try await tokenProvider.refreshAccessToken(baseURL: baseURL) != nil {
            return try await perform(request, as: type, mayRefresh: false)
        }
        if (200..<300).contains(http.statusCode) {
            do {
                return try decoder.decode(APISuccessEnvelope<Value>.self, from: data).data
            } catch {
                throw HTTPClientError.decoding(error, requestId: http.value(forHTTPHeaderField: "x-request-id"))
            }
        }

        let envelope = try? decoder.decode(APIErrorEnvelope.self, from: data)
        throw HTTPClientError.server(
            status: http.statusCode,
            code: envelope?.error.code ?? "HTTP_\(http.statusCode)",
            message: envelope?.error.message ?? "请求失败",
            requestId: envelope?.requestId ?? http.value(forHTTPHeaderField: "x-request-id")
        )
    }

    func sendWithoutResponse(_ request: HTTPRequest) async throws {
        if DemoMode.isEnabled {
            _ = try await DemoAPI.shared.response(for: request)
            return
        }
        try await performWithoutResponse(request, mayRefresh: true)
    }

    private func performWithoutResponse(_ request: HTTPRequest, mayRefresh: Bool) async throws {
        var components = URLComponents(url: baseURL.appendingPathComponent(request.path), resolvingAgainstBaseURL: false)
        if !request.query.isEmpty { components?.queryItems = request.query }
        guard let url = components?.url else { throw HTTPClientError.invalidResponse }
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = request.method.rawValue
        urlRequest.httpBody = request.body
        urlRequest.timeoutInterval = 30
        request.headers.forEach { urlRequest.setValue($1, forHTTPHeaderField: $0) }
        urlRequest.setValue(UUID().uuidString, forHTTPHeaderField: "x-request-id")
        if let key = request.idempotencyKey { urlRequest.setValue(key, forHTTPHeaderField: "Idempotency-Key") }
        if let token = await tokenProvider.accessToken() { urlRequest.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization") }
        let (data, response) = try await session.data(for: urlRequest)
        guard let http = response as? HTTPURLResponse else { throw HTTPClientError.invalidResponse }
        if http.statusCode == 401, mayRefresh, try await tokenProvider.refreshAccessToken(baseURL: baseURL) != nil {
            return try await performWithoutResponse(request, mayRefresh: false)
        }
        guard (200..<300).contains(http.statusCode) else {
            let envelope = try? decoder.decode(APIErrorEnvelope.self, from: data)
            throw HTTPClientError.server(status: http.statusCode, code: envelope?.error.code ?? "HTTP_\(http.statusCode)", message: envelope?.error.message ?? "请求失败", requestId: envelope?.requestId)
        }
    }
}
