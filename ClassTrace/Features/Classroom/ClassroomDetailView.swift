import SwiftUI

struct ClassroomDetailView: View {
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
                List {
                    Section("班级信息") { LabeledContent("班型", value: classroom.classType.localizedStatus); LabeledContent("计费", value: classroom.billingMode == "PREPAID" ? "预付课时" : "现金记账"); LabeledContent("邀请码", value: classroom.inviteCode); if let location = classroom.location { LabeledContent("地点", value: location) } }
                    Section { NavigationLink("查看并导出课时账本") { HourLedgerView(classId: classId) } }
                    Section("学生与课时") {
                        ForEach(classroom.members ?? []) { member in
                            NavigationLink { MemberManagementView(classId: classId, member: member) { await load() } } label: { VStack(alignment: .leading) { HStack { Text(member.student?.name ?? "学生").font(.headline); Spacer(); Text(member.status.localizedStatus).foregroundStyle(Color.ctTextSecondary) }; Text("剩余 \(member.remainingHours.doubleValue.formatted()) 课时 · 单价 ¥\(member.pricePerHour.doubleValue.formatted())").font(.subheadline).foregroundStyle(member.remainingHours.doubleValue <= 2 ? Color.ctDanger : Color.ctTextSecondary) } }
                        }
                    }
                    Section("课表与历史") {
                        ForEach(classroom.sessions ?? []) { session in NavigationLink { SessionDetailView(sessionId: session.id) } label: { SessionRow(session: session) } }
                    }
                }
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
    @MainActor private func load() async { do { async let c = ClassTraceRepository(client: dependencies.client).classDetail(classId); async let s = ClassTraceRepository(client: dependencies.client).students(); (classroom, students) = try await (c, s); errorMessage = nil } catch { errorMessage = error.localizedDescription } }
}

struct SessionDetailView: View {
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
