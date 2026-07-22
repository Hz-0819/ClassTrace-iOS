import SwiftUI

struct ScheduleCalendarView: View {
    @Environment(AppDependencies.self) private var dependencies
    @Environment(AppSession.self) private var appSession

    @State private var mode = 0
    @State private var anchor = Date()
    @State private var sessions: [APISession] = []
    @State private var classes: [APIClassroom] = []
    @State private var showAdd = false
    @State private var addDate = Date()
    @State private var selectedDate: Date?
    @State private var errorMessage: String?

    private var isTeacher: Bool { appSession.activeRole == "TEACHER" }

    var body: some View {
        VStack(spacing: 0) {
            viewSwitcher
            ScrollView(showsIndicators: false) {
                if mode == 0 { weekView } else { monthView }
            }
            .background(MPColor.page)
        }
        .background(MPColor.page)
        .navigationTitle("课程日程")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showAdd) {
            ScheduleQuickSessionView(classes: classes, initialDate: addDate) { await load() }
        }
        .task { await load() }
        .refreshable { await load() }
    }

    private var viewSwitcher: some View {
        HStack(spacing: 10) {
            scheduleModeButton("周日程", 0)
            scheduleModeButton("月日程", 1)
            if isTeacher {
                Button {
                    addDate = Date(); showAdd = true
                } label: {
                    Text("+课次").font(.system(size: 13, weight: .semibold)).foregroundStyle(.white)
                        .frame(width: 68, height: 38).background(MPColor.blue, in: RoundedRectangle(cornerRadius: 9))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 16).padding(.vertical, 10).background(.white)
    }

    private func scheduleModeButton(_ title: String, _ value: Int) -> some View {
        Button {
            mode = value
            selectedDate = nil
            Task { await load() }
        } label: {
            Text(title).font(.system(size: 14, weight: .semibold))
                .foregroundStyle(mode == value ? .white : MPColor.text)
                .frame(maxWidth: .infinity, minHeight: 38)
                .background(mode == value ? MPColor.blue : MPColor.page, in: RoundedRectangle(cornerRadius: 9))
        }
        .buttonStyle(.plain)
    }

    private var weekView: some View {
        LazyVStack(spacing: 14) {
            if isTeacher {
                Button {
                    addDate = Date(); showAdd = true
                } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("临时加课").font(.system(size: 15, weight: .semibold)).foregroundStyle(MPColor.text)
                            Text("上课时间不固定时，可直接添加一条具体课次").font(.system(size: 11)).foregroundStyle(MPColor.secondary)
                        }
                        Spacer(); Image(systemName: "plus.circle.fill").foregroundStyle(MPColor.blue)
                    }
                    .padding(15).background(.white, in: RoundedRectangle(cornerRadius: 16))
                }
                .buttonStyle(.plain)
            }

            periodNavigation(title: weekTitle, previous: -1, next: 1)

            ForEach(weekDays, id: \.self) { day in
                weekDaySection(day)
            }

            if let errorMessage {
                Text(errorMessage).font(.footnote).foregroundStyle(MPColor.red)
            }
        }
        .padding(16)
    }

    private func weekDaySection(_ day: Date) -> some View {
        let rows = sessionsForDay(day)
        let isToday = Calendar.current.isDateInToday(day)

        return VStack(spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text(day.formatted(.dateTime.weekday(.wide)))
                        .font(.system(size: 16, weight: .bold)).foregroundStyle(isToday ? MPColor.blue : MPColor.text)
                    Text(day.formatted(.dateTime.month().day()))
                        .font(.system(size: 11)).foregroundStyle(MPColor.secondary)
                }
                Spacer()
                if isToday {
                    Text("今天").font(.system(size: 10, weight: .semibold)).foregroundStyle(.white)
                        .padding(.horizontal, 9).padding(.vertical, 4).background(MPColor.blue, in: Capsule())
                }
            }
            .padding(15)

            Rectangle().fill(Color.black.opacity(0.05)).frame(height: 0.5)

            if rows.isEmpty {
                Text("暂无课程安排").font(.system(size: 12)).foregroundStyle(MPColor.secondary)
                    .frame(maxWidth: .infinity, minHeight: 54)
            } else {
                VStack(spacing: 0) {
                    ForEach(rows) { item in weekSessionRow(item) }
                }
            }
        }
        .background(isToday ? LinearGradient(colors: [.white, MPColor.blue.opacity(0.06)], startPoint: .topLeading, endPoint: .bottomTrailing) : LinearGradient(colors: [.white, .white], startPoint: .top, endPoint: .bottom))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(isToday ? MPColor.blue : .clear, lineWidth: 1.3))
        .shadow(color: .black.opacity(0.045), radius: 8, y: 2)
    }

    private func weekSessionRow(_ item: APISession) -> some View {
        NavigationLink { SessionDetailView(sessionId: item.id) } label: {
            HStack(alignment: .top, spacing: 12) {
                Circle().fill(classColor(item.classId)).frame(width: 9, height: 9).padding(.top, 8)
                VStack(spacing: 3) {
                    Text(item.startsAt.formatted(date: .omitted, time: .shortened)).font(.system(size: 13, weight: .semibold)).foregroundStyle(MPColor.text)
                    Rectangle().fill(MPColor.secondary.opacity(0.35)).frame(width: 1, height: 12)
                    Text(item.endsAt.formatted(date: .omitted, time: .shortened)).font(.system(size: 11)).foregroundStyle(MPColor.secondary)
                }
                .frame(width: 54)
                VStack(alignment: .leading, spacing: 6) {
                    Text(classroom(item.classId)?.name ?? item.classroom?.name ?? "课程")
                        .font(.system(size: 15, weight: .semibold)).foregroundStyle(MPColor.text)
                    Text("\(classroom(item.classId)?.location ?? "地点待定") · \(billableStudentCount(item))人")
                        .font(.system(size: 11)).foregroundStyle(MPColor.secondary)
                    Text(item.status == "COMPLETED" ? "已确认" : item.status == "CANCELLED" ? "已取消" : "待确认")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(statusColor(item))
                        .padding(.horizontal, 7).padding(.vertical, 3)
                        .background(statusColor(item).opacity(0.12), in: Capsule())
                }
                Spacer()
                if isTeacher && item.status != "COMPLETED" && item.status != "CANCELLED" {
                    Text("确认").font(.system(size: 11, weight: .semibold)).foregroundStyle(.white)
                        .padding(.horizontal, 10).padding(.vertical, 7).background(MPColor.blue, in: Capsule())
                }
            }
            .padding(14)
            .overlay(alignment: .bottom) { Rectangle().fill(Color.black.opacity(0.045)).frame(height: 0.5) }
        }
        .buttonStyle(.plain)
    }

    private var monthView: some View {
        LazyVStack(spacing: 15) {
            periodNavigation(title: anchor.formatted(.dateTime.year().month(.wide)), previous: -1, next: 1)
            monthStatsCard
            calendar
            if let selectedDate { selectedDayCard(selectedDate) }
            teachingSummary
        }
        .padding(16)
    }

    private var monthStatsCard: some View {
        let stats = monthStats
        return MPCard {
            HStack(alignment: .top, spacing: 14) {
                statsColumn(
                    icon: "time-blue", title: "小时统计",
                    first: ("已上", "\(stats.completedHours.compactNumber)h"),
                    second: ("待上", "\(stats.pendingHours.compactNumber)h"),
                    total: ("总课时", "\(stats.totalHours.compactNumber)h")
                )
                Rectangle().fill(Color.black.opacity(0.07)).frame(width: 0.5, height: 122)
                statsColumn(
                    icon: "wallet-brown", title: isTeacher ? "收入统计" : "开销统计",
                    first: (isTeacher ? "实际收入" : "实际开销", "¥\(stats.completedIncome.compactNumber)"),
                    second: (isTeacher ? "待收入" : "待开销", "¥\(stats.pendingIncome.compactNumber)"),
                    total: (isTeacher ? "总收入" : "总开销", "¥\(stats.totalIncome.compactNumber)")
                )
            }
        }
    }

    private func statsColumn(
        icon: String,
        title: String,
        first: (String, String),
        second: (String, String),
        total: (String, String)
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 7) {
                MPIconTile(image: icon, color: icon == "time-blue" ? MPColor.blue : MPColor.gold, size: 32)
                Text(title).font(.system(size: 14, weight: .bold)).foregroundStyle(MPColor.text)
            }
            statLine(first.0, first.1, MPColor.blue)
            statLine(second.0, second.1, MPColor.gold)
            statLine(total.0, total.1, MPColor.text)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func statLine(_ label: String, _ value: String, _ color: Color) -> some View {
        HStack {
            Text(label).font(.system(size: 10)).foregroundStyle(MPColor.secondary)
            Spacer(); Text(value).font(.system(size: 12, weight: .bold)).foregroundStyle(color)
        }
    }

    private var calendar: some View {
        VStack(spacing: 7) {
            LazyVGrid(columns: sevenColumns, spacing: 0) {
                ForEach(["日", "一", "二", "三", "四", "五", "六"], id: \.self) {
                    Text($0).font(.system(size: 11, weight: .semibold)).foregroundStyle(MPColor.secondary).frame(height: 30)
                }
            }
            LazyVGrid(columns: sevenColumns, spacing: 5) {
                ForEach(monthGridDays, id: \.self) { day in monthDayCell(day) }
            }
        }
        .padding(10).background(.white, in: RoundedRectangle(cornerRadius: 16))
    }

    private func monthDayCell(_ day: Date) -> some View {
        let info = dayMetrics(day)
        let currentMonth = Calendar.current.isDate(day, equalTo: anchor, toGranularity: .month)
        let isToday = Calendar.current.isDateInToday(day)

        return Button {
            selectedDate = day
            if isTeacher { addDate = day }
        } label: {
            VStack(spacing: 2) {
                Text(day.formatted(.dateTime.day()))
                    .font(.system(size: 12, weight: isToday ? .bold : .medium))
                    .foregroundStyle(isToday ? .white : currentMonth ? MPColor.text : MPColor.secondary.opacity(0.45))
                if info.hasCompleted {
                    HStack(spacing: 1) {
                        Text("已上").font(.system(size: 6, weight: .bold))
                        Text("\(info.completedHours.compactNumber)h").font(.system(size: 7, weight: .semibold))
                    }
                    .foregroundStyle(isToday ? .white : MPColor.blue)
                }
                if info.hasPending {
                    HStack(spacing: 1) {
                        Text("待上").font(.system(size: 6, weight: .bold))
                        Text("\(info.pendingHours.compactNumber)h").font(.system(size: 7, weight: .semibold))
                    }
                    .foregroundStyle(isToday ? .white : MPColor.gold)
                }
                if info.income > 0 {
                    Text("¥\(info.income.compactNumber)").font(.system(size: 7)).foregroundStyle(isToday ? .white.opacity(0.85) : MPColor.secondary)
                }
            }
            .frame(maxWidth: .infinity, minHeight: 61)
            .background(
                isToday ? AnyShapeStyle(LinearGradient(colors: [MPColor.blue, MPColor.blue.opacity(0.78)], startPoint: .topLeading, endPoint: .bottomTrailing)) : AnyShapeStyle(info.hasCourse ? MPColor.page : Color.clear),
                in: RoundedRectangle(cornerRadius: 9)
            )
        }
        .buttonStyle(.plain)
    }

    private func selectedDayCard(_ day: Date) -> some View {
        let rows = sessionsForDay(day)
        return VStack(spacing: 10) {
            HStack {
                Text(day.formatted(.dateTime.month().day().weekday(.wide))).font(.system(size: 15, weight: .bold)).foregroundStyle(MPColor.text)
                Spacer()
                if isTeacher {
                    Button("+ 添加课次") { addDate = day; showAdd = true }
                        .font(.system(size: 12, weight: .semibold)).foregroundStyle(MPColor.blue)
                }
            }
            if rows.isEmpty {
                Text("当天暂无课程").font(.system(size: 12)).foregroundStyle(MPColor.secondary).frame(maxWidth: .infinity, minHeight: 45)
            } else {
                ForEach(rows) { weekSessionRow($0) }
            }
        }
        .padding(15).background(.white, in: RoundedRectangle(cornerRadius: 16))
    }

    private var teachingSummary: some View {
        let stats = monthStats
        return VStack(alignment: .leading, spacing: 14) {
            Text(isTeacher ? "本月教学总结" : "本月上课总结")
                .font(.system(size: 17, weight: .bold)).foregroundStyle(.white)
            HStack {
                summaryMetric("总课时", stats.totalHours.compactNumber)
                summaryMetric("上课天数", "\(stats.studyDays)")
                summaryMetric("课程数", "\(stats.sessionCount)")
            }
        }
        .padding(18)
        .background(LinearGradient(colors: [Color(red: 201/255, green: 168/255, blue: 154/255), Color(red: 224/255, green: 196/255, blue: 180/255)], startPoint: .topLeading, endPoint: .bottomTrailing), in: RoundedRectangle(cornerRadius: 18))
        .shadow(color: MPColor.coral.opacity(0.24), radius: 10, y: 4)
    }

    private func summaryMetric(_ label: String, _ value: String) -> some View {
        VStack(spacing: 4) {
            Text(value).font(.system(size: 18, weight: .bold)).foregroundStyle(.white)
            Text(label).font(.system(size: 10)).foregroundStyle(.white.opacity(0.82))
        }
        .frame(maxWidth: .infinity)
    }

    private func periodNavigation(title: String, previous: Int, next: Int) -> some View {
        HStack {
            Button { move(previous) } label: { MPLegacyImage(name: "left", size: 16).frame(width: 38, height: 38) }
            Spacer(); Text(title).font(.system(size: 16, weight: .bold)).foregroundStyle(MPColor.text)
            Spacer(); Button { move(next) } label: { MPLegacyImage(name: "right", size: 16).frame(width: 38, height: 38) }
        }
        .padding(.horizontal, 10).padding(.vertical, 8).background(.white, in: RoundedRectangle(cornerRadius: 16))
    }

    private var sevenColumns: [GridItem] { Array(repeating: GridItem(.flexible(), spacing: 4), count: 7) }
    private var weekInterval: DateInterval { Calendar.current.dateInterval(of: .weekOfYear, for: anchor)! }
    private var weekDays: [Date] { (0..<7).compactMap { Calendar.current.date(byAdding: .day, value: $0, to: weekInterval.start) } }
    private var weekTitle: String {
        "\(weekInterval.start.formatted(.dateTime.month().day())) - \(weekInterval.end.addingTimeInterval(-1).formatted(.dateTime.month().day()))"
    }
    private var monthInterval: DateInterval { Calendar.current.dateInterval(of: .month, for: anchor)! }
    private var monthGridDays: [Date] {
        let weekday = Calendar.current.component(.weekday, from: monthInterval.start)
        let start = Calendar.current.date(byAdding: .day, value: -(weekday - 1), to: monthInterval.start) ?? monthInterval.start
        return (0..<42).compactMap { Calendar.current.date(byAdding: .day, value: $0, to: start) }
    }
    private var requestRange: DateInterval {
        if mode == 0 { return weekInterval }
        let days = monthGridDays
        let end = Calendar.current.date(byAdding: .day, value: 1, to: days.last ?? monthInterval.end) ?? monthInterval.end
        return DateInterval(start: days.first ?? monthInterval.start, end: end)
    }

    private func sessionsForDay(_ day: Date) -> [APISession] {
        sessions.filter { Calendar.current.isDate($0.startsAt, inSameDayAs: day) }.sorted { $0.startsAt < $1.startsAt }
    }
    private func classroom(_ id: String) -> APIClassroom? { classes.first { $0.id == id } }
    private func classColor(_ id: String) -> Color {
        switch classroom(id)?.color?.uppercased() {
        case "#6AA08A": MPColor.green
        case "#E8B4A8": MPColor.coral
        case "#D4A574": MPColor.gold
        case "#DC7878": MPColor.red
        default: MPColor.blue
        }
    }
    private func statusColor(_ item: APISession) -> Color {
        item.status == "COMPLETED" ? MPColor.green : item.status == "CANCELLED" ? MPColor.secondary : MPColor.gold
    }
    private func billableStudentCount(_ item: APISession) -> Int {
        if item.status == "COMPLETED" {
            let count = item.attendances?.filter { $0.status == "PRESENT" }.count ?? 0
            if count > 0 { return count }
        }
        return classroom(item.classId)?.members?.filter { $0.status == "APPROVED" }.count ?? 0
    }
    private func income(_ item: APISession) -> Double {
        let cls = classroom(item.classId)
        let price = cls?.priceSettings?.price.doubleValue ?? cls?.members?.first?.pricePerHour.doubleValue ?? 0
        return price * Double(billableStudentCount(item))
    }
    private func dayMetrics(_ day: Date) -> DayMetrics {
        let rows = sessionsForDay(day).filter { $0.status != "CANCELLED" }
        let completed = rows.filter { $0.status == "COMPLETED" }
        let pending = rows.filter { $0.status != "COMPLETED" }
        return DayMetrics(
            completedHours: completed.reduce(0) { $0 + $1.plannedHours.doubleValue },
            pendingHours: pending.reduce(0) { $0 + $1.plannedHours.doubleValue },
            income: rows.reduce(0) { $0 + income($1) }
        )
    }
    private var monthStats: MonthScheduleStats {
        let rows = sessions.filter { Calendar.current.isDate($0.startsAt, equalTo: anchor, toGranularity: .month) && $0.status != "CANCELLED" }
        let completed = rows.filter { $0.status == "COMPLETED" }
        let pending = rows.filter { $0.status != "COMPLETED" }
        return MonthScheduleStats(
            completedHours: completed.reduce(0) { $0 + $1.plannedHours.doubleValue },
            pendingHours: pending.reduce(0) { $0 + $1.plannedHours.doubleValue },
            completedIncome: completed.reduce(0) { $0 + income($1) },
            pendingIncome: pending.reduce(0) { $0 + income($1) },
            studyDays: Set(rows.map { Calendar.current.startOfDay(for: $0.startsAt) }).count,
            sessionCount: rows.count
        )
    }

    private func move(_ value: Int) {
        anchor = Calendar.current.date(byAdding: mode == 0 ? .weekOfYear : .month, value: value, to: anchor) ?? anchor
        selectedDate = nil
        Task { await load() }
    }

    @MainActor private func load() async {
        do {
            let repository = ClassTraceRepository(client: dependencies.client)
            async let sessionRequest = repository.sessions(from: requestRange.start, to: requestRange.end)
            async let classRequest = repository.classes()
            (sessions, classes) = try await (sessionRequest, classRequest)
            errorMessage = nil
        } catch { errorMessage = error.localizedDescription }
    }
}

private struct DayMetrics {
    let completedHours: Double
    let pendingHours: Double
    let income: Double
    var hasCompleted: Bool { completedHours > 0 }
    var hasPending: Bool { pendingHours > 0 }
    var hasCourse: Bool { hasCompleted || hasPending }
}

private struct MonthScheduleStats {
    let completedHours: Double
    let pendingHours: Double
    let completedIncome: Double
    let pendingIncome: Double
    let studyDays: Int
    let sessionCount: Int
    var totalHours: Double { completedHours + pendingHours }
    var totalIncome: Double { completedIncome + pendingIncome }
}

private struct ScheduleQuickSessionView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AppDependencies.self) private var dependencies
    let classes: [APIClassroom]
    let onSaved: () async -> Void

    @State private var classId = ""
    @State private var startsAt: Date
    @State private var duration = 60
    @State private var errorMessage: String?

    init(classes: [APIClassroom], initialDate: Date, onSaved: @escaping () async -> Void) {
        self.classes = classes
        self.onSaved = onSaved
        let hour = Calendar.current.component(.hour, from: Date())
        _startsAt = State(initialValue: Calendar.current.date(bySettingHour: max(hour + 1, 8), minute: 0, second: 0, of: initialDate) ?? initialDate)
        _classId = State(initialValue: classes.count == 1 ? classes[0].id : "")
    }

    var body: some View {
        NavigationStack {
            Form {
                Picker("班级", selection: $classId) {
                    Text("请选择").tag("")
                    ForEach(classes) { Text($0.name).tag($0.id) }
                }
                DatePicker("上课日期与时间", selection: $startsAt)
                Stepper("时长：\(duration) 分钟", value: $duration, in: 15...360, step: 15)
                if let location = classes.first(where: { $0.id == classId })?.location {
                    LabeledContent("上课地点", value: location)
                }
                if let errorMessage { Text(errorMessage).foregroundStyle(MPColor.red) }
            }
            .mpFormChrome().navigationTitle("新增课次")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("取消") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button("保存") { Task { await save() } }.disabled(classId.isEmpty) }
            }
        }
    }

    @MainActor private func save() async {
        do {
            _ = try await ClassTraceRepository(client: dependencies.client).createSession(
                classId: classId,
                startsAt: startsAt,
                endsAt: startsAt.addingTimeInterval(Double(duration * 60))
            )
            await onSaved(); dismiss()
        } catch { errorMessage = error.localizedDescription }
    }
}
