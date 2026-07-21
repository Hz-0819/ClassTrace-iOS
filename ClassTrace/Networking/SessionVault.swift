import Foundation
import Security

actor SessionVault: AccessTokenProviding {
    static let shared = SessionVault()
    private var access: String?
    private var refresh: String?
    private var refreshTask: Task<String?, Error>?

    init() {
        access = Self.read(account: "access_token")
        refresh = Self.read(account: "refresh_token")
    }

    func accessToken() async -> String? { access }
    func refreshToken() -> String? { refresh }

    func save(accessToken: String, refreshToken: String) {
        access = accessToken
        refresh = refreshToken
        Self.write(accessToken, account: "access_token")
        Self.write(refreshToken, account: "refresh_token")
    }

    func clear() {
        access = nil; refresh = nil
        Self.remove(account: "access_token"); Self.remove(account: "refresh_token")
    }

    func refreshAccessToken(baseURL: URL) async throws -> String? {
        if let refreshTask { return try await refreshTask.value }
        guard let refresh else { return nil }
        let task = Task<String?, Error> {
            var request = URLRequest(url: baseURL.appendingPathComponent("auth/refresh"))
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = try JSONEncoder().encode(RefreshBody(refreshToken: refresh))
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse else { throw URLError(.badServerResponse) }
            if http.statusCode == 401 { self.clear(); return nil }
            guard (200..<300).contains(http.statusCode) else { throw URLError(.badServerResponse) }
            let decoder = JSONDecoder(); decoder.dateDecodingStrategy = .iso8601
            let payload = try decoder.decode(APISuccessEnvelope<RefreshPayload>.self, from: data).data
            self.save(accessToken: payload.accessToken, refreshToken: payload.refreshToken)
            return payload.accessToken
        }
        refreshTask = task
        defer { refreshTask = nil }
        return try await task.value
    }

    private static let service = "com.classtrace.auth"
    private static func write(_ value: String, account: String) {
        remove(account: account)
        let query: [String: Any] = [kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: service, kSecAttrAccount as String: account, kSecValueData as String: Data(value.utf8), kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly]
        SecItemAdd(query as CFDictionary, nil)
    }
    private static func read(account: String) -> String? {
        let query: [String: Any] = [kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: service, kSecAttrAccount as String: account, kSecReturnData as String: true, kSecMatchLimit as String: kSecMatchLimitOne]
        var item: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &item) == errSecSuccess, let data = item as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }
    private static func remove(account: String) {
        SecItemDelete([kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: service, kSecAttrAccount as String: account] as CFDictionary)
    }
}

private struct RefreshBody: Encodable { let refreshToken: String }
private struct RefreshPayload: Decodable { let accessToken: String; let refreshToken: String; let expiresIn: Int }
