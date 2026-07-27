import SwiftUI
import UniformTypeIdentifiers

struct MiniProgramLearningCreateView: View {
    enum Kind { case homework, plan, mistake }

    @Environment(\.dismiss) private var dismiss
    @Environment(AppDependencies.self) private var dependencies

    let kind: Kind
    let classes: [APIClassroom]
    let students: [APIStudent]
    let onSaved: () async -> Void

    @State private var classId = ""
    @State private var studentId = ""
    @State private var audienceType = "all"
    @State private var selectedStudentIds: Set<String> = []
    @State private var title = ""
    @State private var content = ""
    @State private var subject = "其他"
    @State private var category = "daily"
    @State private var planTime = Date()
    @State private var deadline = Calendar.current.date(byAdding: .day, value: 7, to: Date()) ?? Date()
    @State private var reminder = false
    @State private var weekDays: Set<Int> = []
    @State private var remark = ""
    @State private var wrongAnswer = ""
    @State private var correctAnswer = ""
    @State private var analysis = ""
    @State private var tags: [String] = []
    @State private var tagDraft = ""
    @State private var attachments: [APIHomeworkAttachment] = []
    @State private var importing = false
    @State private var uploading = false
    @State private var isSaving = false
    @State private var errorMessage: String?

    private let subjects = ["语文", "数学", "英语", "物理", "化学", "生物", "历史", "地理", "政治", "其他"]

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                LazyVStack(spacing: 12) {
                    pageIntro
                    switch kind {
                    case .homework: homeworkForm
                    case .plan: planForm
                    case .mistake: mistakeForm
                    }
                    if let errorMessage {
                        Text(errorMessage).font(.system(size: 12)).foregroundStyle(MPColor.red)
                            .frame(maxWidth: .infinity, alignment: .leading).padding(.horizontal, 16)
                    }
                }.padding(.vertical, 12).padding(.bottom, 78)
            }
            .background(MPColor.page)
            .navigationTitle(navigationTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("取消") { dismiss() } } }
            .safeAreaInset(edge: .bottom) { saveBar }
            .fileImporter(isPresented: $importing, allowedContentTypes: [.item], allowsMultipleSelection: true) { result in
                Task { await importAttachments(result) }
            }
            .onAppear {
                if classId.isEmpty { classId = classes.first?.id ?? "" }
            }
        }
    }

    private var navigationTitle: String {
        switch kind { case .homework: "布置新作业"; case .plan: "新建学习计划"; case .mistake: "添加错题" }
    }

    private var pageIntro: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(navigationTitle).font(.system(size: 24, weight: .bold)).foregroundStyle(MPColor.text)
            Text(kind == .homework ? "按班级发布，也可以只发给指定学生" : kind == .plan ? "设置完整的执行时间、重复方式和提醒" : "记录学生的错题，便于针对性复习")
                .font(.system(size: 12)).foregroundStyle(MPColor.secondary)
        }.frame(maxWidth: .infinity, alignment: .leading).padding(.horizontal, 16)
    }

    private var homeworkForm: some View {
        Group {
            formCard {
                requiredLabel("选择班级")
                menuPicker(value: selectedClass?.name ?? "请选择班级") {
                    ForEach(classes) { classroom in Button(classroom.name) { classId = classroom.id; selectedStudentIds = [] } }
                }

                requiredLabel("发送对象")
                HStack(spacing: 9) {
                    audienceCard("all", "全班学生", "新加入学生也可查看历史作业")
                    audienceCard("selected", "指定学生", "仅所选家庭可见")
                }
                if audienceType == "selected" {
                    let available = classStudents
                    if available.isEmpty {
                        Text("该班级暂无学生").font(.system(size: 12)).foregroundStyle(MPColor.secondary)
                    } else {
                        VStack(spacing: 7) {
                            ForEach(available) { student in
                                Button { toggleStudent(student.id) } label: {
                                    HStack {
                                        Circle()
                                            .fill(selectedStudentIds.contains(student.id) ? MPColor.blue : .clear)
                                            .frame(width: 22, height: 22)
                                            .overlay(Circle().stroke(selectedStudentIds.contains(student.id) ? MPColor.blue : Color.black.opacity(0.15)))
                                            .overlay {
                                                if selectedStudentIds.contains(student.id) { Image(systemName: "checkmark").font(.system(size: 10, weight: .bold)).foregroundStyle(.white) }
                                            }
                                        Text(student.name).font(.system(size: 14)).foregroundStyle(MPColor.text)
                                        Spacer()
                                    }.padding(10).background(MPColor.page, in: RoundedRectangle(cornerRadius: 8))
                                }.buttonStyle(.plain)
                            }
                        }
                    }
                }
            }

            formCard {
                requiredLabel("作业标题")
                textInput("请输入作业标题", text: $title)
                formLabel("作业要求")
                textArea("详细说明作业内容和要求…", text: $content, minHeight: 130)
                Text("\(content.count)/2000").font(.system(size: 10)).foregroundStyle(MPColor.secondary).frame(maxWidth: .infinity, alignment: .trailing)

                formLabel("作业附件")
                ForEach(attachments) { attachment in
                    HStack(spacing: 9) {
                        MPIconTile(image: "file-blue", color: MPColor.blue, size: 34)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(attachment.name).font(.system(size: 12, weight: .medium)).lineLimit(1)
                            Text(ByteCountFormatter.string(fromByteCount: Int64(attachment.sizeBytes), countStyle: .file)).font(.system(size: 10)).foregroundStyle(MPColor.secondary)
                        }
                        Spacer()
                        Button { attachments.removeAll { $0.id == attachment.id } } label: { Image(systemName: "xmark.circle.fill").foregroundStyle(MPColor.secondary) }
                    }.padding(8).background(MPColor.page, in: RoundedRectangle(cornerRadius: 8))
                }
                Button { importing = true } label: {
                    HStack {
                        Image(systemName: "plus")
                        Text(uploading ? "上传中…" : "添加图片或文件（最多9个）")
                    }
                    .font(.system(size: 13, weight: .semibold)).foregroundStyle(MPColor.blue)
                    .frame(maxWidth: .infinity, minHeight: 44)
                    .overlay(RoundedRectangle(cornerRadius: 9).stroke(MPColor.blue, style: StrokeStyle(lineWidth: 1, dash: [5])))
                }.buttonStyle(.plain).disabled(uploading || attachments.count >= 9)

                formLabel("截止时间")
                dateTimeRow($deadline)
            }
        }
    }

    private var planForm: some View {
        Group {
            formCard {
                requiredLabel("计划名称")
                textInput("请输入计划名称", text: $title)
                formLabel("关联学生（选填）")
                menuPicker(value: students.first(where: { $0.id == studentId })?.name ?? "不指定学生") {
                    Button("不指定学生") { studentId = "" }
                    ForEach(students) { student in Button(student.name) { studentId = student.id } }
                }
            }

            formCard {
                formLabel("学科分类")
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 7), count: 5), spacing: 8) {
                    ForEach(subjects, id: \.self) { value in
                        selectionChip(value, selected: subject == value) { subject = value }
                    }
                }

                formLabel("计划类型")
                HStack(spacing: 8) {
                    planTypeCard("daily", "每日计划", "每天")
                    planTypeCard("weekly", "每周计划", "每周")
                    planTypeCard("onetime", "一次性任务", "一次性")
                }

                formLabel("执行时间")
                DatePicker("", selection: $planTime, displayedComponents: .hourAndMinute)
                    .labelsHidden().padding(.horizontal, 12).frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                    .background(MPColor.page, in: RoundedRectangle(cornerRadius: 8))

                formLabel("截止日期")
                DatePicker("", selection: $deadline, displayedComponents: .date)
                    .labelsHidden().padding(.horizontal, 12).frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                    .background(MPColor.page, in: RoundedRectangle(cornerRadius: 8))

                if category == "weekly" {
                    formLabel("重复设置")
                    HStack(spacing: 6) {
                        ForEach(1...7, id: \.self) { day in
                            selectionChip(["一", "二", "三", "四", "五", "六", "日"][day - 1], selected: weekDays.contains(day)) {
                                if weekDays.contains(day) { weekDays.remove(day) } else { weekDays.insert(day) }
                            }
                        }
                    }
                } else if category == "daily" {
                    Text("每天自动重复").font(.system(size: 11)).foregroundStyle(MPColor.secondary)
                }

                Toggle("提醒设置", isOn: $reminder).tint(MPColor.blue).font(.system(size: 14))
                formLabel("备注（选填）")
                textArea("添加备注信息…", text: $remark, minHeight: 90)
            }
        }
    }

    private var mistakeForm: some View {
        Group {
            formCard {
                requiredLabel("选择学生")
                menuPicker(value: students.first(where: { $0.id == studentId })?.name ?? "请选择学生") {
                    ForEach(students) { student in Button(student.name) { studentId = student.id } }
                }
                formLabel("科目")
                textInput("例如：数学", text: $subject)
                requiredLabel("错题标题")
                textInput("输入便于识别的标题", text: $title)
            }

            formCard {
                formLabel("完整题目")
                textArea("输入完整的题目内容…", text: $content, minHeight: 110)
                formLabel("学生错误解答")
                textArea("学生当时的错误解答…", text: $wrongAnswer, minHeight: 80)
                formLabel("正确解答")
                textArea("正确的解答…", text: $correctAnswer, minHeight: 80)
                formLabel("错题解析")
                textArea("详细解析这道题的知识点…", text: $analysis, minHeight: 110)
                formLabel("标签")
                HStack {
                    textInput("添加知识点标签", text: $tagDraft)
                    Button("添加") { addTag() }.font(.system(size: 12, weight: .semibold)).disabled(tagDraft.trimmingCharacters(in: .whitespaces).isEmpty)
                }
                if !tags.isEmpty {
                    FlowLayout(spacing: 7) {
                        ForEach(tags, id: \.self) { tag in
                            HStack(spacing: 4) {
                                Text(tag)
                                Button { tags.removeAll { $0 == tag } } label: { Image(systemName: "xmark").font(.system(size: 8, weight: .bold)) }
                            }
                            .font(.system(size: 11)).foregroundStyle(MPColor.blue)
                            .padding(.horizontal, 9).padding(.vertical, 6).background(MPColor.blue.opacity(0.10), in: Capsule())
                        }
                    }
                }
            }
        }
    }

    private var saveBar: some View {
        Button { Task { await save() } } label: {
            Group {
                if isSaving { ProgressView().tint(.white) }
                else { Text(kind == .homework ? "确认布置" : kind == .plan ? "保存计划" : "确认添加").font(.system(size: 16, weight: .semibold)) }
            }
            .foregroundStyle(.white).frame(maxWidth: .infinity, minHeight: 50).background(MPColor.blue, in: Capsule())
        }
        .buttonStyle(.plain).disabled(isSaving || uploading)
        .padding(.horizontal, 16).padding(.vertical, 10).background(.white)
    }

    private func formCard<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 13) { content() }
            .padding(16).background(.white, in: RoundedRectangle(cornerRadius: 12))
            .shadow(color: .black.opacity(0.04), radius: 8, y: 2).padding(.horizontal, 16)
    }

    private func formLabel(_ text: String) -> some View {
        Text(text).font(.system(size: 14, weight: .medium)).foregroundStyle(MPColor.text)
    }

    private func requiredLabel(_ text: String) -> some View {
        HStack(spacing: 3) { Text(text).font(.system(size: 14, weight: .medium)); Text("*").foregroundStyle(MPColor.red) }
    }

    private func textInput(_ placeholder: String, text: Binding<String>) -> some View {
        TextField(placeholder, text: text).font(.system(size: 14)).padding(.horizontal, 12)
            .frame(maxWidth: .infinity, minHeight: 44).background(MPColor.page, in: RoundedRectangle(cornerRadius: 8))
    }

    private func textArea(_ placeholder: String, text: Binding<String>, minHeight: CGFloat) -> some View {
        TextField(placeholder, text: text, axis: .vertical).lineLimit(4...12).font(.system(size: 14)).padding(12)
            .frame(maxWidth: .infinity, minHeight: minHeight, alignment: .topLeading).background(MPColor.page, in: RoundedRectangle(cornerRadius: 8))
    }

    private func menuPicker<Content: View>(value: String, @ViewBuilder content: () -> Content) -> some View {
        Menu {
            content()
        } label: {
            HStack {
                Text(value).foregroundStyle(value.contains("请选择") ? MPColor.secondary : MPColor.text)
                Spacer()
                Image(systemName: "chevron.right").font(.system(size: 11, weight: .semibold)).foregroundStyle(MPColor.secondary)
            }
            .font(.system(size: 14)).padding(.horizontal, 12).frame(maxWidth: .infinity, minHeight: 44)
            .background(MPColor.page, in: RoundedRectangle(cornerRadius: 8))
        }
    }

    private func audienceCard(_ value: String, _ title: String, _ detail: String) -> some View {
        Button { audienceType = value } label: {
            VStack(alignment: .leading, spacing: 5) {
                Text(title).font(.system(size: 13, weight: .semibold))
                Text(detail).font(.system(size: 10)).foregroundStyle(MPColor.secondary).fixedSize(horizontal: false, vertical: true)
            }
            .foregroundStyle(audienceType == value ? MPColor.blue : MPColor.text)
            .frame(maxWidth: .infinity, minHeight: 60, alignment: .leading).padding(10)
            .background(audienceType == value ? MPColor.blue.opacity(0.10) : MPColor.page, in: RoundedRectangle(cornerRadius: 9))
            .overlay(RoundedRectangle(cornerRadius: 9).stroke(audienceType == value ? MPColor.blue : .clear))
        }.buttonStyle(.plain)
    }

    private func planTypeCard(_ value: String, _ title: String, _ detail: String) -> some View {
        Button { category = value } label: {
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(.system(size: 12, weight: .semibold))
                Text(detail).font(.system(size: 9)).foregroundStyle(MPColor.secondary)
            }
            .foregroundStyle(category == value ? MPColor.blue : MPColor.text)
            .frame(maxWidth: .infinity, minHeight: 48, alignment: .leading).padding(.horizontal, 8)
            .background(category == value ? MPColor.blue.opacity(0.10) : MPColor.page, in: RoundedRectangle(cornerRadius: 8))
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(category == value ? MPColor.blue : .clear))
        }.buttonStyle(.plain)
    }

    private func selectionChip(_ value: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(value).font(.system(size: 11, weight: .semibold)).foregroundStyle(selected ? .white : MPColor.text)
                .frame(maxWidth: .infinity, minHeight: 30).background(selected ? MPColor.blue : MPColor.page, in: Capsule())
        }.buttonStyle(.plain)
    }

    private func dateTimeRow(_ value: Binding<Date>) -> some View {
        DatePicker("", selection: value).labelsHidden().padding(.horizontal, 12)
            .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading).background(MPColor.page, in: RoundedRectangle(cornerRadius: 8))
    }

    private var selectedClass: APIClassroom? { classes.first { $0.id == classId } }
    private var classStudents: [APIStudent] {
        students.filter { student in student.classMembers?.contains(where: { $0.classId == classId }) == true }
    }

    private func toggleStudent(_ id: String) {
        if selectedStudentIds.contains(id) { selectedStudentIds.remove(id) }
        else { selectedStudentIds.insert(id) }
    }

    private func addTag() {
        let value = tagDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty, !tags.contains(value) else { return }
        tags.append(value)
        tagDraft = ""
    }

    @MainActor private func importAttachments(_ result: Result<[URL], Error>) async {
        uploading = true
        defer { uploading = false }
        do {
            let urls = Array(try result.get().prefix(max(0, 9 - attachments.count)))
            for url in urls {
                let accessed = url.startAccessingSecurityScopedResource()
                defer { if accessed { url.stopAccessingSecurityScopedResource() } }
                let data = try Data(contentsOf: url)
                guard data.count <= 20 * 1024 * 1024 else { throw LearningCreateError.fileTooLarge(url.lastPathComponent) }
                let mime = UTType(filenameExtension: url.pathExtension)?.preferredMIMEType ?? "application/octet-stream"
                let key = try await FileTransferService(client: dependencies.client).upload(data: data, fileName: url.lastPathComponent, mimeType: mime)
                attachments.append(APIHomeworkAttachment(id: UUID().uuidString, name: url.lastPathComponent, objectKey: key, mimeType: mime, sizeBytes: data.count))
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    @MainActor private func save() async {
        errorMessage = nil
        guard !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { errorMessage = kind == .plan ? "请输入计划名称" : kind == .mistake ? "请输入错题标题" : "请输入作业标题"; return }
        if kind == .homework {
            guard !classId.isEmpty else { errorMessage = "请选择班级"; return }
            if audienceType == "selected", selectedStudentIds.isEmpty { errorMessage = "请选择至少一名学生"; return }
        }
        if kind == .mistake, studentId.isEmpty { errorMessage = "请选择学生"; return }
        if kind == .plan, category == "weekly", weekDays.isEmpty { errorMessage = "请至少选择一个重复星期"; return }

        isSaving = true
        defer { isSaving = false }
        do {
            let repository = ClassTraceRepository(client: dependencies.client)
            switch kind {
            case .homework:
                _ = try await repository.createHomework(
                    classId: classId,
                    title: title.trimmingCharacters(in: .whitespacesAndNewlines),
                    content: content.trimmingCharacters(in: .whitespacesAndNewlines),
                    dueAt: deadline,
                    publish: true,
                    audienceType: audienceType,
                    targetStudentIds: Array(selectedStudentIds),
                    attachments: attachments
                )
            case .plan:
                _ = try await repository.createPlan(
                    studentId: studentId.nilIfEmpty,
                    title: title.trimmingCharacters(in: .whitespacesAndNewlines),
                    description: remark.nilIfEmpty,
                    subject: subject,
                    category: category,
                    time: planTime.formatted(.dateTime.hour(.twoDigits(amPM: .omitted)).minute(.twoDigits)),
                    deadline: Self.dayFormatter.string(from: deadline),
                    reminder: reminder,
                    weekDays: weekDays.sorted(),
                    remark: remark.nilIfEmpty
                )
            case .mistake:
                _ = try await repository.createMistake(
                    studentId: studentId,
                    subject: subject.nilIfEmpty,
                    title: title.trimmingCharacters(in: .whitespacesAndNewlines),
                    content: content.nilIfEmpty,
                    answer: correctAnswer.nilIfEmpty,
                    analysis: analysis.nilIfEmpty,
                    wrongAnswer: wrongAnswer.nilIfEmpty,
                    tags: tags
                )
            }
            await onSaved()
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private static let dayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()
}

private enum LearningCreateError: LocalizedError {
    case fileTooLarge(String)
    var errorDescription: String? {
        switch self { case let .fileTooLarge(name): "\(name) 超过 20MB" }
    }
}

private struct FlowLayout: Layout {
    var spacing: CGFloat
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? 0
        var rowWidth: CGFloat = 0
        var totalHeight: CGFloat = 0
        var rowHeight: CGFloat = 0
        for view in subviews {
            let size = view.sizeThatFits(.unspecified)
            if rowWidth + size.width > width, rowWidth > 0 {
                totalHeight += rowHeight + spacing
                rowWidth = 0
                rowHeight = 0
            }
            rowWidth += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
        return CGSize(width: width, height: totalHeight + rowHeight)
    }
    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var point = bounds.origin
        var rowHeight: CGFloat = 0
        for view in subviews {
            let size = view.sizeThatFits(.unspecified)
            if point.x + size.width > bounds.maxX, point.x > bounds.minX {
                point.x = bounds.minX
                point.y += rowHeight + spacing
                rowHeight = 0
            }
            view.place(at: point, proposal: ProposedViewSize(size))
            point.x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}
