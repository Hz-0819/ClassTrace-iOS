import SwiftUI

struct MiniProgramClassCreateView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AppDependencies.self) private var dependencies

    let courses: [APICourse]
    let onSaved: () async -> Void

    @State private var className = ""
    @State private var courseId = ""
    @State private var classType = "SMALL_GROUP"
    @State private var billingMode = "PREPAID"
    @State private var color = "#7BA3C0"
    @State private var scheduleMode = "weekly"
    @State private var weeklySlots: [MPWeeklyScheduleSlot] = []
    @State private var dateSlots: [MPDateScheduleSlot] = []
    @State private var showScheduleInput = false
    @State private var selectedPreset = "weekdays"
    @State private var draftWeekdays: Set<Int> = [1, 2, 3, 4, 5]
    @State private var draftDate = Date()
    @State private var draftStart = Self.defaultTime(hour: 17)
    @State private var draftEnd = Self.defaultTime(hour: 18)
    @State private var location = ""
    @State private var startDate = Date()
    @State private var price = 0.0
    @State private var lessonDurationMinutes = 60
    @State private var totalHours = 20.0
    @State private var showCoursePicker = false
    @State private var isSaving = false
    @State private var errorMessage: String?

    private static let colors = ["#7BA3C0", "#E8B4A8", "#6AA08A", "#D4A574", "#B8A8C8", "#7AB8B0"]
    private static let weekdayNames = ["周一", "周二", "周三", "周四", "周五", "周六", "周日"]
    private static let weekdayEnglish = ["monday", "tuesday", "wednesday", "thursday", "friday", "saturday", "sunday"]

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                LazyVStack(spacing: 0) {
                    section("班级信息", "class-white") {
                        requiredField("班级名称") {
                            fieldBackground { TextField("例如：周末数学班A、小明一对一", text: $className) }
                        }
                        formField("科目模板") {
                            Button { showCoursePicker = true } label: {
                                fieldBackground {
                                    HStack {
                                        Text(selectedCourse?.name ?? "不关联科目模板")
                                            .foregroundStyle(selectedCourse == nil ? MPColor.secondary : MPColor.text)
                                        Spacer()
                                        Image(systemName: "chevron.right").font(.system(size: 12, weight: .semibold)).foregroundStyle(MPColor.secondary)
                                    }
                                }
                            }.buttonStyle(.plain)
                        }
                        choiceField(
                            "班级类型",
                            options: [("一对一", "ONE_ON_ONE"), ("小班课", "SMALL_GROUP")],
                            selection: $classType
                        )
                        choiceField(
                            "计费方式",
                            options: [("预付课费", "PREPAID"), ("现结课费", "CASH")],
                            selection: $billingMode,
                            required: true
                        )
                        Text(billingMode == "PREPAID" ? "学生预购课时，上课后自动扣减" : "不预存课时，每次上课后现结")
                            .font(.system(size: 12)).foregroundStyle(MPColor.secondary)
                        formField("主题色") {
                            HStack(spacing: 14) {
                                ForEach(Self.colors, id: \.self) { value in
                                    Button { color = value } label: {
                                        Circle()
                                            .fill(Color.theme.fromHex(value))
                                            .frame(width: 34, height: 34)
                                            .overlay {
                                                if color == value {
                                                    Circle().stroke(.white, lineWidth: 2)
                                                    Image(systemName: "checkmark").font(.system(size: 12, weight: .bold)).foregroundStyle(.white)
                                                }
                                            }
                                            .shadow(color: .black.opacity(0.10), radius: 3, y: 1)
                                            .scaleEffect(color == value ? 1.08 : 1)
                                    }.buttonStyle(.plain)
                                }
                            }
                        }
                    }

                    section("时间与地点", "time-white") {
                        requiredField("上课时间") {
                            HStack(spacing: 8) {
                                scheduleModeCard("weekly", "固定排课", "每周固定时间循环上课")
                                scheduleModeCard("flexible", "自由排课", "按具体日期逐次安排")
                            }
                            scheduleSummary
                            if showScheduleInput { schedulePicker }
                            else {
                                Button { showScheduleInput = true } label: {
                                    Label("添加上课时间", systemImage: "plus")
                                        .font(.system(size: 14, weight: .semibold))
                                        .foregroundStyle(MPColor.blue)
                                        .frame(maxWidth: .infinity, minHeight: 48)
                                        .overlay(RoundedRectangle(cornerRadius: 9).stroke(MPColor.blue, style: StrokeStyle(lineWidth: 1, dash: [5])))
                                }.buttonStyle(.plain)
                            }
                            if currentScheduleIsEmpty {
                                Text("请至少添加一个上课时间").font(.system(size: 12)).foregroundStyle(MPColor.secondary)
                            }
                        }
                        requiredField("上课地点") {
                            fieldBackground { TextField("例如：教室A301", text: $location) }
                        }
                        formField("开课日期") {
                            fieldBackground {
                                DatePicker("", selection: $startDate, displayedComponents: .date)
                                    .labelsHidden().frame(maxWidth: .infinity, alignment: .leading)
                            }
                        }
                    }

                    section("收费标准", "money") {
                        requiredField("单次课费（元/人）") {
                            numberField("例如：120", value: $price)
                            Text("小班课会按出勤学生人数累计收入").font(.system(size: 12)).foregroundStyle(MPColor.secondary)
                        }
                        requiredField("单次时长（分钟）") {
                            fieldBackground {
                                TextField("例如：90", value: $lessonDurationMinutes, format: .number)
                                    .keyboardType(.numberPad)
                            }
                            Text("课时余额仍按“次”扣减，这里用于记录每次课实际时长").font(.system(size: 12)).foregroundStyle(MPColor.secondary)
                        }
                        if billingMode == "PREPAID" {
                            requiredField("预付课时") { numberField("例如：30", value: $totalHours) }
                        }
                    }

                    HStack(alignment: .top, spacing: 9) {
                        Image(systemName: "lightbulb.fill").foregroundStyle(MPColor.gold)
                        Text("提示：创建后可继续添加学生、生成课表，并在课后确认上课扣减课时。")
                            .font(.system(size: 12)).foregroundStyle(MPColor.secondary).lineSpacing(4)
                        Spacer()
                    }
                    .padding(14)
                    .background(Color(red: 232 / 255, green: 244 / 255, blue: 253 / 255), in: RoundedRectangle(cornerRadius: 10))
                    .padding(.horizontal, 12).padding(.top, 2).padding(.bottom, 20)

                    if let errorMessage {
                        Text(errorMessage).font(.system(size: 12)).foregroundStyle(MPColor.red)
                            .frame(maxWidth: .infinity, alignment: .leading).padding(.horizontal, 16).padding(.bottom, 12)
                    }
                }
            }
            .background(Color(red: 245 / 255, green: 247 / 255, blue: 250 / 255))
            .navigationTitle("创建班级")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("取消") { dismiss() } } }
            .safeAreaInset(edge: .bottom) {
                Button { Task { await save() } } label: {
                    Group {
                        if isSaving { ProgressView().tint(.white) }
                        else { Text("保存").font(.system(size: 16, weight: .semibold)) }
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity, minHeight: 50)
                    .background(
                        LinearGradient(colors: [MPColor.blue, Color(red: 106 / 255, green: 146 / 255, blue: 175 / 255)], startPoint: .topLeading, endPoint: .bottomTrailing),
                        in: Capsule()
                    )
                }
                .buttonStyle(.plain).disabled(isSaving)
                .padding(.horizontal, 16).padding(.vertical, 10).background(.white)
            }
            .sheet(isPresented: $showCoursePicker) { coursePicker }
        }
    }

    private var selectedCourse: APICourse? { courses.first { $0.id == courseId } }
    private var currentScheduleIsEmpty: Bool { scheduleMode == "weekly" ? weeklySlots.isEmpty : dateSlots.isEmpty }

    private func section<Content: View>(_ title: String, _ icon: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                ZStack {
                    RoundedRectangle(cornerRadius: 6).fill(MPColor.blue.opacity(0.15))
                    MPLegacyImage(name: icon, size: 16)
                }.frame(width: 24, height: 24)
                Text(title).font(.system(size: 16, weight: .semibold)).foregroundStyle(MPColor.text)
                Spacer()
            }.padding(.horizontal, 16).padding(.vertical, 12)

            VStack(alignment: .leading, spacing: 16) { content() }
                .padding(16)
                .background(.white, in: RoundedRectangle(cornerRadius: 10))
                .shadow(color: .black.opacity(0.05), radius: 10, y: 2)
                .padding(.horizontal, 12)
        }.padding(.bottom, 16)
    }

    private func formField<Content: View>(_ label: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(label).font(.system(size: 14, weight: .medium)).foregroundStyle(MPColor.text)
            content()
        }
    }

    private func requiredField<Content: View>(_ label: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 3) {
                Text(label).font(.system(size: 14, weight: .medium)).foregroundStyle(MPColor.text)
                Text("*").font(.system(size: 14, weight: .semibold)).foregroundStyle(MPColor.red)
            }
            content()
        }
    }

    private func fieldBackground<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        content()
            .font(.system(size: 14))
            .padding(.horizontal, 12)
            .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
            .background(Color(red: 248 / 255, green: 249 / 255, blue: 250 / 255), in: RoundedRectangle(cornerRadius: 7))
    }

    private func numberField(_ placeholder: String, value: Binding<Double>) -> some View {
        fieldBackground {
            TextField(placeholder, value: value, format: .number)
                .keyboardType(.decimalPad)
        }
    }

    private func choiceField(_ label: String, options: [(String, String)], selection: Binding<String>, required: Bool = true) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 3) {
                Text(label).font(.system(size: 14, weight: .medium))
                if required { Text("*").foregroundStyle(MPColor.red) }
            }
            HStack(spacing: 12) {
                ForEach(options.indices, id: \.self) { index in
                    let option = options[index]
                    Button { selection.wrappedValue = option.1 } label: {
                        Text(option.0)
                            .font(.system(size: 14, weight: selection.wrappedValue == option.1 ? .semibold : .regular))
                            .foregroundStyle(selection.wrappedValue == option.1 ? MPColor.blue : MPColor.text)
                            .frame(maxWidth: .infinity, minHeight: 40)
                            .background(selection.wrappedValue == option.1 ? MPColor.blue.opacity(0.15) : MPColor.page, in: RoundedRectangle(cornerRadius: 7))
                            .overlay(RoundedRectangle(cornerRadius: 7).stroke(selection.wrappedValue == option.1 ? MPColor.blue : .clear))
                    }.buttonStyle(.plain)
                }
            }
        }
    }

    private func scheduleModeCard(_ value: String, _ title: String, _ detail: String) -> some View {
        Button {
            scheduleMode = value
            showScheduleInput = false
        } label: {
            VStack(alignment: .leading, spacing: 5) {
                Text(title).font(.system(size: 14, weight: .bold))
                Text(detail).font(.system(size: 11)).foregroundStyle(MPColor.secondary).fixedSize(horizontal: false, vertical: true)
            }
            .foregroundStyle(scheduleMode == value ? MPColor.blue : MPColor.text)
            .frame(maxWidth: .infinity, minHeight: 58, alignment: .leading)
            .padding(10)
            .background(
                scheduleMode == value
                    ? LinearGradient(colors: [MPColor.blue.opacity(0.16), Color.theme.cyan.opacity(0.08)], startPoint: .topLeading, endPoint: .bottomTrailing)
                    : LinearGradient(colors: [MPColor.page, MPColor.page], startPoint: .top, endPoint: .bottom),
                in: RoundedRectangle(cornerRadius: 10)
            )
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(scheduleMode == value ? MPColor.blue : .clear))
        }.buttonStyle(.plain)
    }

    @ViewBuilder private var scheduleSummary: some View {
        if scheduleMode == "weekly" {
            ForEach(weeklySlots) { slot in
                scheduleRow(
                    title: slot.weekdays.sorted().map { Self.weekdayNames[$0 - 1] }.joined(separator: "、"),
                    detail: "\(time(slot.startTime))-\(time(slot.endTime))"
                ) { weeklySlots.removeAll { $0.id == slot.id } }
            }
        } else {
            ForEach(dateSlots) { slot in
                scheduleRow(
                    title: slot.date.formatted(.dateTime.year().month().day().weekday(.wide)),
                    detail: "\(time(slot.startTime))-\(time(slot.endTime))"
                ) { dateSlots.removeAll { $0.id == slot.id } }
            }
        }
    }

    private func scheduleRow(_ title: String, detail: String, onDelete: @escaping () -> Void) -> some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(.system(size: 13, weight: .semibold)).foregroundStyle(MPColor.blue)
                Text(detail).font(.system(size: 12)).foregroundStyle(MPColor.text)
            }
            Spacer()
            Button(action: onDelete) {
                Image(systemName: "xmark")
                    .font(.system(size: 10, weight: .bold)).foregroundStyle(MPColor.red)
                    .frame(width: 28, height: 28).background(MPColor.red.opacity(0.12), in: Circle())
            }.buttonStyle(.plain)
        }
        .padding(11).background(MPColor.blue.opacity(0.10), in: RoundedRectangle(cornerRadius: 9))
    }

    private var schedulePicker: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text(scheduleMode == "weekly" ? "选择重复方式" : "添加具体课次").font(.system(size: 14, weight: .semibold))
                    Text(scheduleMode == "weekly" ? "可一次添加多个上课日" : "选择日期和时间，逐条加入课表")
                        .font(.system(size: 11)).foregroundStyle(MPColor.secondary)
                }
                Spacer()
            }

            if scheduleMode == "weekly" {
                HStack(spacing: 8) {
                    presetButton("weekdays", "工作日", "周一至周五")
                    presetButton("weekend", "周末", "周六、周日")
                    presetButton("custom", "自定义", "自由组合")
                }
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 7), count: 4), spacing: 8) {
                    ForEach(1...7, id: \.self) { day in
                        Button { toggleDraftDay(day) } label: {
                            Text(Self.weekdayNames[day - 1])
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(draftWeekdays.contains(day) ? .white : MPColor.text)
                                .frame(maxWidth: .infinity, minHeight: 34)
                                .background(draftWeekdays.contains(day) ? MPColor.blue : .white, in: Capsule())
                                .overlay(Capsule().stroke(draftWeekdays.contains(day) ? MPColor.blue : Color.black.opacity(0.08)))
                        }.buttonStyle(.plain)
                    }
                }
            } else {
                DatePicker("上课日期", selection: $draftDate, in: startDate..., displayedComponents: .date)
                    .font(.system(size: 13)).padding(11).background(.white, in: RoundedRectangle(cornerRadius: 9))
            }

            HStack(spacing: 8) {
                DatePicker("开始", selection: $draftStart, displayedComponents: .hourAndMinute)
                    .font(.system(size: 12)).padding(9).background(.white, in: RoundedRectangle(cornerRadius: 9))
                Text("-").foregroundStyle(MPColor.secondary)
                DatePicker("结束", selection: $draftEnd, displayedComponents: .hourAndMinute)
                    .font(.system(size: 12)).padding(9).background(.white, in: RoundedRectangle(cornerRadius: 9))
            }

            HStack {
                Spacer()
                Button("取消") { showScheduleInput = false }.foregroundStyle(MPColor.secondary)
                Button("确认") { confirmSchedule() }
                    .font(.system(size: 13, weight: .semibold)).foregroundStyle(.white)
                    .padding(.horizontal, 18).padding(.vertical, 8).background(MPColor.blue, in: RoundedRectangle(cornerRadius: 7))
            }.font(.system(size: 13))
        }
        .padding(12)
        .background(
            LinearGradient(colors: [Color(red: 247 / 255, green: 251 / 255, blue: 253 / 255), Color(red: 248 / 255, green: 249 / 255, blue: 250 / 255)], startPoint: .top, endPoint: .bottom),
            in: RoundedRectangle(cornerRadius: 12)
        )
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(MPColor.blue.opacity(0.18)))
    }

    private func presetButton(_ value: String, _ title: String, _ detail: String) -> some View {
        Button { applyPreset(value) } label: {
            VStack(alignment: .leading, spacing: 3) {
                Text(title).font(.system(size: 12, weight: .semibold))
                Text(detail).font(.system(size: 9)).foregroundStyle(MPColor.secondary)
            }
            .foregroundStyle(selectedPreset == value ? MPColor.blue : MPColor.text)
            .frame(maxWidth: .infinity, minHeight: 48, alignment: .leading)
            .padding(.horizontal, 8)
            .background(selectedPreset == value ? MPColor.blue.opacity(0.12) : .white, in: RoundedRectangle(cornerRadius: 9))
            .overlay(RoundedRectangle(cornerRadius: 9).stroke(selectedPreset == value ? MPColor.blue : .clear))
        }.buttonStyle(.plain)
    }

    private var coursePicker: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(spacing: 10) {
                    Button {
                        courseId = ""
                        showCoursePicker = false
                    } label: {
                        courseOption(name: "不关联科目模板", detail: "后续仍可补充课程内容", color: MPColor.secondary, selected: courseId.isEmpty)
                    }.buttonStyle(.plain)

                    ForEach(courses) { course in
                        Button {
                            courseId = course.id
                            showCoursePicker = false
                        } label: {
                            courseOption(
                                name: course.name,
                                detail: course.description ?? course.subject ?? "暂无描述",
                                color: Color.theme.fromHex(course.color ?? "#7BA3C0"),
                                selected: courseId == course.id
                            )
                        }.buttonStyle(.plain)
                    }
                    if courses.isEmpty {
                        MPEmptyView(image: "null", title: "暂无科目模板", detail: "可先创建模板，也可以后续补充")
                    }
                }.padding(16)
            }
            .background(MPColor.page)
            .navigationTitle("选择科目模板")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { Button("关闭") { showCoursePicker = false } }
        }
        .presentationDetents([.medium, .large])
    }

    private func courseOption(name: String, detail: String, color: Color, selected: Bool) -> some View {
        HStack(spacing: 12) {
            Text(String(name.prefix(1))).font(.system(size: 16, weight: .bold)).foregroundStyle(.white)
                .frame(width: 38, height: 38).background(color, in: RoundedRectangle(cornerRadius: 9))
            VStack(alignment: .leading, spacing: 4) {
                Text(name).font(.system(size: 15, weight: .semibold)).foregroundStyle(MPColor.text)
                Text(detail).font(.system(size: 11)).foregroundStyle(MPColor.secondary).lineLimit(1)
            }
            Spacer()
            if selected {
                Image(systemName: "checkmark").font(.system(size: 11, weight: .bold)).foregroundStyle(.white)
                    .frame(width: 24, height: 24).background(MPColor.blue, in: Circle())
            }
        }
        .padding(12)
        .background(selected ? MPColor.blue.opacity(0.10) : Color(red: 248 / 255, green: 249 / 255, blue: 250 / 255), in: RoundedRectangle(cornerRadius: 10))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(selected ? MPColor.blue : .clear))
    }

    private func applyPreset(_ value: String) {
        selectedPreset = value
        switch value {
        case "weekdays": draftWeekdays = [1, 2, 3, 4, 5]
        case "weekend": draftWeekdays = [6, 7]
        default: draftWeekdays = []
        }
    }

    private func toggleDraftDay(_ day: Int) {
        selectedPreset = "custom"
        if draftWeekdays.contains(day) { draftWeekdays.remove(day) }
        else { draftWeekdays.insert(day) }
    }

    private func confirmSchedule() {
        guard draftEnd > draftStart else {
            errorMessage = "结束时间必须晚于开始时间"
            return
        }
        if scheduleMode == "weekly" {
            guard !draftWeekdays.isEmpty else {
                errorMessage = "请至少选择一个上课日"
                return
            }
            weeklySlots.append(MPWeeklyScheduleSlot(weekdays: draftWeekdays, startTime: draftStart, endTime: draftEnd))
        } else {
            dateSlots.append(MPDateScheduleSlot(date: draftDate, startTime: draftStart, endTime: draftEnd))
        }
        errorMessage = nil
        showScheduleInput = false
    }

    @MainActor private func save() async {
        errorMessage = nil
        guard !className.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { errorMessage = "请输入班级名称"; return }
        guard !location.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { errorMessage = "请输入上课地点"; return }
        guard !currentScheduleIsEmpty else { errorMessage = "请至少添加一个上课时间"; return }
        guard price > 0 else { errorMessage = "请输入有效的单次课费"; return }
        guard lessonDurationMinutes > 0 else { errorMessage = "请输入有效的单次时长"; return }
        guard billingMode != "PREPAID" || totalHours > 0 else { errorMessage = "请输入有效的预付课时"; return }

        isSaving = true
        defer { isSaving = false }
        do {
            let repository = ClassTraceRepository(client: dependencies.client)
            let items = scheduleItems
            let schedule = APIClassSchedule(
                mode: scheduleMode,
                text: items.map(scheduleLabel).joined(separator: "、"),
                days: items.compactMap(\.dayEn),
                items: items
            )
            let classroom = try await repository.createClass(
                name: className.trimmingCharacters(in: .whitespacesAndNewlines),
                type: classType,
                billingMode: billingMode,
                location: location.trimmingCharacters(in: .whitespacesAndNewlines),
                courseId: courseId.nilIfEmpty,
                schedule: schedule,
                price: price,
                totalHours: billingMode == "PREPAID" ? totalHours : 0,
                lessonDurationMinutes: lessonDurationMinutes,
                startDate: startDate,
                color: color
            )
            if scheduleMode == "weekly" {
                let end = Calendar.current.date(byAdding: .month, value: 6, to: startDate) ?? startDate
                for slot in weeklySlots {
                    _ = try await repository.generateSessions(
                        classId: classroom.id,
                        from: startDate,
                        to: end,
                        weekdays: slot.weekdays.sorted(),
                        startTime: time(slot.startTime),
                        durationMinutes: minutes(slot.startTime, slot.endTime)
                    )
                }
            } else {
                for slot in dateSlots {
                    let values = dateRange(slot)
                    _ = try await repository.createSession(classId: classroom.id, startsAt: values.start, endsAt: values.end)
                }
            }
            await onSaved()
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private var scheduleItems: [APIClassScheduleItem] {
        if scheduleMode == "weekly" {
            return weeklySlots.flatMap { slot in
                slot.weekdays.sorted().map { day in
                    APIClassScheduleItem(
                        id: UUID().uuidString,
                        day: Self.weekdayNames[day - 1],
                        dayEn: Self.weekdayEnglish[day - 1],
                        date: nil,
                        startTime: time(slot.startTime),
                        endTime: time(slot.endTime),
                        time: "\(time(slot.startTime))-\(time(slot.endTime))"
                    )
                }
            }
        }
        return dateSlots.map { slot in
            APIClassScheduleItem(
                id: UUID().uuidString,
                day: slot.date.formatted(.dateTime.weekday(.wide)),
                dayEn: nil,
                date: dateText(slot.date),
                startTime: time(slot.startTime),
                endTime: time(slot.endTime),
                time: "\(time(slot.startTime))-\(time(slot.endTime))"
            )
        }
    }

    private func scheduleLabel(_ item: APIClassScheduleItem) -> String {
        item.date.map { "\($0) \(item.startTime)-\(item.endTime)" }
            ?? "\(item.day ?? "") \(item.startTime)-\(item.endTime)"
    }

    private func dateRange(_ slot: MPDateScheduleSlot) -> (start: Date, end: Date) {
        let calendar = Calendar.current
        let startParts = calendar.dateComponents([.hour, .minute], from: slot.startTime)
        let endParts = calendar.dateComponents([.hour, .minute], from: slot.endTime)
        let start = calendar.date(bySettingHour: startParts.hour ?? 0, minute: startParts.minute ?? 0, second: 0, of: slot.date) ?? slot.date
        let end = calendar.date(bySettingHour: endParts.hour ?? 0, minute: endParts.minute ?? 0, second: 0, of: slot.date) ?? start.addingTimeInterval(3600)
        return (start, end)
    }

    private func time(_ value: Date) -> String {
        value.formatted(.dateTime.hour(.twoDigits(amPM: .omitted)).minute(.twoDigits))
    }

    private func dateText(_ value: Date) -> String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: value)
    }

    private func minutes(_ start: Date, _ end: Date) -> Int {
        max(15, Int(end.timeIntervalSince(start) / 60))
    }

    private static func defaultTime(hour: Int) -> Date {
        Calendar.current.date(bySettingHour: hour, minute: 0, second: 0, of: Date()) ?? Date()
    }
}

private struct MPWeeklyScheduleSlot: Identifiable {
    let id = UUID()
    let weekdays: Set<Int>
    let startTime: Date
    let endTime: Date
}

private struct MPDateScheduleSlot: Identifiable {
    let id = UUID()
    let date: Date
    let startTime: Date
    let endTime: Date
}
