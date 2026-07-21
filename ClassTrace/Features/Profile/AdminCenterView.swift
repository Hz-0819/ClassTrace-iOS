import SwiftUI

struct AdminCenterView: View {
    @Environment(AppDependencies.self) private var dependencies
    @State private var title = ""; @State private var content = ""; @State private var audience = "ALL"; @State private var days = 30; @State private var activation: ActivationCodePayload?; @State private var error: String?
    @State private var feedback: [APIFeedback] = []
    var body: some View { Form {
        Section("发布公告") { TextField("标题", text: $title); TextField("内容", text: $content, axis: .vertical); Picker("受众", selection: $audience) { Text("全部").tag("ALL"); Text("教师").tag("TEACHER"); Text("家长").tag("GUARDIAN") }; Button("发布") { Task { await publish() } }.disabled(title.isEmpty || content.isEmpty) }
        Section("生成 VIP 激活码") { Stepper("有效权益 \(days) 天", value: $days, in: 1...3650); Button("生成") { Task { await createCode() } }; if let activation { ShareLink(item: activation.code) { Label("分享 \(activation.code)", systemImage: "square.and.arrow.up") } } }
        Section("用户反馈") { ForEach(feedback) { item in NavigationLink { AdminFeedbackReplyView(item: item) { await loadFeedback() } } label: { VStack(alignment: .leading) { Text(item.category).font(.headline); Text(item.content).lineLimit(2); Text(item.status.localizedStatus).font(.caption) } } } }
        if let error { Text(error).foregroundStyle(Color.ctDanger) }
    }.navigationTitle("管理员工具").task { await loadFeedback() } }
    @MainActor private func publish() async { do { _ = try await ClassTraceRepository(client: dependencies.client).createAnnouncement(title: title, content: content, audience: audience == "ALL" ? ["TEACHER", "GUARDIAN", "ADMIN"] : [audience]); title = ""; content = "" } catch { self.error = error.localizedDescription } }
    @MainActor private func createCode() async { do { activation = try await ClassTraceRepository(client: dependencies.client).createActivationCode(days: days) } catch { self.error = error.localizedDescription } }
    @MainActor private func loadFeedback() async { feedback = (try? await ClassTraceRepository(client: dependencies.client).adminFeedback()) ?? [] }
}

private struct AdminFeedbackReplyView: View {
    @Environment(\.dismiss) private var dismiss; @Environment(AppDependencies.self) private var dependencies
    let item: APIFeedback; let onSaved: () async -> Void
    @State private var reply = ""; @State private var status = "RESOLVED"; @State private var error: String?
    var body: some View { Form { Section("反馈") { Text(item.content) }; TextField("客服回复", text: $reply, axis: .vertical); Picker("状态", selection: $status) { Text("处理中").tag("PROCESSING"); Text("已解决").tag("RESOLVED"); Text("已关闭").tag("CLOSED") }; if let error { Text(error).foregroundStyle(Color.ctDanger) }; Button("发送回复") { Task { await save() } }.disabled(reply.isEmpty) }.navigationTitle("处理反馈") }
    @MainActor private func save() async { do { _ = try await ClassTraceRepository(client: dependencies.client).replyFeedback(item.id, reply: reply, status: status); await onSaved(); dismiss() } catch { self.error = error.localizedDescription } }
}
