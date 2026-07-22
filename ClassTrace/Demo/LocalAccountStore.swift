import Foundation
import Security

struct LocalAccount: Codable, Identifiable, Sendable {
    var id: String { account }
    let account: String
    let displayName: String
    let role: String
}

actor LocalAccountStore {
    static let shared = LocalAccountStore()
    private let profilesKey = "classtrace.local.accounts.v1"

    func accounts() -> [LocalAccount] {
        guard let data = UserDefaults.standard.data(forKey: profilesKey), let values = try? JSONDecoder().decode([LocalAccount].self, from: data) else {
            return []
        }
        return values
    }

    func ensureDemoAccount() {
        guard accounts().isEmpty else { return }
        try? register(account: "demo", password: "123456", displayName: "演示教师", role: "TEACHER")
    }

    @discardableResult
    func register(account: String, password: String, displayName: String, role: String) throws -> APIUser {
        let normalized = account.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard normalized.count >= 3 else { throw LocalAccountError.invalidAccount }
        guard password.count >= 6 else { throw LocalAccountError.weakPassword }
        var values = accounts()
        guard !values.contains(where: { $0.account == normalized }) else { throw LocalAccountError.exists }
        let profile = LocalAccount(account: normalized, displayName: displayName.nilIfEmpty ?? normalized, role: role)
        values.append(profile)
        UserDefaults.standard.set(try JSONEncoder().encode(values), forKey: profilesKey)
        try Self.writePassword(password, account: normalized)
        return Self.user(profile)
    }

    func login(account: String, password: String) throws -> APIUser {
        ensureDemoAccount()
        let normalized = account.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard let profile = accounts().first(where: { $0.account == normalized }), Self.readPassword(account: normalized) == password else {
            throw LocalAccountError.wrongCredentials
        }
        return Self.user(profile)
    }

    static func deletePersistedAccount(_ account: String) throws {
        let normalized = account.lowercased()
        let key = "classtrace.local.accounts.v1"
        var values: [LocalAccount] = []
        if let data = UserDefaults.standard.data(forKey: key) { values = (try? JSONDecoder().decode([LocalAccount].self, from: data)) ?? [] }
        values.removeAll { $0.account == normalized }
        UserDefaults.standard.set(try JSONEncoder().encode(values), forKey: key)
        SecItemDelete([kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: service, kSecAttrAccount as String: normalized] as CFDictionary)
        LocalProfileCache.remove(account: normalized)
    }

    private static func user(_ profile: LocalAccount) -> APIUser {
        APIUser(id: "local-\(profile.account)", displayName: profile.displayName, avatarUrl: nil, status: "ACTIVE", roles: [UserRoleRecord(role: profile.role)], identities: [])
    }

    private static let service = "com.classtrace.local-account"
    private static func writePassword(_ value: String, account: String) throws {
        SecItemDelete([kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: service, kSecAttrAccount as String: account] as CFDictionary)
        let query: [String: Any] = [kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: service, kSecAttrAccount as String: account, kSecValueData as String: Data(value.utf8), kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly]
        guard SecItemAdd(query as CFDictionary, nil) == errSecSuccess else { throw LocalAccountError.cannotSave }
    }
    private static func readPassword(account: String) -> String? {
        let query: [String: Any] = [kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: service, kSecAttrAccount as String: account, kSecReturnData as String: true, kSecMatchLimit as String: kSecMatchLimitOne]
        var result: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess, let data = result as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }
}

enum LocalAccountError: LocalizedError {
    case invalidAccount, weakPassword, exists, wrongCredentials, cannotSave
    var errorDescription: String? {
        switch self {
        case .invalidAccount: "账号至少需要 3 个字符"
        case .weakPassword: "密码至少需要 6 位"
        case .exists: "这个账号已经注册"
        case .wrongCredentials: "账号或密码不正确"
        case .cannotSave: "无法把密码保存到本机钥匙串"
        }
    }
}

enum LocalProfileCache {
    private static func key(_ account: String) -> String { "classtrace.local.profile.\(account.lowercased())" }

    static func load(account: String) -> APIUser? {
        guard let data = UserDefaults.standard.data(forKey: key(account)) else { return nil }
        return try? JSONDecoder().decode(APIUser.self, from: data)
    }

    static func save(_ user: APIUser, account: String? = nil) {
        let value = account ?? user.id.replacingOccurrences(of: "local-", with: "")
        if let data = try? JSONEncoder().encode(user) { UserDefaults.standard.set(data, forKey: key(value)) }
    }

    static func remove(account: String) { UserDefaults.standard.removeObject(forKey: key(account)) }
}
