import Foundation
import Observation

@MainActor @Observable
final class AppSession {
    var user: APIUser?
    var isRestoring = true
    var errorMessage: String?
    var activeRole: String = UserDefaults.standard.string(forKey: "classtrace.active-role") ?? "TEACHER"
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
    func signIn(_ payload: AuthSessionPayload) {
        user = payload.user
        errorMessage = nil
        if payload.user.roles?.contains(where: { $0.role == activeRole }) != true {
            activeRole = payload.user.roles?.first?.role ?? "GUARDIAN"
            UserDefaults.standard.set(activeRole, forKey: "classtrace.active-role")
        }
    }
    func switchRole(_ role: String) {
        guard user?.roles?.contains(where: { $0.role == role }) == true else { return }
        activeRole = role
        UserDefaults.standard.set(role, forKey: "classtrace.active-role")
    }
    func signInLocal(_ user: APIUser) {
        self.user = user
        errorMessage = nil
        activeRole = user.roles?.first?.role ?? "GUARDIAN"
        UserDefaults.standard.set(activeRole, forKey: "classtrace.active-role")
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
