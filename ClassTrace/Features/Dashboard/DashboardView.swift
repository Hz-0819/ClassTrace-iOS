import SwiftUI

struct DashboardView: View {
    @Binding var selectedTab: Int
    @Environment(AppDependencies.self) private var dependencies
    @Environment(AppSession.self) private var appSession

    @State private var home: APIHome?
    @State private var classes: [APIClassroom] = []
    @State private var notifications: [APINotification] = []
    @State private var errorMessage: String?
    @State private var showSchedule = false

    var body: some View {
        ScrollView(showsIndicators: false) {
            LazyVStack(spacing: 22) {
                MPPageHeader(greeting: greeting, name: appSession.user?.displayName ?? "课迹用户") {
                    NavigationLink { NotificationCenterView() } label: {
                        ZStack(alignment: .topTrailing) {
                            MPLegacyImage(name: "notice", size: 27)
                            if unreadCount > 0 {
                                Text(unreadCount > 99 ? "99+" : "\(unreadCount)")
                                    .font(.system(size: 9, weight: .bold))
                                    .foregroundStyle(.white)
                                    .padding(.horizontal, unreadCount > 9 ? 5 : 0)
                                    .frame(minWidth: 18, minHeight: 18)
                                    .background(MPColor.red, in: Capsule())
                                    .overlay(Capsule().stroke(.white.opacity(0.9), lineWidth: 1.5))
                                    .offset(x: 7, y: -7)
                            }
                        }
                        .frame(width: 42, height: 42)
                        .background(.white.opacity(0.18), in: Circle())
                    }
                }

                if let errorMessage {
                    MPCard { MPEmptyView(image: "null", title: "加载失败", detail: errorMessage) }
                        .padding(.horizontal, 16)
                } else if let home {
                    recentReminders(home)
                    quickAccess
                    recentSchedule(home)
                } else {
                    ProgressView().tint(MPColor.blue).padding(.vertical, 80)
                }
            }
            .padding(.bottom, 22)
        }
        .background(MPColor.page)
        .toolbar(.hidden, for: .navigationBar)
        .navigationDestination(isPresented: $showSchedule) { ScheduleCalendarView() }
        .refreshable { await load() }
        .task { if home == nil { await load() } }
    }

    private var greeting: String {
        let hour = Calendar.current.component(.hour, from: Date())
        return hour < 11 ? "早上好" : (hour < 18 ? "下午好" : "晚上好")
    }

    private var unreadCount: Int {
        max(home?.unreadNotificationCount ?? 0, notifications.filter { $0.readAt == nil }.count)
    }

    private func recentReminders(_ value: APIHome) -> some View {
        let upcoming = value.sessions
            .filter { $0.status == "SCHEDULED" || $0.status == "RESCHEDULED" }
            .sorted { $0.startsAt < $1.startsAt }
        let unread = notifications.filter { $0.readAt == nil }

        return VStack(spacing: 12) {
            MPSectionHeader(title: "近期提醒", action: "查看全部") { showSchedule = true }
            MPCard {
                VStack(spacing: 0) {
                    ForEach(upcoming.prefix(2)) { item in
                        reminderRow(
                            image: "time-blue",
                            color: MPColor.blue,
                            title: item.classroom?.name ?? classroom(item.classId)?.name ?? "课程提醒",
                            detail: item.startsAt.formatted(.dateTime.month().day().weekday(.wide).hour().minute()),
                            status: item.status.localizedStatus
                        )
                    }
                    ForEach(value.homework.filter { $0.status == "PUBLISHED" }.prefix(1)) { item in
                        reminderRow(
                            image: "file-red",
                            color: MPColor.red,
                            title: item.title,
                            detail: item.dueAt.map { "截止时间 \($0.formatted(.dateTime.month().day().hour().minute()))" } ?? "待完成",
                            status: "待完成"
                        )
                    }
                    ForEach(unread.prefix(1)) { item in
                        NavigationLink { NotificationCenterView() } label: {
                            reminderRow(image: "notice", color: MPColor.coral, title: item.title, detail: item.body, status: "未读")
                        }
                        .buttonStyle(.plain)
                    }
                    if upcoming.isEmpty && value.homework.isEmpty && unread.isEmpty {
                        MPEmptyView(image: "null", title: "近期暂无课程和任务", detail: "新的课程、作业和通知会显示在这里")
                    }
                }
            }
        }
        .padding(.horizontal, 16)
    }

    private func reminderRow(image: String, color: Color, title: String, detail: String, status: String?) -> some View {
        HStack(spacing: 12) {
            MPIconTile(image: image, color: color, size: 44)
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(title).font(.system(size: 15, weight: .semibold)).foregroundStyle(MPColor.text).lineLimit(1)
                    Spacer()
                    if let status {
                        Text(status)
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(color)
                            .padding(.horizontal, 8).padding(.vertical, 4)
                            .background(color.opacity(0.13), in: Capsule())
                    }
                }
                Text(detail).font(.system(size: 12)).foregroundStyle(MPColor.secondary).lineLimit(2)
            }
        }
        .padding(.vertical, 10)
        .overlay(alignment: .bottom) { Rectangle().fill(Color.black.opacity(0.045)).frame(height: 0.5) }
    }

    private var quickAccess: some View {
        VStack(spacing: 12) {
            MPSectionHeader(title: "快捷入口")
            MPCard {
                HStack(alignment: .top, spacing: 2) {
                    quickLink("我的课表", "timetable-blue", MPColor.blue) { ScheduleCalendarView() }
                    if appSession.activeRole == "TEACHER" {
                        quickLink("班级管理", "class-green", MPColor.green) { ClassroomDashboardView() }
                        quickLink("学生管理", "student-red", MPColor.red) { StudentDirectoryView() }
                        quickLink("课时档案", "bar chart-orange", MPColor.gold) { HourArchiveView() }
                    } else {
                        quickLink("课程管理", "class-green", MPColor.green) { ClassroomDashboardView() }
                        quickLink("作业提交", "file-red", MPColor.red) { LearningHubView(initialSelection: 0) }
                        quickLink("课时明细", "bill-green", MPColor.gold) { HourArchiveView() }
                    }
                }
            }
        }
        .padding(.horizontal, 16)
    }

    private func quickLink<Destination: View>(
        _ title: String,
        _ image: String,
        _ color: Color,
        @ViewBuilder destination: () -> Destination
    ) -> some View {
        NavigationLink(destination: destination()) {
            VStack(spacing: 8) {
                MPIconTile(image: image, color: color, size: 50)
                Text(title).font(.system(size: 12)).foregroundStyle(MPColor.text).lineLimit(1)
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
    }

    private func recentSchedule(_ value: APIHome) -> some View {
        let activeClasses = classes.filter { $0.status == "ACTIVE" }
        return VStack(spacing: 12) {
            MPSectionHeader(title: "近期排课", action: "查看全部") { showSchedule = true }
            if activeClasses.isEmpty {
                MPCard { MPEmptyView(image: "class", title: "暂无近期排课", detail: "创建班级并完成排课后会显示在这里") }
            } else {
                ForEach(activeClasses.prefix(4)) { classroom in recentClassCard(classroom, sessions: value.sessions) }
            }
        }
        .padding(.horizontal, 16)
    }

    private func recentClassCard(_ classroom: APIClassroom, sessions: [APISession]) -> some View {
        let values = sessions.filter { $0.classId == classroom.id }
        let completed = values.filter { $0.status == "COMPLETED" }.reduce(0) { $0 + $1.plannedHours.doubleValue }
        let total = classroom.members?.reduce(0) { $0 + $1.totalHours.doubleValue } ?? 0
        let progress = total > 0 ? min(completed / total, 1) : 0
        let tint = classColor(classroom)
        let next = values
            .filter { $0.startsAt >= Date() && $0.status != "CANCELLED" }
            .min { $0.startsAt < $1.startsAt }

        return NavigationLink { ClassroomDetailView(classId: classroom.id) } label: {
            ZStack(alignment: .bottomLeading) {
                Color.white
                Circle().fill(tint.opacity(0.10)).frame(width: 100, height: 100).offset(x: -45, y: 55)
                VStack(spacing: 0) {
                    HStack(spacing: 12) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 12).fill(tint)
                            MPLegacyImage(name: "book", size: 24)
                        }.frame(width: 48, height: 48).shadow(color: .black.opacity(0.10), radius: 4, y: 2)
                        VStack(alignment: .leading, spacing: 5) {
                            HStack {
                                Text(classroom.name).font(.system(size: 15, weight: .semibold)).foregroundStyle(MPColor.text)
                                Spacer()
                                MPLegacyImage(name: "right", size: 12).opacity(0.4)
                            }
                            Text("\(classroom.classType.localizedStatus) · \(classroom.members?.count ?? 0)人 · ¥\(classPrice(classroom).compactNumber)/次/人")
                                .font(.system(size: 11)).foregroundStyle(MPColor.secondary)
                        }
                    }.padding(16)

                    VStack(spacing: 6) {
                        HStack {
                            Text(classroom.billingMode == "CASH" ? "累计上课" : "课程进度")
                                .font(.system(size: 11)).foregroundStyle(MPColor.secondary)
                            Spacer()
                            Text(classroom.billingMode == "CASH"
                                 ? "\(values.filter { $0.status == "COMPLETED" }.count) 次"
                                 : "\(completed.compactNumber)/\(total.compactNumber)课时")
                                .font(.system(size: 12, weight: .semibold)).foregroundStyle(tint)
                        }
                        if classroom.billingMode != "CASH" {
                            GeometryReader { proxy in
                                ZStack(alignment: .leading) {
                                    Capsule().fill(tint.opacity(0.12))
                                    Capsule().fill(tint).frame(width: proxy.size.width * progress)
                                }
                            }.frame(height: 4)
                        }
                    }.padding(.horizontal, 16).padding(.bottom, 12)

                    HStack(spacing: 6) {
                        MPLegacyImage(name: "time", size: 14)
                        Text("下次课：\(next?.startsAt.formatted(.dateTime.month().day().weekday(.wide).hour().minute()) ?? "待安排")")
                            .font(.system(size: 11)).foregroundStyle(MPColor.secondary)
                        Spacer()
                    }
                    .padding(.horizontal, 16).padding(.vertical, 9)
                    .overlay(alignment: .top) { Rectangle().fill(Color.black.opacity(0.045)).frame(height: 0.5) }
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .shadow(color: .black.opacity(0.055), radius: 10, y: 3)
        }.buttonStyle(.plain)
    }

    private func classPrice(_ classroom: APIClassroom) -> Double {
        classroom.priceSettings?.price.doubleValue
            ?? classroom.members?.first?.pricePerHour.doubleValue
            ?? 0
    }

    private func classColor(_ classroom: APIClassroom) -> Color {
        Color.theme.fromHex(classroom.color ?? "#7BA3C0")
    }

    private func classroom(_ id: String) -> APIClassroom? { classes.first { $0.id == id } }

    @MainActor
    private func load() async {
        errorMessage = nil
        let repository = ClassTraceRepository(client: dependencies.client)
        do {
            async let homeRequest = repository.home()
            async let classesRequest = repository.classes()
            async let notificationRequest = try? repository.notifications()
            home = try await homeRequest
            classes = try await classesRequest
            notifications = await notificationRequest ?? []
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

struct SessionRow: View {
    let session: APISession
    var body: some View {
        HStack {
            VStack(alignment: .leading) {
                Text(session.classroom?.name ?? "课程").font(.headline)
                Text(session.startsAt.formatted(date: .abbreviated, time: .shortened))
                    .font(.subheadline).foregroundStyle(Color.ctTextSecondary)
            }
            Spacer()
            CTStatusBadge(
                title: LocalizedStringKey(session.status.localizedStatus),
                symbol: "circle.fill",
                color: session.status == "COMPLETED" ? .ctSuccess : .ctBrand
            )
        }
        .padding(.vertical, 4)
    }
}

private extension Int {
    var formattedCompactCurrency: String {
        "¥" + (Double(self) / 100).formatted(.number.precision(.fractionLength(0)))
    }
}

extension String {
    var localizedStatus: String {
        [
            "SCHEDULED":"待上课", "COMPLETED":"已完成", "CANCELLED":"已取消", "RESCHEDULED":"已调课",
            "ACTIVE":"进行中", "PAUSED":"已暂停", "PENDING":"待审批", "APPROVED":"已加入",
            "PUBLISHED":"已发布", "DRAFT":"草稿", "TEACHER":"教师", "GUARDIAN":"家长", "ADMIN":"管理员",
            "PAID":"已支付", "PROCESSING":"处理中", "REQUESTED":"待处理", "REFUNDED":"已退款",
            "REJECTED":"已拒绝", "DIRECT_FULL":"课费直收", "ONE_ON_ONE":"一对一", "SMALL_GROUP":"小班课",
            "PREPAID":"预付课时", "CASH":"现金记账", "PRESENT":"出勤", "LEAVE":"请假", "ABSENT":"缺席",
            "CONSUME":"课时消费", "RECHARGE":"课时充值"
        ][self] ?? self
    }
}
