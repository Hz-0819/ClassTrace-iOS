import SwiftUI

struct ProfileHubView: View {
    @Environment(AppSession.self) private var session
    @Environment(AppDependencies.self) private var dependencies
    @State private var classrooms: [APIClassroom] = []
    @State private var students: [APIStudent] = []
    @State private var points: APIPoints?

    private var isTeacher: Bool { session.activeRole == "TEACHER" }
    private var totalHours: Double {
        classrooms.flatMap { $0.members ?? [] }.reduce(0) { $0 + $1.remainingHours.doubleValue }
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            LazyVStack(spacing: 18) {
                header
                summary
                preview
                workSection
                financeSection
                settingsSection
                Button {
                    Task { await session.signOut(using: AuthRepository(client: dependencies.client, vault: dependencies.sessionVault)) }
                } label: {
                    HStack(spacing: 9) {
                        MPLegacyImage(name: "logout", size: 18)
                        Text(DemoMode.isEnabled ? "退出演示模式" : "退出登录")
                    }
                    .font(.system(size: 15, weight: .semibold)).foregroundStyle(MPColor.red)
                    .frame(maxWidth: .infinity).padding(16)
                    .background(.white, in: RoundedRectangle(cornerRadius: 16))
                }
                .buttonStyle(.plain).padding(.horizontal, 16)
            }
            .padding(.bottom, 28)
        }
        .background(MPColor.page)
        .toolbar(.hidden, for: .navigationBar)
        .task { await load() }
        .refreshable { await load() }
    }

    private var header: some View {
        ZStack {
            MPColor.blue
            Circle().fill(.white.opacity(0.10)).frame(width: 160, height: 160).offset(x: 150, y: -65)
            Circle().fill(.white.opacity(0.08)).frame(width: 90, height: 90).offset(x: -170, y: 30)
            HStack(spacing: 15) {
                ZStack {
                    Circle().fill(.white.opacity(0.22))
                    MPLegacyImage(name: "avatar", size: 54)
                }
                .frame(width: 66, height: 66)
                .overlay(Circle().stroke(.white.opacity(0.5), lineWidth: 2))
                VStack(alignment: .leading, spacing: 7) {
                    Text(session.user?.displayName ?? (isTeacher ? "教师用户" : "家长用户"))
                        .font(.system(size: 22, weight: .bold))
                    HStack(spacing: 8) {
                        Text("\(isTeacher ? "教师" : "家长")账号 · ID: \((session.user?.id ?? "12138").suffix(6))")
                        if availableRoles.count > 1 {
                            Menu {
                                ForEach(availableRoles, id: \.self) { role in
                                    Button {
                                        session.switchRole(role)
                                        Task { await load() }
                                    } label: {
                                        Label(role == "TEACHER" ? "教师身份" : "家长身份", systemImage: session.activeRole == role ? "checkmark.circle.fill" : "person.crop.circle")
                                    }
                                }
                            } label: {
                                HStack(spacing: 3) { Text("切换身份"); Image(systemName: "chevron.down").font(.system(size: 8, weight: .bold)) }
                                    .font(.system(size: 10, weight: .semibold)).foregroundStyle(.white)
                                    .padding(.horizontal, 8).padding(.vertical, 4).background(.white.opacity(0.2), in: Capsule())
                            }
                        }
                    }
                    .font(.system(size: 12)).foregroundStyle(.white.opacity(0.8))
                    if DemoMode.isEnabled {
                        Text("演示模式").font(.system(size: 10, weight: .semibold))
                            .padding(.horizontal, 8).padding(.vertical, 3)
                            .background(.white.opacity(0.2), in: Capsule())
                    }
                }
                .foregroundStyle(.white)
                Spacer()
                NavigationLink { AccountSettingsView() } label: {
                    Image(systemName: "gearshape.fill").foregroundStyle(.white)
                        .frame(width: 42, height: 42).background(.white.opacity(0.2), in: Circle())
                }
            }
            .padding(.horizontal, 20).padding(.top, 24)
        }
        .frame(height: 170)
        .clipShape(UnevenRoundedRectangle(bottomLeadingRadius: 28, bottomTrailingRadius: 28))
    }

    private var summary: some View {
        MPCard {
            HStack {
                metric(isTeacher ? "班级数量" : "孩子数量", "\(isTeacher ? classrooms.count : students.count)")
                divider
                metric(isTeacher ? "我的学生" : "在读课程", "\(isTeacher ? students.count : classrooms.filter { $0.status == "ACTIVE" }.count)")
                divider
                metric(isTeacher ? "剩余课时" : "我的积分", isTeacher ? totalHours.compactNumber : "\(points?.balance ?? 0)")
            }
        }
        .padding(.horizontal, 16).offset(y: -40).padding(.bottom, -40)
    }

    private var divider: some View { Rectangle().fill(.black.opacity(0.07)).frame(width: 0.5, height: 42) }

    private func metric(_ title: String, _ value: String) -> some View {
        VStack(spacing: 5) {
            Text(value).font(.system(size: 20, weight: .bold)).foregroundStyle(MPColor.text)
            Text(title).font(.system(size: 11)).foregroundStyle(MPColor.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    private var preview: some View {
        VStack(spacing: 12) {
            HStack {
                MPSectionHeader(title: isTeacher ? "我的班级" : "我的孩子")
                Spacer()
                NavigationLink(isTeacher ? "管理更多" : "管理更多") {
                    if isTeacher { AnyView(ClassroomDashboardView()) } else { AnyView(ChildrenDirectoryView()) }
                }
                .font(.system(size: 13)).foregroundStyle(MPColor.blue)
            }
            if isTeacher {
                if classrooms.isEmpty { emptyPreview(title: "添加班级", detail: "创建班级，开始管理排课与课时") }
                else { ForEach(classrooms.prefix(3)) { classroomPreview($0) } }
            } else {
                if students.isEmpty { emptyPreview(title: "添加孩子", detail: "录入孩子信息，查看课程与课时") }
                else { ForEach(students.prefix(3)) { studentPreview($0) } }
            }
        }
        .padding(.horizontal, 16)
    }

    private func classroomPreview(_ classroom: APIClassroom) -> some View {
        NavigationLink { ClassroomDetailView(classId: classroom.id) } label: {
            HStack(spacing: 12) {
                Text(String(classroom.name.prefix(1))).font(.system(size: 18, weight: .bold)).foregroundStyle(.white)
                    .frame(width: 46, height: 46).background(MPColor.blue, in: Circle())
                VStack(alignment: .leading, spacing: 4) {
                    Text(classroom.name).font(.system(size: 15, weight: .semibold)).foregroundStyle(MPColor.text)
                    Text("\(classroom.members?.count ?? 0) 名学生 · \(classroom.schedule?.text ?? "暂未设置排课")")
                        .font(.system(size: 12)).foregroundStyle(MPColor.secondary).lineLimit(1)
                }
                Spacer(); MPLegacyImage(name: "right", size: 13).opacity(0.5)
            }
            .padding(14).background(.white, in: RoundedRectangle(cornerRadius: 15))
        }.buttonStyle(.plain)
    }

    private func studentPreview(_ student: APIStudent) -> some View {
        NavigationLink { StudentProfileView(studentId: student.id) } label: {
            HStack(spacing: 12) {
                MPLegacyImage(name: student.gender?.uppercased() == "FEMALE" ? "girl" : "boy", size: 46)
                VStack(alignment: .leading, spacing: 4) {
                    Text(student.name).font(.system(size: 15, weight: .semibold)).foregroundStyle(MPColor.text)
                    Text("\(student.grade ?? "暂无年级") · \(student.classMembers?.count ?? 0) 个班级/课程")
                        .font(.system(size: 12)).foregroundStyle(MPColor.secondary)
                }
                Spacer(); MPLegacyImage(name: "right", size: 13).opacity(0.5)
            }
            .padding(14).background(.white, in: RoundedRectangle(cornerRadius: 15))
        }.buttonStyle(.plain)
    }

    private func emptyPreview(title: String, detail: String) -> some View {
        NavigationLink { if isTeacher { AnyView(ClassroomDashboardView()) } else { AnyView(ChildrenDirectoryView()) } } label: {
            HStack(spacing: 12) {
                Image(systemName: "plus").font(.system(size: 18, weight: .semibold)).foregroundStyle(MPColor.blue)
                    .frame(width: 46, height: 46).background(MPColor.blue.opacity(0.12), in: Circle())
                VStack(alignment: .leading, spacing: 4) {
                    Text(title).font(.system(size: 15, weight: .semibold)).foregroundStyle(MPColor.text)
                    Text(detail).font(.system(size: 12)).foregroundStyle(MPColor.secondary)
                }
                Spacer(); MPLegacyImage(name: "right", size: 13).opacity(0.5)
            }.padding(14).background(.white, in: RoundedRectangle(cornerRadius: 15))
        }.buttonStyle(.plain)
    }

    private var workSection: some View {
        menuSection(isTeacher ? "教学工作" : "课程管理") {
            MPMenuRow(title: isTeacher ? "班级管理" : "课程管理", image: "class-blue", color: MPColor.blue) { ClassroomDashboardView() }
            if isTeacher { MPMenuRow(title: "学生管理", image: "student-green", color: MPColor.green) { StudentDirectoryView() } }
            MPMenuRow(title: isTeacher ? "作业管理" : "作业与提交", image: "file-red", color: MPColor.red) { LearningHubView(initialSelection: 0) }
            MPMenuRow(title: isTeacher ? "资料中心" : "学习计划", image: isTeacher ? "material-brown" : "plan-brown", color: MPColor.gold) { LearningHubView(initialSelection: isTeacher ? 1 : 2) }
            if isTeacher { MPMenuRow(title: "个人日程", image: "timetable-blue", color: MPColor.blue) { ManualScheduleView() } }
        }
    }

    private var financeSection: some View {
        menuSection("财务管理") {
            MPMenuRow(title: isTeacher ? "经营概览" : "开销概览", image: isTeacher ? "bar chart-orange" : "wallet-blue", color: MPColor.gold) { BusinessOverviewView() }
            MPMenuRow(title: isTeacher ? "课时档案" : "课时明细", image: isTeacher ? "time-blue" : "bill-green", color: MPColor.green) { HourArchiveView() }
            MPMenuRow(title: "账单与退款", image: "wallet-brown", color: MPColor.gold) { CommerceCenterView() }
            MPMenuRow(title: "我的积分", image: "points-red", color: MPColor.red) { PointsCenterView() }
        }
    }

    private var settingsSection: some View {
        menuSection("设置") {
            MPMenuRow(title: "消息通知", image: "notice", color: MPColor.blue) { NotificationCenterView() }
            MPMenuRow(title: "VIP 权益", image: "vip-yellow", color: MPColor.gold) { VIPCenterView() }
            MPMenuRow(title: "问题反馈", image: "feedback-green", color: MPColor.green) { FeedbackCenterView() }
            MPMenuRow(title: "关于我们", image: "info-brown", color: MPColor.gold) { MiniProgramAboutView() }
            if session.user?.roles?.contains(where: { $0.role == "ADMIN" }) == true {
                MPMenuRow(title: "管理员工具", image: "identity", color: MPColor.blue) { AdminCenterView() }
            }
        }
    }

    private func menuSection<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(spacing: 12) { MPSectionHeader(title: title); MPCard { VStack(spacing: 0) { content() } } }
            .padding(.horizontal, 16)
    }

    @MainActor private func load() async {
        let repository = ClassTraceRepository(client: dependencies.client)
        async let classroomRequest = try? repository.classes()
        async let studentRequest = try? repository.students()
        async let pointsRequest = try? repository.points()
        classrooms = (await classroomRequest) ?? []
        students = (await studentRequest) ?? []
        points = await pointsRequest
    }

    private var availableRoles: [String] {
        (session.user?.roles ?? []).map(\.role).filter { ["TEACHER", "GUARDIAN"].contains($0) }
    }
}
