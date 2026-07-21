import SwiftUI

struct ConfirmAttendanceView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AppDependencies.self) private var dependencies
    let session: APISession; let members: [APIClassMember]; let onSaved: (APISession) async -> Void
    @State private var statuses: [String: String] = [:]
    @State private var error: String?
    var body: some View { NavigationStack { Form {
        Section("逐个记录考勤") { ForEach(members) { member in Picker(member.student?.name ?? "学生", selection: Binding(get: { statuses[member.studentId] ?? "PRESENT" }, set: { statuses[member.studentId] = $0 })) { Text("出勤").tag("PRESENT"); Text("请假").tag("LEAVE"); Text("缺席").tag("ABSENT") } } }
        Section { Text("只有出勤学生会按计划课时扣减；余额不足将标记为课时不足，不会出现负数。").font(.footnote).foregroundStyle(Color.ctTextSecondary) }
        if let error { Text(error).foregroundStyle(Color.ctDanger) }
    }.mpFormChrome().navigationTitle("确认上课").toolbar { ToolbarItem(placement: .cancellationAction) { Button("取消") { dismiss() } }; ToolbarItem(placement: .confirmationAction) { Button("确认") { Task { await save() } } } } } }
    @MainActor private func save() async { do { let rows = members.map { ConfirmAttendanceRequest(studentId: $0.studentId, status: statuses[$0.studentId] ?? "PRESENT", deductHours: session.plannedHours.doubleValue, remark: nil) }; let value = try await ClassTraceRepository(client: dependencies.client).confirmSession(id: session.id, attendances: rows); await onSaved(value); dismiss() } catch { self.error = error.localizedDescription } }
}

struct SessionEditView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AppDependencies.self) private var dependencies
    let session: APISession; let mode: Mode; let onSaved: () async -> Void
    enum Mode: Int, Identifiable { case reschedule, feedback, cancel; var id: Int { rawValue } }
    @State private var startsAt: Date; @State private var durationMinutes: Int
    @State private var summary = ""; @State private var performance = ""; @State private var homework = ""; @State private var reason = ""; @State private var error: String?
    init(session: APISession, mode: Mode, onSaved: @escaping () async -> Void) { self.session = session; self.mode = mode; self.onSaved = onSaved; _startsAt = State(initialValue: session.startsAt); _durationMinutes = State(initialValue: max(15, Int(session.endsAt.timeIntervalSince(session.startsAt) / 60))); _summary = State(initialValue: session.feedback?.summary ?? ""); _performance = State(initialValue: session.feedback?.performance ?? ""); _homework = State(initialValue: session.feedback?.homeworkNote ?? "") }
    var body: some View { NavigationStack { Form {
        if mode == .reschedule { DatePicker("新的开始时间", selection: $startsAt); Stepper("时长 \(durationMinutes) 分钟", value: $durationMinutes, in: 15...360, step: 15) }
        if mode == .feedback { TextField("课堂总结", text: $summary, axis: .vertical); TextField("学生表现", text: $performance, axis: .vertical); TextField("课后作业说明", text: $homework, axis: .vertical) }
        if mode == .cancel { TextField("取消原因", text: $reason, axis: .vertical) }
        if let error { Text(error).foregroundStyle(Color.ctDanger) }
    }.mpFormChrome().navigationTitle(title).toolbar { ToolbarItem(placement: .cancellationAction) { Button("取消") { dismiss() } }; ToolbarItem(placement: .confirmationAction) { Button("保存") { Task { await save() } } } } } }
    private var title: String { switch mode { case .reschedule: "调整课节"; case .feedback: "课后反馈"; case .cancel: "取消课节" } }
    @MainActor private func save() async { do { let repository = ClassTraceRepository(client: dependencies.client); switch mode { case .reschedule: _ = try await repository.rescheduleSession(session.id, startsAt: startsAt, endsAt: startsAt.addingTimeInterval(Double(durationMinutes * 60))); case .feedback: _ = try await repository.saveSessionFeedback(session.id, summary: summary.nilIfEmpty, performance: performance.nilIfEmpty, homeworkNote: homework.nilIfEmpty); case .cancel: _ = try await repository.cancelSession(session.id, reason: reason.nilIfEmpty) }; await onSaved(); dismiss() } catch { self.error = error.localizedDescription } }
}
