import SwiftUI

struct ClassroomHubView: View {
    @Environment(AppDependencies.self) private var dependencies
    @Environment(AppSession.self) private var session
    @State private var classes: [APIClassroom] = []
    @State private var courses: [APICourse] = []
    @State private var students: [APIStudent] = []
    @State private var selection = 0
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var sheet: Sheet?
    enum Sheet: Identifiable { case newClass, newStudent, newCourse, join, bind; var id: Int { switch self { case .newClass: 0; case .newStudent: 1; case .newCourse: 2; case .join: 3; case .bind: 4 } } }
    private var isTeacher: Bool { session.activeRole == "TEACHER" }

    var body: some View {
        ScrollView(showsIndicators: false) {
            LazyVStack(spacing: 20) {
                MPPageHeader(greeting: "课程与班级", name: "教学安排") {
                    Menu {
                        if isTeacher {
                            Button("创建班级", systemImage: "person.3.fill") { sheet = .newClass }
                            Button("添加学生", systemImage: "person.badge.plus") { sheet = .newStudent }
                            Button("新建课程模板", systemImage: "books.vertical") { sheet = .newCourse }
                        } else {
                            Button("使用邀请码加入课程", systemImage: "link") { sheet = .join }
                            Button("绑定孩子", systemImage: "person.2.badge.gearshape") { sheet = .bind }
                        }
                    } label: {
                        Image(systemName: "plus").font(.system(size: 18, weight: .bold)).foregroundStyle(.white)
                            .frame(width: 42, height: 42).background(.white.opacity(0.18), in: Circle())
                    }
                }
                Picker("内容", selection: $selection) { Text("班级").tag(0); Text("学生").tag(1); Text("课程模板").tag(2) }
                    .pickerStyle(.segmented).padding(.horizontal, 16)
                if isLoading { ProgressView().tint(MPColor.blue).padding(.vertical, 80) }
                else if let errorMessage { MPCard { MPEmptyView(image: "null", title: "加载失败", detail: errorMessage) }.padding(.horizontal, 16) }
                else { content }
            }.padding(.bottom, 22)
        }
        .background(MPColor.page).toolbar(.hidden, for: .navigationBar)
        .sheet(item: $sheet) { item in switch item { case .newClass: ClassEditorView(courses: courses) { await load() }; case .newStudent: CreateStudentSheet { await load() }; case .newCourse: NavigationStack { CourseEditorView { await load() } }; case .join: ParentCourseAddView(students: students) { await load() }; case .bind: BindStudentSheet { await load() } } }
        .refreshable { await load() }.task { if classes.isEmpty && students.isEmpty { await load() } }
    }
    @ViewBuilder private var content: some View {
        if selection == 0 {
            VStack(spacing: 12) {
                NavigationLink { ScheduleCalendarView() } label: {
                    MPCard { HStack(spacing: 12) { MPIconTile(image: "timetable-blue", color: MPColor.blue, size: 48); VStack(alignment: .leading, spacing: 4) { Text("我的课表").font(.system(size: 16, weight: .semibold)); Text("按周或按月查看全部课程安排").font(.system(size: 12)).foregroundStyle(MPColor.secondary) }; Spacer(); Image(systemName: "chevron.right").font(.caption.bold()).foregroundStyle(MPColor.secondary) } }
                }.buttonStyle(.plain)
                MPSectionHeader(title: "进行中的班级 (\(classes.count))")
                if classes.isEmpty { MPCard { MPEmptyView(image: "class", title: "还没有班级", detail: "教师可以创建班级，家长可以使用邀请码加入") } }
                else { ForEach(classes) { item in classCard(item) } }
            }.padding(.horizontal, 16)
        } else if selection == 1 {
            VStack(spacing: 12) {
                MPSectionHeader(title: "学生管理 (\(students.count))")
                if students.isEmpty { MPCard { MPEmptyView(image: "student", title: "还没有学生", detail: "创建学生档案后即可加入班级") } }
                else { MPCard { VStack(spacing: 0) { ForEach(students) { item in MPMenuRow(title: "\(item.name) · \(item.grade ?? "未填写年级")", image: item.gender == "FEMALE" ? "girl" : "boy", color: MPColor.green) { StudentEditorView(student: item) { await load() } } } } } }
            }.padding(.horizontal, 16)
        } else {
            VStack(spacing: 12) {
                MPSectionHeader(title: "课程模板 (\(courses.count))")
                if courses.isEmpty { MPCard { MPEmptyView(image: "book", title: "还没有课程模板", detail: "创建班级时可以直接填写课程信息") } }
                else { MPCard { VStack(spacing: 0) { ForEach(courses) { item in MPMenuRow(title: "\(item.name) · \(item.subject ?? "未分类")", image: "book", color: MPColor.gold) { CourseEditorView(course: item) { await load() } } } } } }
            }.padding(.horizontal, 16)
        }
    }

    private func classCard(_ item: APIClassroom) -> some View {
        NavigationLink { ClassroomDetailView(classId: item.id) } label: {
            MPCard {
                HStack(spacing: 14) {
                    MPIconTile(image: "class-blue", color: MPColor.blue, size: 56)
                    VStack(alignment: .leading, spacing: 7) {
                        HStack { Text(item.name).font(.system(size: 17, weight: .semibold)); Text(item.status.localizedStatus).font(.system(size: 11, weight: .medium)).foregroundStyle(MPColor.green).padding(.horizontal, 8).padding(.vertical, 3).background(MPColor.green.opacity(0.13), in: Capsule()) }
                        Text("\(item.classType.localizedStatus) · \(item.billingMode == "PREPAID" ? "预付课时" : "现金记账")").font(.system(size: 13)).foregroundStyle(MPColor.secondary)
                        if let location = item.location { Text(location).font(.system(size: 12)).foregroundStyle(MPColor.secondary) }
                    }
                    Spacer(); Image(systemName: "chevron.right").font(.caption.bold()).foregroundStyle(MPColor.secondary)
                }
            }
        }.buttonStyle(.plain)
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
    var body: some View { NavigationStack { Form { TextField("监护人邀请码", text: $code); TextField("与孩子的关系", text: $relationship); if let error { Text(error).foregroundStyle(Color.ctDanger) } }.mpFormChrome().navigationTitle("绑定孩子").toolbar { ToolbarItem(placement: .cancellationAction) { Button("取消") { dismiss() } }; ToolbarItem(placement: .confirmationAction) { Button("绑定") { Task { await save() } }.disabled(code.count < 8) } } } }
    @MainActor private func save() async { do { _ = try await ClassTraceRepository(client: dependencies.client).bindStudent(code: code, relationship: relationship.nilIfEmpty); await onSaved(); dismiss() } catch { self.error = error.localizedDescription } }
}
