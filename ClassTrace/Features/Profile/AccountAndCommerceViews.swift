import SwiftUI

private struct LegacyAccountSettingsView: View {
    @Environment(AppSession.self) private var session
    @Environment(AppDependencies.self) private var dependencies
    @State private var displayName = ""; @State private var error: String?; @State private var confirmDelete = false
    @State private var exportURL: URL?
    @State private var phone = ""; @State private var code = ""; @State private var developmentCode: String?
    var body: some View { Form {
        Section("个人资料") { TextField("显示名称", text: $displayName); Button("保存资料") { Task { await save() } }.disabled(displayName.isEmpty) }
        Section("身份与角色") { ForEach(session.user?.roles ?? [], id: \.role) { Text($0.role.localizedStatus) }; ForEach(session.user?.identities ?? [], id: \.provider) { identity in LabeledContent(identity.provider.localizedStatus, value: identity.verifiedAt == nil ? "未验证" : "已验证") }; Button("启用教师角色") { Task { await role("TEACHER") } }; Button("启用家长角色") { Task { await role("GUARDIAN") } } }
        Section("绑定手机号") { TextField("+86 手机号", text: $phone).keyboardType(.phonePad); HStack { TextField("验证码", text: $code).keyboardType(.numberPad); Button("发送验证码") { Task { await sendCode() } } }; if let developmentCode { Text("开发验证码：\(developmentCode)").font(.caption) }; Button("确认绑定") { Task { await linkPhone() } }.disabled(code.count != 6) }
        Section("通知与数据") { NavigationLink("通知权限与偏好") { NotificationSettingsView() }; Button("生成我的数据副本") { Task { await exportData() } }; if let exportURL { ShareLink(item: exportURL) { Label("分享数据副本", systemImage: "square.and.arrow.up") } } }
        if let error { Text(error).foregroundStyle(Color.ctDanger) }
        Section { Button("注销账号", role: .destructive) { confirmDelete = true } }
    }.navigationTitle("账号设置").onAppear { displayName = session.user?.displayName ?? "" }.alert("确认注销账号？", isPresented: $confirmDelete) { Button("取消", role: .cancel) {}; Button("注销", role: .destructive) { Task { await removeAccount() } } } message: { Text("登录会话和推送设备将失效，账号进入删除状态。") } }
    @MainActor private func save() async { do { session.user = try await ClassTraceRepository(client: dependencies.client).updateProfile(displayName: displayName, avatarURL: session.user?.avatarUrl?.absoluteString) } catch { self.error = error.localizedDescription } }
    @MainActor private func role(_ role: String) async { do { session.user = try await ClassTraceRepository(client: dependencies.client).ensureRole(role) } catch { self.error = error.localizedDescription } }
    @MainActor private func sendCode() async { do { let normalized = phone.hasPrefix("+") ? phone : "+86\(phone)"; let result = try await ClassTraceRepository(client: dependencies.client).requestBindPhoneCode(normalized); phone = normalized; developmentCode = result.developmentCode } catch { self.error = error.localizedDescription } }
    @MainActor private func linkPhone() async { do { session.user = try await ClassTraceRepository(client: dependencies.client).linkPhone(phone, code: code); code = "" } catch { self.error = error.localizedDescription } }
    @MainActor private func exportData() async { do { let value = try await ClassTraceRepository(client: dependencies.client).exportAccount(); let encoder = JSONEncoder(); encoder.outputFormatting = [.prettyPrinted, .sortedKeys]; let url = FileManager.default.temporaryDirectory.appendingPathComponent("ClassTrace-account-export.json"); try encoder.encode(value).write(to: url, options: .atomic); exportURL = url } catch { self.error = error.localizedDescription } }
    @MainActor private func removeAccount() async { do { try await ClassTraceRepository(client: dependencies.client).deleteAccount(); await session.signOut(using: AuthRepository(client: dependencies.client, vault: dependencies.sessionVault)) } catch { self.error = error.localizedDescription } }
}

struct NotificationSettingsView: View {
    @Environment(AppDependencies.self) private var dependencies
    @State private var preferences: [APINotificationPreference] = []; @State private var error: String?
    private let events = ["SESSION_REMINDER": "课前提醒", "SESSION_COMPLETED": "课后通知", "HOMEWORK": "作业动态", "MATERIAL": "资料动态", "LOW_HOURS": "课时不足"]
    var body: some View { List {
        Section { Button("允许系统推送") { Task { await enablePush() } } }
        ForEach(events.keys.sorted(), id: \.self) { event in Section(events[event] ?? event) { Toggle("App 推送", isOn: binding(event, "APNS")); Toggle("站内消息", isOn: binding(event, "IN_APP")) } }
        if let error { Text(error).foregroundStyle(Color.ctDanger) }
    }.navigationTitle("通知设置").task { await load() } }
    private func binding(_ event: String, _ channel: String) -> Binding<Bool> { Binding(get: { preferences.first { $0.eventType == event && $0.channel == channel }?.enabled ?? true }, set: { value in Task { await set(event, channel, value) } }) }
    @MainActor private func load() async { do { preferences = try await ClassTraceRepository(client: dependencies.client).notificationPreferences() } catch { self.error = error.localizedDescription } }
    @MainActor private func enablePush() async { do { try await PushNotificationManager.shared.requestAuthorization() } catch { self.error = error.localizedDescription } }
    @MainActor private func set(_ event: String, _ channel: String, _ enabled: Bool) async { do { _ = try await ClassTraceRepository(client: dependencies.client).setNotificationPreference(eventType: event, channel: channel, enabled: enabled); await load() } catch { self.error = error.localizedDescription } }
}

private struct LegacyCommerceCenterView: View {
    @Environment(AppDependencies.self) private var dependencies
    @State private var orders: [APIOrder] = []; @State private var classes: [APIClassroom] = []; @State private var students: [APIStudent] = []; @State private var showCreate = false; @State private var error: String?
    var body: some View { List(orders) { order in NavigationLink { OrderDetailView(order: order) { await load() } } label: { VStack(alignment: .leading) { HStack { Text(order.orderNumber).font(.headline); Spacer(); Text(order.status.localizedStatus) }; Text(order.student?.name ?? "学生"); Text((Double(order.totalAmountCents) / 100).formatted(.currency(code: "CNY"))).foregroundStyle(Color.ctTextSecondary) } } }.overlay { if orders.isEmpty { CTStateView(kind: .empty, title: "暂无账单", message: "家长可创建购课记录，教师确认外部收款。") } }.navigationTitle("账单与退款").toolbar { Button { showCreate = true } label: { Image(systemName: "plus") } }.sheet(isPresented: $showCreate) { CreateOrderView(classes: classes, students: students) { await load() } }.task { await load() } }
    @MainActor private func load() async { do { let r = ClassTraceRepository(client: dependencies.client); async let o = r.orders(); async let c = r.classes(); async let s = r.students(); (orders, classes, students) = try await (o, c, s) } catch { self.error = error.localizedDescription } }
}

private struct CreateOrderView: View {
    @Environment(\.dismiss) private var dismiss; @Environment(AppDependencies.self) private var dependencies
    let classes: [APIClassroom]; let students: [APIStudent]; let onSaved: () async -> Void
    @State private var classId = ""; @State private var studentId = ""; @State private var amount = 0.0; @State private var hours = 0.0; @State private var error: String?
    var body: some View { NavigationStack { Form { Picker("班级", selection: $classId) { Text("请选择").tag(""); ForEach(classes) { Text($0.name).tag($0.id) } }; Picker("学生", selection: $studentId) { Text("请选择").tag(""); ForEach(students) { Text($0.name).tag($0.id) } }; TextField("总课费（元）", value: $amount, format: .number).keyboardType(.decimalPad); TextField("购买课时", value: $hours, format: .number).keyboardType(.decimalPad); if let error { Text(error).foregroundStyle(Color.ctDanger) } }.navigationTitle("创建购课账单").toolbar { ToolbarItem(placement: .cancellationAction) { Button("取消") { dismiss() } }; ToolbarItem(placement: .confirmationAction) { Button("创建") { Task { await save() } }.disabled(classId.isEmpty || studentId.isEmpty || amount <= 0 || hours <= 0) } } } }
    @MainActor private func save() async { do { _ = try await ClassTraceRepository(client: dependencies.client).createOrder(studentId: studentId, classId: classId, amountCents: Int((amount * 100).rounded()), hours: hours); await onSaved(); dismiss() } catch { self.error = error.localizedDescription } }
}

private struct OrderDetailView: View {
    @Environment(AppDependencies.self) private var dependencies
    let order: APIOrder; let onSaved: () async -> Void
    @State private var provider = "WECHAT"; @State private var transactionId = ""; @State private var refundAmount = 0.0; @State private var refundHours = 0.0; @State private var reason = ""; @State private var error: String?
    var body: some View { Form {
        Section("账单") { LabeledContent("订单号", value: order.orderNumber); LabeledContent("金额", value: (Double(order.totalAmountCents) / 100).formatted(.currency(code: "CNY"))); LabeledContent("课时", value: order.purchasedHours.doubleValue.formatted()); LabeledContent("结算", value: order.settlementPolicy.localizedStatus) }
        Section("教师确认外部收款") { Picker("渠道", selection: $provider) { Text("微信").tag("WECHAT"); Text("支付宝").tag("ALIPAY"); Text("现金").tag("CASH"); Text("银行转账").tag("BANK") }; TextField("外部流水号", text: $transactionId); Button("确认已全额收款") { Task { await payment() } }.disabled(transactionId.isEmpty) }
        Section("家长申请退款") { TextField("退款金额（元）", value: $refundAmount, format: .number).keyboardType(.decimalPad); TextField("退回课时", value: $refundHours, format: .number).keyboardType(.decimalPad); TextField("原因", text: $reason); Button("提交退款申请") { Task { await refund() } }.disabled(refundAmount <= 0) }
        if let refunds = order.refunds {
            Section("退款记录") {
                ForEach(refunds) { item in
                    VStack(alignment: .leading) {
                        Text(item.status.localizedStatus)
                        Text(item.reason ?? "无原因").font(.caption)
                    }
                    if item.status == "REQUESTED" {
                        HStack {
                            Button("确认已退款") { Task { await resolve(item.id, "REFUNDED") } }
                            Button("拒绝") { Task { await resolve(item.id, "REJECTED") } }
                        }
                    }
                }
            }
        }
        if let error { Text(error).foregroundStyle(Color.ctDanger) }
    }.navigationTitle("账单详情") }
    @MainActor private func payment() async { do { _ = try await ClassTraceRepository(client: dependencies.client).recordPayment(orderId: order.id, amountCents: order.totalAmountCents, provider: provider, transactionId: transactionId); await onSaved() } catch { self.error = error.localizedDescription } }
    @MainActor private func refund() async { do { _ = try await ClassTraceRepository(client: dependencies.client).requestRefund(orderId: order.id, amountCents: Int((refundAmount * 100).rounded()), hours: refundHours, reason: reason.nilIfEmpty); await onSaved() } catch { self.error = error.localizedDescription } }
    @MainActor private func resolve(_ id: String, _ status: String) async { do { _ = try await ClassTraceRepository(client: dependencies.client).resolveRefund(id, status: status, providerRefundId: status == "REFUNDED" ? UUID().uuidString : nil); await onSaved() } catch { self.error = error.localizedDescription } }
}
