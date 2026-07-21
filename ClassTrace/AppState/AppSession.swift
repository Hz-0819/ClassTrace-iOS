import Foundation
import Observation

@MainActor @Observable
final class AppSession {
    var user: APIUser?
    var isRestoring = true
    var errorMessage: String?
    var isAuthenticated: Bool { user != nil }

    init() {
        if DemoMode.isEnabled && !UserDefaults.standard.bool(forKey: "classtrace.local.requires-login") {
            if UserDefaults.standard.string(forKey: "classtrace.local.active-account") == nil {
                UserDefaults.standard.set("demo", forKey: "classtrace.local.active-account")
            }
            user = DemoMode.user
            isRestoring = false
        }
    }

    func restore(using repository: AuthRepository) async {
        defer { isRestoring = false }
        guard await repository.vault.accessToken() != nil else { return }
        do { user = try await repository.me() }
        catch { await repository.logout(); user = nil }
    }
    func signIn(_ payload: AuthSessionPayload) { user = payload.user; errorMessage = nil }
    func signInLocal(_ user: APIUser) {
        self.user = user
        errorMessage = nil
        UserDefaults.standard.set(user.id.replacingOccurrences(of: "local-", with: ""), forKey: "classtrace.local.active-account")
        UserDefaults.standard.set(false, forKey: "classtrace.local.requires-login")
    }
    func signOut(using repository: AuthRepository) async {
        if DemoMode.isEnabled {
            UserDefaults.standard.set(true, forKey: "classtrace.local.requires-login")
            user = nil
            return
        }
        await repository.logout(); user = nil
    }
}
