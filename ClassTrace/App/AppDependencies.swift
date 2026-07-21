import Foundation
import Observation

@Observable
final class AppDependencies {
    let sessionVault: SessionVault
    let client: HTTPClient

    init(baseURL: URL = AppEnvironment.apiBaseURL, sessionVault: SessionVault = .shared) {
        self.sessionVault = sessionVault
        let client = HTTPClient(baseURL: baseURL, tokenProvider: sessionVault)
        self.client = client
        Task { await PushNotificationManager.shared.configure(client: client) }
    }
}
