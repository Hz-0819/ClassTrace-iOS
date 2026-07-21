import SwiftUI
import UniformTypeIdentifiers

struct NewLearningItemView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AppDependencies.self) private var dependencies
    let kind: Kind; let classes: [APIClassroom]; let students: [APIStudent]; let onSaved: () async -> Void
    enum Kind { case homework, plan, mistake }
    @State private var classId = ""; @State private var studentId = ""; @State private var title = ""; @State private var content = ""; @State private var subject = ""; @State private var answer = ""; @State private var analysis = ""; @State private var dueAt = Date().addingTimeInterval(86400 * 7); @State private var publish = true; @State private var error: String?
    var body: some View { NavigationStack { Form {
        if kind == .homework { Picker("班级", selection: $classId) { Text("请选择").tag(""); ForEach(classes) { Text($0.name).tag($0.id) } } }
        if kind != .homework { Picker("学生（可选）", selection: $studentId) { Text("不指定").tag(""); ForEach(students) { Text($0.name).tag($0.id) } } }
        if kind == .mistake { TextField("科目", text: $subject) }
        TextField(kind == .plan ? "计划名称" : kind == .mistake ? "题目" : "作业标题", text: $title)
        TextField(kind == .plan ? "计划说明" : kind == .mistake ? "题目内容" : "作业要求", text: $content, axis: .vertical).lineLimit(3...10)
        if kind == .homework { DatePicker("截止时间", selection: $dueAt); Toggle("立即发布", isOn: $publish) }
        if kind == .mistake { TextField("正确答案", text: $answer, axis: .vertical); TextField("错因分析", text: $analysis, axis: .vertical) }
        if let error { Text(error).foregroundStyle(Color.ctDanger) }
    }.navigationTitle(titleText).toolbar { ToolbarItem(placement: .cancellationAction) { Button("取消") { dismiss() } }; ToolbarItem(placement: .confirmationAction) { Button("保存") { Task { await save() } }.disabled(title.isEmpty || (kind == .homework && classId.isEmpty)) } } } }
    private var titleText: String { switch kind { case .homework: "新建作业"; case .plan: "新建学习计划"; case .mistake: "录入错题" } }
    @MainActor private func save() async { do { let r = ClassTraceRepository(client: dependencies.client); switch kind { case .homework: _ = try await r.createHomework(classId: classId, title: title, content: content, dueAt: dueAt, publish: publish); case .plan: _ = try await r.createPlan(studentId: studentId.nilIfEmpty, title: title, description: content.nilIfEmpty); case .mistake: _ = try await r.createMistake(studentId: studentId.nilIfEmpty, subject: subject.nilIfEmpty, title: title, content: content.nilIfEmpty, answer: answer.nilIfEmpty, analysis: analysis.nilIfEmpty) }; await onSaved(); dismiss() } catch { self.error = error.localizedDescription } }
}

struct HomeworkDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AppDependencies.self) private var dependencies
    let homework: APIHomework; let students: [APIStudent]; let onSaved: () async -> Void
    @State private var details: APIHomework?
    @State private var title: String; @State private var content: String; @State private var status: String; @State private var studentId = ""; @State private var submission = ""; @State private var error: String?
    init(homework: APIHomework, students: [APIStudent], onSaved: @escaping () async -> Void) { self.homework = homework; self.students = students; self.onSaved = onSaved; _title = State(initialValue: homework.title); _content = State(initialValue: homework.content); _status = State(initialValue: homework.status) }
    var body: some View { Form {
        Section("作业") { TextField("标题", text: $title); TextField("要求", text: $content, axis: .vertical); Picker("状态", selection: $status) { Text("草稿").tag("DRAFT"); Text("已发布").tag("PUBLISHED"); Text("已截止").tag("CLOSED") }; Button("保存修改") { Task { await update() } } }
        Section("提交作业") { Picker("学生", selection: $studentId) { Text("请选择").tag(""); ForEach(students) { Text($0.name).tag($0.id) } }; TextField("作业内容", text: $submission, axis: .vertical); Button("提交") { Task { await submit() } }.disabled(studentId.isEmpty) }
        if let rows = details?.submissions { Section("学生提交") { ForEach(rows) { row in VStack(alignment: .leading) { Text(row.student?.name ?? "学生").font(.headline); Text(row.content ?? "无文字内容"); Text(row.status.localizedStatus).font(.caption) }; HStack { Button("通过") { Task { await review(row.id, "REVIEWED") } }; Button("退回") { Task { await review(row.id, "RETURNED") } } } } } }
        if let error { Text(error).foregroundStyle(Color.ctDanger) }
        Button("删除作业", role: .destructive) { Task { await remove() } }
    }.navigationTitle("作业详情").task { await reload() } }
    @MainActor private func reload() async { details = try? await ClassTraceRepository(client: dependencies.client).homeworkDetail(homework.id) }
    @MainActor private func update() async { do { _ = try await ClassTraceRepository(client: dependencies.client).updateHomework(homework.id, title: title, content: content, status: status); await onSaved(); await reload() } catch { self.error = error.localizedDescription } }
    @MainActor private func submit() async { do { _ = try await ClassTraceRepository(client: dependencies.client).submitHomework(homework.id, studentId: studentId, content: submission.nilIfEmpty); await onSaved(); await reload() } catch { self.error = error.localizedDescription } }
    @MainActor private func review(_ id: String, _ status: String) async { do { _ = try await ClassTraceRepository(client: dependencies.client).reviewSubmission(id, status: status, score: nil, comment: nil); await onSaved(); await reload() } catch { self.error = error.localizedDescription } }
    @MainActor private func remove() async { do { try await ClassTraceRepository(client: dependencies.client).deleteHomework(homework.id); await onSaved(); dismiss() } catch { self.error = error.localizedDescription } }
}

struct PlanDetailView: View {
    @Environment(\.dismiss) private var dismiss; @Environment(AppDependencies.self) private var dependencies
    let plan: APIStudyPlan; let onSaved: () async -> Void
    @State private var title: String; @State private var details: String; @State private var status: String; @State private var error: String?
    init(plan: APIStudyPlan, onSaved: @escaping () async -> Void) { self.plan = plan; self.onSaved = onSaved; _title = State(initialValue: plan.title); _details = State(initialValue: plan.description ?? ""); _status = State(initialValue: plan.status) }
    var body: some View { Form { TextField("计划名称", text: $title); TextField("说明", text: $details, axis: .vertical); Picker("状态", selection: $status) { Text("进行中").tag("ACTIVE"); Text("已完成").tag("COMPLETED"); Text("已归档").tag("ARCHIVED") }; Section("打卡历史") { ForEach(plan.checkIns ?? []) { Text($0.checkedAt.formatted(date: .abbreviated, time: .omitted)) } }; if let error { Text(error).foregroundStyle(Color.ctDanger) }; Button("保存") { Task { await save() } }; Button("删除计划", role: .destructive) { Task { await remove() } } }.navigationTitle("学习计划") }
    @MainActor private func save() async { do { _ = try await ClassTraceRepository(client: dependencies.client).updatePlan(plan.id, title: title, description: details.nilIfEmpty, status: status); await onSaved() } catch { self.error = error.localizedDescription } }
    @MainActor private func remove() async { do { try await ClassTraceRepository(client: dependencies.client).deletePlan(plan.id); await onSaved(); dismiss() } catch { self.error = error.localizedDescription } }
}

struct MistakeDetailView: View {
    @Environment(\.dismiss) private var dismiss; @Environment(AppDependencies.self) private var dependencies
    let mistake: APIMistake; let onSaved: () async -> Void
    @State private var subject: String; @State private var title: String; @State private var content: String; @State private var answer: String; @State private var analysis: String; @State private var error: String?
    init(mistake: APIMistake, onSaved: @escaping () async -> Void) { self.mistake = mistake; self.onSaved = onSaved; _subject = State(initialValue: mistake.subject ?? ""); _title = State(initialValue: mistake.title); _content = State(initialValue: mistake.content ?? ""); _answer = State(initialValue: mistake.answer ?? ""); _analysis = State(initialValue: mistake.analysis ?? "") }
    var body: some View { Form { TextField("科目", text: $subject); TextField("题目", text: $title); TextField("内容", text: $content, axis: .vertical); TextField("答案", text: $answer, axis: .vertical); TextField("分析", text: $analysis, axis: .vertical); if let error { Text(error).foregroundStyle(Color.ctDanger) }; Button("保存") { Task { await save() } }; if mistake.masteredAt == nil { Button("标记为已掌握") { Task { await mastered() } } }; Button("删除错题", role: .destructive) { Task { await remove() } } }.navigationTitle("错题详情") }
    @MainActor private func save() async { do { _ = try await ClassTraceRepository(client: dependencies.client).updateMistake(mistake.id, subject: subject.nilIfEmpty, title: title, content: content.nilIfEmpty, answer: answer.nilIfEmpty, analysis: analysis.nilIfEmpty); await onSaved() } catch { self.error = error.localizedDescription } }
    @MainActor private func mastered() async { do { _ = try await ClassTraceRepository(client: dependencies.client).markMistakeMastered(mistake.id); await onSaved() } catch { self.error = error.localizedDescription } }
    @MainActor private func remove() async { do { try await ClassTraceRepository(client: dependencies.client).deleteMistake(mistake.id); await onSaved(); dismiss() } catch { self.error = error.localizedDescription } }
}

struct MaterialUploadView: View {
    @Environment(\.dismiss) private var dismiss; @Environment(AppDependencies.self) private var dependencies
    let classes: [APIClassroom]; let onSaved: () async -> Void
    @State private var classId = ""; @State private var category = "课堂资料"; @State private var importing = false; @State private var error: String?
    private var allowedTypes: [UTType] {
        var types: [UTType] = [.image, .pdf]
        if let docx = UTType(filenameExtension: "docx") { types.append(docx) }
        if let doc = UTType(filenameExtension: "doc") { types.append(doc) }
        return types
    }
    var body: some View { NavigationStack { Form { Picker("班级（可选）", selection: $classId) { Text("公共资料").tag(""); ForEach(classes) { Text($0.name).tag($0.id) } }; TextField("分类", text: $category); Button("选择文件并上传", systemImage: "arrow.up.doc") { importing = true }; if let error { Text(error).foregroundStyle(Color.ctDanger) } }.navigationTitle("上传资料").toolbar { Button("完成") { dismiss() } }.fileImporter(isPresented: $importing, allowedContentTypes: allowedTypes) { result in Task { await upload(result) } } } }
    @Environment(\.dismiss) private var dismiss; @Environment(AppDependencies.self) private var dependencies
    let classes: [APIClassroom]; let onSaved: () async -> Void
    @State private var classId = ""; @State private var category = "课堂资料"; @State private var importing = false; @State private var error: String?
    var body: some View { NavigationStack { Form { Picker("班级（可选）", selection: $classId) { Text("公共资料").tag(""); ForEach(classes) { Text($0.name).tag($0.id) } }; TextField("分类", text: $category); Button("选择文件并上传", systemImage: "arrow.up.doc") { importing = true }; if let error { Text(error).foregroundStyle(Color.ctDanger) } }.navigationTitle("上传资料").toolbar { Button("完成") { dismiss() } }.fileImporter(isPresented: $importing, allowedContentTypes: [.image, .pdf, .word]) { result in Task { await upload(result) } } } }
    @MainActor private func upload(_ result: Result<URL, Error>) async { do { let url = try result.get(); guard url.startAccessingSecurityScopedResource() else { throw URLError(.noPermissionsToReadFile) }; defer { url.stopAccessingSecurityScopedResource() }; let data = try Data(contentsOf: url); let mime = UTType(filenameExtension: url.pathExtension)?.preferredMIMEType ?? "application/octet-stream"; let key = try await FileTransferService(client: dependencies.client).upload(data: data, fileName: url.lastPathComponent, mimeType: mime); _ = try await ClassTraceRepository(client: dependencies.client).createMaterial(classId: classId.nilIfEmpty, name: url.lastPathComponent, objectKey: key, mimeType: mime, sizeBytes: data.count, category: category.nilIfEmpty); await onSaved(); dismiss() } catch { self.error = error.localizedDescription } }
}
