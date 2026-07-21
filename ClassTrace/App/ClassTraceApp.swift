import SwiftUI
import UIKit

@main
struct ClassTraceApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @State private var session = AppSession()
    @State private var dependencies = AppDependencies()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(session)
                .environment(dependencies)
                .tint(MPColor.blue)
                .background(MPColor.page.ignoresSafeArea())
        }
    }
}
