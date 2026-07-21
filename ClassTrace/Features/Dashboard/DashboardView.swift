import SwiftUI

struct DashboardView: View {
    @Binding var selectedTab: Int
    @Environment(AppDependencies.self) private var dependencies
    @Environment(AppSession.self) private var session
    @State private var home: APIHome?
    @State private var business: APIBusinessOverview?
    @State private var errorMessage: String?
    @State private var showSchedule = false

    var body: some View {
        ScrollView(showsIndicators: false) {
            LazyVStack(spacing: 22) {
                MPPageHeader(greeting: greeting, name: session.user?.displayName ?? "课迹用户") {
                    NavigationLink { NotificationCenterView() } label: {
                        ZStack(alignment: .topTrailing) {
                            MPLegacyImage(name: "notice", size: 27)
                            if (home?.unreadNotificationCount ?? 0) > 0 {
                                Text("\(min(home?.unreadNotificationCount ?? 0, 99))")
                                    .font(.system(size: 9, weight: .bold)).foregroundStyle(.white)
                                    .frame(minWidth: 17, minHeight: 17).background(MPColor.red, in: Circle()).offset(x: 7, y: -7)
                            }
                        }.frame(width: 42, height: 42).background(.white.opacity(0.18), in: Circle())
                    }
                }

                if let errorMessage {
                    MPCard { MPEmptyView(image: "null", title: "加载失败", detail: errorMessage) }
                } else if let home {
                    reminderSection(home)
                    quickAccess
                    classesSection(home)
                    if let business { businessSection(business) }
                } else {
                    ProgressView().tint(MPColor.blue).padding(.vertical, 80)
                }
            }.padding(.bottom, 22)
        }
        .background(MPColor.page).toolbar(.hidden, for: .navigationBar)
        .navigationDestination(isPresented: $showSchedule) { ScheduleCalendarView() }
        .refreshable { await load() }.task { if home == nil { await load() } }
    }

    private var greeting: String {
        let hour = Calendar.current.component(.hour, from: Date())
        return hour < 11 ? "早上好" : (hour < 18 ? "下午好" : "晚上好")
    }

    private func reminderSection(_ home: APIHome) -> some View {
        VStack(spacing: 12) {
            MPSectionHeader(title: "近期提醒", action: "查看全部") { showSchedule = true }
            MPCard {
                VStack(spacing: 0) {
                    ForEach(home.sessions.prefix(3)) { session in
                        reminderRow(image: "time-blue", color: MPColor.blue, title: session.classroom?.name ?? "课程提醒", detail: session.startsAt.formatted(date: .abbreviated, time: .shortened), status: session.status.localizedStatus)
                    }
                    ForEach(home.homework.prefix(2)) { item in
                        reminderRow(image: "file-red", color: MPColor.red, title: item.title, detail: item.dueAt.map { "截止时间 \($0.formatted(date: .abbreviated, time: .shortened))" } ?? "待完成", status: nil)
                    }
                    if home.sessions.isEmpty && home.homework.isEmpty {
                        MPEmptyView(image: "time", title: "近期没有待办", detail: "新的课程与作业提醒会显示在这里")
                    }
                }
            }
        }.padding(.horizontal, 16)
    }

    private func reminderRow(image: String, color: Color, title: String, detail: String, status: String?) -> some View {
        HStack(spacing: 12) {
            MPIconTile(image: image, color: color, size: 44)
            VStack(alignment: .leading, spacing: 5) {
                HStack { Text(title).font(.system(size: 15, weight: .semibold)).foregroundStyle(MPColor.text); Spacer(); if let status { Text(status).font(.system(size: 11, weight: .medium)).foregroundStyle(color).padding(.horizontal, 8).padding(.vertical, 4).background(color.opacity(0.12), in: Capsule()) } }
                Text(detail).font(.system(size: 12)).foregroundStyle(MPColor.secondary)
            }
        }.padding(.vertical, 10).overlay(alignment: .bottom) { Rectangle().fill(Color.black.opacity(0.045)).frame(height: 0.5) }
    }

    private var quickAccess: some View {
        VStack(spacing: 12) {
            MPSectionHeader(title: "快捷入口")
            MPCard {
                HStack(alignment: .top, spacing: 4) {
                    quickLink("课表", "timetable-blue", MPColor.blue) { ScheduleCalendarView() }
                    quickLink("学生", "student-green", MPColor.green) { ClassroomHubView() }
                    quickLink("作业", "file-red", MPColor.red) { LearningHubView(initialSelection: 0) }
                    quickLink("资料", "material-brown", MPColor.gold) { LearningHubView(initialSelection: 1) }
                }
            }
        }.padding(.horizontal, 16)
    }

    private func quickLink<Destination: View>(_ title: String, _ image: String, _ color: Color, @ViewBuilder destination: () -> Destination) -> some View {
        NavigationLink(destination: destination()) {
            VStack(spacing: 8) { MPIconTile(image: image, color: color, size: 50); Text(title).font(.system(size: 13)).foregroundStyle(MPColor.text) }
                .frame(maxWidth: .infinity)
        }.buttonStyle(.plain)
    }

    private func classesSection(_ home: APIHome) -> some View {
        VStack(spacing: 12) {
            MPSectionHeader(title: "我的课程", action: "查看全部") { selectedTab = 1 }
            if home.sessions.isEmpty {
                MPCard { MPEmptyView(image: "class", title: "还没有课程", detail: "创建或加入课程后会显示在这里") }
            } else {
                ForEach(home.sessions.prefix(3)) { item in
                    MPCard {
                        HStack(spacing: 13) {
                            MPIconTile(image: "class-blue", color: MPColor.blue, size: 52)
                            VStack(alignment: .leading, spacing: 6) {
                                Text(item.classroom?.name ?? "课程").font(.system(size: 16, weight: .semibold)).foregroundStyle(MPColor.text)
                                Text(item.startsAt.formatted(date: .abbreviated, time: .shortened)).font(.system(size: 12)).foregroundStyle(MPColor.secondary)
                            }
                            Spacer(); Image(systemName: "chevron.right").font(.caption.bold()).foregroundStyle(MPColor.secondary)
                        }
                    }
                }
            }
        }.padding(.horizontal, 16)
    }

    private func businessSection(_ item: APIBusinessOverview) -> some View {
        VStack(spacing: 12) {
            MPSectionHeader(title: "经营概览")
            MPCard {
                HStack {
                    metric("进行中班级", "\(item.activeClassCount)")
                    divider
                    metric("已完成课节", "\(item.completedSessionCount)")
                    divider
                    metric("记录收入", item.recordedRevenueCents.formattedCompactCurrency)
                }
            }
        }.padding(.horizontal, 16)
    }

    private func metric(_ title: String, _ value: String) -> some View {
        VStack(spacing: 5) { Text(value).font(.system(size: 18, weight: .bold)).foregroundStyle(MPColor.text); Text(title).font(.system(size: 11)).foregroundStyle(MPColor.secondary) }.frame(maxWidth: .infinity)
    }
    private var divider: some View { Rectangle().fill(Color.black.opacity(0.07)).frame(width: 0.5, height: 40) }

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

private extension Int {
    var formattedCompactCurrency: String { "¥" + (Double(self) / 100).formatted(.number.precision(.fractionLength(0))) }
}

extension String { var localizedStatus: String { ["SCHEDULED":"待上课","COMPLETED":"已完成","CANCELLED":"已取消","RESCHEDULED":"已调课","ACTIVE":"进行中","PAUSED":"已暂停","PENDING":"待审批","APPROVED":"已加入","PUBLISHED":"已发布","DRAFT":"草稿","TEACHER":"教师","GUARDIAN":"家长","ADMIN":"管理员","PAID":"已支付","PROCESSING":"处理中","REQUESTED":"待处理","REFUNDED":"已退款","REJECTED":"已拒绝","DIRECT_FULL":"课费直收" ][self] ?? self } }
