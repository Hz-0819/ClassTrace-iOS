import SwiftUI
import UniformTypeIdentifiers
import UIKit

struct NotificationCenterView: View {
    @Environment(AppDependencies.self) private var dependencies
    @State private var items: [APINotification] = []
    @State private var showPreferences = false

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 14) {
                HStack {
                    Text("共 \(items.count) 条消息，\(items.filter { $0.readAt == nil }.count) 条未读")
                        .font(.system(size: 13)).foregroundStyle(MPColor.secondary)
                    Spacer()
                    Button("全部已读") { Task { await markAllRead() } }
                        .font(.system(size: 13, weight: .semibold)).foregroundStyle(MPColor.blue)
                }
                .padding(.horizontal, 16)

                if items.isEmpty {
                    MPCard { MPEmptyView(image: "notice", title: "暂无通知", detail: "课前提醒和教学动态会显示在这里") }
                        .padding(.horizontal, 16)
                } else {
                    ForEach(items) { item in
                        Button { Task { await markRead(item) } } label: {
                            HStack(alignment: .top, spacing: 12) {
                                MPIconTile(image: notificationImage(item.type), color: item.readAt == nil ? MPColor.blue : MPColor.secondary, size: 42)
                                VStack(alignment: .leading, spacing: 6) {
                                    HStack {
                                        Text(item.title).font(.system(size: 15, weight: item.readAt == nil ? .bold : .medium)).foregroundStyle(MPColor.text)
                                        Spacer()
                                        if item.readAt == nil { Circle().fill(MPColor.red).frame(width: 7, height: 7) }
                                    }
                                    Text(item.body).font(.system(size: 13)).foregroundStyle(MPColor.secondary).multilineTextAlignment(.leading)
                                    Text(item.createdAt.formatted(date: .abbreviated, time: .shortened)).font(.system(size: 11)).foregroundStyle(MPColor.secondary.opacity(0.8))
                                }
                            }
                            .padding(15).background(.white, in: RoundedRectangle(cornerRadius: 16))
                        }
                        .buttonStyle(.plain).padding(.horizontal, 16)
                    }
                }
            }.padding(.vertical, 16)
        }
        .background(MPColor.page).navigationTitle("消息通知")
        .toolbar { Button { showPreferences = true } label: { Image(systemName: "slider.horizontal.3") } }
        .sheet(isPresented: $showPreferences) { NotificationPreferencesView() }
        .task { await load() }.refreshable { await load() }
    }

    private func notificationImage(_ type: String) -> String {
        if type.localizedCaseInsensitiveContains("HOMEWORK") { return "file-red" }
        if type.localizedCaseInsensitiveContains("HOUR") { return "time-blue" }
        return "notice"
    }

    @MainActor private func load() async { items = (try? await ClassTraceRepository(client: dependencies.client).notifications()) ?? [] }
    @MainActor private func markRead(_ item: APINotification) async {
        if item.readAt == nil { _ = try? await ClassTraceRepository(client: dependencies.client).markNotificationRead(item.id); await load() }
    }
    @MainActor private func markAllRead() async {
        _ = try? await ClassTraceRepository(client: dependencies.client).markAllNotificationsRead(); await load()
    }
}

private struct NotificationPreferencesView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AppDependencies.self) private var dependencies
    @State private var preferences: [APINotificationPreference] = []

    var body: some View {
        NavigationStack {
            List {
                Section("接收范围") {
                    if preferences.isEmpty { Text("当前使用系统默认提醒设置").foregroundStyle(MPColor.secondary) }
                    ForEach(preferences) { preference in
                        Toggle(preference.eventType.localizedStatus, isOn: Binding(
                            get: { preference.enabled },
                            set: { enabled in Task { await update(preference, enabled: enabled) } }
                        ))
                    }
                }
                Section { Text("系统通知权限需要在 iPhone 设置中允许；应用内可分别关闭各类提醒。") }
            }
            .navigationTitle("通知设置")
            .toolbar { Button("完成") { dismiss() } }
            .task { await load() }
        }
    }

    @MainActor private func load() async { preferences = (try? await ClassTraceRepository(client: dependencies.client).notificationPreferences()) ?? [] }
    @MainActor private func update(_ item: APINotificationPreference, enabled: Bool) async {
        _ = try? await ClassTraceRepository(client: dependencies.client).setNotificationPreference(eventType: item.eventType, channel: item.channel, enabled: enabled)
        await load()
    }
}

struct BusinessOverviewView: View {
    @Environment(AppDependencies.self) private var dependencies
    @Environment(AppSession.self) private var session
    @State private var selectedMonth = Date()
    @State private var classrooms: [APIClassroom] = []
    @State private var sessions: [APISession] = []
    @State private var overview: APIBusinessOverview?

    private var isTeacher: Bool { session.activeRole == "TEACHER" }
    private var completed: [APISession] { sessions.filter { ["COMPLETED", "CONFIRMED"].contains($0.status) } }
    private var pending: [APISession] { sessions.filter { !["COMPLETED", "CONFIRMED", "CANCELLED"].contains($0.status) } }
    private var expectedRevenue: Double { sessions.reduce(0) { $0 + revenue(for: $1) } }
    private var confirmedRevenue: Double { completed.reduce(0) { $0 + revenue(for: $1) } }
    private var completion: Double { sessions.isEmpty ? 0 : Double(completed.count) / Double(sessions.count) }

    var body: some View {
        ScrollView(showsIndicators: false) {
            LazyVStack(spacing: 16) {
                monthHeader
                hero
                metrics
                executionCard
                compositionCard
                studentSplitCard
                analysisCard
                sourceCard
            }.padding(.bottom, 28)
        }
        .background(MPColor.page).toolbar(.hidden, for: .navigationBar)
        .task(id: selectedMonth) { await load() }.refreshable { await load() }
    }

    private var monthHeader: some View {
        ZStack {
            MPColor.blue
            HStack {
                VStack(alignment: .leading, spacing: 5) {
                    Text(isTeacher ? "经营看板" : "开销看板").font(.system(size: 24, weight: .bold))
                    Text(isTeacher ? "排课、人次和预计收入" : "课程、课时和预计开销").font(.system(size: 13)).opacity(0.8)
                }
                Spacer()
                DatePicker("", selection: $selectedMonth, displayedComponents: .date)
                    .labelsHidden().tint(.white).colorScheme(.dark)
            }
            .foregroundStyle(.white).padding(.horizontal, 20).padding(.top, 20)
        }.frame(height: 126).clipShape(UnevenRoundedRectangle(bottomLeadingRadius: 24, bottomTrailingRadius: 24))
    }

    private var hero: some View {
        MPCard {
            VStack(alignment: .leading, spacing: 14) {
                HStack { Text(isTeacher ? "本月已确认收入" : "本月已确认开销").font(.system(size: 13)).foregroundStyle(MPColor.secondary); Spacer(); Text("按已确认课节统计").font(.system(size: 11)).foregroundStyle(MPColor.secondary) }
                Text(confirmedRevenue.money).font(.system(size: 34, weight: .bold)).foregroundStyle(MPColor.text)
                HStack {
                    heroMetric("预计总额", expectedRevenue.money)
                    heroMetric("待确认", (expectedRevenue - confirmedRevenue).money)
                    heroMetric("完成进度", "\(Int(completion * 100))%")
                }
                ProgressView(value: completion).tint(MPColor.blue)
            }
        }.padding(.horizontal, 16).offset(y: -22).padding(.bottom, -22)
    }

    private func heroMetric(_ title: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) { Text(title).font(.system(size: 11)).foregroundStyle(MPColor.secondary); Text(value).font(.system(size: 14, weight: .semibold)).foregroundStyle(MPColor.text) }.frame(maxWidth: .infinity, alignment: .leading)
    }

    private var metrics: some View {
        HStack(spacing: 12) {
            MPCard { metricBlock("\(Set(classrooms.flatMap { ($0.members ?? []).map(\.studentId) }).count)", isTeacher ? "授课学生" : "学习成员", "\(classrooms.count) 个班级") }
            MPCard { metricBlock("\(completed.count)/\(sessions.count)", "已确认/已排课节", "完成率 \(Int(completion * 100))%") }
        }.padding(.horizontal, 16)
    }

    private func metricBlock(_ value: String, _ label: String, _ sub: String) -> some View {
        VStack(alignment: .leading, spacing: 5) { Text(value).font(.system(size: 24, weight: .bold)).foregroundStyle(MPColor.text); Text(label).font(.system(size: 13)).foregroundStyle(MPColor.text); Text(sub).font(.system(size: 11)).foregroundStyle(MPColor.secondary) }
    }

    private var executionCard: some View {
        sectionCard("上课执行", note: "本月排课完成情况") {
            HStack(spacing: 22) {
                Gauge(value: completion) { Text("完成") } currentValueLabel: { Text("\(Int(completion * 100))%").font(.system(size: 18, weight: .bold)) }
                    .gaugeStyle(.accessoryCircularCapacity).tint(MPColor.blue).frame(width: 90, height: 90)
                VStack(spacing: 10) {
                    executionLine("已确认课节", "\(completed.count)")
                    executionLine("已排课节", "\(sessions.count)")
                    executionLine("平均单节", sessions.isEmpty ? "¥0" : (expectedRevenue / Double(sessions.count)).money)
                }
            }
        }
    }

    private func executionLine(_ title: String, _ value: String) -> some View { HStack { Text(title).font(.system(size: 12)).foregroundStyle(MPColor.secondary); Spacer(); Text(value).font(.system(size: 14, weight: .semibold)).foregroundStyle(MPColor.text) } }

    private var compositionCard: some View {
        sectionCard(isTeacher ? "收入构成" : "开销构成", note: "按班级统计") {
            if classrooms.isEmpty { MPEmptyView(image: "bar chart-orange", title: "暂无可统计数据", detail: "完成排课后将按班级形成统计") }
            else {
                VStack(spacing: 14) {
                    ForEach(classrooms) { classroom in
                        let classSessions = sessions.filter { $0.classId == classroom.id }
                        let amount = classSessions.reduce(0) { $0 + revenue(for: $1) }
                        VStack(spacing: 7) {
                            HStack { Text(classroom.name).font(.system(size: 14, weight: .semibold)); Spacer(); Text(amount.money).font(.system(size: 14, weight: .bold)) }
                            ProgressView(value: expectedRevenue == 0 ? 0 : amount / expectedRevenue).tint(MPColor.blue)
                            HStack { Text("\(classSessions.count) 节 · 已确认 \(classSessions.filter { ["COMPLETED", "CONFIRMED"].contains($0.status) }.count) 节"); Spacer() }.font(.system(size: 11)).foregroundStyle(MPColor.secondary)
                        }
                    }
                }
            }
        }
    }

    private var studentSplitCard: some View {
        let members = classrooms.flatMap { $0.members ?? [] }
        let prepaid = members.filter { $0.remainingHours.doubleValue > 0 }.count
        let low = members.filter { $0.remainingHours.doubleValue > 0 && $0.remainingHours.doubleValue <= 3 }.count
        return sectionCard("学员结构", note: "按课时余额统计") {
            HStack {
                splitMetric(prepaid, "预付课时")
                splitMetric(max(0, members.count - prepaid), "单次结算")
                splitMetric(low, "低课时预警", attention: low > 0)
            }
            if low > 0 { NavigationLink("查看低课时学员") { HourArchiveView() }.font(.system(size: 13, weight: .semibold)).foregroundStyle(MPColor.red).padding(.top, 10) }
        }
    }

    private func splitMetric(_ value: Int, _ title: String, attention: Bool = false) -> some View {
        VStack(spacing: 5) { Text("\(value)").font(.system(size: 22, weight: .bold)).foregroundStyle(attention ? MPColor.red : MPColor.text); Text(title).font(.system(size: 11)).foregroundStyle(MPColor.secondary) }.frame(maxWidth: .infinity)
    }

    private var analysisCard: some View {
        sectionCard("经营提示", note: "按真实数据生成") {
            VStack(alignment: .leading, spacing: 12) {
                analysisLine("本月已确认 \(completed.count) 节，尚有 \(pending.count) 节待确认。")
                analysisLine(completion >= 0.8 ? "排课确认进度良好，请继续保持。" : "还有较多课程未确认，建议及时补录考勤。")
                if classrooms.flatMap({ $0.members ?? [] }).contains(where: { $0.remainingHours.doubleValue <= 3 }) { analysisLine("存在低课时学员，建议提前沟通续费安排。") }
            }
        }
    }

    private func analysisLine(_ text: String) -> some View { HStack(alignment: .top, spacing: 9) { Circle().fill(MPColor.blue).frame(width: 6, height: 6).padding(.top, 6); Text(text).font(.system(size: 13)).foregroundStyle(MPColor.text) } }

    private var sourceCard: some View {
        MPCard { VStack(alignment: .leading, spacing: 7) { Text("数据口径").font(.system(size: 14, weight: .semibold)); Text("金额 = 已排/已确认学生人次 × 班级单次课费"); Text("平台仅记录双方确认的教学账单，不代收或保管课费。") }.font(.system(size: 11)).foregroundStyle(MPColor.secondary) }.padding(.horizontal, 16)
    }

    private func sectionCard<Content: View>(_ title: String, note: String, @ViewBuilder content: () -> Content) -> some View {
        MPCard { VStack(alignment: .leading, spacing: 16) { HStack { Text(title).font(.system(size: 17, weight: .bold)); Spacer(); Text(note).font(.system(size: 11)).foregroundStyle(MPColor.secondary) }; content() } }.padding(.horizontal, 16)
    }

    private func revenue(for item: APISession) -> Double {
        guard let classroom = classrooms.first(where: { $0.id == item.classId }) else { return 0 }
        let price = classroom.priceSettings?.price.doubleValue ?? classroom.members?.first?.pricePerHour.doubleValue ?? 0
        let people = max(1, item.attendances?.filter { $0.status != "ABSENT" }.count ?? classroom.members?.count ?? 1)
        return price * Double(people)
    }

    @MainActor private func load() async {
        let calendar = Calendar.current
        let interval = calendar.dateInterval(of: .month, for: selectedMonth)
        let repository = ClassTraceRepository(client: dependencies.client)
        async let classroomRequest = try? repository.classes()
        async let sessionRequest = try? repository.sessions(from: interval?.start, to: interval?.end)
        async let overviewRequest = try? repository.businessOverview(from: interval?.start, to: interval?.end)
        classrooms = (await classroomRequest) ?? []
        sessions = (await sessionRequest) ?? []
        overview = await overviewRequest
    }
}

struct PointsCenterView: View {
    @Environment(AppDependencies.self) private var dependencies
    @State private var points: APIPoints?

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                ZStack {
                    LinearGradient(colors: [MPColor.gold, MPColor.coral], startPoint: .topLeading, endPoint: .bottomTrailing)
                    HStack {
                        VStack(alignment: .leading, spacing: 8) { Text("总积分").font(.system(size: 13)); Text("\(points?.balance ?? 0)").font(.system(size: 38, weight: .bold)); Text("坚持学习与完成任务可获得积分").font(.system(size: 12)).opacity(0.85) }
                        Spacer(); MPLegacyImage(name: "points-red", size: 64)
                    }.foregroundStyle(.white).padding(22)
                }.frame(height: 150).clipShape(RoundedRectangle(cornerRadius: 20)).padding(.horizontal, 16)

                VStack(spacing: 12) {
                    MPSectionHeader(title: "积分明细")
                    if points?.entries.isEmpty != false { MPCard { MPEmptyView(image: "points-red", title: "暂无积分记录", detail: "打卡、提交作业或上课后可获得积分") } }
                    else { ForEach(points?.entries ?? []) { entry in pointRow(entry) } }
                }.padding(.horizontal, 16)
            }.padding(.vertical, 16)
        }.background(MPColor.page).navigationTitle("我的积分").task { await load() }.refreshable { await load() }
    }

    private func pointRow(_ entry: APIPointEntry) -> some View {
        HStack(spacing: 12) {
            MPIconTile(image: entry.delta >= 0 ? "points-red" : "bill-red", color: entry.delta >= 0 ? MPColor.gold : MPColor.red, size: 42)
            VStack(alignment: .leading, spacing: 4) { Text(entry.reason).font(.system(size: 14, weight: .medium)); Text(entry.createdAt.formatted(date: .abbreviated, time: .shortened)).font(.system(size: 11)).foregroundStyle(MPColor.secondary) }
            Spacer(); Text("\(entry.delta >= 0 ? "+" : "")\(entry.delta)").font(.system(size: 16, weight: .bold)).foregroundStyle(entry.delta >= 0 ? MPColor.green : MPColor.red)
        }.padding(14).background(.white, in: RoundedRectangle(cornerRadius: 15))
    }

    @MainActor private func load() async { points = try? await ClassTraceRepository(client: dependencies.client).points() }
}

struct FeedbackCenterView: View {
    @Environment(AppDependencies.self) private var dependencies
    @State private var category = "功能异常"
    @State private var content = ""
    @State private var contact = ""
    @State private var attachments: [URL] = []
    @State private var showImporter = false
    @State private var submitting = false
    @State private var submitted = false
    @State private var history: [APIFeedback] = []
    private let categories = ["功能异常", "功能建议", "界面体验", "账号问题", "其他"]

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                if submitted { successCard }
                MPCard {
                    VStack(alignment: .leading, spacing: 16) {
                        Text("反馈类型").font(.system(size: 16, weight: .bold))
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 92))], spacing: 10) {
                            ForEach(categories, id: \.self) { item in Button(item) { category = item }.font(.system(size: 13, weight: .medium)).foregroundStyle(category == item ? .white : MPColor.text).padding(.vertical, 10).frame(maxWidth: .infinity).background(category == item ? MPColor.blue : MPColor.page, in: RoundedRectangle(cornerRadius: 10)) }
                        }
                        Text("问题描述").font(.system(size: 16, weight: .bold))
                        ZStack(alignment: .bottomTrailing) {
                            TextEditor(text: $content).frame(minHeight: 150).padding(8).background(MPColor.page, in: RoundedRectangle(cornerRadius: 12)).onChange(of: content) { _, value in if value.count > 500 { content = String(value.prefix(500)) } }
                            Text("\(content.count)/500").font(.system(size: 11)).foregroundStyle(MPColor.secondary).padding(12)
                        }
                        Text("图片或文件").font(.system(size: 16, weight: .bold))
                        Button { showImporter = true } label: { Label("添加附件", systemImage: "paperclip").font(.system(size: 14, weight: .semibold)).foregroundStyle(MPColor.blue).frame(maxWidth: .infinity).padding(13).background(MPColor.blue.opacity(0.1), in: RoundedRectangle(cornerRadius: 12)) }
                        ForEach(attachments, id: \.self) { url in HStack { Image(systemName: "doc.fill").foregroundStyle(MPColor.blue); Text(url.lastPathComponent).font(.system(size: 12)).lineLimit(1); Spacer(); Button { attachments.removeAll { $0 == url } } label: { Image(systemName: "xmark.circle.fill").foregroundStyle(MPColor.secondary) } } }
                        TextField("联系方式（选填）", text: $contact).textFieldStyle(.roundedBorder)
                        Button { Task { await submit() } } label: { if submitting { ProgressView().tint(.white) } else { Text("提交反馈").fontWeight(.semibold) } }.frame(maxWidth: .infinity).padding(14).foregroundStyle(.white).background(content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? MPColor.secondary : MPColor.blue, in: RoundedRectangle(cornerRadius: 12)).disabled(submitting || content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                }.padding(.horizontal, 16)
                if !history.isEmpty { feedbackHistory }
            }.padding(.vertical, 16)
        }
        .background(MPColor.page).navigationTitle("问题反馈")
        .fileImporter(isPresented: $showImporter, allowedContentTypes: [.image, .pdf, .plainText, .data], allowsMultipleSelection: true) { result in if case let .success(urls) = result { attachments = Array((attachments + urls).prefix(6)) } }
        .task { await loadHistory() }
    }

    private var successCard: some View { MPCard { HStack(spacing: 12) { Image(systemName: "checkmark.circle.fill").font(.system(size: 30)).foregroundStyle(MPColor.green); VStack(alignment: .leading) { Text("反馈已提交").font(.system(size: 16, weight: .bold)); Text("我们会尽快查看并处理").font(.system(size: 12)).foregroundStyle(MPColor.secondary) } } }.padding(.horizontal, 16) }
    private var feedbackHistory: some View { VStack(spacing: 12) { MPSectionHeader(title: "历史反馈"); ForEach(history.prefix(5)) { item in MPCard { VStack(alignment: .leading, spacing: 7) { HStack { Text(item.category).font(.system(size: 14, weight: .bold)); Spacer(); Text(item.status.localizedStatus).font(.system(size: 11)).foregroundStyle(MPColor.blue) }; Text(item.content).font(.system(size: 13)).lineLimit(3); if let reply = item.reply { Text("回复：\(reply)").font(.system(size: 12)).foregroundStyle(MPColor.green) } } } } }.padding(.horizontal, 16) }

    @MainActor private func loadHistory() async { history = (try? await ClassTraceRepository(client: dependencies.client).feedback()) ?? [] }
    @MainActor private func submit() async {
        submitting = true; defer { submitting = false }
        let names = attachments.map(\.lastPathComponent)
        let body = names.isEmpty ? content : content + "\n附件：" + names.joined(separator: "、")
        if (try? await ClassTraceRepository(client: dependencies.client).submitFeedback(category: category, content: body, contact: contact.isEmpty ? nil : contact)) != nil {
            submitted = true; content = ""; contact = ""; attachments = []; await loadHistory()
        }
    }
}

struct MiniProgramAboutView: View {
    @State private var copied: String?
    private let wechat = "ClassTrace_2024"
    private let email = "508772359@qq.com"

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                ZStack {
                    LinearGradient(colors: [MPColor.blue, MPColor.green], startPoint: .topLeading, endPoint: .bottomTrailing)
                    VStack(spacing: 10) { MPLegacyImage(name: "icon", size: 76); Text("课迹 ClassTrace").font(.system(size: 24, weight: .bold)); Text("版本 \(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0")").font(.system(size: 12)); Text("让每一次教学都有迹可循").font(.system(size: 13)).opacity(0.85) }.foregroundStyle(.white)
                }.frame(height: 220).clipShape(UnevenRoundedRectangle(bottomLeadingRadius: 26, bottomTrailingRadius: 26))
                section("功能特色") {
                    feature("class-blue", "班级与排课", "按固定时间、指定日期或日程快速创建课程")
                    feature("time-blue", "课时与考勤", "记录课时余额、上课确认和学生出勤")
                    feature("bar chart-orange", "经营数据", "按月查看已确认和待确认的教学数据")
                    feature("file-red", "作业与资料", "统一管理作业、学习计划与班级资料")
                }
                section("联系我们") {
                    contactRow("feedback-green", "客服微信", wechat)
                    contactRow("feedback-blue", "联系邮箱", email)
                    if let copied { Text("已复制：\(copied)").font(.system(size: 11)).foregroundStyle(MPColor.green) }
                }
                section("协议与隐私") {
                    NavigationLink("隐私政策") { AboutLegalView(title: "隐私政策", text: "课迹仅为提供登录、教学管理、消息提醒、资料存储、账单记录和 VIP 权益所必需而处理相关信息。数据不会用于跨应用跟踪或广告，您可以在账号设置中申请导出或注销账号。") }
                    Divider()
                    NavigationLink("用户协议") { AboutLegalView(title: "用户协议", text: "课迹是教师与家长的教学管理工具。教学课费默认由双方通过外部渠道直接结算，平台只记录双方确认的账单与履约信息，不保管教学资金。VIP 数字权益通过 App Store 购买。") }
                }
                Text("© 2026 ClassTrace · 让教学管理更简单").font(.system(size: 11)).foregroundStyle(MPColor.secondary).padding(.vertical, 12)
            }.padding(.bottom, 24)
        }.background(MPColor.page).toolbar(.hidden, for: .navigationBar)
    }

    private func section<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View { VStack(spacing: 12) { MPSectionHeader(title: title); MPCard { VStack(spacing: 12) { content() } } }.padding(.horizontal, 16) }
    private func feature(_ image: String, _ title: String, _ detail: String) -> some View { HStack(spacing: 12) { MPIconTile(image: image, color: MPColor.blue, size: 42); VStack(alignment: .leading, spacing: 3) { Text(title).font(.system(size: 14, weight: .semibold)); Text(detail).font(.system(size: 11)).foregroundStyle(MPColor.secondary) }; Spacer() } }
    private func contactRow(_ image: String, _ label: String, _ value: String) -> some View { Button { UIPasteboard.general.string = value; copied = value } label: { HStack(spacing: 12) { MPLegacyImage(name: image, size: 24); Text(label).foregroundStyle(MPColor.text); Spacer(); Text(value).font(.system(size: 12)).foregroundStyle(MPColor.secondary); Text("复制").font(.system(size: 12, weight: .semibold)).foregroundStyle(MPColor.blue) } }.buttonStyle(.plain) }
}

private struct AboutLegalView: View {
    let title: String
    let text: String
    var body: some View { ScrollView { Text(text).font(.system(size: 15)).lineSpacing(8).frame(maxWidth: .infinity, alignment: .leading).padding(20) }.navigationTitle(title) }
}

private extension Double {
    var money: String { formatted(.currency(code: "CNY").precision(.fractionLength(0...2))) }
}
