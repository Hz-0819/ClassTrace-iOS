import SwiftUI

enum DemoMode {
    #if DEMO_MODE
    static let isEnabled = true
    #else
    static let isEnabled = false
    #endif

    static let user = APIUser(
        id: "00000000-0000-0000-0000-000000000001",
        displayName: "演示教师",
        avatarUrl: nil,
        status: "ACTIVE",
        roles: [UserRoleRecord(role: "TEACHER"), UserRoleRecord(role: "GUARDIAN"), UserRoleRecord(role: "ADMIN")],
        identities: []
    )
}

struct DemoModeBanner: View {
    var body: some View {
        Text("演示模式 · 已跳过登录 · 操作数据不会保存")
            .font(.caption.weight(.semibold))
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 7)
            .background(Color.orange)
            .accessibilityLabel("当前为免登录演示模式，操作数据不会保存")
    }
}
