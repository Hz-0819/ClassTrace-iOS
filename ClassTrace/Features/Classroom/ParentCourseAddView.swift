import SwiftUI

struct ParentCourseAddView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AppDependencies.self) private var dependencies

    let students: [APIStudent]
    let onSaved: () async -> Void

    @State private var tab = 0
    @State private var inviteCode = ""
    @State private var studentId = ""
    @State private var name = ""
    @State private var teacherName = ""
    @State private var classType = "ONE_ON_ONE"
    @State private var totalHours = 30.0
    @State private var price = 0.0
    @State private var weekday = 1
    @State private var startTime = Date()
    @State private var endTime = Date().addingTimeInterval(3600)
    @State private var isSaving = false
    @State private var error: String?

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 18) {
                    Picker("添加方式", selection: $tab) {
                        Text("邀请码加入").tag(0)
                        Text("手动添加").tag(1)
                    }
                    .pickerStyle(.segmented)

                    MPCard {
                        VStack(alignment: .leading, spacing: 18) {
                            if tab == 0 {
                                field("课程邀请码", "请输入老师提供的邀请码", $inviteCode)
                            } else {
                                field("课程名称", "如：钢琴课", $name)
                                field("老师姓名", "如：王老师", $teacherName)
                                choice(
                                    "课程类型",
                                    [("一对一", "ONE_ON_ONE"), ("小班课", "SMALL_GROUP")],
                                    $classType
                                )
                                number("总课时数", $totalHours)
                                number("单节价格（可选）", $price)

                                VStack(alignment: .leading, spacing: 8) {
                                    Text("上课时间").formLabel()
                                    Picker("星期", selection: $weekday) {
                                        ForEach(1...7, id: \.self) {
                                            Text(ClassEditorView.weekdayNames[$0 - 1]).tag($0)
                                        }
                                    }
                                    .pickerStyle(.menu)

                                    HStack {
                                        DatePicker("开始", selection: $startTime, displayedComponents: .hourAndMinute)
                                        DatePicker("结束", selection: $endTime, displayedComponents: .hourAndMinute)
                                    }
                                    .font(.caption)
                                }
                            }

                            VStack(alignment: .leading, spacing: 8) {
                                Text("选择孩子").formLabel()
                                Picker("选择孩子", selection: $studentId) {
                                    Text("请选择").tag("")
                                    ForEach(students) { Text($0.name).tag($0.id) }
                                }
                                .pickerStyle(.menu)
                                .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                                .padding(.horizontal, 12)
                                .background(MPColor.page, in: RoundedRectangle(cornerRadius: 9))
                            }
                        }
                    }

                    if let error {
                        Text(error)
                            .font(.footnote)
                            .foregroundStyle(MPColor.red)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .padding(16)
            }
            .background(MPColor.page)
            .navigationTitle("添加课程")
            .navigationBarTitleDisplayMode(.inline)
            .safeAreaInset(edge: .bottom) {
                Button { Task { await save() } } label: {
                    HStack {
                        if isSaving { ProgressView().tint(.white) }
                        Text(tab == 0 ? "提交申请" : "保存课程")
                    }
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity, minHeight: 50)
                    .background(MPColor.blue, in: Capsule())
                }
                .buttonStyle(.plain)
                .disabled(isSaving || studentId.isEmpty)
                .padding(.horizontal, 20)
                .padding(.vertical, 10)
                .background(.white)
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
            }
        }
    }

    @MainActor
    private func save() async {
        error = nil
        isSaving = true
        defer { isSaving = false }

        do {
            let repository = ClassTraceRepository(client: dependencies.client)
            if tab == 0 {
                guard !inviteCode.isEmpty else { throw ParentCourseError.missingFields }
                _ = try await repository.joinClass(inviteCode: inviteCode, studentId: studentId)
            } else {
                guard !name.isEmpty,
                      !teacherName.isEmpty,
                      endTime > startTime,
                      totalHours > 0
                else { throw ParentCourseError.missingFields }

                let start = time(startTime)
                let end = time(endTime)
                let item = APIClassScheduleItem(
                    id: UUID().uuidString,
                    day: ClassEditorView.weekdayNames[weekday - 1],
                    dayEn: ClassEditorView.weekdayEnglish[weekday - 1],
                    date: nil,
                    startTime: start,
                    endTime: end,
                    time: "\(start)-\(end)"
                )
                let schedule = APIClassSchedule(
                    mode: "weekly",
                    text: "\(item.day ?? "") \(start)-\(end)",
                    days: [item.dayEn ?? ""],
                    items: [item]
                )
                let classroom = try await repository.createClass(
                    name: name,
                    type: classType,
                    billingMode: "PREPAID",
                    location: nil,
                    schedule: schedule,
                    price: price,
                    totalHours: totalHours,
                    lessonDurationMinutes: durationMinutes(start, end),
                    startDate: Date(),
                    teacherName: teacherName
                )
                _ = try await repository.addMember(
                    classId: classroom.id,
                    studentId: studentId,
                    initialHours: totalHours,
                    pricePerHour: price
                )
                let until = Calendar.current.date(byAdding: .month, value: 6, to: Date()) ?? Date()
                _ = try await repository.generateSessions(
                    classId: classroom.id,
                    from: Date(),
                    to: until,
                    weekdays: [weekday],
                    startTime: start,
                    durationMinutes: durationMinutes(start, end)
                )
            }
            await onSaved()
            dismiss()
        } catch {
            self.error = error.localizedDescription
        }
    }

    private func field(_ label: String, _ placeholder: String, _ text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(label).formLabel()
            TextField(placeholder, text: text)
                .padding(.horizontal, 12)
                .frame(height: 46)
                .background(MPColor.page, in: RoundedRectangle(cornerRadius: 9))
        }
    }

    private func number(_ label: String, _ value: Binding<Double>) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(label).formLabel()
            TextField("0", value: value, format: .number)
                .keyboardType(.decimalPad)
                .padding(.horizontal, 12)
                .frame(height: 46)
                .background(MPColor.page, in: RoundedRectangle(cornerRadius: 9))
        }
    }

    private func choice(
        _ label: String,
        _ options: [(String, String)],
        _ value: Binding<String>
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(label).formLabel()
            HStack {
                ForEach(options.indices, id: \.self) { index in
                    Button { value.wrappedValue = options[index].1 } label: {
                        Text(options[index].0)
                            .frame(maxWidth: .infinity, minHeight: 40)
                            .background(
                                value.wrappedValue == options[index].1
                                    ? MPColor.blue.opacity(0.14)
                                    : MPColor.page,
                                in: RoundedRectangle(cornerRadius: 9)
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private func time(_ value: Date) -> String {
        value.formatted(.dateTime.hour(.twoDigits(amPM: .omitted)).minute(.twoDigits))
    }

    private func durationMinutes(_ start: String, _ end: String) -> Int {
        let startParts = start.split(separator: ":").compactMap { Int($0) }
        let endParts = end.split(separator: ":").compactMap { Int($0) }
        guard startParts.count == 2, endParts.count == 2 else { return 60 }
        return max(15, endParts[0] * 60 + endParts[1] - startParts[0] * 60 - startParts[1])
    }
}

private extension Text {
    func formLabel() -> some View {
        font(.system(size: 14, weight: .medium)).foregroundStyle(MPColor.text)
    }
}

private enum ParentCourseError: LocalizedError {
    case missingFields

    var errorDescription: String? {
        "请完整填写必填信息，并确认结束时间晚于开始时间"
    }
}
