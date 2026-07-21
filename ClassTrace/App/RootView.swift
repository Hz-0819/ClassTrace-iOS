import SwiftUI

struct RootView: View {
    @Environment(AppSession.self) private var session
    @Environment(AppDependencies.self) private var dependencies

    var body: some View {
        Group {
            if DemoMode.isEnabled {
                MainTabView()
                    .safeAreaInset(edge: .top, spacing: 0) { DemoModeBanner() }
            }
            else if session.isRestoring { ProgressView("正在恢复登录状态…") }
            else if session.isAuthenticated { MainTabView() }
            else { LoginView() }
        }
        .task {
            guard !DemoMode.isEnabled else { return }
            guard session.isRestoring else { return }
            await session.restore(using: AuthRepository(client: dependencies.client, vault: dependencies.sessionVault))
        }
    }
}
