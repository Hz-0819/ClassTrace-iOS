import SwiftUI

struct CourseEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AppDependencies.self) private var dependencies
    let course: APICourse?
    let onSaved: () async -> Void
    @State private var name: String
    @State private var subject: String
    @State private var details: String
    @State private var error: String?

    init(course: APICourse? = nil, onSaved: @escaping () async -> Void) {
        self.course = course; self.onSaved = onSaved
        _name = State(initialValue: course?.name ?? "")
        _subject = State(initialValue: course?.subject ?? "")
        _details = State(initialValue: course?.description ?? "")
    }

    var body: some View {
        Form {
            TextField("课程名称", text: $name)
            TextField("科目", text: $subject)
            TextField("课程说明", text: $details, axis: .vertical).lineLimit(3...8)
            if let error { Text(error).foregroundStyle(Color.ctDanger) }
            if let course { Button("删除课程", role: .destructive) { Task { await remove(course.id) } } }
        }
        .navigationTitle(course == nil ? "新建课程" : "编辑课程")
        .toolbar { Button("保存") { Task { await save() } }.disabled(name.trimmingCharacters(in: .whitespaces).isEmpty) }
    }

    @MainActor private func save() async {
        do {
            let repository = ClassTraceRepository(client: dependencies.client)
            if let course { _ = try await repository.updateCourse(course.id, name: name, subject: subject.nilIfEmpty, description: details.nilIfEmpty) }
            else { _ = try await repository.createCourse(name: name, subject: subject.nilIfEmpty, description: details.nilIfEmpty) }
            await onSaved(); dismiss()
        } catch { self.error = error.localizedDescription }
    }
    @MainActor private func remove(_ id: String) async { do { try await ClassTraceRepository(client: dependencies.client).deleteCourse(id); await onSaved(); dismiss() } catch { self.error = error.localizedDescription } }
}

struct StudentEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AppDependencies.self) private var dependencies
    let student: APIStudent
    let onSaved: () async -> Void
    @State private var name: String
    @State private var grade: String
    @State private var gender: String
    @State private var error: String?
    @State private var invite: GuardianInvitePayload?
    @State private var details: APIStudent?
    @State private var stats: APIAttendanceStats?

    init(student: APIStudent, onSaved: @escaping () async -> Void) {
        self.student = student; self.onSaved = onSaved
        _name = State(initialValue: student.name); _grade = State(initialValue: student.grade ?? ""); _gender = State(initialValue: student.gender ?? "")
    }
    var body: some View {
        Form {
            TextField("姓名", text: $name); TextField("年级", text: $grade)
            Picker("性别", selection: $gender) { Text("未填写").tag(""); Text("男").tag("male"); Text("女").tag("female") }
            Section("关联数据") {
                LabeledContent("所在班级", value: "\(student.classMembers?.count ?? 0)")
                LabeledContent("监护关系", value: "\(student.guardians?.count ?? 0)")
            }
            if let stats { Section("考勤统计") { LabeledContent("总计", value: "\(stats.total)"); LabeledContent("出勤", value: "\(stats.counts["PRESENT"] ?? 0)"); LabeledContent("请假", value: "\(stats.counts["LEAVE"] ?? 0)"); LabeledContent("缺席", value: "\(stats.counts["ABSENT"] ?? 0)"); LabeledContent("出勤率", value: stats.attendanceRate.formatted(.percent)) } }
            if let details { Section("学习概览") { LabeledContent("作业提交", value: "\(details.homeworkSubmissions?.count ?? 0)"); LabeledContent("进行中计划", value: "\(details.studyPlans?.count ?? 0)"); LabeledContent("待掌握错题", value: "\(details.mistakes?.count ?? 0)") } }
            Section("监护人") {
                Button("生成监护人邀请") { Task { await createInvite() } }
                if let invite { ShareLink(item: invite.code) { Label("分享邀请码：\(invite.code)", systemImage: "square.and.arrow.up") } }
                ForEach(student.guardians ?? []) { guardian in
                    HStack { Text(guardian.relationship ?? "监护人"); Spacer(); if let guardianUserId = guardian.guardianUserId { Button("解除", role: .destructive) { Task { await removeGuardian(guardianUserId) } } } }
                }
            }
            if let error { Text(error).foregroundStyle(Color.ctDanger) }
            Button("删除学生档案", role: .destructive) { Task { await remove() } }
        }.navigationTitle("学生档案").toolbar { Button("保存") { Task { await save() } }.disabled(name.isEmpty) }.task { await loadDetail() }
    }
    @MainActor private func save() async { do { _ = try await ClassTraceRepository(client: dependencies.client).updateStudent(student.id, name: name, grade: grade.nilIfEmpty, gender: gender.nilIfEmpty); await onSaved(); dismiss() } catch { self.error = error.localizedDescription } }
    @MainActor private func remove() async { do { try await ClassTraceRepository(client: dependencies.client).deleteStudent(student.id); await onSaved(); dismiss() } catch { self.error = error.localizedDescription } }
    @MainActor private func createInvite() async { do { invite = try await ClassTraceRepository(client: dependencies.client).createGuardianInvite(studentId: student.id) } catch { self.error = error.localizedDescription } }
    @MainActor private func removeGuardian(_ guardianId: String) async { do { try await ClassTraceRepository(client: dependencies.client).removeGuardian(studentId: student.id, guardianId: guardianId); await onSaved() } catch { self.error = error.localizedDescription } }
    @MainActor private func loadDetail() async { let r = ClassTraceRepository(client: dependencies.client); async let d = try? r.studentDetail(student.id); async let s = try? r.attendanceStats(studentId: student.id); (details, stats) = await (d, s) }
}

struct AddClassMemberView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AppDependencies.self) private var dependencies
    let classId: String; let students: [APIStudent]; let onSaved: () async -> Void
    @State private var studentId = ""; @State private var hours = 0.0; @State private var price = 0.0; @State private var error: String?
    var body: some View { NavigationStack { Form {
        Picker("学生", selection: $studentId) { Text("请选择").tag(""); ForEach(students) { Text($0.name).tag($0.id) } }
        TextField("初始课时", value: $hours, format: .number).keyboardType(.decimalPad)
        TextField("课时单价", value: $price, format: .number).keyboardType(.decimalPad)
        if let error { Text(error).foregroundStyle(Color.ctDanger) }
    }.navigationTitle("添加班级学生").toolbar { ToolbarItem(placement: .cancellationAction) { Button("取消") { dismiss() } }; ToolbarItem(placement: .confirmationAction) { Button("添加") { Task { await save() } }.disabled(studentId.isEmpty) } } } }
    @MainActor private func save() async { do { _ = try await ClassTraceRepository(client: dependencies.client).addMember(classId: classId, studentId: studentId, initialHours: hours, pricePerHour: price); await onSaved(); dismiss() } catch { self.error = error.localizedDescription } }
}

struct MemberManagementView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AppDependencies.self) private var dependencies
    let classId: String; let member: APIClassMember; let onSaved: () async -> Void
    @State private var price: Double; @State private var rechargeHours = 0.0; @State private var status: String; @State private var error: String?
    init(classId: String, member: APIClassMember, onSaved: @escaping () async -> Void) { self.classId = classId; self.member = member; self.onSaved = onSaved; _price = State(initialValue: member.pricePerHour.doubleValue); _status = State(initialValue: member.status) }
    var body: some View { Form {
        LabeledContent("学生", value: member.student?.name ?? "学生"); LabeledContent("剩余课时", value: member.remainingHours.doubleValue.formatted())
        TextField("课时单价", value: $price, format: .number).keyboardType(.decimalPad)
        Picker("成员状态", selection: $status) { Text("待审核").tag("PENDING"); Text("已通过").tag("APPROVED"); Text("暂停").tag("PAUSED"); Text("结课").tag("COMPLETED") }
        Section("课时充值") { TextField("增加课时", value: $rechargeHours, format: .number).keyboardType(.decimalPad); Button("确认充值") { Task { await recharge() } }.disabled(rechargeHours <= 0) }
        if let error { Text(error).foregroundStyle(Color.ctDanger) }
        Button("移出班级", role: .destructive) { Task { await remove() } }
    }.navigationTitle("成员与课时").toolbar { Button("保存") { Task { await save() } } } }
    @MainActor private func save() async { do { _ = try await ClassTraceRepository(client: dependencies.client).updateMember(classId: classId, memberId: member.id, status: status, pricePerHour: price); await onSaved(); dismiss() } catch { self.error = error.localizedDescription } }
    @MainActor private func recharge() async { do { _ = try await ClassTraceRepository(client: dependencies.client).recharge(memberId: member.id, hours: rechargeHours, remark: "iOS 端充值"); rechargeHours = 0; await onSaved() } catch { self.error = error.localizedDescription } }
    @MainActor private func remove() async { do { try await ClassTraceRepository(client: dependencies.client).removeMember(classId: classId, memberId: member.id); await onSaved(); dismiss() } catch { self.error = error.localizedDescription } }
}

extension String { var nilIfEmpty: String? { isEmpty ? nil : self } }

struct ClassSettingsView: View {
    @Environment(\.dismiss) private var dismiss; @Environment(AppDependencies.self) private var dependencies
    let classroom: APIClassroom; let onSaved: () async -> Void
    @State private var name: String; @State private var location: String; @State private var status: String; @State private var error: String?
    init(classroom: APIClassroom, onSaved: @escaping () async -> Void) { self.classroom = classroom; self.onSaved = onSaved; _name = State(initialValue: classroom.name); _location = State(initialValue: classroom.location ?? ""); _status = State(initialValue: classroom.status) }
    var body: some View { Form { TextField("班级名称", text: $name); TextField("地点", text: $location); Picker("状态", selection: $status) { Text("进行中").tag("ACTIVE"); Text("暂停").tag("PAUSED"); Text("已结课").tag("COMPLETED") }; if let error { Text(error).foregroundStyle(Color.ctDanger) }; Button("保存") { Task { await save() } }; Button("删除班级", role: .destructive) { Task { await remove() } } }.navigationTitle("班级设置") }
    @MainActor private func save() async { do { _ = try await ClassTraceRepository(client: dependencies.client).updateClass(classroom.id, name: name, status: status, location: location.nilIfEmpty); await onSaved(); dismiss() } catch { self.error = error.localizedDescription } }
    @MainActor private func remove() async { do { try await ClassTraceRepository(client: dependencies.client).deleteClass(classroom.id); await onSaved(); dismiss() } catch { self.error = error.localizedDescription } }
}

struct HourLedgerView: View {
    @Environment(AppDependencies.self) private var dependencies
    let classId: String
    @State private var entries: [APIHourEntry] = []; @State private var exportURL: URL?
    var body: some View { List { if let exportURL { Section { ShareLink(item: exportURL) { Label("导出课时账本", systemImage: "square.and.arrow.up") } } }; ForEach(entries) { item in VStack(alignment: .leading) { HStack { Text(item.student?.name ?? "学生").font(.headline); Spacer(); Text(item.delta.doubleValue >= 0 ? "+\(item.delta.doubleValue.formatted())" : item.delta.doubleValue.formatted()) }; Text("余额 \(item.balanceAfter.doubleValue.formatted()) · \(item.type.localizedStatus)").font(.caption).foregroundStyle(Color.ctTextSecondary); Text(item.createdAt.formatted(date: .abbreviated, time: .shortened)).font(.caption2) } } }.navigationTitle("课时账本").task { await load() } }
    @MainActor private func load() async { entries = (try? await ClassTraceRepository(client: dependencies.client).hourLedger(classId: classId)) ?? []; let header = "学生,类型,变动,余额,时间,备注\n"; let rows = entries.map { "\($0.student?.name ?? ""),\($0.type),\($0.delta.doubleValue),\($0.balanceAfter.doubleValue),\($0.createdAt.ISO8601Format()),\(($0.remark ?? "").replacingOccurrences(of: ",", with: "，"))" }.joined(separator: "\n"); let url = FileManager.default.temporaryDirectory.appendingPathComponent("ClassTrace-hour-ledger.csv"); try? (header + rows).data(using: .utf8)?.write(to: url); exportURL = url }
}
