import SwiftUI
import PhotosUI
import UniformTypeIdentifiers
import UIKit

struct FeedbackCenterView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AppDependencies.self) private var dependencies
    @State private var category = "功能异常"
    @State private var content = ""
    @State private var contact = ""
    @State private var photoItems: [PhotosPickerItem] = []
    @State private var photos: [FeedbackAttachment] = []
    @State private var files: [FeedbackAttachment] = []
    @State private var showFileImporter = false
    @State private var submitting = false
    @State private var submitted = false
    @State private var history: [APIFeedback] = []
    @State private var errorMessage: String?
    private let categories = ["功能异常", "功能建议", "界面体验", "账号问题", "其他"]

    var body: some View {
        Group {
            if submitted { successView }
            else { formView }
        }
        .background(MPColor.page).navigationTitle("问题反馈")
        .fileImporter(isPresented: $showFileImporter, allowedContentTypes: [.pdf, .plainText, .spreadsheet, .presentation, .data], allowsMultipleSelection: true, onCompletion: importFiles)
        .task { await loadHistory() }
        .onChange(of: photoItems) { _, values in Task { await importPhotos(values) } }
    }

    private var formView: some View {
        ScrollView(showsIndicators: false) {
            LazyVStack(spacing: 16) {
                MPCard {
                    VStack(alignment: .leading, spacing: 16) {
                        fieldTitle("反馈类型", required: true)
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 92))], spacing: 10) {
                            ForEach(categories, id: \.self) { item in
                                Button(item) { category = item }
                                    .font(.system(size: 13, weight: .semibold)).foregroundStyle(category == item ? .white : MPColor.text)
                                    .padding(.vertical, 10).frame(maxWidth: .infinity)
                                    .background(category == item ? MPColor.blue : MPColor.page, in: RoundedRectangle(cornerRadius: 10))
                            }
                        }

                        fieldTitle("问题描述", required: true)
                        ZStack(alignment: .bottomTrailing) {
                            TextEditor(text: $content).scrollContentBackground(.hidden).frame(minHeight: 150).padding(8)
                                .background(MPColor.page, in: RoundedRectangle(cornerRadius: 12))
                                .onChange(of: content) { _, value in if value.count > 500 { content = String(value.prefix(500)) } }
                            Text("\(content.count)/500").font(.system(size: 11)).foregroundStyle(MPColor.secondary).padding(12)
                        }

                        fieldTitle("图片和文件", required: false)
                        if !photos.isEmpty { photoGrid }
                        if !files.isEmpty { fileList }
                        HStack(spacing: 10) {
                            PhotosPicker(selection: $photoItems, maxSelectionCount: max(0, 6 - photos.count), matching: .images) {
                                attachmentButton("选择图片", "photo.on.rectangle")
                            }.disabled(photos.count >= 6)
                            Button { showFileImporter = true } label: { attachmentButton("选择文件", "doc.badge.plus") }
                                .disabled(files.count >= 6)
                        }

                        fieldTitle("联系方式", required: false)
                        TextField("手机号、微信或邮箱（选填）", text: $contact).textFieldStyle(.roundedBorder)
                        if let errorMessage { Text(errorMessage).font(.system(size: 12)).foregroundStyle(MPColor.red) }
                        Button { Task { await submit() } } label: {
                            Group { if submitting { ProgressView().tint(.white) } else { Text("提交反馈").fontWeight(.semibold) } }
                                .frame(maxWidth: .infinity).padding(14).foregroundStyle(.white)
                                .background(canSubmit ? MPColor.blue : MPColor.secondary, in: RoundedRectangle(cornerRadius: 12))
                        }.disabled(!canSubmit || submitting)
                    }
                }.padding(.horizontal, 16)
                if !history.isEmpty { historySection }
            }.padding(.vertical, 16)
        }
    }

    private var successView: some View {
        VStack(spacing: 20) {
            Spacer()
            ZStack { Circle().fill(MPColor.green.opacity(0.12)); Image(systemName: "checkmark").font(.system(size: 34, weight: .bold)).foregroundStyle(MPColor.green) }.frame(width: 92, height: 92)
            Text("反馈已提交").font(.system(size: 24, weight: .bold)).foregroundStyle(MPColor.text)
            Text("感谢你的反馈，我们会尽快查看并处理。处理进度和回复会保留在历史反馈中。")
                .font(.system(size: 14)).foregroundStyle(MPColor.secondary).multilineTextAlignment(.center).padding(.horizontal, 38)
            Button("再提一条") { resetForm() }.font(.system(size: 15, weight: .semibold)).foregroundStyle(.white)
                .frame(maxWidth: .infinity).padding(14).background(MPColor.blue, in: RoundedRectangle(cornerRadius: 13)).padding(.horizontal, 28)
            Button("返回") { dismiss() }.font(.system(size: 15, weight: .semibold)).foregroundStyle(MPColor.blue)
            Spacer()
        }
    }

    private var photoGrid: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 3), spacing: 8) {
            ForEach(photos) { item in
                ZStack(alignment: .topTrailing) {
                    if let image = UIImage(data: item.data) { Image(uiImage: image).resizable().scaledToFill().frame(height: 92).frame(maxWidth: .infinity).clipped().clipShape(RoundedRectangle(cornerRadius: 10)) }
                    Button { photos.removeAll { $0.id == item.id } } label: { Image(systemName: "xmark.circle.fill").font(.system(size: 20)).foregroundStyle(.white).shadow(radius: 2) }.padding(5)
                }
            }
        }
    }

    private var fileList: some View {
        VStack(spacing: 8) {
            ForEach(files) { file in
                HStack(spacing: 10) {
                    MPIconTile(image: "file-blue", color: MPColor.blue, size: 38)
                    VStack(alignment: .leading, spacing: 2) { Text(file.name).font(.system(size: 12, weight: .medium)).lineLimit(1); Text(ByteCountFormatter.string(fromByteCount: Int64(file.data.count), countStyle: .file)).font(.system(size: 10)).foregroundStyle(MPColor.secondary) }
                    Spacer(); Button { files.removeAll { $0.id == file.id } } label: { Image(systemName: "xmark.circle.fill").foregroundStyle(MPColor.secondary) }
                }.padding(9).background(MPColor.page, in: RoundedRectangle(cornerRadius: 10))
            }
        }
    }

    private var historySection: some View {
        VStack(spacing: 12) {
            MPSectionHeader(title: "历史反馈")
            ForEach(history) { item in
                MPCard {
                    VStack(alignment: .leading, spacing: 7) {
                        HStack { Text(item.category).font(.system(size: 14, weight: .bold)); Spacer(); Text(item.status.localizedStatus).font(.system(size: 11, weight: .semibold)).foregroundStyle(MPColor.blue) }
                        Text(item.content.components(separatedBy: "\n附件：").first ?? item.content).font(.system(size: 13)).lineLimit(4)
                        Text(item.createdAt.formatted(date: .abbreviated, time: .shortened)).font(.system(size: 10)).foregroundStyle(MPColor.secondary)
                        if let reply = item.reply { Text("回复：\(reply)").font(.system(size: 12)).foregroundStyle(MPColor.green).padding(9).frame(maxWidth: .infinity, alignment: .leading).background(MPColor.green.opacity(0.08), in: RoundedRectangle(cornerRadius: 9)) }
                    }
                }
            }
        }.padding(.horizontal, 16)
    }

    private var canSubmit: Bool { !content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    private func fieldTitle(_ title: String, required: Bool) -> some View { HStack(spacing: 4) { Text(title).font(.system(size: 16, weight: .bold)); if required { Text("*").foregroundStyle(MPColor.red) } } }
    private func attachmentButton(_ title: String, _ symbol: String) -> some View { Label(title, systemImage: symbol).font(.system(size: 13, weight: .semibold)).foregroundStyle(MPColor.blue).frame(maxWidth: .infinity).padding(12).background(MPColor.blue.opacity(0.1), in: RoundedRectangle(cornerRadius: 11)) }

    private func importFiles(_ result: Result<[URL], Error>) {
        do {
            for url in try result.get().prefix(max(0, 6 - files.count)) {
                let accessed = url.startAccessingSecurityScopedResource(); defer { if accessed { url.stopAccessingSecurityScopedResource() } }
                let data = try Data(contentsOf: url)
                files.append(FeedbackAttachment(name: url.lastPathComponent, data: data, mimeType: UTType(filenameExtension: url.pathExtension)?.preferredMIMEType ?? "application/octet-stream"))
            }
            errorMessage = nil
        } catch { errorMessage = "文件读取失败：\(error.localizedDescription)" }
    }

    @MainActor private func importPhotos(_ values: [PhotosPickerItem]) async {
        for value in values.prefix(max(0, 6 - photos.count)) {
            if let data = try? await value.loadTransferable(type: Data.self) { photos.append(FeedbackAttachment(name: "feedback-\(UUID().uuidString).jpg", data: data, mimeType: "image/jpeg")) }
        }
        photoItems = []
    }

    @MainActor private func submit() async {
        submitting = true; defer { submitting = false }
        do {
            let saved = try FeedbackAttachmentStore.save(photos + files)
            let body = saved.isEmpty ? content : content + "\n附件：" + saved.joined(separator: "、")
            _ = try await ClassTraceRepository(client: dependencies.client).submitFeedback(category: category, content: body, contact: contact.nilIfEmpty)
            await loadHistory(); submitted = true; errorMessage = nil
        } catch { errorMessage = error.localizedDescription }
    }

    @MainActor private func loadHistory() async { history = (try? await ClassTraceRepository(client: dependencies.client).feedback()) ?? [] }
    private func resetForm() { category = "功能异常"; content = ""; contact = ""; photos = []; files = []; submitted = false; errorMessage = nil }
}

private struct FeedbackAttachment: Identifiable {
    let id = UUID()
    let name: String
    let data: Data
    let mimeType: String
}

private enum FeedbackAttachmentStore {
    static func save(_ attachments: [FeedbackAttachment]) throws -> [String] {
        guard !attachments.isEmpty else { return [] }
        let root = try FileManager.default.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
            .appendingPathComponent("ClassTrace/FeedbackAttachments", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        return try attachments.map { item in
            let safeName = item.name.replacingOccurrences(of: "/", with: "-")
            let url = root.appendingPathComponent("\(UUID().uuidString)-\(safeName)")
            try item.data.write(to: url, options: .atomic)
            return url.lastPathComponent
        }
    }
}
