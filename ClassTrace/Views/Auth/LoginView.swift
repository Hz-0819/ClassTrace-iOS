import SwiftUI

struct LoginView: View {
    @Environment(AppSession.self) private var session
    @State private var account = ""
    @State private var password = ""
    @State private var displayName = ""
    @State private var role = "GUARDIAN"
    @State private var isRegistering = false
    @State private var isWorking = false
    @State private var errorMessage: String?

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 0) {
                header
                card.offset(y: -40).padding(.bottom, -40)
                if DemoMode.isEnabled {
                    Text("本地测试账号：demo　密码：123456")
                        .font(.system(size: 12)).foregroundStyle(MPColor.secondary).padding(.top, 18)
                }
            }
        }.background(MPColor.page.ignoresSafeArea()).task { await LocalAccountStore.shared.ensureDemoAccount() }
    }

    private var header: some View {
        ZStack {
            MPColor.blue
            Circle().fill(.white.opacity(0.10)).frame(width: 130, height: 130).offset(x: 150, y: -65)
            Circle().fill(.white.opacity(0.08)).frame(width: 78, height: 78).offset(x: -170, y: 0)
            Circle().fill(.white.opacity(0.06)).frame(width: 50, height: 50).offset(x: 120, y: 70)
            VStack(spacing: 9) {
                Text("欢迎使用课迹").font(.system(size: 22, weight: .semibold)).foregroundStyle(.white)
                Text("成长，有迹可循").font(.system(size: 14)).foregroundStyle(.white.opacity(0.8))
            }.padding(.bottom, 30)
        }.frame(height: 230)
    }

    private var card: some View {
        VStack(spacing: 24) {
            Text(isRegistering ? "注册账号" : "登录账号").font(.system(size: 20, weight: .semibold)).foregroundStyle(MPColor.text)
            VStack(alignment: .leading, spacing: 13) {
                Text("选择身份").font(.system(size: 15, weight: .medium)).foregroundStyle(MPColor.text)
                HStack(spacing: 12) { roleButton("GUARDIAN", "家", "家长", MPColor.blue); roleButton("TEACHER", "师", "教师", MPColor.coral) }
            }
            VStack(spacing: 16) {
                field("账号", "请输入账号", text: $account, secure: false)
                field("密码", "请输入密码", text: $password, secure: true)
                if isRegistering { field("昵称", "请输入昵称", text: $displayName, secure: false) }
            }
            if let errorMessage { Text(errorMessage).font(.system(size: 13)).foregroundStyle(MPColor.red).frame(maxWidth: .infinity, alignment: .leading) }
            Button { Task { await submit() } } label: {
                HStack { if isWorking { ProgressView().tint(.white) }; Text(isRegistering ? "注册并登录" : "登录").font(.system(size: 17, weight: .semibold)) }
                    .foregroundStyle(.white).frame(maxWidth: .infinity, minHeight: 50).background(MPColor.blue, in: RoundedRectangle(cornerRadius: 10))
            }.buttonStyle(.plain).disabled(isWorking || account.count < 3 || password.count < 6)
            Button(isRegistering ? "已有账号 · 返回登录" : "注册账号") { errorMessage = nil; isRegistering.toggle() }
                .font(.system(size: 14)).foregroundStyle(MPColor.blue)
        }
        .padding(.horizontal, 20).padding(.vertical, 26)
        .background(.white, in: RoundedRectangle(cornerRadius: 20)).shadow(color: .black.opacity(0.08), radius: 20, y: 4)
        .padding(.horizontal, 16)
    }

    private func roleButton(_ value: String, _ character: String, _ title: String, _ color: Color) -> some View {
        Button { role = value } label: {
            VStack(spacing: 8) {
                Text(character).font(.system(size: 17, weight: .bold)).foregroundStyle(role == value ? .white : color)
                    .frame(width: 46, height: 46).background(role == value ? color : color.opacity(0.15), in: Circle())
                Text(title).font(.system(size: 15, weight: .medium)).foregroundStyle(MPColor.text)
            }.frame(maxWidth: .infinity).padding(.vertical, 15)
                .background((role == value ? color.opacity(0.08) : Color(red: 250/255, green: 250/255, blue: 250/255)), in: RoundedRectangle(cornerRadius: 12))
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(role == value ? color : Color.black.opacity(0.08), lineWidth: 1))
        }.buttonStyle(.plain)
    }

    private func field(_ label: String, _ placeholder: String, text: Binding<String>, secure: Bool) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(label).font(.system(size: 14, weight: .medium)).foregroundStyle(MPColor.text)
            Group { if secure { SecureField(placeholder, text: text) } else { TextField(placeholder, text: text).textInputAutocapitalization(.never) } }
                .font(.system(size: 15)).padding(.horizontal, 14).frame(height: 50).background(MPColor.page, in: RoundedRectangle(cornerRadius: 9))
        }
    }

    @MainActor private func submit() async {
        isWorking = true; defer { isWorking = false }; errorMessage = nil
        do {
            let user: APIUser
            if DemoMode.isEnabled {
                if isRegistering { user = try await LocalAccountStore.shared.register(account: account, password: password, displayName: displayName, role: role) }
                else { user = try await LocalAccountStore.shared.login(account: account, password: password) }
                session.signInLocal(user)
            } else {
                throw LocalAccountError.cannotSave
            }
        } catch { errorMessage = error.localizedDescription }
    }
}
