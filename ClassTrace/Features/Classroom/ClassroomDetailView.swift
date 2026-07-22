import SwiftUI

private struct LegacyClassroomDetailView: View {
    @Environment(AppDependencies.self) private var dependencies
    let classId: String
    @State private var classroom: APIClassroom?
    @State private var errorMessage: String?
    @State private var showNewSession = false
    @State private var showAddMember = false
    @State private var showGenerateSchedule = false
    @State private var students: [APIStudent] = []

    var body: some View {
        Group {
            if let classroom {
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 20) {
                        ZStack {
                            MPColor.blue
                            Circle().fill(.white.opacity(0.10)).frame(width: 120, height: 120).offset(x: 150, y: -45)
                            VStack(alignment: .leading, spacing: 9) {
                                HStack { MPIconTile(image: "class-white", color: .white, size: 50); VStack(alignment: .leading, spacing: 4) { Text(classroom.name).font(.system(size: 22, weight: .bold)); Text(classroom.status.localizedStatus).font(.system(size: 12)) }; Spacer() }
                                Text(classroom.schedule?.text ?? "暂未设置固定排课").font(.system(size: 13)).opacity(0.82)
                            }.foregroundStyle(.white).padding(20)
                        }.frame(height: 145).clipShape(RoundedRectangle(cornerRadius: 0))

                        VStack(spacing: 12) {
                            MPSectionHeader(title: "班级信息")
                            MPCard { VStack(spacing: 12) { infoRow("班型", classroom.classType.localizedStatus); infoRow("计费", classroom.billingMode == "PREPAID" ? "预付课时" : "现金记账"); infoRow("邀请码", classroom.inviteCode); if let location = classroom.location { infoRow("地点", location) } } }
                        }.padding(.horizontal, 16)

                        HStack(spacing: 10) {
                            NavigationLink { ScheduleCalendarView() } label: { actionCard("课表", "timetable-blue", MPColor.blue) }
                            NavigationLink { HourLedgerView(classId: classId) } label: { actionCard("课时账本", "bill-green", MPColor.green) }
                        }.buttonStyle(.plain).padding(.horizontal, 16)

                        VStack(spacing: 12) {
                            MPSectionHeader(title: "学生与课时")
                            if (classroom.members ?? []).isEmpty { MPCard { MPEmptyView(image: "student", title: "还没有学生", detail: "从右上角菜单添加学生到班级") } }
                            ForEach(classroom.members ?? []) { member in NavigationLink { MemberManagementView(classId: classId, member: member) { await load() } } label: { MPCard { HStack { MPIconTile(image: member.student?.gender == "FEMALE" ? "girl" : "boy", color: MPColor.green, size: 46); VStack(alignment: .leading, spacing: 5) { Text(member.student?.name ?? "学生").font(.system(size: 15, weight: .semibold)); Text("剩余 \(member.remainingHours.doubleValue.formatted()) 课时 · 单价 ¥\(member.pricePerHour.doubleValue.formatted())").font(.system(size: 12)).foregroundStyle(member.remainingHours.doubleValue <= 2 ? MPColor.red : MPColor.secondary) }; Spacer(); Image(systemName: "chevron.right").font(.caption).foregroundStyle(MPColor.secondary) } } }.buttonStyle(.plain) }
                        }.padding(.horizontal, 16)

                        VStack(spacing: 12) {
                            MPSectionHeader(title: "课表与历史")
                            if (classroom.sessions ?? []).isEmpty { MPCard { MPEmptyView(image: "time", title: "暂无课节", detail: "可以添加单次课节或按固定周期批量排课") } }
                            ForEach((classroom.sessions ?? []).sorted { $0.startsAt < $1.startsAt }) { session in NavigationLink { SessionDetailView(sessionId: session.id) } label: { MPCard { SessionRow(session: session) } }.buttonStyle(.plain) }
                        }.padding(.horizontal, 16)
                    }.padding(.bottom, 20)
                }.background(MPColor.page)
            } else if let errorMessage { CTStateView(kind: .error, title: "加载失败", message: LocalizedStringKey(errorMessage), actionTitle: "重试") { Task { await load() } } }
            else { ProgressView() }
        }
        .navigationTitle(classroom?.name ?? "班级详情")
        .toolbar { Menu { Button("添加课节", systemImage: "calendar.badge.plus") { showNewSession = true }; Button("按周批量排课", systemImage: "calendar") { showGenerateSchedule = true }; Button("添加学生", systemImage: "person.badge.plus") { showAddMember = true }; if let classroom { NavigationLink("班级设置") { ClassSettingsView(classroom: classroom) { await load() } } } } label: { Image(systemName: "ellipsis.circle") } }
        .sheet(isPresented: $showNewSession) { CreateSessionSheet(classId: classId) { await load() } }
        .sheet(isPresented: $showAddMember) { AddClassMemberView(classId: classId, students: students) { await load() } }
        .sheet(isPresented: $showGenerateSchedule) { GenerateScheduleView(classId: classId) { await load() } }
        .refreshable { await load() }.task { if classroom == nil { await load() } }
    }
    private func infoRow(_ title: String, _ value: String) -> some View { HStack { Text(title).font(.system(size: 13)).foregroundStyle(MPColor.secondary); Spacer(); Text(value).font(.system(size: 14, weight: .medium)).foregroundStyle(MPColor.text) } }
    private func actionCard(_ title: String, _ image: String, _ color: Color) -> some View { MPCard { HStack { MPIconTile(image: image, color: color, size: 42); Text(title).font(.system(size: 14, weight: .semibold)).foregroundStyle(MPColor.text); Spacer() } } }
    @MainActor private func load() async { do { let client = dependencies.client; async let c = ClassTraceRepository(client: client).classDetail(classId); async let s = ClassTraceRepository(client: client).students(); (classroom, students) = try await (c, s); errorMessage = nil } catch { errorMessage = error.localizedDescription } }
}

private struct LegacySessionDetailView: View {
    @Environment(AppDependencies.self) private var dependencies
    let sessionId: String
    @State private var session: APISession?
    @State private var errorMessage: String?
    @State private var isWorking = false
    @State private var members: [APIClassMember] = []
    @State private var showAttendance = false
    @State private var editMode: SessionEditView.Mode?
    var body: some View {
        Group {
            if let session {
                List {
                    Section("课节") { LabeledContent("时间", value: session.startsAt.formatted(date: .abbreviated, time: .shortened)); LabeledContent("状态", value: session.status.localizedStatus); LabeledContent("计划课时", value: session.plannedHours.doubleValue.formatted()) }
                    Section("考勤") { ForEach(session.attendances ?? []) { item in LabeledContent(item.student?.name ?? "学生", value: item.status.localizedStatus) } }
                    if let feedback = session.feedback { Section("课后反馈") { Text(feedback.summary ?? "暂无课堂总结"); Text(feedback.performance ?? "暂无表现评价") } }
                    if session.status == "SCHEDULED" { Button("确认上课并记录考勤") { showAttendance = true }.disabled(isWorking) }
                    if session.status == "COMPLETED" { Button("撤销上课确认", role: .destructive) { Task { await undo() } }.disabled(isWorking) }
                }
            } else if let errorMessage { CTStateView(kind: .error, title: "加载失败", message: LocalizedStringKey(errorMessage), actionTitle: "重试") { Task { await load() } } }
            else { ProgressView() }
        }.navigationTitle("课节详情").toolbar { if let session { Menu { if session.status == "SCHEDULED" { Button("调整时间") { editMode = .reschedule }; Button("取消课节", role: .destructive) { editMode = .cancel } }; Button("课后反馈") { editMode = .feedback } } label: { Image(systemName: "ellipsis.circle") } } }.sheet(isPresented: $showAttendance) { if let session { ConfirmAttendanceView(session: session, members: members) { value in self.session = value } } }.sheet(item: $editMode) { mode in if let session { SessionEditView(session: session, mode: mode) { await load() } } }.task { if session == nil { await load() } }
    }
    @MainActor private func load() async { do { let value = try await ClassTraceRepository(client: dependencies.client).sessionDetail(sessionId); session = value; members = (try await ClassTraceRepository(client: dependencies.client).classDetail(value.classId)).members ?? []; errorMessage = nil } catch { errorMessage = error.localizedDescription } }
    @MainActor private func undo() async { isWorking = true; defer { isWorking = false }; do { session = try await ClassTraceRepository(client: dependencies.client).undoSession(id: sessionId) } catch { errorMessage = error.localizedDescription } }
}

private struct CreateSessionSheet: View {
    @Environment(\.dismiss) private var dismiss; @Environment(AppDependencies.self) private var dependencies
    let classId: String; let onSaved: () async -> Void
    @State private var startsAt = Date().addingTimeInterval(3600); @State private var duration = 60; @State private var error: String?
    var body: some View { NavigationStack { Form { DatePicker("开始时间", selection: $startsAt); Stepper("时长：\(duration) 分钟", value: $duration, in: 15...360, step: 15); if let error { Text(error).foregroundStyle(Color.ctDanger) } }.navigationTitle("添加课节").toolbar { ToolbarItem(placement: .cancellationAction) { Button("取消") { dismiss() } }; ToolbarItem(placement: .confirmationAction) { Button("保存") { Task { await save() } } } } } }
    @MainActor private func save() async { do { _ = try await ClassTraceRepository(client: dependencies.client).createSession(classId: classId, startsAt: startsAt, endsAt: startsAt.addingTimeInterval(Double(duration * 60))); await onSaved(); dismiss() } catch { self.error = error.localizedDescription } }
}

private struct GenerateScheduleView: View {
    @Environment(\.dismiss) private var dismiss; @Environment(AppDependencies.self) private var dependencies
    let classId: String; let onSaved: () async -> Void
    @State private var from = Date(); @State private var to = Date().addingTimeInterval(86400 * 90); @State private var weekdays: Set<Int> = [1]; @State private var startsAt = Date(); @State private var duration = 60; @State private var error: String?
    var body: some View { NavigationStack { Form { DatePicker("开始日期", selection: $from, displayedComponents: .date); DatePicker("结束日期", selection: $to, displayedComponents: .date); Section("上课日") { ForEach(1...7, id: \.self) { day in Toggle(["周一","周二","周三","周四","周五","周六","周日"][day - 1], isOn: Binding(get: { weekdays.contains(day) }, set: { if $0 { weekdays.insert(day) } else { weekdays.remove(day) } })) } }; DatePicker("上课时间", selection: $startsAt, displayedComponents: .hourAndMinute); Stepper("时长 \(duration) 分钟", value: $duration, in: 15...360, step: 15); if let error { Text(error).foregroundStyle(Color.ctDanger) } }.navigationTitle("批量排课").toolbar { ToolbarItem(placement: .cancellationAction) { Button("取消") { dismiss() } }; ToolbarItem(placement: .confirmationAction) { Button("生成") { Task { await save() } }.disabled(weekdays.isEmpty || to < from) } } } }
    @MainActor private func save() async { do { let parts = Calendar.current.dateComponents([.hour, .minute], from: startsAt); let time = String(format: "%02d:%02d", parts.hour ?? 0, parts.minute ?? 0); _ = try await ClassTraceRepository(client: dependencies.client).generateSessions(classId: classId, from: from, to: to, weekdays: weekdays.sorted(), startTime: time, durationMinutes: duration); await onSaved(); dismiss() } catch { self.error = error.localizedDescription } }
}
