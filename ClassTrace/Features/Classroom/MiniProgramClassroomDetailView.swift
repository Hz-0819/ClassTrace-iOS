import SwiftUI

struct ClassroomDetailView: View {
    @Environment(AppDependencies.self) private var dependencies
    @Environment(AppSession.self) private var appSession
    @Environment(\.openURL) private var openURL

    let classId: String
    @State private var classroom: APIClassroom?
    @State private var materials: [APIMaterial] = []
    @State private var students: [APIStudent] = []
    @State private var activeTab = 0
    @State private var errorMessage: String?
    @State private var showNewSession = false
    @State private var showAddMember = false
    @State private var showGenerateSchedule = false
    @State private var showUpload = false

    private var isTeacher: Bool { appSession.activeRole == "TEACHER" }

    var body: some View {
        Group {
            if let classroom {
                ScrollView(showsIndicators: false) {
                    LazyVStack(spacing: 18) {
                        courseHeader(classroom)
                        tabSection(classroom)
                        quickActions(classroom)
                        timelineSection(classroom)
                    }
                    .padding(.bottom, 22)
                }
                .background(MPColor.page)
            } else if let errorMessage {
                CTStateView(kind: .error, title: "加载失败", message: LocalizedStringKey(errorMessage), actionTitle: "重试") {
                    Task { await load() }
                }
            } else {
                ProgressView().tint(MPColor.blue)
            }
        }
        .navigationTitle(classroom?.name ?? "班级详情")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if isTeacher {
                Menu {
                    Button("添加课次", systemImage: "calendar.badge.plus") { showNewSession = true }
                    Button("按周批量排课", systemImage: "calendar") { showGenerateSchedule = true }
                    Button("添加学生", systemImage: "person.badge.plus") { showAddMember = true }
                    Button("上传班级资料", systemImage: "arrow.up.doc") { showUpload = true }
                    if let classroom {
                        NavigationLink("班级设置") { ClassSettingsView(classroom: classroom) { await load() } }
                    }
                } label: { Image(systemName: "ellipsis.circle") }
            }
        }
        .sheet(isPresented: $showNewSession) { CreateClassSessionView(classId: classId) { await load() } }
        .sheet(isPresented: $showAddMember) { AddClassMemberView(classId: classId, students: students) { await load() } }
        .sheet(isPresented: $showGenerateSchedule) { ClassGenerateScheduleView(classId: classId) { await load() } }
        .sheet(isPresented: $showUpload) {
            if let classroom { MaterialUploadView(classes: [classroom]) { await load() } }
        }
        .refreshable { await load() }
        .task { if classroom == nil { await load() } }
    }

    private func courseHeader(_ item: APIClassroom) -> some View {
        let completed = completedHours(item)
        let total = totalHours(item)
        let progress = total > 0 ? min(completed / total, 1) : 0
        let tint = classColor(item)

        return ZStack {
            LinearGradient(colors: [tint, tint.opacity(0.72)], startPoint: .topLeading, endPoint: .bottomTrailing)
            Circle().fill(.white.opacity(0.10)).frame(width: 150, height: 150).offset(x: 150, y: -55)
            Circle().fill(.white.opacity(0.08)).frame(width: 90, height: 90).offset(x: -170, y: 55)

            VStack(spacing: 18) {
                HStack(spacing: 14) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 15).fill(.white.opacity(0.22))
                        Text(String(item.name.prefix(1))).font(.system(size: 23, weight: .bold)).foregroundStyle(.white)
                    }
                    .frame(width: 58, height: 58)
                    VStack(alignment: .leading, spacing: 5) {
                        Text(item.name).font(.system(size: 22, weight: .bold)).foregroundStyle(.white)
                        Text(item.teacherName ?? "教师").font(.system(size: 12)).foregroundStyle(.white.opacity(0.85))
                        Text("\(item.classType.localizedStatus) · \(item.members?.count ?? 0)人")
                            .font(.system(size: 11)).foregroundStyle(.white.opacity(0.78))
                    }
                    Spacer()
                }

                VStack(spacing: 8) {
                    HStack {
                        Text(item.billingMode == "CASH" ? "累计上课" : "课程进度")
                            .font(.system(size: 12)).foregroundStyle(.white.opacity(0.82))
                        Spacer()
                        Text(item.billingMode == "CASH" ? "\(completedSessions(item)) 次" : "\(completed.compactNumber)/\(total.compactNumber)节")
                            .font(.system(size: 13, weight: .bold)).foregroundStyle(.white)
                    }
                    if item.billingMode != "CASH" {
                        GeometryReader { proxy in
                            ZStack(alignment: .leading) {
                                Capsule().fill(.white.opacity(0.22))
                                Capsule().fill(.white).frame(width: proxy.size.width * progress)
                            }
                        }
                        .frame(height: 7)
                    }
                }
            }
            .padding(20)
        }
        .frame(height: 200)
        .clipShape(UnevenRoundedRectangle(bottomLeadingRadius: 26, bottomTrailingRadius: 26))
    }

    private func tabSection(_ item: APIClassroom) -> some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                detailTab("班级信息", 0)
                detailTab("班级资料", 1)
            }
            .padding(.horizontal, 8).background(.white)

            if activeTab == 0 { informationTab(item) } else { materialTab(item) }
        }
        .background(.white, in: RoundedRectangle(cornerRadius: 16))
        .padding(.horizontal, 16)
    }

    private func detailTab(_ title: String, _ value: Int) -> some View {
        Button { activeTab = value } label: {
            VStack(spacing: 10) {
                Text(title).font(.system(size: 14, weight: activeTab == value ? .bold : .medium))
                    .foregroundStyle(activeTab == value ? MPColor.blue : MPColor.secondary)
                Rectangle().fill(activeTab == value ? MPColor.blue : .clear).frame(height: 2)
            }
            .padding(.top, 14).frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
    }

    private func informationTab(_ item: APIClassroom) -> some View {
        VStack(spacing: 18) {
            infoBlock("基本信息") {
                infoRow("上课时间", item.schedule?.text ?? "待设置")
                infoRow("上课地点", item.location ?? "待安排")
                infoRow("授课类型", item.classType.localizedStatus)
                infoRow("学生人数", "\(item.members?.count ?? 0) 人")
                infoRow("邀请码", item.inviteCode)
                if isTeacher {
                    ShareLink(item: item.inviteCode) {
                        HStack {
                            VStack(alignment: .leading, spacing: 3) {
                                Text("邀请家长加入班级").font(.system(size: 13, weight: .semibold)).foregroundStyle(MPColor.text)
                                Text("分享后家长可通过邀请码加入这个班级").font(.system(size: 10)).foregroundStyle(MPColor.secondary)
                            }
                            Spacer(); Text("分享").font(.system(size: 12, weight: .semibold)).foregroundStyle(.white)
                                .padding(.horizontal, 13).padding(.vertical, 7).background(MPColor.blue, in: Capsule())
                        }
                        .padding(12).background(MPColor.blue.opacity(0.08), in: RoundedRectangle(cornerRadius: 12))
                    }
                }
            }
            infoBlock("收费信息") {
                infoRow("计费方式", item.billingMode == "CASH" ? "现结课费" : "预付课费")
                infoRow("单次课费", "\(price(item).compactNumber) 元/次/人")
                infoRow("单次时长", "\(item.lessonDurationMinutes ?? 60) 分钟")
                if item.billingMode != "CASH" { infoRow("预付课时", "\(totalHours(item).compactNumber) 次") }
            }
        }
        .padding(16)
    }

    private func infoBlock<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(spacing: 12) {
            MPSectionHeader(title: title)
            VStack(spacing: 11) { content() }
        }
    }

    private func infoRow(_ title: String, _ value: String) -> some View {
        HStack(alignment: .top) {
            Text(title).font(.system(size: 12)).foregroundStyle(MPColor.secondary).frame(width: 70, alignment: .leading)
            Spacer()
            Text(value).font(.system(size: 13, weight: .medium)).foregroundStyle(MPColor.text).multilineTextAlignment(.trailing)
        }
    }

    private func materialTab(_ item: APIClassroom) -> some View {
        VStack(spacing: 12) {
            if isTeacher {
                Button { showUpload = true } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("班级共享资料").font(.system(size: 15, weight: .bold)).foregroundStyle(MPColor.text)
                            Text("上传讲义、课件和练习，家长可在班级内查看").font(.system(size: 10)).foregroundStyle(MPColor.secondary)
                        }
                        Spacer(); Label("上传", systemImage: "plus").font(.system(size: 12, weight: .semibold)).foregroundStyle(MPColor.blue)
                    }
                    .padding(12).background(MPColor.blue.opacity(0.08), in: RoundedRectangle(cornerRadius: 12))
                }
                .buttonStyle(.plain)
            }

            if materials.isEmpty {
                MPEmptyView(image: "material-brown", title: "暂无班级资料", detail: isTeacher ? "上传共享资料或课后资料后会在这里汇总" : "老师上传的班级资料会显示在这里")
                    .padding(.vertical, 10)
            } else {
                ForEach(materials) { material in
                    HStack(spacing: 12) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 11).fill(MPColor.coral.opacity(0.14))
                            Text(materialType(material)).font(.system(size: 9, weight: .bold)).foregroundStyle(MPColor.coral)
                        }
                        .frame(width: 44, height: 44)
                        VStack(alignment: .leading, spacing: 4) {
                            Text(material.name).font(.system(size: 13, weight: .semibold)).foregroundStyle(MPColor.text).lineLimit(1)
                            Text("来源：\(material.category ?? "班级资料") · \(fileSize(material.sizeBytes))")
                                .font(.system(size: 10)).foregroundStyle(MPColor.secondary)
                        }
                        Spacer()
                        Button("查看") { Task { await open(material) } }.font(.system(size: 11, weight: .semibold)).foregroundStyle(MPColor.blue)
                        if isTeacher {
                            Button("删除", role: .destructive) { Task { await remove(material) } }.font(.system(size: 11))
                        }
                    }
                    .padding(.vertical, 9)
                    .overlay(alignment: .bottom) { Rectangle().fill(Color.black.opacity(0.05)).frame(height: 0.5) }
                }
            }
        }
        .padding(16)
    }

    private func quickActions(_ item: APIClassroom) -> some View {
        HStack(spacing: 10) {
            NavigationLink { ScheduleCalendarView() } label: { actionCard("班级课表", "timetable-blue", MPColor.blue) }
            NavigationLink { HourLedgerView(classId: item.id) } label: { actionCard("课时账本", "bill-green", MPColor.green) }
            NavigationLink { StudentDirectoryView() } label: { actionCard("学生档案", "student-red", MPColor.coral) }
        }
        .buttonStyle(.plain).padding(.horizontal, 16)
    }

    private func actionCard(_ title: String, _ image: String, _ color: Color) -> some View {
        VStack(spacing: 7) {
            MPIconTile(image: image, color: color, size: 42)
            Text(title).font(.system(size: 11, weight: .medium)).foregroundStyle(MPColor.text).lineLimit(1)
        }
        .frame(maxWidth: .infinity).padding(.vertical, 13).background(.white, in: RoundedRectangle(cornerRadius: 15))
        .shadow(color: .black.opacity(0.045), radius: 8, y: 2)
    }

    private func timelineSection(_ item: APIClassroom) -> some View {
        let rows = (item.sessions ?? []).sorted { $0.startsAt > $1.startsAt }
        return VStack(spacing: 12) {
            HStack {
                MPSectionHeader(title: "上课统计")
                Spacer(); Text("记录教学与学习足迹").font(.system(size: 10)).foregroundStyle(MPColor.secondary)
            }
            if rows.isEmpty {
                MPCard { MPEmptyView(image: "time", title: "暂无课节", detail: "添加单次课节或按固定周期批量排课") }
            } else {
                ForEach(Array(rows.enumerated()), id: \.element.id) { index, session in
                    timelineRow(session, showLine: index < rows.count - 1)
                }
            }
        }
        .padding(.horizontal, 16)
    }

    private func timelineRow(_ session: APISession, showLine: Bool) -> some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(spacing: 0) {
                ZStack {
                    Circle().fill(statusColor(session)).frame(width: 26, height: 26)
                    Image(systemName: session.status == "COMPLETED" ? "checkmark" : "sparkles")
                        .font(.system(size: 10, weight: .bold)).foregroundStyle(.white)
                }
                if showLine { Rectangle().fill(statusColor(session).opacity(0.25)).frame(width: 2, height: 112) }
            }
            NavigationLink { SessionDetailView(sessionId: session.id) } label: {
                MPCard {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Text(session.status == "COMPLETED" ? "已完成" : session.status == "CANCELLED" ? "已取消" : "即将上课")
                                .font(.system(size: 10, weight: .semibold)).foregroundStyle(statusColor(session))
                                .padding(.horizontal, 8).padding(.vertical, 4).background(statusColor(session).opacity(0.12), in: Capsule())
                            Spacer()
                            Text(session.startsAt.formatted(.dateTime.month().day().hour().minute()))
                                .font(.system(size: 10)).foregroundStyle(MPColor.secondary)
                        }
                        Text(itemName(session)).font(.system(size: 15, weight: .semibold)).foregroundStyle(MPColor.text)
                        if let summary = session.feedback?.summary, !summary.isEmpty {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("老师评语").font(.system(size: 10, weight: .semibold)).foregroundStyle(MPColor.blue)
                                Text(summary).font(.system(size: 11)).foregroundStyle(MPColor.secondary).lineLimit(3)
                            }
                            .padding(10).background(MPColor.blue.opacity(0.07), in: RoundedRectangle(cornerRadius: 9))
                        }
                        HStack {
                            Text(session.status == "COMPLETED" ? "已签到 · 已提交" : "请准时参加课程")
                                .font(.system(size: 10)).foregroundStyle(MPColor.secondary)
                            Spacer(); Text("查看详情").font(.system(size: 11, weight: .semibold)).foregroundStyle(MPColor.blue)
                        }
                    }
                }
            }
            .buttonStyle(.plain)
        }
    }

    private func itemName(_ session: APISession) -> String { classroom?.name ?? session.classroom?.name ?? "课程" }
    private func completedSessions(_ item: APIClassroom) -> Int { item.sessions?.filter { $0.status == "COMPLETED" }.count ?? 0 }
    private func completedHours(_ item: APIClassroom) -> Double { item.sessions?.filter { $0.status == "COMPLETED" }.reduce(0) { $0 + $1.plannedHours.doubleValue } ?? 0 }
    private func totalHours(_ item: APIClassroom) -> Double { item.hourSettings?.totalHours.doubleValue ?? item.members?.reduce(0) { $0 + $1.totalHours.doubleValue } ?? 0 }
    private func price(_ item: APIClassroom) -> Double { item.priceSettings?.price.doubleValue ?? item.members?.first?.pricePerHour.doubleValue ?? 0 }
    private func classColor(_ item: APIClassroom) -> Color {
        switch item.color?.uppercased() {
        case "#6AA08A": MPColor.green
        case "#E8B4A8": MPColor.coral
        case "#D4A574": MPColor.gold
        case "#DC7878": MPColor.red
        default: MPColor.blue
        }
    }
    private func statusColor(_ session: APISession) -> Color {
        session.status == "COMPLETED" ? MPColor.green : session.status == "CANCELLED" ? MPColor.secondary : MPColor.blue
    }
    private func materialType(_ material: APIMaterial) -> String { material.name.split(separator: ".").last.map { String($0).uppercased() } ?? "FILE" }
    private func fileSize(_ bytes: Int) -> String { ByteCountFormatter.string(fromByteCount: Int64(bytes), countStyle: .file) }

    @MainActor private func open(_ material: APIMaterial) async {
        do {
            let url = try await FileTransferService(client: dependencies.client).downloadURL(objectKey: material.objectKey)
            openURL(url)
        } catch { errorMessage = error.localizedDescription }
    }
    @MainActor private func remove(_ material: APIMaterial) async {
        do {
            try await ClassTraceRepository(client: dependencies.client).deleteMaterial(material.id)
            await load()
        } catch { errorMessage = error.localizedDescription }
    }
    @MainActor private func load() async {
        do {
            let repository = ClassTraceRepository(client: dependencies.client)
            async let classRequest = repository.classDetail(classId)
            async let materialRequest = repository.materials(classId: classId)
            async let studentRequest = repository.students()
            (classroom, materials, students) = try await (classRequest, materialRequest, studentRequest)
            errorMessage = nil
        } catch { errorMessage = error.localizedDescription }
    }
}

private struct CreateClassSessionView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AppDependencies.self) private var dependencies
    let classId: String
    let onSaved: () async -> Void
    @State private var startsAt = Date().addingTimeInterval(3600)
    @State private var duration = 60
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            Form {
                DatePicker("开始时间", selection: $startsAt)
                Stepper("时长：\(duration) 分钟", value: $duration, in: 15...360, step: 15)
                if let errorMessage { Text(errorMessage).foregroundStyle(MPColor.red) }
            }
            .mpFormChrome().navigationTitle("添加课次")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("取消") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button("保存") { Task { await save() } } }
            }
        }
    }
    @MainActor private func save() async {
        do {
            _ = try await ClassTraceRepository(client: dependencies.client).createSession(classId: classId, startsAt: startsAt, endsAt: startsAt.addingTimeInterval(Double(duration * 60)))
            await onSaved(); dismiss()
        } catch { errorMessage = error.localizedDescription }
    }
}

private struct ClassGenerateScheduleView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AppDependencies.self) private var dependencies
    let classId: String
    let onSaved: () async -> Void
    @State private var from = Date()
    @State private var to = Calendar.current.date(byAdding: .month, value: 3, to: Date()) ?? Date()
    @State private var weekdays: Set<Int> = [1]
    @State private var startsAt = Date()
    @State private var duration = 60
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            Form {
                DatePicker("开始日期", selection: $from, displayedComponents: .date)
                DatePicker("结束日期", selection: $to, displayedComponents: .date)
                Section("上课日") {
                    ForEach(1...7, id: \.self) { day in
                        Toggle(ClassEditorView.weekdayNames[day - 1], isOn: Binding(
                            get: { weekdays.contains(day) },
                            set: { if $0 { weekdays.insert(day) } else { weekdays.remove(day) } }
                        ))
                    }
                }
                DatePicker("上课时间", selection: $startsAt, displayedComponents: .hourAndMinute)
                Stepper("时长 \(duration) 分钟", value: $duration, in: 15...360, step: 15)
                if let errorMessage { Text(errorMessage).foregroundStyle(MPColor.red) }
            }
            .mpFormChrome().navigationTitle("批量排课")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("取消") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button("生成") { Task { await save() } }.disabled(weekdays.isEmpty || to < from) }
            }
        }
    }

    @MainActor private func save() async {
        do {
            let parts = Calendar.current.dateComponents([.hour, .minute], from: startsAt)
            let time = String(format: "%02d:%02d", parts.hour ?? 0, parts.minute ?? 0)
            _ = try await ClassTraceRepository(client: dependencies.client).generateSessions(classId: classId, from: from, to: to, weekdays: weekdays.sorted(), startTime: time, durationMinutes: duration)
            await onSaved(); dismiss()
        } catch { errorMessage = error.localizedDescription }
    }
}
