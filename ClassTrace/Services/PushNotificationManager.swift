import Foundation
import CryptoKit
import UIKit
import UserNotifications

actor PushNotificationManager {
    static let shared = PushNotificationManager()
    private var client: HTTPClient?
    private var pendingToken: String?
    private var registeredToken: String?

    func configure(client: HTTPClient) async {
        self.client = client
        if let pendingToken { try? await register(pendingToken) }
    }

    @MainActor
    func requestAuthorization() async throws {
        let granted = try await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound])
        if granted { UIApplication.shared.registerForRemoteNotifications() }
    }

    func received(deviceToken: String) async {
        pendingToken = deviceToken
        try? await register(deviceToken)
    }
    func retryPendingRegistration() async { if let pendingToken { try? await register(pendingToken) } }
    func unregister() async {
        guard let token = registeredToken ?? pendingToken, let client else { return }
        let hash = SHA256.hash(data: Data(token.utf8)).map { String(format: "%02x", $0) }.joined()
        try? await client.sendWithoutResponse(HTTPRequest(method: .delete, path: "devices/\(hash)"))
        pendingToken = nil
        registeredToken = nil
    }

    func failed(_ error: Error) { }

    private func register(_ token: String) async throws {
        guard let client else { return }
        #if DEBUG
        let environment = "development"
        #else
        let environment = "production"
        #endif
        let _: APIDeviceToken = try await client.send(.json(method: .post, path: "devices", body: DeviceRegistration(token: token, environment: environment)))
        registeredToken = token
        pendingToken = nil
    }
}

private struct DeviceRegistration: Encodable { let token: String; let environment: String }
