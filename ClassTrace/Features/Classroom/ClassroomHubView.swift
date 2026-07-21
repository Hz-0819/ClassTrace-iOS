import SwiftUI

struct ClassroomHubView: View {
    @Environment(AppDependencies.self) private var dependencies
    @State private var classes: [APIClassroom] = []
    @State private var courses: [APICourse] = []
    @State private var students: [APIStudent] = []
    @State private var selection = 0
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var sheet: Sheet?
    enum Sheet: Identifiable { case newClass, newStudent, newCourse, join, bind; var id: Int { switch self { case .newClass: 0; case .newStudent: 1; case .newCourse: 2; case .join: 3; case .bind: 4 } } }

    var body: some View {
        VStack(spacing: 0) {
            Picker("内容", selection: $selection) { Text("班级").tag(0); Text("学生").tag(1); Text("课程").tag(2) }.pickerStyle(.segmented).padding()
            if isLoading { Spacer(); ProgressView(); Spacer() }
            else if let errorMessage { CTStateView(kind: .error, title: "加载失败", message: LocalizedStringKey(errorMessage), actionTitle: "重试") { Task { await load() } } }
            else { content }
        }
        .background(Color.ctPage).navigationTitle("班级与学生")
        .toolbar { ToolbarItem(placement: .topBarTrailing) { Menu { Button("创建班级", systemImage: "person.3.fill") { sheet = .newClass }; Button("添加学生", systemImage: "person.badge.plus") { sheet = .newStudent }; Button("新建课程", systemImage: "books.vertical") { sheet = .newCourse }; Button("班级邀请码加入", systemImage: "link") { sheet = .join }; Button("绑定孩子", systemImage: "person.2.badge.gearshape") { sheet = .bind } } label: { Image(systemName: "plus.circle.fill") } } }
        .sheet(item: $sheet) { item in switch item { case .newClass: CreateClassSheet { await load() }; case .newStudent: CreateStudentSheet { await load() }; case .newCourse: NavigationStack { CourseEditorView { await load() } }; case .join: JoinClassSheet(students: students) { await load() }; case .bind: BindStudentSheet { await load() } } }
        .refreshable { await load() }.task { if classes.isEmpty && students.isEmpty { await load() } }
    }
    @ViewBuilder private var content: some View {
        if selection == 0 {
            if classes.isEmpty { CTStateView(kind: .empty, title: "还没有班级", message: "教师可以创建班级，家长可以使用邀请码加入") }
            else { List(classes) { item in NavigationLink { ClassroomDetailView(classId: item.id) } label: { VStack(alignment: .leading) { Text(item.name).font(.headline); Text("\(item.classType.localizedStatus) · \(item.billingMode == "PREPAID" ? "预付课时" : "现金记账")").foregroundStyle(Color.ctTextSecondary) } } }.listStyle(.plain) }
        } else if selection == 1 {
            if students.isEmpty { CTStateView(kind: .empty, title: "还没有学生", message: "创建学生档案后即可加入班级") }
            else { List(students) { item in NavigationLink { StudentEditorView(student: item) { await load() } } label: { VStack(alignment: .leading) { Text(item.name).font(.headline); Text(item.grade ?? "未填写年级").foregroundStyle(Color.ctTextSecondary) } } }.listStyle(.plain) }
        } else {
            if courses.isEmpty { CTStateView(kind: .empty, title: "还没有课程模板", message: "创建班级时可以直接填写课程信息") }
            else { List(courses) { item in NavigationLink { CourseEditorView(course: item) { await load() } } label: { VStack(alignment: .leading) { Text(item.name).font(.headline); Text(item.subject ?? "未分类").foregroundStyle(Color.ctTextSecondary) } } }.listStyle(.plain) }
        }
    }
    @MainActor private func load() async {
        isLoading = true; defer { isLoading = false }; errorMessage = nil
        let repository = ClassTraceRepository(client: dependencies.client)
        do { async let c = repository.classes(); async let s = repository.students(); async let o = repository.courses(); (classes, students, courses) = try await (c, s, o) }
        catch { errorMessage = error.localizedDescription }
    }
}

private struct CreateClassSheet: View {
    @Environment(\.dismiss) private var dismiss; @Environment(AppDependencies.self) private var dependencies
    @State private var name = ""; @State private var type = "SMALL_GROUP"; @State private var billing = "PREPAID"; @State private var location = ""; @State private var error: String?
    let onSaved: () async -> Void
    var body: some View { NavigationStack { Form { TextField("班级名称", text: $name); Picker("班型", selection: $type) { Text("一对一").tag("ONE_ON_ONE"); Text("小班").tag("SMALL_GROUP") }; Picker("计费", selection: $billing) { Text("预付课时").tag("PREPAID"); Text("现金记账").tag("CASH") }; TextField("地点", text: $location); if let error { Text(error).foregroundStyle(Color.ctDanger) } }.navigationTitle("创建班级").toolbar { ToolbarItem(placement: .cancellationAction) { Button("取消") { dismiss() } }; ToolbarItem(placement: .confirmationAction) { Button("保存") { Task { await save() } }.disabled(name.isEmpty) } } } }
    @MainActor private func save() async { do { _ = try await ClassTraceRepository(client: dependencies.client).createClass(name: name, type: type, billingMode: billing, location: location.isEmpty ? nil : location); await onSaved(); dismiss() } catch { self.error = error.localizedDescription } }
}
private struct CreateStudentSheet: View {
    @Environment(\.dismiss) private var dismiss; @Environment(AppDependencies.self) private var dependencies
    @State private var name = ""; @State private var grade = ""; @State private var link = true; @State private var error: String?; let onSaved: () async -> Void
    var body: some View { NavigationStack { Form { TextField("学生姓名", text: $name); TextField("年级", text: $grade); Toggle("同时绑定为我的孩子", isOn: $link); if let error { Text(error).foregroundStyle(Color.ctDanger) } }.navigationTitle("添加学生").toolbar { ToolbarItem(placement: .cancellationAction) { Button("取消") { dismiss() } }; ToolbarItem(placement: .confirmationAction) { Button("保存") { Task { await save() } }.disabled(name.isEmpty) } } } }
    @MainActor private func save() async { do { _ = try await ClassTraceRepository(client: dependencies.client).createStudent(name: name, grade: grade.isEmpty ? nil : grade, linkAsGuardian: link); await onSaved(); dismiss() } catch { self.error = error.localizedDescription } }
}
private struct JoinClassSheet: View {
    @Environment(\.dismiss) private var dismiss; @Environment(AppDependencies.self) private var dependencies
    let students: [APIStudent]; let onSaved: () async -> Void; @State private var code = ""; @State private var studentId = ""; @State private var error: String?
    var body: some View { NavigationStack { Form { TextField("班级邀请码", text: $code).textInputAutocapitalization(.characters); Picker("选择孩子", selection: $studentId) { Text("请选择").tag(""); ForEach(students) { Text($0.name).tag($0.id) } }; if let error { Text(error).foregroundStyle(Color.ctDanger) } }.navigationTitle("加入班级").toolbar { ToolbarItem(placement: .cancellationAction) { Button("取消") { dismiss() } }; ToolbarItem(placement: .confirmationAction) { Button("申请加入") { Task { await save() } }.disabled(code.isEmpty || studentId.isEmpty) } } } }
    @MainActor private func save() async { do { _ = try await ClassTraceRepository(client: dependencies.client).joinClass(inviteCode: code, studentId: studentId); await onSaved(); dismiss() } catch { self.error = error.localizedDescription } }
}

private struct BindStudentSheet: View {
    @Environment(\.dismiss) private var dismiss; @Environment(AppDependencies.self) private var dependencies
    let onSaved: () async -> Void; @State private var code = ""; @State private var relationship = "家长"; @State private var error: String?
    var body: some View { NavigationStack { Form { TextField("监护人邀请码", text: $code); TextField("与孩子的关系", text: $relationship); if let error { Text(error).foregroundStyle(Color.ctDanger) } }.navigationTitle("绑定孩子").toolbar { ToolbarItem(placement: .cancellationAction) { Button("取消") { dismiss() } }; ToolbarItem(placement: .confirmationAction) { Button("绑定") { Task { await save() } }.disabled(code.count < 12) } } } }
    @MainActor private func save() async { do { _ = try await ClassTraceRepository(client: dependencies.client).bindStudent(code: code, relationship: relationship.nilIfEmpty); await onSaved(); dismiss() } catch { self.error = error.localizedDescription } }
}
