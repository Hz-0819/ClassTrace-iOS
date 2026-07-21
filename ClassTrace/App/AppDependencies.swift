import Foundation
import Observation

@Observable
final class AppDependencies {
    let sessionVault: SessionVault
    let client: HTTPClient

    init(baseURL: URL = AppEnvironment.apiBaseURL, sessionVault: SessionVault = .shared) {
        self.sessionVault = sessionVault
        self.client = HTTPClient(baseURL: baseURL, tokenProvider: sessionVault)
        Task { await PushNotificationManager.shared.configure(client: self.client) }
    }
}
