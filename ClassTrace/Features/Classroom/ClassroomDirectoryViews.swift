import SwiftUI

struct StudentDirectoryView: View {
    @Environment(AppDependencies.self) private var dependencies
    @State private var students: [APIStudent] = []
    @State private var showCreate = false
    @State private var errorMessage: String?

    var body: some View {
        ScrollView(showsIndicators: false) {
            LazyVStack(spacing: 14) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("学生管理").font(.system(size: 25, weight: .bold)).foregroundStyle(MPColor.text)
                        Text("共 \(students.count) 名学生").font(.system(size: 12)).foregroundStyle(MPColor.secondary)
                    }
                    Spacer()
                    Button { showCreate = true } label: {
                        Image(systemName: "plus").font(.system(size: 16, weight: .bold)).foregroundStyle(.white)
                            .frame(width: 40, height: 40).background(MPColor.blue, in: Circle())
                    }
                }
                .padding(.horizontal, 18).padding(.top, 10)

                if students.isEmpty {
                    MPCard { MPEmptyView(image: "student", title: "暂无学生", detail: "添加学生后可管理班级、课时和考勤") }
                        .padding(.horizontal, 16)
                } else {
                    ForEach(students) { item in
                        NavigationLink { StudentProfileView(studentId: item.id) } label: {
                            MPCard {
                                HStack(spacing: 13) {
                                    MPIconTile(image: item.gender?.uppercased() == "FEMALE" ? "girl" : "boy", color: MPColor.green, size: 50)
                                    VStack(alignment: .leading, spacing: 5) {
                                        Text(item.name).font(.system(size: 16, weight: .semibold)).foregroundStyle(MPColor.text)
                                        Text("\(item.grade ?? "未填写年级") · \(item.classMembers?.count ?? 0) 个班级")
                                            .font(.system(size: 12)).foregroundStyle(MPColor.secondary)
                                    }
                                    Spacer()
                                    MPLegacyImage(name: "right", size: 14).opacity(0.45)
                                }
                            }
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal, 16)
                }

                if let errorMessage { Text(errorMessage).font(.footnote).foregroundStyle(MPColor.red).padding(.horizontal, 16) }
            }
            .padding(.bottom, 20)
        }
        .background(MPColor.page)
        .navigationTitle("学生管理")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showCreate) { StudentCreateView { await load() } }
        .task { await load() }
        .refreshable { await load() }
    }

    @MainActor private func load() async {
        do {
            students = try await ClassTraceRepository(client: dependencies.client).students()
            errorMessage = nil
        } catch { errorMessage = error.localizedDescription }
    }
}

struct ChildrenDirectoryView: View {
    @Environment(AppDependencies.self) private var dependencies
    @State private var students: [APIStudent] = []
    @State private var sheet: Sheet?
    private enum Sheet: Int, Identifiable { case create, bind; var id: Int { rawValue } }

    var body: some View {
        ScrollView(showsIndicators: false) {
            LazyVStack(spacing: 14) {
                MPCard {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("我的孩子").font(.system(size: 22, weight: .bold)).foregroundStyle(MPColor.text)
                        Text("孩子档案会关联课程、课时、作业和学习记录").font(.system(size: 12)).foregroundStyle(MPColor.secondary)
                    }
                }
                .padding(.horizontal, 16).padding(.top, 12)

                ForEach(students) { child in
                    NavigationLink { StudentProfileView(studentId: child.id) } label: {
                        MPCard {
                            HStack(spacing: 13) {
                                MPIconTile(image: child.gender?.uppercased() == "FEMALE" ? "girl" : "boy", color: MPColor.coral, size: 52)
                                VStack(alignment: .leading, spacing: 5) {
                                    Text(child.name).font(.system(size: 16, weight: .semibold)).foregroundStyle(MPColor.text)
                                    Text("\(child.grade ?? "暂无年级") · \(child.classMembers?.count ?? 0) 个班级/课程")
                                        .font(.system(size: 12)).foregroundStyle(MPColor.secondary)
                                }
                                Spacer(); MPLegacyImage(name: "right", size: 14).opacity(0.45)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 16)

                Button { sheet = .create } label: {
                    HStack(spacing: 12) {
                        Image(systemName: "plus").font(.system(size: 18, weight: .bold)).foregroundStyle(MPColor.blue)
                            .frame(width: 46, height: 46).background(MPColor.blue.opacity(0.12), in: RoundedRectangle(cornerRadius: 13))
                        VStack(alignment: .leading, spacing: 4) {
                            Text("添加孩子").font(.system(size: 15, weight: .semibold)).foregroundStyle(MPColor.text)
                            Text("录入孩子信息，查看课程与课时").font(.system(size: 12)).foregroundStyle(MPColor.secondary)
                        }
                        Spacer()
                    }
                    .padding(16).background(.white, in: RoundedRectangle(cornerRadius: 16))
                }
                .buttonStyle(.plain).padding(.horizontal, 16)
            }
            .padding(.bottom, 20)
        }
        .background(MPColor.page)
        .navigationTitle("孩子管理")
        .toolbar { Button("绑定") { sheet = .bind } }
        .sheet(item: $sheet) { item in
            switch item {
            case .create: StudentCreateView(linkAsGuardian: true) { await load() }
            case .bind: GuardianBindView { await load() }
            }
        }
        .task { await load() }
    }

    @MainActor private func load() async {
        students = (try? await ClassTraceRepository(client: dependencies.client).students()) ?? []
    }
}

struct HourArchiveView: View {
    @Environment(AppDependencies.self) private var dependencies
    @State private var classes: [APIClassroom] = []
    @State private var entries: [APIHourEntry] = []

    private var recharge: Double { entries.filter { $0.delta.doubleValue > 0 }.reduce(0) { $0 + $1.delta.doubleValue } }
    private var consumed: Double { abs(entries.filter { $0.delta.doubleValue < 0 }.reduce(0) { $0 + $1.delta.doubleValue }) }

    var body: some View {
        ScrollView(showsIndicators: false) {
            LazyVStack(spacing: 16) {
                MPCard {
                    HStack {
                        archiveMetric("累计充值", recharge.compactNumber, MPColor.green)
                        Rectangle().fill(Color.black.opacity(0.07)).frame(width: 0.5, height: 44)
                        archiveMetric("累计消耗", consumed.compactNumber, MPColor.coral)
                        Rectangle().fill(Color.black.opacity(0.07)).frame(width: 0.5, height: 44)
                        archiveMetric("记录数", "\(entries.count)", MPColor.blue)
                    }
                }
                .padding(.horizontal, 16).padding(.top, 12)

                VStack(spacing: 12) {
                    MPSectionHeader(title: "班级课时档案")
                    ForEach(classes) { item in
                        NavigationLink { HourLedgerView(classId: item.id) } label: {
                            MPCard {
                                HStack(spacing: 12) {
                                    MPIconTile(image: "bill-green", color: MPColor.green, size: 48)
                                    VStack(alignment: .leading, spacing: 5) {
                                        Text(item.name).font(.system(size: 16, weight: .semibold)).foregroundStyle(MPColor.text)
                                        Text("\(item.members?.count ?? 0) 名学生 · 剩余 \(remainingHours(item).compactNumber) 课时")
                                            .font(.system(size: 12)).foregroundStyle(MPColor.secondary)
                                    }
                                    Spacer(); MPLegacyImage(name: "right", size: 14).opacity(0.45)
                                }
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 16)
            }
            .padding(.bottom, 20)
        }
        .background(MPColor.page)
        .navigationTitle("课时档案")
        .task { await load() }
        .refreshable { await load() }
    }

    private func archiveMetric(_ title: String, _ value: String, _ color: Color) -> some View {
        VStack(spacing: 5) {
            Text(value).font(.system(size: 20, weight: .bold)).foregroundStyle(color)
            Text(title).font(.system(size: 10)).foregroundStyle(MPColor.secondary)
        }
        .frame(maxWidth: .infinity)
    }
    private func remainingHours(_ item: APIClassroom) -> Double {
        item.members?.reduce(0) { $0 + $1.remainingHours.doubleValue } ?? 0
    }
    @MainActor private func load() async {
        let repository = ClassTraceRepository(client: dependencies.client)
        async let classRequest = try? repository.classes()
        async let ledgerRequest = try? repository.hourLedger()
        classes = await classRequest ?? []
        entries = await ledgerRequest ?? []
    }
}

private struct StudentCreateView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AppDependencies.self) private var dependencies
    var linkAsGuardian = false
    let onSaved: () async -> Void
    @State private var name = ""
    @State private var grade = ""
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            Form {
                Section("基本信息") {
                    TextField("学生姓名", text: $name)
                    TextField("年级", text: $grade)
                }
                Toggle("同时绑定为我的孩子", isOn: .constant(linkAsGuardian)).disabled(true)
                if let errorMessage { Text(errorMessage).foregroundStyle(MPColor.red) }
            }
            .mpFormChrome().navigationTitle("添加学生")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("取消") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button("保存") { Task { await save() } }.disabled(name.isEmpty) }
            }
        }
    }

    @MainActor private func save() async {
        do {
            _ = try await ClassTraceRepository(client: dependencies.client).createStudent(name: name, grade: grade.nilIfEmpty, linkAsGuardian: linkAsGuardian)
            await onSaved(); dismiss()
        } catch { errorMessage = error.localizedDescription }
    }
}

private struct GuardianBindView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AppDependencies.self) private var dependencies
    let onSaved: () async -> Void
    @State private var code = ""
    @State private var relationship = "家长"
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            Form {
                Section("监护人邀请码") {
                    TextField("请输入 8 位邀请码", text: $code).textInputAutocapitalization(.characters)
                    TextField("与孩子的关系", text: $relationship)
                }
                if let errorMessage { Text(errorMessage).foregroundStyle(MPColor.red) }
            }
            .mpFormChrome().navigationTitle("绑定孩子")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("取消") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button("绑定") { Task { await save() } }.disabled(code.count < 8) }
            }
        }
    }

    @MainActor private func save() async {
        do {
            _ = try await ClassTraceRepository(client: dependencies.client).bindStudent(code: code, relationship: relationship.nilIfEmpty)
            await onSaved(); dismiss()
        } catch { errorMessage = error.localizedDescription }
    }
}
