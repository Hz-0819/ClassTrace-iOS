import SwiftUI
import UniformTypeIdentifiers

struct CourseEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AppDependencies.self) private var dependencies
    let course: APICourse?
    let onSaved: () async -> Void
    @State private var name: String
    @State private var subject: String
    @State private var details: String
    @State private var color: String
    @State private var objectives: String
    @State private var requirements: String
    @State private var outlines: [APICourseOutline]
    @State private var lessons: [APICourseLesson]
    @State private var uploadingLesson: Int?
    @State private var error: String?

    init(course: APICourse? = nil, onSaved: @escaping () async -> Void) {
        self.course = course; self.onSaved = onSaved
        _name = State(initialValue: course?.name ?? "")
        _subject = State(initialValue: course?.subject ?? "")
        _details = State(initialValue: course?.description ?? "")
        _color = State(initialValue: course?.color ?? "#7BA3C0")
        _objectives = State(initialValue: course?.objectives ?? "")
        _requirements = State(initialValue: course?.requirements ?? "")
        _outlines = State(initialValue: course?.outlineSections ?? [APICourseOutline(id: UUID().uuidString, phaseTitle: "", phaseContent: "")])
        _lessons = State(initialValue: course?.lessonSections ?? [APICourseLesson(id: UUID().uuidString, title: "", content: "", materials: [])])
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 20) {
                courseSection("基本信息", "info-green") {
                    courseField("课程名称", "例如：小学数学思维训练", $name)
                    courseField("科目", "例如：数学", $subject)
                    courseTextArea("课程简介", "简要描述课程内容和特色…", $details)
                    VStack(alignment: .leading, spacing: 10) { Text("主题色").font(.system(size: 14, weight: .medium)); HStack { ForEach(Self.colors, id: \.0) { item in Button { color = item.0 } label: { Circle().fill(item.1).frame(width: 32, height: 32).overlay { if color == item.0 { Image(systemName: "checkmark").font(.caption.bold()).foregroundStyle(.white) } } }.buttonStyle(.plain) } } }
                }
                courseSection("课程信息", "book") {
                    courseTextArea("课程目标", "描述学生完成本课程后能达到的目标…", $objectives)
                    VStack(alignment: .leading, spacing: 12) {
                        Text("课程内容").font(.system(size: 14, weight: .medium))
                        ForEach($outlines) { $outline in
                            VStack(alignment: .leading, spacing: 10) { Text("阶段 \((outlines.firstIndex(where: { $0.id == outline.id }) ?? 0) + 1)").font(.caption.bold()).foregroundStyle(MPColor.blue); TextField("阶段标题，如：基础入门", text: $outline.phaseTitle); TextField("描述本阶段的具体教学内容", text: $outline.phaseContent, axis: .vertical).lineLimit(2...5) }.padding(12).background(MPColor.page, in: RoundedRectangle(cornerRadius: 12))
                        }
                        Button { outlines.append(APICourseOutline(id: UUID().uuidString, phaseTitle: "", phaseContent: "")) } label: { Label("添加阶段", systemImage: "plus").frame(maxWidth: .infinity, minHeight: 42).overlay(RoundedRectangle(cornerRadius: 10).stroke(MPColor.blue, style: StrokeStyle(lineWidth: 1, dash: [5]))) }.buttonStyle(.plain).foregroundStyle(MPColor.blue)
                    }
                    courseTextArea("课程要求", "描述学生需要具备的基础条件或前置知识…", $requirements)
                }
                courseSection("课程课时信息", "timetable-blue") {
                    Text("为每次课设置具体的教学内容和教学资料").font(.caption).foregroundStyle(MPColor.secondary)
                    ForEach(Array(lessons.indices), id: \.self) { index in
                        VStack(alignment: .leading, spacing: 10) {
                            HStack { Text("第 \(index + 1) 课").font(.system(size: 14, weight: .bold)).foregroundStyle(MPColor.blue); Spacer(); if lessons.count > 1 { Button(role: .destructive) { lessons.remove(at: index) } label: { Image(systemName: "trash") } } }
                            TextField("课时标题", text: $lessons[index].title)
                            TextField("详细描述本节课的教学内容", text: $lessons[index].content, axis: .vertical).lineLimit(3...7)
                            ForEach(lessons[index].materials) { material in HStack { MPLegacyImage(name: "file-blue", size: 20); Text(material.name).font(.caption).lineLimit(1); Spacer(); Button(role: .destructive) { lessons[index].materials.removeAll { $0.id == material.id } } label: { Image(systemName: "xmark.circle") } } }
                            Button { uploadingLesson = index } label: { Label("上传资料", systemImage: "plus").font(.system(size: 13)).frame(maxWidth: .infinity, minHeight: 40).background(MPColor.blue.opacity(0.10), in: RoundedRectangle(cornerRadius: 9)) }.buttonStyle(.plain)
                        }.padding(14).background(MPColor.page, in: RoundedRectangle(cornerRadius: 13))
                    }
                    Button { lessons.append(APICourseLesson(id: UUID().uuidString, title: "", content: "", materials: [])) } label: { Label("添加课时", systemImage: "plus").frame(maxWidth: .infinity, minHeight: 42).overlay(RoundedRectangle(cornerRadius: 10).stroke(MPColor.blue, style: StrokeStyle(lineWidth: 1, dash: [5]))) }.buttonStyle(.plain).foregroundStyle(MPColor.blue)
                }
                if let error { Text(error).font(.footnote).foregroundStyle(MPColor.red).padding(.horizontal, 16) }
                if let course { Button("删除课程", role: .destructive) { Task { await remove(course.id) } }.padding() }
            }.padding(.vertical, 16)
        }
        .background(MPColor.page).navigationTitle(course == nil ? "新建课程" : "编辑课程").navigationBarTitleDisplayMode(.inline)
        .safeAreaInset(edge: .bottom) { Button { Task { await save() } } label: { Text("保存课程").font(.system(size: 17, weight: .semibold)).foregroundStyle(.white).frame(maxWidth: .infinity, minHeight: 50).background(MPColor.blue, in: Capsule()) }.buttonStyle(.plain).disabled(name.trimmingCharacters(in: .whitespaces).isEmpty).padding(.horizontal, 20).padding(.vertical, 10).background(.white) }
        .fileImporter(isPresented: Binding(get: { uploadingLesson != nil }, set: { if !$0 { uploadingLesson = nil } }), allowedContentTypes: [.item]) { result in Task { await importMaterial(result) } }
    }

    @MainActor private func save() async {
        do {
            let repository = ClassTraceRepository(client: dependencies.client)
            if let course { _ = try await repository.updateCourse(course.id, name: name, subject: subject.nilIfEmpty, description: details.nilIfEmpty, color: color, objectives: objectives.nilIfEmpty, requirements: requirements.nilIfEmpty, outlineSections: outlines, lessonSections: lessons) }
            else { _ = try await repository.createCourse(name: name, subject: subject.nilIfEmpty, description: details.nilIfEmpty, color: color, objectives: objectives.nilIfEmpty, requirements: requirements.nilIfEmpty, outlineSections: outlines, lessonSections: lessons) }
            await onSaved(); dismiss()
        } catch { self.error = error.localizedDescription }
    }
    @MainActor private func remove(_ id: String) async { do { try await ClassTraceRepository(client: dependencies.client).deleteCourse(id); await onSaved(); dismiss() } catch { self.error = error.localizedDescription } }
    @MainActor private func importMaterial(_ result: Result<URL, Error>) async { do { guard let index = uploadingLesson else { return }; let url = try result.get(); guard url.startAccessingSecurityScopedResource() else { throw URLError(.noPermissionsToReadFile) }; defer { url.stopAccessingSecurityScopedResource() }; let data = try Data(contentsOf: url); let mime = UTType(filenameExtension: url.pathExtension)?.preferredMIMEType ?? "application/octet-stream"; let key = try await FileTransferService(client: dependencies.client).upload(data: data, fileName: url.lastPathComponent, mimeType: mime); lessons[index].materials.append(APICourseMaterial(id: UUID().uuidString, name: url.lastPathComponent, objectKey: key, mimeType: mime, sizeBytes: data.count)); uploadingLesson = nil } catch { self.error = error.localizedDescription } }
    private func courseSection<Content: View>(_ title: String, _ icon: String, @ViewBuilder content: () -> Content) -> some View { VStack(spacing: 10) { HStack { MPIconTile(image: icon, color: MPColor.blue, size: 32); Text(title).font(.system(size: 17, weight: .semibold)); Spacer() }.padding(.horizontal, 16); MPCard { VStack(alignment: .leading, spacing: 18) { content() } }.padding(.horizontal, 12) } }
    private func courseField(_ label: String, _ placeholder: String, _ text: Binding<String>) -> some View { VStack(alignment: .leading, spacing: 8) { Text(label).font(.system(size: 14, weight: .medium)); TextField(placeholder, text: text).padding(.horizontal, 12).frame(height: 46).background(MPColor.page, in: RoundedRectangle(cornerRadius: 9)) } }
    private func courseTextArea(_ label: String, _ placeholder: String, _ text: Binding<String>) -> some View { VStack(alignment: .leading, spacing: 8) { Text(label).font(.system(size: 14, weight: .medium)); TextField(placeholder, text: text, axis: .vertical).lineLimit(3...8).padding(12).background(MPColor.page, in: RoundedRectangle(cornerRadius: 9)) } }
    private static let colors: [(String, Color)] = [("#7BA3C0", MPColor.blue), ("#6AA08A", MPColor.green), ("#E8B4A8", MPColor.coral), ("#D4A574", MPColor.gold), ("#DC7878", MPColor.red)]
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
    @State private var confirmDelete = false

    init(student: APIStudent, onSaved: @escaping () async -> Void) {
        self.student = student; self.onSaved = onSaved
        _name = State(initialValue: student.name); _grade = State(initialValue: student.grade ?? ""); _gender = State(initialValue: student.gender?.lowercased() ?? "")
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
                ForEach(details?.guardians ?? student.guardians ?? []) { guardian in
                    HStack { Text(guardian.relationship ?? "监护人"); Spacer(); Button("解除", role: .destructive) { Task { await removeGuardian(guardian.id) } } }
                }
            }
            if let error { Text(error).foregroundStyle(Color.ctDanger) }
            Button("删除学生档案", role: .destructive) { confirmDelete = true }
        }.mpFormChrome().navigationTitle("学生档案").toolbar { Button("保存") { Task { await save() } }.disabled(name.isEmpty) }.task { await loadDetail() }
            .alert("确认删除学生档案？", isPresented: $confirmDelete) { Button("取消", role: .cancel) {}; Button("删除", role: .destructive) { Task { await remove() } } } message: { Text("相关班级成员关系和学习记录可能受到影响，该操作不能撤销。") }
    }
    @MainActor private func save() async { do { _ = try await ClassTraceRepository(client: dependencies.client).updateStudent(student.id, name: name, grade: grade.nilIfEmpty, gender: gender.nilIfEmpty); await onSaved(); dismiss() } catch { self.error = error.localizedDescription } }
    @MainActor private func remove() async { do { try await ClassTraceRepository(client: dependencies.client).deleteStudent(student.id); await onSaved(); dismiss() } catch { self.error = error.localizedDescription } }
    @MainActor private func createInvite() async { do { invite = try await ClassTraceRepository(client: dependencies.client).createGuardianInvite(studentId: student.id) } catch { self.error = error.localizedDescription } }
    @MainActor private func removeGuardian(_ guardianId: String) async { do { try await ClassTraceRepository(client: dependencies.client).removeGuardian(studentId: student.id, guardianId: guardianId); await onSaved(); await loadDetail() } catch { self.error = error.localizedDescription } }
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
