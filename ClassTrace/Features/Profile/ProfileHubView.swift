import SwiftUI

struct ProfileHubView: View {
    @Environment(AppSession.self) private var session
    @Environment(AppDependencies.self) private var dependencies
    @State private var classes: [APIClassroom] = []
    @State private var students: [APIStudent] = []
    @State private var points: APIPoints?

    private var isTeacher: Bool { session.activeRole == "TEACHER" }

    var body: some View {
        ScrollView(showsIndicators: false) {
            LazyVStack(spacing: 22) {
                profileHeader
                summary
                if isTeacher { teacherSections } else { guardianSections }
                settings
                Button { Task { await session.signOut(using: AuthRepository(client: dependencies.client, vault: dependencies.sessionVault)) } } label: {
                    HStack { MPLegacyImage(name: "logout", size: 18); Text(DemoMode.isEnabled ? "退出演示模式" : "退出登录").font(.system(size: 15, weight: .medium)).foregroundStyle(MPColor.red) }
                        .frame(maxWidth: .infinity).padding(17).background(.white, in: RoundedRectangle(cornerRadius: 16)).shadow(color: .black.opacity(0.05), radius: 10, y: 3)
                }.buttonStyle(.plain).padding(.horizontal, 16)
            }.padding(.bottom, 22)
        }
        .background(MPColor.page).toolbar(.hidden, for: .navigationBar).task { await load() }.refreshable { await load() }
    }

    private var profileHeader: some View {
        ZStack {
            MPColor.blue
            Circle().fill(.white.opacity(0.1)).frame(width: 160, height: 160).offset(x: 150, y: -65)
            Circle().fill(.white.opacity(0.08)).frame(width: 90, height: 90).offset(x: -170, y: 30)
            HStack(spacing: 15) {
                ZStack { Circle().fill(.white.opacity(0.22)); MPLegacyImage(name: "avatar", size: 54) }.frame(width: 66, height: 66).overlay(Circle().stroke(.white.opacity(0.5), lineWidth: 2))
                VStack(alignment: .leading, spacing: 7) {
                    HStack { Text(session.user?.displayName ?? "课迹用户").font(.system(size: 22, weight: .bold)); if DemoMode.isEnabled { Text("演示模式").font(.system(size: 10, weight: .semibold)).padding(.horizontal, 7).padding(.vertical, 3).background(.white.opacity(0.2), in: Capsule()) } }
                    Menu {
                        if session.user?.roles?.contains(where: { $0.role == "TEACHER" }) == true { Button("切换为教师身份") { session.switchRole("TEACHER") } }
                        if session.user?.roles?.contains(where: { $0.role == "GUARDIAN" }) == true { Button("切换为家长身份") { session.switchRole("GUARDIAN") } }
                    } label: { HStack(spacing: 4) { Text(session.activeRole.localizedStatus); Image(systemName: "chevron.down").font(.caption2) }.font(.system(size: 13)).foregroundStyle(.white.opacity(0.82)) }
                }.foregroundStyle(.white)
                Spacer()
                NavigationLink { AccountSettingsView() } label: { Image(systemName: "gearshape.fill").foregroundStyle(.white).frame(width: 42, height: 42).background(.white.opacity(0.2), in: Circle()) }
            }.padding(.horizontal, 20).padding(.top, 28)
        }.frame(height: 170).clipShape(UnevenRoundedRectangle(bottomLeadingRadius: 28, bottomTrailingRadius: 28))
    }

    private var summary: some View {
        MPCard {
            HStack {
                summaryItem(isTeacher ? "我的班级" : "我的孩子", "\(isTeacher ? classes.count : students.count)")
                Rectangle().fill(Color.black.opacity(0.07)).frame(width: 0.5, height: 42)
                summaryItem("进行中课程", "\(classes.filter { $0.status == "ACTIVE" }.count)")
                Rectangle().fill(Color.black.opacity(0.07)).frame(width: 0.5, height: 42)
                summaryItem("我的积分", "\(points?.balance ?? 0)")
            }
        }.padding(.horizontal, 16).offset(y: -42).padding(.bottom, -42)
    }

    private func summaryItem(_ title: String, _ value: String) -> some View {
        VStack(spacing: 5) { Text(value).font(.system(size: 20, weight: .bold)).foregroundStyle(MPColor.text); Text(title).font(.system(size: 11)).foregroundStyle(MPColor.secondary) }.frame(maxWidth: .infinity)
    }

    private var teacherSections: some View {
        Group {
            menuSection("教学工作") {
                MPMenuRow(title: "班级管理", image: "class-blue", color: MPColor.blue) { ClassroomHubView() }
                MPMenuRow(title: "学生管理", image: "student-green", color: MPColor.green) { ClassroomHubView() }
                MPMenuRow(title: "作业管理", image: "file-red", color: MPColor.red) { LearningHubView(initialSelection: 0) }
                MPMenuRow(title: "资料中心", image: "material-brown", color: MPColor.gold) { LearningHubView(initialSelection: 1) }
                MPMenuRow(title: "个人日程", image: "timetable-blue", color: MPColor.blue) { ManualScheduleView() }
            }
            menuSection("财务管理") {
                MPMenuRow(title: "经营概览", image: "bar chart-orange", color: MPColor.gold) { BusinessOverviewView() }
                MPMenuRow(title: "课时档案", image: "time-blue", color: MPColor.blue) { ClassroomHubView() }
                MPMenuRow(title: "账单与退款", image: "wallet-brown", color: MPColor.gold) { CommerceCenterView() }
            }
        }
    }

    private var guardianSections: some View {
        Group {
            menuSection("课程管理") {
                MPMenuRow(title: "课程管理", image: "timetable-blue", color: MPColor.blue) { ClassroomHubView() }
                MPMenuRow(title: "作业与提交", image: "file-red", color: MPColor.red) { LearningHubView(initialSelection: 0) }
                MPMenuRow(title: "学习计划", image: "plan-brown", color: MPColor.gold) { LearningHubView(initialSelection: 2) }
            }
            menuSection("财务管理") {
                MPMenuRow(title: "开销概览", image: "bill-red", color: MPColor.red) { CommerceCenterView() }
                MPMenuRow(title: "课时明细", image: "time-blue", color: MPColor.blue) { ClassroomHubView() }
            }
        }
    }

    private var settings: some View {
        menuSection("设置") {
            MPMenuRow(title: "消息通知", image: "notice", color: MPColor.blue) { NotificationCenterView() }
            MPMenuRow(title: "VIP 权益", image: "vip-yellow", color: MPColor.gold) { VIPCenterView() }
            MPMenuRow(title: "问题反馈", image: "feedback-green", color: MPColor.green) { FeedbackCenterView() }
            MPMenuRow(title: "关于我们", image: "info-brown", color: MPColor.gold) { AboutView() }
            if session.user?.roles?.contains(where: { $0.role == "ADMIN" }) == true { MPMenuRow(title: "管理员工具", image: "identity", color: MPColor.blue) { AdminCenterView() } }
        }
    }

    private func menuSection<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(spacing: 12) { MPSectionHeader(title: title); MPCard { VStack(spacing: 0) { content() } } }.padding(.horizontal, 16)
    }

    @MainActor private func load() async {
        let repository = ClassTraceRepository(client: dependencies.client)
        async let c = try? repository.classes(); async let s = try? repository.students(); async let p = try? repository.points()
        classes = (await c) ?? []; students = (await s) ?? []; points = await p
    }
}

struct NotificationCenterView: View {
    @Environment(AppDependencies.self) private var dependencies; @State private var items: [APINotification] = []; @State private var error: String?
    var body: some View { List(items) { item in Button { Task { await read(item) } } label: { HStack(alignment: .top) { Circle().fill(item.readAt == nil ? Color.ctBrand : Color.clear).frame(width: 8, height: 8).padding(.top, 6); VStack(alignment: .leading) { Text(item.title).font(.headline); Text(item.body).foregroundStyle(Color.ctTextSecondary); Text(item.createdAt.formatted()).font(.caption).foregroundStyle(Color.ctTextSecondary) } } }.buttonStyle(.plain) }.overlay { if items.isEmpty && error == nil { CTStateView(kind: .empty, title: "暂无通知", message: "课前提醒和教学动态会显示在这里") } }.navigationTitle("消息通知").toolbar { Button("全部已读") { Task { _ = try? await ClassTraceRepository(client: dependencies.client).markAllNotificationsRead(); await load() } } }.task { await load() } }
    @MainActor private func load() async { do { items = try await ClassTraceRepository(client: dependencies.client).notifications() } catch { self.error = error.localizedDescription } }
    @MainActor private func read(_ item: APINotification) async { do { _ = try await ClassTraceRepository(client: dependencies.client).markNotificationRead(item.id); await load() } catch { self.error = error.localizedDescription } }
}

private struct OrderCenterView: View {
    @Environment(AppDependencies.self) private var dependencies; @State private var orders: [APIOrder] = []
    var body: some View { List(orders) { order in VStack(alignment: .leading) { HStack { Text(order.orderNumber).font(.headline); Spacer(); Text(order.status.localizedStatus) }; Text(order.student?.name ?? "学生"); Text(order.totalAmountCents.formattedCurrency).foregroundStyle(Color.ctTextSecondary); if let refunds = order.refunds, !refunds.isEmpty { Text("退款记录 \(refunds.count) 条").font(.caption).foregroundStyle(Color.ctWarning) } } }.overlay { if orders.isEmpty { CTStateView(kind: .empty, title: "暂无账单", message: "购课和退款记录会显示在这里") } }.navigationTitle("账单与退款").task { orders = (try? await ClassTraceRepository(client: dependencies.client).orders()) ?? [] } }
}

struct VIPCenterView: View {
    @Environment(AppDependencies.self) private var dependencies; @Environment(AppSession.self) private var session; @State private var entitlements: APIEntitlements?; @State private var store = StoreKitManager(); @State private var activationCode = ""
    var body: some View { List { Section { VStack(spacing: 14) { Image(systemName: "crown.fill").font(.system(size: 64)).foregroundStyle(Color.ctWarning); Text(entitlements?.active == true ? "VIP 权益已生效" : "尚未开通 VIP").font(.title2.bold()); Text("交易由 App Store 完成，最终权益以服务端验签结果为准。").multilineTextAlignment(.center).foregroundStyle(Color.ctTextSecondary) }.frame(maxWidth: .infinity).padding() }; Section("订阅方案") { ForEach(store.products, id: \.id) { product in Button { Task { if let userId = session.user?.id, await store.purchase(product, repository: ClassTraceRepository(client: dependencies.client), userId: userId) { await reload() } } } label: { HStack { VStack(alignment: .leading) { Text(product.displayName); Text(product.description).font(.caption).foregroundStyle(Color.ctTextSecondary) }; Spacer(); Text(product.displayPrice) } } }; if store.products.isEmpty { Text("请在 App Store Connect 配置月度和年度 VIP 商品。") } }; Section("内部激活码") { TextField("激活码", text: $activationCode).textInputAutocapitalization(.characters); Button("兑换权益") { Task { _ = try? await ClassTraceRepository(client: dependencies.client).redeemActivationCode(activationCode); await reload() } }.disabled(activationCode.count < 8) }; Section { Button("恢复购买") { Task { if await store.restore(repository: ClassTraceRepository(client: dependencies.client)) { await reload() } } }.disabled(store.isWorking) }; if let error = store.errorMessage { Section { Text(error).foregroundStyle(Color.ctDanger) } } }.navigationTitle("VIP 权益").task { await store.load(); await reload() } }
    @MainActor private func reload() async { entitlements = try? await ClassTraceRepository(client: dependencies.client).entitlements() }
}

struct BusinessOverviewView: View {
    @Environment(AppDependencies.self) private var dependencies; @State private var overview: APIBusinessOverview?; @State private var from = Calendar.current.date(byAdding: .month, value: -1, to: Date()) ?? Date(); @State private var to = Date()
    var body: some View { List { Section("统计范围") { DatePicker("开始", selection: $from, displayedComponents: .date); DatePicker("结束", selection: $to, displayedComponents: .date); Button("刷新") { Task { await load() } } }; if let overview { Section("经营数据") { LabeledContent("进行中班级", value: "\(overview.activeClassCount)"); LabeledContent("完成课节", value: "\(overview.completedSessionCount)"); LabeledContent("累计课时", value: overview.consumedHours.formatted()); LabeledContent("订单数", value: "\(overview.orderCount)"); LabeledContent("记录收入", value: overview.recordedRevenueCents.formattedCurrency) } } }.navigationTitle("经营概览").task { await load() } }
    @MainActor private func load() async { overview = try? await ClassTraceRepository(client: dependencies.client).businessOverview(from: from, to: Calendar.current.date(byAdding: .day, value: 1, to: to)) }
}

struct FeedbackCenterView: View {
    @Environment(AppDependencies.self) private var dependencies; @State private var items: [APIFeedback] = []; @State private var showNew = false
    var body: some View { List(items) { item in VStack(alignment: .leading) { HStack { Text(item.category).font(.headline); Spacer(); Text(item.status.localizedStatus) }; Text(item.content); if let reply = item.reply { Text("回复：\(reply)").foregroundStyle(Color.ctBrand) } } }.navigationTitle("意见反馈").toolbar { Button { showNew = true } label: { Image(systemName: "square.and.pencil") } }.sheet(isPresented: $showNew) { NewFeedbackSheet { await load() } }.task { await load() } }
    @MainActor private func load() async { items = (try? await ClassTraceRepository(client: dependencies.client).feedback()) ?? [] }
}
private struct NewFeedbackSheet: View {
    @Environment(\.dismiss) private var dismiss; @Environment(AppDependencies.self) private var dependencies; @State private var category = "功能建议"; @State private var content = ""; let onSaved: () async -> Void
    var body: some View { NavigationStack { Form { Picker("类型", selection: $category) { Text("功能建议").tag("功能建议"); Text("问题反馈").tag("问题反馈"); Text("其他").tag("其他") }; TextEditor(text: $content).frame(minHeight: 180) }.navigationTitle("提交反馈").toolbar { ToolbarItem(placement: .cancellationAction) { Button("取消") { dismiss() } }; ToolbarItem(placement: .confirmationAction) { Button("提交") { Task { _ = try? await ClassTraceRepository(client: dependencies.client).submitFeedback(category: category, content: content, contact: nil); await onSaved(); dismiss() } }.disabled(content.isEmpty) } } } }
}
struct AboutView: View { var body: some View { List { Section { LabeledContent("应用", value: "课迹 ClassTrace"); LabeledContent("版本", value: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0") }; Section { NavigationLink("隐私政策") { LegalDocumentView(title: "隐私政策", text: "课迹仅为提供登录、教学管理、消息提醒、资料存储、账单记录和 VIP 权益所必需而处理您的手机号、身份标识、学生与教学内容、设备推送标识及交易记录。数据不会用于跨应用跟踪或广告。您可以在账号设置中申请注销账号；正式发布前，运营主体应补充公司名称、联系方式、保存期限和投诉渠道。") }; NavigationLink("用户协议") { LegalDocumentView(title: "用户协议", text: "课迹是教师与家长的教学管理工具。教学课费默认由双方通过微信、支付宝、现金或银行等外部渠道直接结算，平台只记录双方确认的账单和履约信息，不保管教学资金。VIP 属于应用内数字服务，通过 App Store 购买。正式发布前，运营主体应完成法务审核并填写主体信息。") } } }.navigationTitle("关于课迹") } }

private struct LegalDocumentView: View { let title: String; let text: String; var body: some View { ScrollView { Text(text).frame(maxWidth: .infinity, alignment: .leading).padding() }.navigationTitle(title) } }

private extension Int { var formattedCurrency: String { (Double(self) / 100).formatted(.currency(code: "CNY")) } }
