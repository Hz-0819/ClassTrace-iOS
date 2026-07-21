import SwiftUI

struct MainTabView: View {
    var body: some View {
        TabView {
            NavigationStack { DashboardView() }
                .tabItem { Label("首页", systemImage: "house") }
            NavigationStack { ClassroomHubView() }
                .tabItem { Label("班级", systemImage: "person.3") }
            NavigationStack { LearningHubView() }
                .tabItem { Label("教学", systemImage: "book.closed") }
            NavigationStack { ProfileHubView() }
                .tabItem { Label("我的", systemImage: "person.crop.circle") }
        }
        .tint(.ctBrand)
    }
}
