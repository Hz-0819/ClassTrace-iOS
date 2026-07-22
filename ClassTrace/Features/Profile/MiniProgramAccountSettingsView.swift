import SwiftUI

struct AccountSettingsView: View {
    @Environment(AppSession.self) private var session
    @Environment(AppDependencies.self) private var dependencies
    @State private var displayName = ""
    @State private var phone = ""
    @State private var code = ""
    @State private var developmentCode: String?
    @State private var exportURL: URL?
    @State private var isWorking = false
    @State private var message: String?
    @State private var confirmDelete = false

    var body: some View {
        ScrollView(showsIndicators: false) {
            LazyVStack(spacing: 16) {
                profileCard
                section("个人资料") {
                    VStack(alignment: .leading, spacing: 8) { Text("显示名称").font(.system(size: 12)).foregroundStyle(MPColor.secondary); TextField("请输入显示名称", text: $displayName).padding(12).background(MPColor.page, in: RoundedRectangle(cornerRadius: 10)) }
                    Button("保存个人资料") { Task { await saveProfile() } }.buttonStyle(ProfileActionStyle(color: MPColor.blue)).disabled(displayName.trimmingCharacters(in: .whitespaces).isEmpty || isWorking)
                }
                section("身份与角色") {
                    ForEach(session.user?.roles ?? [], id: \.role) { role in
                        HStack { MPIconTile(image: role.role == "TEACHER" ? "teacher-mode" : "user-blue", color: role.role == "TEACHER" ? MPColor.blue : MPColor.green, size: 40); Text(role.role.localizedStatus).font(.system(size: 14, weight: .semibold)); Spacer(); if session.activeRole == role.role { Text("当前身份").font(.system(size: 10)).foregroundStyle(MPColor.blue).padding(.horizontal, 8).padding(.vertical, 4).background(MPColor.blue.opacity(0.1), in: Capsule()) } else { Button("切换") { session.switchRole(role.role) }.font(.system(size: 12, weight: .semibold)) } }
                    }
                    if session.user?.roles?.contains(where: { $0.role == "TEACHER" }) != true { Button("启用教师角色") { Task { await enableRole("TEACHER") } }.buttonStyle(ProfileActionStyle(color: MPColor.blue)) }
                    if session.user?.roles?.contains(where: { $0.role == "GUARDIAN" }) != true { Button("启用家长角色") { Task { await enableRole("GUARDIAN") } }.buttonStyle(ProfileActionStyle(color: MPColor.green)) }
                    ForEach(session.user?.identities ?? [], id: \.provider) { identity in HStack { Image(systemName: "checkmark.shield.fill").foregroundStyle(MPColor.green); Text(identity.provider.localizedStatus).font(.system(size: 13)); Spacer(); Text(identity.verifiedAt == nil ? "未验证" : "已验证").font(.system(size: 11)).foregroundStyle(MPColor.secondary) } }
                }
                section("绑定手机号") {
                    TextField("+86 手机号", text: $phone).keyboardType(.phonePad).padding(12).background(MPColor.page, in: RoundedRectangle(cornerRadius: 10))
                    HStack { TextField("验证码", text: $code).keyboardType(.numberPad).padding(12).background(MPColor.page, in: RoundedRectangle(cornerRadius: 10)); Button("发送验证码") { Task { await sendCode() } }.font(.system(size: 12, weight: .semibold)).disabled(normalizedPhone.count < 11 || isWorking) }
                    if let developmentCode { HStack { Text("测试验证码：\(developmentCode)").font(.system(size: 12)).foregroundStyle(MPColor.gold); Spacer(); Button("填入") { code = developmentCode }.font(.system(size: 12, weight: .semibold)) } }
                    Button("确认绑定") { Task { await linkPhone() } }.buttonStyle(ProfileActionStyle(color: MPColor.green)).disabled(code.count != 6 || isWorking)
                }
                section("通知与数据") {
                    NavigationLink { NotificationSettingsView() } label: { settingsRow("notice", "通知权限与偏好", "管理课前、作业和课时提醒") }
                    Divider()
                    Button { Task { await exportData() } } label: { settingsRow("file-blue", "生成我的数据副本", "导出账号下的教学与交易记录") }.buttonStyle(.plain)
                    if let exportURL { ShareLink(item: exportURL) { Label("分享数据副本", systemImage: "square.and.arrow.up").font(.system(size: 13, weight: .semibold)).foregroundStyle(MPColor.blue) } }
                }
                if let message { Text(message).font(.system(size: 12)).foregroundStyle(message.contains("失败") ? MPColor.red : MPColor.green).padding(.horizontal, 16) }
                Button(role: .destructive) { confirmDelete = true } label: { Text("注销账号").font(.system(size: 14, weight: .semibold)).frame(maxWidth: .infinity).padding(15).background(.white, in: RoundedRectangle(cornerRadius: 14)) }.padding(.horizontal, 16)
            }.padding(.vertical, 16)
        }
        .background(MPColor.page).navigationTitle("账号设置")
        .onAppear { displayName = session.user?.displayName ?? "" }
        .alert("确认注销账号？", isPresented: $confirmDelete) { Button("取消", role: .cancel) {}; Button("注销", role: .destructive) { Task { await removeAccount() } } } message: { Text("本地教学数据、登录会话和推送设备将失效。该操作不能撤销。") }
    }

    private var profileCard: some View {
        MPCard { HStack(spacing: 14) { ZStack { Circle().fill(MPColor.blue.opacity(0.14)); MPLegacyImage(name: "avatar", size: 48) }.frame(width: 62, height: 62); VStack(alignment: .leading, spacing: 5) { Text(session.user?.displayName ?? "课迹用户").font(.system(size: 19, weight: .bold)); Text("ID: \((session.user?.id ?? "").suffix(8))").font(.system(size: 11)).foregroundStyle(MPColor.secondary); Text(session.activeRole.localizedStatus).font(.system(size: 10, weight: .semibold)).foregroundStyle(MPColor.blue) }; Spacer() } }.padding(.horizontal, 16)
    }

    private func section<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View { VStack(spacing: 12) { MPSectionHeader(title: title); MPCard { VStack(spacing: 13) { content() } } }.padding(.horizontal, 16) }
    private func settingsRow(_ image: String, _ title: String, _ detail: String) -> some View { HStack(spacing: 12) { MPIconTile(image: image, color: MPColor.blue, size: 40); VStack(alignment: .leading, spacing: 3) { Text(title).font(.system(size: 14, weight: .semibold)).foregroundStyle(MPColor.text); Text(detail).font(.system(size: 10)).foregroundStyle(MPColor.secondary) }; Spacer(); MPLegacyImage(name: "right", size: 12).opacity(0.45) } }
    private var normalizedPhone: String { phone.filter(\.isNumber) }

    @MainActor private func saveProfile() async { await perform { session.user = try await ClassTraceRepository(client: dependencies.client).updateProfile(displayName: displayName.trimmingCharacters(in: .whitespaces), avatarURL: session.user?.avatarUrl?.absoluteString); return "个人资料已保存" } }
    @MainActor private func enableRole(_ role: String) async { await perform { session.user = try await ClassTraceRepository(client: dependencies.client).ensureRole(role); return "角色已启用" } }
    @MainActor private func sendCode() async { await perform { let number = phone.hasPrefix("+") ? phone : "+86\(normalizedPhone)"; let result = try await ClassTraceRepository(client: dependencies.client).requestBindPhoneCode(number); phone = number; developmentCode = result.developmentCode; return "验证码已发送" } }
    @MainActor private func linkPhone() async { await perform { session.user = try await ClassTraceRepository(client: dependencies.client).linkPhone(phone, code: code); code = ""; developmentCode = nil; return "手机号已绑定" } }
    @MainActor private func exportData() async { await perform { let value = try await ClassTraceRepository(client: dependencies.client).exportAccount(); let encoder = JSONEncoder(); encoder.outputFormatting = [.prettyPrinted, .sortedKeys]; let url = FileManager.default.temporaryDirectory.appendingPathComponent("ClassTrace-account-export.json"); try encoder.encode(value).write(to: url, options: .atomic); exportURL = url; return "数据副本已生成" } }
    @MainActor private func removeAccount() async { await perform { try await ClassTraceRepository(client: dependencies.client).deleteAccount(); await session.signOut(using: AuthRepository(client: dependencies.client, vault: dependencies.sessionVault)); return "账号已注销" } }
    @MainActor private func perform(_ operation: () async throws -> String) async { isWorking = true; defer { isWorking = false }; do { message = try await operation() } catch { message = "操作失败：\(error.localizedDescription)" } }
}

private struct ProfileActionStyle: ButtonStyle {
    let color: Color
    func makeBody(configuration: Configuration) -> some View { configuration.label.font(.system(size: 13, weight: .semibold)).foregroundStyle(.white).frame(maxWidth: .infinity).padding(12).background(color.opacity(configuration.isPressed ? 0.7 : 1), in: RoundedRectangle(cornerRadius: 10)) }
}
