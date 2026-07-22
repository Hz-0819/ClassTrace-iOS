import SwiftUI

struct SessionDetailView: View {
    @Environment(AppDependencies.self) private var dependencies
    @Environment(AppSession.self) private var appSession
    let sessionId: String
    @State private var item: APISession?
    @State private var classroom: APIClassroom?
    @State private var errorMessage: String?
    @State private var isWorking = false
    @State private var showAttendance = false
    @State private var editMode: SessionEditView.Mode?

    private var isTeacher: Bool { appSession.activeRole == "TEACHER" }

    var body: some View {
        Group {
            if let item {
                ScrollView(showsIndicators: false) {
                    LazyVStack(spacing: 16) {
                        header(item)
                        overview(item)
                        attendance(item)
                        feedback(item)
                        actions(item)
                    }.padding(.bottom, 28)
                }.background(MPColor.page)
            } else if let errorMessage {
                CTStateView(kind: .error, title: "加载失败", message: LocalizedStringKey(errorMessage), actionTitle: "重试") { Task { await load() } }
            } else { ProgressView().tint(MPColor.blue) }
        }
        .navigationTitle("课次详情").navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if let item, isTeacher {
                Menu {
                    if !["COMPLETED", "CANCELLED"].contains(item.status) {
                        Button("调整时间", systemImage: "calendar") { editMode = .reschedule }
                        Button("取消课次", systemImage: "xmark.circle", role: .destructive) { editMode = .cancel }
                    }
                    Button("填写课后反馈", systemImage: "square.and.pencil") { editMode = .feedback }
                } label: { Image(systemName: "ellipsis.circle") }
            }
        }
        .sheet(isPresented: $showAttendance) {
            if let item { ConfirmAttendanceView(session: item, members: classroom?.members ?? []) { value in self.item = value; await load() } }
        }
        .sheet(item: $editMode) { mode in
            if let item { SessionEditView(session: item, mode: mode) { await load() } }
        }
        .task { if item == nil { await load() } }.refreshable { await load() }
    }

    private func header(_ session: APISession) -> some View {
        ZStack {
            LinearGradient(colors: [statusColor(session), statusColor(session).opacity(0.72)], startPoint: .topLeading, endPoint: .bottomTrailing)
            Circle().fill(.white.opacity(0.10)).frame(width: 140, height: 140).offset(x: 155, y: -45)
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    VStack(alignment: .leading, spacing: 5) {
                        Text(classroom?.name ?? session.classroom?.name ?? "课程")
                            .font(.system(size: 23, weight: .bold))
                        Text(classroom?.teacherName ?? "授课教师")
                            .font(.system(size: 12)).opacity(0.82)
                    }
                    Spacer()
                    Text(session.status.localizedStatus).font(.system(size: 11, weight: .semibold))
                        .padding(.horizontal, 10).padding(.vertical, 6).background(.white.opacity(0.2), in: Capsule())
                }
                HStack(spacing: 12) {
                    Image(systemName: "calendar").font(.system(size: 17))
                    VStack(alignment: .leading, spacing: 3) {
                        Text(session.startsAt.formatted(.dateTime.year().month().day().weekday(.wide)))
                            .font(.system(size: 13, weight: .semibold))
                        Text("\(session.startsAt.formatted(date: .omitted, time: .shortened)) - \(session.endsAt.formatted(date: .omitted, time: .shortened))")
                            .font(.system(size: 12)).opacity(0.85)
                    }
                }
            }.foregroundStyle(.white).padding(20)
        }.frame(height: 178).clipShape(UnevenRoundedRectangle(bottomLeadingRadius: 25, bottomTrailingRadius: 25))
    }

    private func overview(_ session: APISession) -> some View {
        MPCard {
            VStack(spacing: 13) {
                infoRow("上课地点", classroom?.location ?? "待安排")
                infoRow("计划课时", "\(session.plannedHours.doubleValue.compactNumber) 课时")
                infoRow("排课来源", sourceText(session.source))
                infoRow("班级人数", "\(classroom?.members?.count ?? session.attendances?.count ?? 0) 人")
                if let reason = session.cancelReason, !reason.isEmpty { infoRow("取消原因", reason, color: MPColor.red) }
            }
        }.padding(.horizontal, 16)
    }

    private func attendance(_ session: APISession) -> some View {
        VStack(spacing: 12) {
            MPSectionHeader(title: "出勤与课时")
            if session.attendances?.isEmpty != false {
                MPCard { MPEmptyView(image: "student-green", title: session.status == "COMPLETED" ? "未记录考勤" : "等待上课确认", detail: isTeacher ? "确认上课时可逐一记录出勤和扣除课时" : "老师确认上课后会显示考勤结果") }
            } else {
                MPCard {
                    VStack(spacing: 0) {
                        ForEach(session.attendances ?? []) { record in
                            HStack(spacing: 11) {
                                MPLegacyImage(name: record.student?.gender == "FEMALE" ? "girl" : "boy", size: 36)
                                VStack(alignment: .leading, spacing: 3) { Text(record.student?.name ?? "学生").font(.system(size: 14, weight: .semibold)); Text(record.remark ?? "已记录本次考勤").font(.system(size: 11)).foregroundStyle(MPColor.secondary) }
                                Spacer()
                                VStack(alignment: .trailing, spacing: 3) { Text(record.status.localizedStatus).font(.system(size: 12, weight: .semibold)).foregroundStyle(attendanceColor(record.status)); Text("扣除 \(record.deductHours.doubleValue.compactNumber) 课时").font(.system(size: 10)).foregroundStyle(MPColor.secondary) }
                            }.padding(.vertical, 10)
                        }
                    }
                }
            }
        }.padding(.horizontal, 16)
    }

    private func feedback(_ session: APISession) -> some View {
        VStack(spacing: 12) {
            MPSectionHeader(title: "课后反馈")
            if let value = session.feedback {
                MPCard {
                    VStack(alignment: .leading, spacing: 13) {
                        feedbackBlock("课堂总结", value.summary)
                        feedbackBlock("课堂表现", value.performance)
                        feedbackBlock("课后作业", value.homeworkNote)
                        if isTeacher { Button("编辑反馈") { editMode = .feedback }.font(.system(size: 13, weight: .semibold)).foregroundStyle(MPColor.blue) }
                    }
                }
            } else {
                MPCard { MPEmptyView(image: "feedback-blue", title: "暂无课后反馈", detail: isTeacher ? "课后记录课堂表现与作业安排" : "老师提交后将在这里展示") }
            }
        }.padding(.horizontal, 16)
    }

    @ViewBuilder private func actions(_ session: APISession) -> some View {
        if isTeacher {
            VStack(spacing: 10) {
                if !["COMPLETED", "CANCELLED"].contains(session.status) {
                    Button { showAttendance = true } label: { Label("确认上课并记录考勤", systemImage: "checkmark.circle.fill").frame(maxWidth: .infinity).padding(15).foregroundStyle(.white).background(MPColor.blue, in: RoundedRectangle(cornerRadius: 13)) }
                }
                if session.status == "COMPLETED" {
                    Button(role: .destructive) { Task { await undo() } } label: { Text("撤销上课确认").frame(maxWidth: .infinity).padding(14).background(.white, in: RoundedRectangle(cornerRadius: 13)) }.disabled(isWorking)
                }
            }.font(.system(size: 14, weight: .semibold)).padding(.horizontal, 16)
        }
    }

    private func feedbackBlock(_ title: String, _ text: String?) -> some View {
        VStack(alignment: .leading, spacing: 5) { Text(title).font(.system(size: 12, weight: .semibold)).foregroundStyle(MPColor.blue); Text((text?.isEmpty == false ? text : nil) ?? "暂未填写").font(.system(size: 13)).foregroundStyle(text?.isEmpty == false ? MPColor.text : MPColor.secondary) }.frame(maxWidth: .infinity, alignment: .leading)
    }
    private func infoRow(_ title: String, _ value: String, color: Color = MPColor.text) -> some View { HStack { Text(title).font(.system(size: 12)).foregroundStyle(MPColor.secondary); Spacer(); Text(value).font(.system(size: 13, weight: .medium)).foregroundStyle(color) } }
    private func sourceText(_ source: String) -> String { source == "RECURRING" ? "固定排课" : source == "MANUAL" ? "临时添加" : "日程创建" }
    private func statusColor(_ session: APISession) -> Color { session.status == "COMPLETED" ? MPColor.green : session.status == "CANCELLED" ? MPColor.secondary : MPColor.blue }
    private func attendanceColor(_ status: String) -> Color { status == "PRESENT" ? MPColor.green : status == "ABSENT" ? MPColor.red : MPColor.gold }

    @MainActor private func load() async {
        do {
            let repository = ClassTraceRepository(client: dependencies.client)
            let value = try await repository.sessionDetail(sessionId)
            async let classRequest = repository.classDetail(value.classId)
            item = value; classroom = try await classRequest; errorMessage = nil
        } catch { errorMessage = error.localizedDescription }
    }
    @MainActor private func undo() async {
        isWorking = true; defer { isWorking = false }
        do { item = try await ClassTraceRepository(client: dependencies.client).undoSession(id: sessionId); await load() }
        catch { errorMessage = error.localizedDescription }
    }
}
