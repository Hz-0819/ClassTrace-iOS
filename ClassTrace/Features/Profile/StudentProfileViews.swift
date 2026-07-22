import SwiftUI

struct StudentProfileView: View {
    @Environment(AppDependencies.self) private var dependencies
    @Environment(AppSession.self) private var appSession
    let studentId: String
    @State private var student: APIStudent?
    @State private var stats: APIAttendanceStats?
    @State private var showEdit = false
    @State private var errorMessage: String?

    private var isTeacher: Bool { appSession.activeRole == "TEACHER" }
    private var members: [APIClassMember] { student?.classMembers ?? [] }
    private var remainingHours: Double { members.reduce(0) { $0 + $1.remainingHours.doubleValue } }

    var body: some View {
        Group {
            if let student {
                ScrollView(showsIndicators: false) {
                    LazyVStack(spacing: 16) {
                        header(student)
                        courseSection(student)
                        learningSection(student)
                        attendanceSection
                        guardianSection(student)
                    }.padding(.bottom, 28)
                }.background(MPColor.page)
            } else if let errorMessage {
                CTStateView(kind: .error, title: "加载失败", message: LocalizedStringKey(errorMessage), actionTitle: "重试") { Task { await load() } }
            } else { ProgressView().tint(MPColor.blue) }
        }
        .navigationTitle("学生档案").navigationBarTitleDisplayMode(.inline)
        .toolbar { if student != nil { Button("编辑") { showEdit = true } } }
        .sheet(isPresented: $showEdit) {
            if let student { NavigationStack { StudentEditorView(student: student) { await load() } } }
        }
        .task { await load() }.refreshable { await load() }
    }

    private func header(_ value: APIStudent) -> some View {
        ZStack {
            LinearGradient(colors: [MPColor.blue, MPColor.blue.opacity(0.72)], startPoint: .topLeading, endPoint: .bottomTrailing)
            Circle().fill(.white.opacity(0.10)).frame(width: 150, height: 150).offset(x: 155, y: -50)
            VStack(spacing: 18) {
                HStack(spacing: 14) {
                    ZStack { Circle().fill(.white.opacity(0.23)); MPLegacyImage(name: value.gender?.uppercased() == "FEMALE" ? "girl" : "boy", size: 54) }
                        .frame(width: 68, height: 68).overlay(Circle().stroke(.white.opacity(0.5), lineWidth: 2))
                    VStack(alignment: .leading, spacing: 6) {
                        Text(value.name).font(.system(size: 23, weight: .bold))
                        Text("\(value.grade ?? "暂无年级") · \(members.count) 个班级/课程").font(.system(size: 12)).opacity(0.82)
                    }
                    Spacer()
                }
                HStack {
                    headerMetric("累计考勤", "\(stats?.total ?? 0)")
                    headerDivider
                    headerMetric("剩余课时", remainingHours.compactNumber)
                    headerDivider
                    headerMetric("出勤率", (stats?.attendanceRate ?? 0).formatted(.percent.precision(.fractionLength(0))))
                }
            }.foregroundStyle(.white).padding(20)
        }.frame(height: 208).clipShape(UnevenRoundedRectangle(bottomLeadingRadius: 26, bottomTrailingRadius: 26))
    }

    private func headerMetric(_ title: String, _ value: String) -> some View {
        VStack(spacing: 4) { Text(value).font(.system(size: 18, weight: .bold)); Text(title).font(.system(size: 10)).opacity(0.8) }.frame(maxWidth: .infinity)
    }
    private var headerDivider: some View { Rectangle().fill(.white.opacity(0.25)).frame(width: 0.5, height: 34) }

    private func courseSection(_ value: APIStudent) -> some View {
        VStack(spacing: 12) {
            MPSectionHeader(title: "课程与课时")
            if members.isEmpty { MPCard { MPEmptyView(image: "class-blue", title: "暂无在读课程", detail: isTeacher ? "将学生加入班级后会显示课程与课时" : "加入课程后会显示课时余额和流水") } }
            ForEach(members) { member in
                NavigationLink { StudentHourLedgerView(student: value, member: member) } label: {
                    MPCard {
                        VStack(spacing: 12) {
                            HStack(spacing: 12) {
                                MPIconTile(image: "class-blue", color: MPColor.blue, size: 46)
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(member.classroom?.name ?? "班级").font(.system(size: 15, weight: .semibold)).foregroundStyle(MPColor.text)
                                    Text(member.classroom?.billingMode == "CASH" ? "按次现结" : "预付课时").font(.system(size: 11)).foregroundStyle(MPColor.secondary)
                                }
                                Spacer(); MPLegacyImage(name: "right", size: 13).opacity(0.45)
                            }
                            if member.classroom?.billingMode != "CASH" {
                                HStack { ledgerMetric("总课时", member.totalHours.doubleValue); ledgerMetric("已消耗", member.consumedHours.doubleValue); ledgerMetric("剩余", member.remainingHours.doubleValue, warning: member.remainingHours.doubleValue <= 3) }
                            }
                        }
                    }
                }.buttonStyle(.plain)
            }
        }.padding(.horizontal, 16)
    }

    private func ledgerMetric(_ title: String, _ value: Double, warning: Bool = false) -> some View {
        VStack(spacing: 3) { Text(value.compactNumber).font(.system(size: 15, weight: .bold)).foregroundStyle(warning ? MPColor.red : MPColor.text); Text(title).font(.system(size: 10)).foregroundStyle(MPColor.secondary) }.frame(maxWidth: .infinity)
    }

    private func learningSection(_ value: APIStudent) -> some View {
        VStack(spacing: 12) {
            MPSectionHeader(title: "学习概览")
            MPCard {
                VStack(spacing: 0) {
                    NavigationLink { LearningHubView(initialSelection: 0) } label: { overviewRow("file-red", "作业与提交", "\(value.homeworkSubmissions?.count ?? 0) 条记录", MPColor.red) }
                    Divider().padding(.leading, 54)
                    NavigationLink { LearningHubView(initialSelection: 2) } label: { overviewRow("plan-brown", "学习计划", "\(value.studyPlans?.filter { $0.status == "ACTIVE" }.count ?? 0) 个进行中", MPColor.gold) }
                    Divider().padding(.leading, 54)
                    NavigationLink { LearningHubView(initialSelection: 3) } label: { overviewRow("mistakebook-red", "错题本", "\(value.mistakes?.filter { $0.masteredAt == nil }.count ?? 0) 道待掌握", MPColor.coral) }
                }
            }
        }.padding(.horizontal, 16)
    }

    private func overviewRow(_ image: String, _ title: String, _ detail: String, _ color: Color) -> some View {
        HStack(spacing: 12) { MPIconTile(image: image, color: color, size: 42); VStack(alignment: .leading, spacing: 3) { Text(title).font(.system(size: 14, weight: .semibold)).foregroundStyle(MPColor.text); Text(detail).font(.system(size: 11)).foregroundStyle(MPColor.secondary) }; Spacer(); MPLegacyImage(name: "right", size: 12).opacity(0.45) }.padding(.vertical, 7)
    }

    private var attendanceSection: some View {
        VStack(spacing: 12) {
            MPSectionHeader(title: "考勤统计")
            MPCard {
                HStack {
                    attendanceMetric("出勤", stats?.counts["PRESENT"] ?? 0, MPColor.green)
                    attendanceMetric("请假", stats?.counts["LEAVE"] ?? 0, MPColor.gold)
                    attendanceMetric("缺席", stats?.counts["ABSENT"] ?? 0, MPColor.red)
                }
            }
        }.padding(.horizontal, 16)
    }

    private func attendanceMetric(_ title: String, _ value: Int, _ color: Color) -> some View {
        VStack(spacing: 5) { Text("\(value)").font(.system(size: 22, weight: .bold)).foregroundStyle(color); Text(title).font(.system(size: 11)).foregroundStyle(MPColor.secondary) }.frame(maxWidth: .infinity)
    }

    private func guardianSection(_ value: APIStudent) -> some View {
        VStack(spacing: 12) {
            MPSectionHeader(title: "监护关系")
            MPCard {
                VStack(spacing: 10) {
                    if value.guardians?.isEmpty != false { Text("暂无已绑定监护人").font(.system(size: 13)).foregroundStyle(MPColor.secondary) }
                    ForEach(value.guardians ?? []) { guardian in HStack { MPIconTile(image: "user-blue", color: MPColor.blue, size: 38); Text(guardian.relationship ?? "监护人").font(.system(size: 14)); Spacer(); if guardian.isPrimary { Text("主要监护人").font(.system(size: 10)).foregroundStyle(MPColor.blue).padding(.horizontal, 8).padding(.vertical, 4).background(MPColor.blue.opacity(0.1), in: Capsule()) } } }
                    if isTeacher { Button("编辑档案或管理监护人") { showEdit = true }.font(.system(size: 13, weight: .semibold)).foregroundStyle(MPColor.blue).frame(maxWidth: .infinity, alignment: .leading) }
                }
            }
        }.padding(.horizontal, 16)
    }

    @MainActor private func load() async {
        do {
            let repository = ClassTraceRepository(client: dependencies.client)
            async let detailRequest = repository.studentDetail(studentId)
            async let statsRequest = repository.attendanceStats(studentId: studentId)
            (student, stats) = try await (detailRequest, statsRequest); errorMessage = nil
        } catch { errorMessage = error.localizedDescription }
    }
}

struct StudentHourLedgerView: View {
    @Environment(AppDependencies.self) private var dependencies
    let student: APIStudent
    let member: APIClassMember
    @State private var entries: [APIHourEntry] = []
    @State private var exportURL: URL?

    var body: some View {
        ScrollView(showsIndicators: false) {
            LazyVStack(spacing: 16) {
                MPCard {
                    VStack(spacing: 14) {
                        HStack(spacing: 12) {
                            MPLegacyImage(name: student.gender?.uppercased() == "FEMALE" ? "girl" : "boy", size: 50)
                            VStack(alignment: .leading, spacing: 4) { Text(student.name).font(.system(size: 19, weight: .bold)); Text(member.classroom?.name ?? "班级").font(.system(size: 12)).foregroundStyle(MPColor.secondary) }
                            Spacer()
                            if let exportURL { ShareLink(item: exportURL) { Label("导出", systemImage: "square.and.arrow.up").font(.system(size: 12, weight: .semibold)) } }
                        }
                        HStack { ledgerSummary("总课时", member.totalHours.doubleValue); ledgerSummary("已消耗", member.consumedHours.doubleValue); ledgerSummary("剩余", member.remainingHours.doubleValue) }
                        ProgressView(value: member.totalHours.doubleValue > 0 ? member.consumedHours.doubleValue / member.totalHours.doubleValue : 0).tint(MPColor.blue)
                    }
                }.padding(.horizontal, 16).padding(.top, 12)

                VStack(spacing: 12) {
                    MPSectionHeader(title: "课时流水")
                    if entries.isEmpty { MPCard { MPEmptyView(image: "null", title: "暂无课时流水", detail: "确认上课或调整课时后会自动生成记录") } }
                    ForEach(entries) { entry in
                        MPCard {
                            HStack(alignment: .top, spacing: 12) {
                                Circle().fill(entry.delta.doubleValue >= 0 ? MPColor.green : MPColor.coral).frame(width: 10, height: 10).padding(.top, 5)
                                VStack(alignment: .leading, spacing: 5) { Text(entry.type.localizedStatus).font(.system(size: 14, weight: .semibold)); Text(entry.createdAt.formatted(date: .abbreviated, time: .shortened)).font(.system(size: 11)).foregroundStyle(MPColor.secondary); if let remark = entry.remark { Text(remark).font(.system(size: 11)).foregroundStyle(MPColor.secondary) } }
                                Spacer()
                                VStack(alignment: .trailing, spacing: 4) { Text("\(entry.delta.doubleValue >= 0 ? "+" : "")\(entry.delta.doubleValue.compactNumber)").font(.system(size: 16, weight: .bold)).foregroundStyle(entry.delta.doubleValue >= 0 ? MPColor.green : MPColor.coral); Text("余额 \(entry.balanceAfter.doubleValue.compactNumber)").font(.system(size: 10)).foregroundStyle(MPColor.secondary) }
                            }
                        }
                    }
                }.padding(.horizontal, 16)
            }.padding(.bottom, 24)
        }.background(MPColor.page).navigationTitle("课时档案").task { await load() }.refreshable { await load() }
    }

    private func ledgerSummary(_ title: String, _ value: Double) -> some View { VStack(spacing: 4) { Text(value.compactNumber).font(.system(size: 18, weight: .bold)).foregroundStyle(MPColor.text); Text(title).font(.system(size: 10)).foregroundStyle(MPColor.secondary) }.frame(maxWidth: .infinity) }

    @MainActor private func load() async {
        entries = (try? await ClassTraceRepository(client: dependencies.client).hourLedger(classId: member.classId, studentId: student.id)) ?? []
        let header = "学生,班级,类型,课时变化,余额,时间,备注\n"
        let rows = entries.map { "\(csv(student.name)),\(csv(member.classroom?.name ?? "")),\(csv($0.type.localizedStatus)),\($0.delta.doubleValue),\($0.balanceAfter.doubleValue),\($0.createdAt.ISO8601Format()),\(csv($0.remark ?? ""))" }.joined(separator: "\n")
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("ClassTrace-\(student.id)-hours.csv")
        try? (header + rows).data(using: .utf8)?.write(to: url, options: .atomic); exportURL = url
    }
    private func csv(_ value: String) -> String { "\"\(value.replacingOccurrences(of: "\"", with: "\"\""))\"" }
}
