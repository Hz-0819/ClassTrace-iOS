import SwiftUI

struct ManualScheduleView: View {
    @Environment(AppDependencies.self) private var dependencies
    @State private var items: [APIManualCourse] = []; @State private var editing: APIManualCourse?; @State private var showNew = false
    var body: some View { List(items) { item in Button { editing = item } label: { VStack(alignment: .leading) { Text(item.name).font(.headline); Text(item.startsAt.formatted(date: .abbreviated, time: .shortened)); Text(item.location ?? "").font(.caption).foregroundStyle(Color.ctTextSecondary) } }.buttonStyle(.plain) }.overlay { if items.isEmpty { CTStateView(kind: .empty, title: "暂无个人日程", message: "可记录不属于班级排课的临时事项。") } }.navigationTitle("个人日程").toolbar { Button { showNew = true } label: { Image(systemName: "plus") } }.sheet(isPresented: $showNew) { ManualCourseEditor(item: nil) { await load() } }.sheet(item: $editing) { item in ManualCourseEditor(item: item) { await load() } }.task { await load() } }
    @MainActor private func load() async { items = (try? await ClassTraceRepository(client: dependencies.client).manualCourses()) ?? [] }
}

private struct ManualCourseEditor: View {
    @Environment(\.dismiss) private var dismiss; @Environment(AppDependencies.self) private var dependencies
    let item: APIManualCourse?; let onSaved: () async -> Void
    @State private var name: String; @State private var startsAt: Date; @State private var endsAt: Date; @State private var location: String; @State private var note: String; @State private var error: String?
    init(item: APIManualCourse?, onSaved: @escaping () async -> Void) { self.item = item; self.onSaved = onSaved; _name = State(initialValue: item?.name ?? ""); _startsAt = State(initialValue: item?.startsAt ?? Date()); _endsAt = State(initialValue: item?.endsAt ?? Date().addingTimeInterval(3600)); _location = State(initialValue: item?.location ?? ""); _note = State(initialValue: item?.note ?? "") }
    var body: some View { NavigationStack { Form { TextField("事项名称", text: $name); DatePicker("开始", selection: $startsAt); DatePicker("结束", selection: $endsAt); TextField("地点", text: $location); TextField("备注", text: $note, axis: .vertical); if let error { Text(error).foregroundStyle(Color.ctDanger) }; if item != nil { Button("删除", role: .destructive) { Task { await remove() } } } }.navigationTitle(item == nil ? "添加日程" : "编辑日程").toolbar { ToolbarItem(placement: .cancellationAction) { Button("取消") { dismiss() } }; ToolbarItem(placement: .confirmationAction) { Button("保存") { Task { await save() } }.disabled(name.isEmpty || endsAt <= startsAt) } } } }
    @MainActor private func save() async { do { let r = ClassTraceRepository(client: dependencies.client); if let item { _ = try await r.updateManualCourse(item.id, name: name, startsAt: startsAt, endsAt: endsAt, location: location.nilIfEmpty, note: note.nilIfEmpty) } else { _ = try await r.createManualCourse(name: name, startsAt: startsAt, endsAt: endsAt, location: location.nilIfEmpty, note: note.nilIfEmpty) }; await onSaved(); dismiss() } catch { self.error = error.localizedDescription } }
    @MainActor private func remove() async { guard let item else { return }; do { try await ClassTraceRepository(client: dependencies.client).deleteManualCourse(item.id); await onSaved(); dismiss() } catch { self.error = error.localizedDescription } }
}

struct AnnouncementCenterView: View {
    @Environment(AppDependencies.self) private var dependencies; @State private var items: [APIAnnouncement] = []
    var body: some View { List(items) { item in NavigationLink { ScrollView { VStack(alignment: .leading, spacing: 16) { Text(item.title).font(.title2.bold()); Text(item.publishedAt?.formatted() ?? "").font(.caption).foregroundStyle(Color.ctTextSecondary); Text(item.content).frame(maxWidth: .infinity, alignment: .leading) }.padding() }.navigationTitle("公告详情") } label: { VStack(alignment: .leading) { Text(item.title).font(.headline); Text(item.content).lineLimit(2).foregroundStyle(Color.ctTextSecondary) } } }.navigationTitle("公告").task { items = (try? await ClassTraceRepository(client: dependencies.client).announcements()) ?? [] } }
}
