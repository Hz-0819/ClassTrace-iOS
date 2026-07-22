import SwiftUI

struct ClassroomDashboardView: View {
    @Environment(AppDependencies.self) private var dependencies
    @Environment(AppSession.self) private var appSession

    @State private var classes: [APIClassroom] = []
    @State private var courses: [APICourse] = []
    @State private var students: [APIStudent] = []
    @State private var sessions: [APISession] = []
    @State private var overview: APIBusinessOverview?
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var sheet: Sheet?

    private enum Sheet: Int, Identifiable {
        case createClass, joinClass
        var id: Int { rawValue }
    }

    private var isTeacher: Bool { appSession.activeRole == "TEACHER" }
    private var todaySessions: [APISession] {
        sessions.filter { Calendar.current.isDateInToday($0.startsAt) }.sorted { $0.startsAt < $1.startsAt }
    }
    private var activeClasses: [APIClassroom] { classes.filter { $0.status == "ACTIVE" } }
    private var uniqueStudents: Int {
        Set(classes.flatMap { $0.members ?? [] }.map(\.studentId)).count
    }
    private var totalHours: Double {
        sessions.filter { $0.status == "COMPLETED" }.reduce(0) { $0 + $1.plannedHours.doubleValue }
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            LazyVStack(spacing: 20) {
                titleBar

                if isLoading {
                    ProgressView().tint(MPColor.blue).padding(.vertical, 90)
                } else if let errorMessage {
                    MPCard { MPEmptyView(image: "null", title: "加载失败", detail: errorMessage) }
                        .padding(.horizontal, 16)
                } else {
                    dataBoard
                    todaySection
                    classList
                }
            }
            .padding(.bottom, 22)
        }
        .background(MPColor.page)
        .toolbar(.hidden, for: .navigationBar)
        .sheet(item: $sheet) { item in
            switch item {
            case .createClass:
                ClassEditorView(courses: courses) { await load() }
            case .joinClass:
                ParentCourseAddView(students: students) { await load() }
            }
        }
        .refreshable { await load() }
        .task { if classes.isEmpty { await load() } }
    }

    private var titleBar: some View {
        HStack {
            Text(isTeacher ? "我的班级" : "我的课程")
                .font(.system(size: 27, weight: .bold)).foregroundStyle(MPColor.text)
            Spacer()
            Menu {
                if isTeacher {
                    Button("创建班级", systemImage: "person.3.fill") { sheet = .createClass }
                    NavigationLink("学生管理", destination: StudentDirectoryView())
                    NavigationLink("课程模板", destination: ClassroomHubView())
                } else {
                    Button("添加课程", systemImage: "plus") { sheet = .joinClass }
                    NavigationLink("管理孩子", destination: ChildrenDirectoryView())
                }
            } label: {
                Image(systemName: "plus")
                    .font(.system(size: 17, weight: .bold)).foregroundStyle(.white)
                    .frame(width: 42, height: 42).background(MPColor.blue, in: Circle())
                    .shadow(color: MPColor.blue.opacity(0.25), radius: 8, y: 3)
            }
        }
        .padding(.horizontal, 18).padding(.top, 14)
    }

    private var dataBoard: some View {
        VStack(spacing: 12) {
            MPSectionHeader(title: "数据看板")
            MPCard {
                HStack {
                    metric(isTeacher ? "班级" : "在读课程", "\(activeClasses.count)")
                    divider
                    metric(isTeacher ? "学生人数" : "已完成课时", isTeacher ? "\(uniqueStudents)" : totalHours.compactNumber)
                    divider
                    metric(isTeacher ? "累计课时" : "累计学习天数", isTeacher ? totalHours.compactNumber : "\(studyDays)")
                }
            }
        }
        .padding(.horizontal, 16)
    }

    private var studyDays: Int {
        Set(sessions.filter { $0.status == "COMPLETED" }.map {
            Calendar.current.startOfDay(for: $0.startsAt)
        }).count
    }

    private func metric(_ label: String, _ value: String) -> some View {
        VStack(spacing: 6) {
            Text(value).font(.system(size: 23, weight: .bold)).foregroundStyle(MPColor.blue)
            Text(label).font(.system(size: 11)).foregroundStyle(MPColor.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    private var divider: some View {
        Rectangle().fill(Color.black.opacity(0.07)).frame(width: 0.5, height: 42)
    }

    private var todaySection: some View {
        VStack(spacing: 12) {
            MPSectionHeader(title: "今日课程")
                .overlay(alignment: .trailing) {
                    NavigationLink { ScheduleCalendarView() } label: {
                        HStack(spacing: 3) {
                            Text("查看更多")
                            MPLegacyImage(name: "right-blue", size: 12)
                        }
                        .font(.system(size: 13)).foregroundStyle(MPColor.blue)
                    }
                }

            if todaySessions.isEmpty {
                MPCard { MPEmptyView(image: "null", title: "今日暂无课程", detail: "可以在日程中添加临时课次") }
            } else {
                MPCard {
                    VStack(spacing: 0) {
                        ForEach(todaySessions) { item in
                            NavigationLink { SessionDetailView(sessionId: item.id) } label: {
                                HStack(spacing: 14) {
                                    VStack(spacing: 3) {
                                        Text(item.startsAt.formatted(date: .omitted, time: .shortened))
                                            .font(.system(size: 14, weight: .semibold)).foregroundStyle(MPColor.text)
                                        Rectangle().fill(MPColor.blue.opacity(0.45)).frame(width: 1, height: 13)
                                        Text(item.endsAt.formatted(date: .omitted, time: .shortened))
                                            .font(.system(size: 12)).foregroundStyle(MPColor.secondary)
                                    }
                                    .frame(width: 58)

                                    VStack(alignment: .leading, spacing: 5) {
                                        Text(item.classroom?.name ?? classroom(item.classId)?.name ?? "课程")
                                            .font(.system(size: 15, weight: .semibold)).foregroundStyle(MPColor.text)
                                        Text(todayDetail(item))
                                            .font(.system(size: 11)).foregroundStyle(MPColor.secondary)
                                        Text(attendanceSummary(item))
                                            .font(.system(size: 11)).foregroundStyle(item.status == "COMPLETED" ? MPColor.green : MPColor.gold)
                                    }
                                    Spacer()
                                    Text(item.status == "COMPLETED" ? "已确认" : "确认上课")
                                        .font(.system(size: 11, weight: .semibold))
                                        .foregroundStyle(item.status == "COMPLETED" ? MPColor.green : .white)
                                        .padding(.horizontal, 10).padding(.vertical, 7)
                                        .background(item.status == "COMPLETED" ? MPColor.green.opacity(0.12) : MPColor.blue, in: Capsule())
                                }
                                .padding(.vertical, 12)
                                .overlay(alignment: .bottom) { Rectangle().fill(Color.black.opacity(0.045)).frame(height: 0.5) }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
        }
        .padding(.horizontal, 16)
    }

    private var classList: some View {
        VStack(spacing: 12) {
            MPSectionHeader(title: "进行中的\(isTeacher ? "班级" : "课程")（\(activeClasses.count)）")
            if activeClasses.isEmpty {
                MPCard {
                    MPEmptyView(
                        image: "class",
                        title: isTeacher ? "暂无班级" : "暂无课程",
                        detail: isTeacher ? "点击右上角创建班级" : "使用邀请码或手动添加课程"
                    )
                }
            } else {
                ForEach(activeClasses) { item in classCard(item) }
            }
        }
        .padding(.horizontal, 16)
    }

    private func classCard(_ item: APIClassroom) -> some View {
        let completed = completedHours(item)
        let total = max(item.members?.reduce(0) { $0 + $1.totalHours.doubleValue } ?? 0, 0)
        let progress = total > 0 ? min(completed / total, 1) : 0

        return NavigationLink { ClassroomDetailView(classId: item.id) } label: {
            MPCard {
                VStack(spacing: 14) {
                    HStack(spacing: 13) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 14).fill(classColor(item))
                            MPLegacyImage(name: "book", size: 28)
                        }
                        .frame(width: 54, height: 54)
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Text(item.name).font(.system(size: 17, weight: .semibold)).foregroundStyle(MPColor.text)
                                Spacer(); MPLegacyImage(name: "right", size: 14).opacity(0.45)
                            }
                            Text("\(item.classType.localizedStatus) · \(item.members?.count ?? 0)人 · ¥\(price(item).compactNumber)/次/人")
                                .font(.system(size: 12)).foregroundStyle(MPColor.secondary)
                        }
                    }

                    if item.billingMode == "PREPAID" {
                        VStack(spacing: 7) {
                            HStack {
                                Text("课程进度").font(.system(size: 12)).foregroundStyle(MPColor.secondary)
                                Spacer()
                                Text("\(completed.compactNumber)/\(total.compactNumber)课时")
                                    .font(.system(size: 12, weight: .semibold)).foregroundStyle(classColor(item))
                            }
                            GeometryReader { proxy in
                                ZStack(alignment: .leading) {
                                    Capsule().fill(classColor(item).opacity(0.13))
                                    Capsule().fill(classColor(item)).frame(width: proxy.size.width * progress)
                                }
                            }
                            .frame(height: 7)
                        }
                    } else {
                        HStack {
                            Text("累计上课").font(.system(size: 12)).foregroundStyle(MPColor.secondary)
                            Spacer(); Text("\(classSessions(item.id).filter { $0.status == "COMPLETED" }.count) 次").font(.system(size: 12, weight: .semibold)).foregroundStyle(classColor(item))
                        }
                    }

                    HStack {
                        MPLegacyImage(name: "time", size: 15)
                        Text("下次课：\(nextClassText(item.id))").font(.system(size: 11)).foregroundStyle(MPColor.secondary)
                        Spacer()
                        Text(isTeacher ? "管理班级" : "进入课程").font(.system(size: 12, weight: .semibold)).foregroundStyle(MPColor.blue)
                    }
                }
            }
        }
        .buttonStyle(.plain)
    }

    private func classSessions(_ classId: String) -> [APISession] { sessions.filter { $0.classId == classId } }
    private func classroom(_ classId: String) -> APIClassroom? { classes.first { $0.id == classId } }
    private func completedHours(_ item: APIClassroom) -> Double {
        classSessions(item.id).filter { $0.status == "COMPLETED" }.reduce(0) { $0 + $1.plannedHours.doubleValue }
    }
    private func price(_ item: APIClassroom) -> Double {
        item.priceSettings?.price.doubleValue ?? item.members?.first?.pricePerHour.doubleValue ?? 0
    }
    private func classColor(_ item: APIClassroom) -> Color {
        switch item.color?.uppercased() {
        case "#6AA08A": MPColor.green
        case "#E8B4A8": MPColor.coral
        case "#D4A574": MPColor.gold
        case "#DC7878": MPColor.red
        default: MPColor.blue
        }
    }
    private func nextClassText(_ classId: String) -> String {
        classSessions(classId).filter { $0.startsAt >= Date() && $0.status != "CANCELLED" }
            .min { $0.startsAt < $1.startsAt }?
            .startsAt.formatted(.dateTime.month().day().hour().minute()) ?? "待安排"
    }
    private func todayDetail(_ item: APISession) -> String {
        let cls = classroom(item.classId)
        return "\(cls?.location ?? "地点待定") · \(cls?.members?.count ?? 0)人"
    }
    private func attendanceSummary(_ item: APISession) -> String {
        guard item.status == "COMPLETED" else { return "待确认出勤与课时" }
        let present = item.attendances?.filter { $0.status == "PRESENT" }.count ?? 0
        let absent = item.attendances?.filter { $0.status == "ABSENT" }.count ?? 0
        return "出勤 \(present) 人\(absent > 0 ? " · 缺席 \(absent) 人" : "")"
    }

    @MainActor
    private func load() async {
        isLoading = true
        defer { isLoading = false }
        errorMessage = nil
        let repository = ClassTraceRepository(client: dependencies.client)
        do {
            async let classRequest = repository.classes()
            async let courseRequest = repository.courses()
            async let studentRequest = repository.students()
            async let sessionRequest = repository.sessions()
            async let overviewRequest = try? repository.businessOverview()
            (classes, courses, students, sessions) = try await (classRequest, courseRequest, studentRequest, sessionRequest)
            overview = await overviewRequest
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

extension Double {
    var compactNumber: String {
        formatted(.number.precision(.fractionLength(self.rounded() == self ? 0 : 1)))
    }
}
