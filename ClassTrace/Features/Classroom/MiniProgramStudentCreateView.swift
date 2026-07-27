import SwiftUI

struct MiniProgramStudentCreateView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AppDependencies.self) private var dependencies

    var linkAsGuardian = false
    let onSaved: () async -> Void

    @State private var name = ""
    @State private var grade = ""
    @State private var age = ""
    @State private var address = ""
    @State private var baseHours = ""
    @State private var remark = ""
    @State private var classes: [APIClassroom] = []
    @State private var selectedClassIds: Set<String> = []
    @State private var isLoading = true
    @State private var isSaving = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                LazyVStack(spacing: 12) {
                    formSection("学生信息", subtitle: "只保留建班和记课时需要的信息", icon: "identity") {
                        requiredField("学生姓名") {
                            inputBackground { TextField("请输入学生姓名", text: $name) }
                        }
                        HStack(alignment: .top, spacing: 10) {
                            formField("年级") {
                                inputBackground { TextField("如：三年级", text: $grade) }
                            }
                            formField("年龄") {
                                inputBackground {
                                    TextField("选填", text: $age)
                                        .keyboardType(.numberPad)
                                }
                            }
                        }
                        formField("地址") {
                            inputBackground { TextField("选填，便于上门或线下排课", text: $address) }
                        }
                    }

                    if !linkAsGuardian {
                        formSection("加入班级", subtitle: "选择后会同步建立班级成员和课时档案", icon: "class") {
                            formField("基础课时") {
                                inputBackground {
                                    TextField("预付班可填初始课时，现结班可填 0", text: $baseHours)
                                        .keyboardType(.decimalPad)
                                }
                            }
                            if isLoading {
                                ProgressView().tint(MPColor.blue).frame(maxWidth: .infinity).padding(.vertical, 20)
                            } else if classes.isEmpty {
                                Text("暂无班级，请先创建班级")
                                    .font(.system(size: 13)).foregroundStyle(MPColor.secondary)
                                    .frame(maxWidth: .infinity).padding(.vertical, 20)
                            } else {
                                VStack(spacing: 8) {
                                    ForEach(classes) { classroom in classSelectionRow(classroom) }
                                }
                            }
                        }
                    }

                    formSection("备注信息", subtitle: nil, icon: nil) {
                        TextField("选填，例如学习情况、排课偏好等", text: $remark, axis: .vertical)
                            .lineLimit(4...7)
                            .font(.system(size: 14))
                            .padding(12)
                            .background(MPColor.page, in: RoundedRectangle(cornerRadius: 7))
                    }

                    if linkAsGuardian {
                        HStack(alignment: .top, spacing: 8) {
                            Image(systemName: "info.circle.fill").foregroundStyle(MPColor.blue)
                            Text("保存后会把该学生档案绑定为你的孩子，后续可通过班级邀请码加入课程。")
                                .font(.system(size: 11)).foregroundStyle(MPColor.secondary).lineSpacing(3)
                            Spacer()
                        }
                        .padding(12)
                        .background(MPColor.blue.opacity(0.08), in: RoundedRectangle(cornerRadius: 9))
                        .padding(.horizontal, 16)
                    }

                    if let errorMessage {
                        Text(errorMessage).font(.system(size: 12)).foregroundStyle(MPColor.red)
                            .frame(maxWidth: .infinity, alignment: .leading).padding(.horizontal, 16)
                    }
                }
                .padding(.vertical, 12).padding(.bottom, 86)
            }
            .background(MPColor.page)
            .navigationTitle(linkAsGuardian ? "添加孩子" : "添加学生")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("取消") { dismiss() } } }
            .safeAreaInset(edge: .bottom) {
                VStack(spacing: 0) {
                    Button { Task { await save() } } label: {
                        Group {
                            if isSaving { ProgressView().tint(.white) }
                            else { Text("保存学生信息").font(.system(size: 15, weight: .semibold)) }
                        }
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity, minHeight: 50)
                        .background(MPColor.blue, in: Capsule())
                        .shadow(color: MPColor.blue.opacity(0.25), radius: 5, y: 2)
                    }
                    .buttonStyle(.plain).disabled(isSaving)
                    .padding(.horizontal, 16).padding(.top, 10).padding(.bottom, 8)

                    Text(linkAsGuardian
                         ? "提示：保存后可在孩子管理里继续完善资料。"
                         : "提示：学生加入班级后，可在学生管理里调整课时流水和查看上课记录。")
                        .font(.system(size: 10)).foregroundStyle(Color(red: 111 / 255, green: 132 / 255, blue: 152 / 255))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 16).padding(.vertical, 8)
                        .background(Color(red: 244 / 255, green: 248 / 255, blue: 251 / 255))
                }.background(.white)
            }
            .task { await loadClasses() }
        }
    }

    private func formSection<Content: View>(_ title: String, subtitle: String?, icon: String?, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 8) {
                if let icon { MPLegacyImage(name: icon, size: 18).opacity(0.75) }
                VStack(alignment: .leading, spacing: 3) {
                    Text(title).font(.system(size: 15, weight: .semibold)).foregroundStyle(MPColor.text)
                    if let subtitle { Text(subtitle).font(.system(size: 11)).foregroundStyle(Color(red: 138 / 255, green: 154 / 255, blue: 173 / 255)) }
                }
                Spacer()
            }
            content()
        }
        .padding(14)
        .background(.white, in: RoundedRectangle(cornerRadius: 8))
        .shadow(color: .black.opacity(0.035), radius: 6, y: 1)
        .padding(.horizontal, 16)
    }

    private func formField<Content: View>(_ label: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label).font(.system(size: 14)).foregroundStyle(Color(red: 85 / 255, green: 85 / 255, blue: 85 / 255))
            content()
        }.frame(maxWidth: .infinity, alignment: .leading)
    }

    private func requiredField<Content: View>(_ label: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 3) {
                Text(label).font(.system(size: 14)).foregroundStyle(Color(red: 85 / 255, green: 85 / 255, blue: 85 / 255))
                Text("*").foregroundStyle(MPColor.red)
            }
            content()
        }
    }

    private func inputBackground<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        content()
            .font(.system(size: 14)).padding(.horizontal, 12)
            .frame(maxWidth: .infinity, minHeight: 40, alignment: .leading)
            .background(Color(red: 245 / 255, green: 247 / 255, blue: 250 / 255), in: RoundedRectangle(cornerRadius: 7))
    }

    private func classSelectionRow(_ classroom: APIClassroom) -> some View {
        let selected = selectedClassIds.contains(classroom.id)
        return Button { toggleClass(classroom) } label: {
            HStack(spacing: 10) {
                Text(String(classroom.name.prefix(1)))
                    .font(.system(size: 13, weight: .bold)).foregroundStyle(.white)
                    .frame(width: 30, height: 30)
                    .background(
                        LinearGradient(colors: [MPColor.blue, Color(red: 155 / 255, green: 187 / 255, blue: 208 / 255)], startPoint: .topLeading, endPoint: .bottomTrailing),
                        in: RoundedRectangle(cornerRadius: 7)
                    )
                VStack(alignment: .leading, spacing: 3) {
                    Text(classroom.name).font(.system(size: 14, weight: .medium)).foregroundStyle(MPColor.text)
                    Text("\(classroom.billingMode == "CASH" ? "现结" : "预付") · 默认 \(classroom.hourSettings?.totalHours.doubleValue.compactNumber ?? "0") 课时")
                        .font(.system(size: 11)).foregroundStyle(Color(red: 138 / 255, green: 154 / 255, blue: 173 / 255))
                }
                Spacer()
                Circle()
                    .fill(selected ? MPColor.blue : .clear)
                    .frame(width: 22, height: 22)
                    .overlay(Circle().stroke(selected ? MPColor.blue : Color.black.opacity(0.15)))
                    .overlay {
                        if selected { Image(systemName: "checkmark").font(.system(size: 10, weight: .bold)).foregroundStyle(.white) }
                    }
            }
            .padding(10)
            .background(selected ? Color(red: 238 / 255, green: 246 / 255, blue: 251 / 255) : Color(red: 245 / 255, green: 247 / 255, blue: 250 / 255), in: RoundedRectangle(cornerRadius: 7))
            .overlay(RoundedRectangle(cornerRadius: 7).stroke(selected ? MPColor.blue : .clear))
        }.buttonStyle(.plain)
    }

    private func toggleClass(_ classroom: APIClassroom) {
        if selectedClassIds.contains(classroom.id) {
            selectedClassIds.remove(classroom.id)
        } else {
            selectedClassIds.insert(classroom.id)
            if baseHours.isEmpty, classroom.billingMode != "CASH", let defaultHours = classroom.hourSettings?.totalHours.doubleValue, defaultHours > 0 {
                baseHours = defaultHours.compactNumber
            }
        }
    }

    @MainActor private func loadClasses() async {
        guard !linkAsGuardian else { isLoading = false; return }
        isLoading = true
        defer { isLoading = false }
        do {
            classes = try await ClassTraceRepository(client: dependencies.client).classes()
            errorMessage = nil
        } catch {
            errorMessage = "班级加载失败：\(error.localizedDescription)"
        }
    }

    @MainActor private func save() async {
        errorMessage = nil
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { errorMessage = "请输入学生姓名"; return }
        if !linkAsGuardian, selectedClassIds.isEmpty { errorMessage = "请选择加入的班级"; return }
        let parsedAge: Int?
        if age.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            parsedAge = nil
        } else if let value = Int(age), value > 0, value < 100 {
            parsedAge = value
        } else {
            errorMessage = "请输入有效的年龄"
            return
        }
        let parsedHours: Double
        if baseHours.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            parsedHours = 0
        } else if let value = Double(baseHours), value >= 0 {
            parsedHours = value
        } else {
            errorMessage = "基础课时不能小于 0"
            return
        }

        isSaving = true
        defer { isSaving = false }
        do {
            let repository = ClassTraceRepository(client: dependencies.client)
            let student = try await repository.createStudent(
                name: trimmedName,
                grade: grade.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty,
                linkAsGuardian: linkAsGuardian,
                age: parsedAge,
                address: address.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty,
                remark: remark.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
            )
            for classId in selectedClassIds {
                guard let classroom = classes.first(where: { $0.id == classId }) else { continue }
                let initialHours = classroom.billingMode == "CASH" ? 0 : parsedHours
                let price = classroom.priceSettings?.price.doubleValue
                    ?? classroom.members?.first?.pricePerHour.doubleValue
                    ?? 0
                _ = try await repository.addMember(classId: classId, studentId: student.id, initialHours: initialHours, pricePerHour: price)
            }
            await onSaved()
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
