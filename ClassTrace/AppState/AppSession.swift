import Foundation
import Observation

@MainActor @Observable
final class AppSession {
    var user: APIUser?
    var isRestoring = true
    var errorMessage: String?
    var isAuthenticated: Bool { user != nil }

    func restore(using repository: AuthRepository) async {
        defer { isRestoring = false }
        guard await repository.vault.accessToken() != nil else { return }
        do { user = try await repository.me() }
        catch { await repository.logout(); user = nil }
    }
    func signIn(_ payload: AuthSessionPayload) { user = payload.user; errorMessage = nil }
    func signOut(using repository: AuthRepository) async { await repository.logout(); user = nil }
}
