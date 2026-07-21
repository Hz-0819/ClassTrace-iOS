import SwiftUI

struct DashboardView: View {
    @Environment(AppDependencies.self) private var dependencies
    @State private var home: APIHome?
    @State private var business: APIBusinessOverview?
    @State private var errorMessage: String?

    var body: some View {
        ScrollView {
            LazyVStack(spacing: CTSpacing.md) {
                if let errorMessage { CTStateView(kind: .error, title: "加载失败", message: LocalizedStringKey(errorMessage), actionTitle: "重试") { Task { await load() } } }
                if let home {
                    HStack(spacing: CTSpacing.sm) {
                        metric("今日课程", "\(home.sessions.count)", "calendar")
                        metric("未读通知", "\(home.unreadNotificationCount)", "bell")
                        metric("课时预警", "\(home.lowBalances.count)", "clock.badge.exclamationmark")
                    }
                    if !home.sessions.isEmpty { section("今日课表") { ForEach(home.sessions) { SessionRow(session: $0) } } }
                    if !home.homework.isEmpty { section("待办作业") { ForEach(home.homework.prefix(5)) { Text($0.title).frame(maxWidth: .infinity, alignment: .leading) } } }
                    if !home.announcements.isEmpty { section("公告") { ForEach(home.announcements) { Text($0.title).frame(maxWidth: .infinity, alignment: .leading) } } }
                } else if errorMessage == nil { ProgressView().padding(.top, 100) }
                if let business {
                    section("经营概览") {
                        LabeledContent("进行中班级", value: "\(business.activeClassCount)")
                        LabeledContent("已完成课节", value: "\(business.completedSessionCount)")
                        LabeledContent("记录收入", value: business.recordedRevenueCents.formattedCurrency)
                    }
                }
            }.padding()
        }
        .background(Color.ctPage).navigationTitle("课迹").refreshable { await load() }.task { if home == nil { await load() } }
    }
    private func metric(_ title: String, _ value: String, _ symbol: String) -> some View { CTCard { Image(systemName: symbol).foregroundStyle(Color.ctBrand); Text(value).font(.title2.bold()); Text(title).font(.caption).foregroundStyle(Color.ctTextSecondary) } }
    private func section<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View { CTCard { Text(title).font(.headline).padding(.bottom, 4); content() } }
    @MainActor private func load() async {
        errorMessage = nil
        let repository = ClassTraceRepository(client: dependencies.client)
        do { async let h = repository.home(); async let b = try? repository.businessOverview(); home = try await h; business = await b }
        catch { errorMessage = error.localizedDescription }
    }
}

struct SessionRow: View {
    let session: APISession
    var body: some View {
        HStack { VStack(alignment: .leading) { Text(session.classroom?.name ?? "课程").font(.headline); Text(session.startsAt.formatted(date: .abbreviated, time: .shortened)).font(.subheadline).foregroundStyle(Color.ctTextSecondary) }; Spacer(); CTStatusBadge(title: LocalizedStringKey(session.status.localizedStatus), symbol: "circle.fill", color: session.status == "COMPLETED" ? .ctSuccess : .ctBrand) }
        .padding(.vertical, 4)
    }
}

private extension Int { var formattedCurrency: String { (Double(self) / 100).formatted(.currency(code: "CNY")) } }
extension String { var localizedStatus: String { ["SCHEDULED":"待上课","COMPLETED":"已完成","CANCELLED":"已取消","RESCHEDULED":"已调课","ACTIVE":"进行中","PAUSED":"已暂停","PENDING":"待审批","APPROVED":"已加入","PUBLISHED":"已发布","DRAFT":"草稿" ][self] ?? self } }
