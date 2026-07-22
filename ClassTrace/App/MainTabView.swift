import SwiftUI

struct MainTabView: View {
    @State private var selection = 0

    var body: some View {
        ZStack(alignment: .bottom) {
            Group {
                switch selection {
                case 1: NavigationStack { ClassroomDashboardView() }
                case 2: NavigationStack { ProfileHubView() }
                default: NavigationStack { DashboardView(selectedTab: $selection) }
                }
            }
            .padding(.bottom, 82)

            HStack {
                tab(0, "首页", "home", "home-blue")
                tab(1, "班级", "class", "class-blue")
                tab(2, "我的", "user", "user-blue")
            }
            .frame(height: 64)
            .background(.white, in: Capsule())
            .shadow(color: .black.opacity(0.12), radius: 15, y: 3)
            .padding(.horizontal, 12).padding(.bottom, 8)
        }
        .background(MPColor.page.ignoresSafeArea())
        .tint(MPColor.blue)
    }

    private func tab(_ index: Int, _ title: String, _ image: String, _ selectedImage: String) -> some View {
        Button { selection = index } label: {
            VStack(spacing: 3) {
                MPLegacyImage(name: selection == index ? selectedImage : image, size: 24)
                Text(title).font(.system(size: 11, weight: selection == index ? .medium : .regular))
                    .foregroundStyle(selection == index ? MPColor.blue : Color(red: 168/255, green: 168/255, blue: 168/255))
            }.frame(maxWidth: .infinity, maxHeight: .infinity)
        }.buttonStyle(.plain).accessibilityLabel(title)
    }
}
