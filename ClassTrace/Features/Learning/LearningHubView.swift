import SwiftUI
import UIKit

struct LearningHubView: View {
    @Environment(AppDependencies.self) private var dependencies
    @State private var selection = 0
    @State private var homework: [APIHomework] = []
    @State private var materials: [APIMaterial] = []
    @State private var plans: [APIStudyPlan] = []
    @State private var mistakes: [APIMistake] = []
    @State private var points: APIPoints?
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var classes: [APIClassroom] = []
    @State private var students: [APIStudent] = []
    @State private var sheet: Sheet?
    enum Sheet: Int, Identifiable { case homework, material, plan, mistake; var id: Int { rawValue } }

    var body: some View {
        VStack(spacing: 0) {
            Picker("教学内容", selection: $selection) { Text("作业").tag(0); Text("资料").tag(1); Text("计划").tag(2); Text("错题").tag(3) }.pickerStyle(.segmented).padding()
            if isLoading { Spacer(); ProgressView(); Spacer() }
            else if let errorMessage { CTStateView(kind: .error, title: "加载失败", message: LocalizedStringKey(errorMessage), actionTitle: "重试") { Task { await load() } } }
            else { list }
        }
        .background(Color.ctPage).navigationTitle("教学与学习")
        .toolbar { ToolbarItem(placement: .topBarTrailing) { Menu { Button("新建作业") { sheet = .homework }; Button("上传资料") { sheet = .material }; Button("新建计划") { sheet = .plan }; Button("录入错题") { sheet = .mistake } } label: { Label("\(points?.balance ?? 0)", systemImage: "plus.circle.fill") } } }
        .sheet(item: $sheet) { item in switch item { case .homework: NewLearningItemView(kind: .homework, classes: classes, students: students) { await load() }; case .material: MaterialUploadView(classes: classes) { await load() }; case .plan: NewLearningItemView(kind: .plan, classes: classes, students: students) { await load() }; case .mistake: NewLearningItemView(kind: .mistake, classes: classes, students: students) { await load() } } }
        .refreshable { await load() }.task { if homework.isEmpty && plans.isEmpty { await load() } }
    }
    @ViewBuilder private var list: some View {
        if selection == 0 { List(homework) { item in NavigationLink { HomeworkDetailView(homework: item, students: students) { await load() } } label: { VStack(alignment: .leading) { HStack { Text(item.title).font(.headline); Spacer(); Text(item.status.localizedStatus).foregroundStyle(Color.ctTextSecondary) }; Text(item.content).font(.subheadline).lineLimit(2); if let due = item.dueAt { Text("截止：\(due.formatted(date: .abbreviated, time: .shortened))").font(.caption).foregroundStyle(Color.ctTextSecondary) } } } }.overlay { if homework.isEmpty { CTStateView(kind: .empty, title: "暂无作业", message: "教师发布的作业会显示在这里") } } }
        else if selection == 1 { List(materials) { item in Button { Task { await open(item) } } label: { HStack { Image(systemName: "doc.fill").foregroundStyle(Color.ctBrand); VStack(alignment: .leading) { Text(item.name); Text(ByteCountFormatter.string(fromByteCount: Int64(item.sizeBytes), countStyle: .file)).font(.caption).foregroundStyle(Color.ctTextSecondary) } } }.buttonStyle(.plain) }.overlay { if materials.isEmpty { CTStateView(kind: .empty, title: "暂无资料", message: "课堂资料会显示在这里") } } }
        else if selection == 2 { List(plans) { plan in NavigationLink { PlanDetailView(plan: plan) { await load() } } label: { VStack(alignment: .leading, spacing: 8) { HStack { Text(plan.title).font(.headline); Spacer(); Text(plan.status.localizedStatus) }; Text(plan.description ?? "").font(.subheadline).foregroundStyle(Color.ctTextSecondary) } }; Button("今日打卡") { Task { await checkIn(plan.id) } }.buttonStyle(.bordered).disabled(plan.status != "ACTIVE") }.overlay { if plans.isEmpty { CTStateView(kind: .empty, title: "暂无学习计划", message: "创建计划并坚持每日打卡") } } }
        else { List(mistakes) { item in NavigationLink { MistakeDetailView(mistake: item) { await load() } } label: { VStack(alignment: .leading) { HStack { Text(item.title).font(.headline); Spacer(); if item.masteredAt != nil { Image(systemName: "checkmark.seal.fill").foregroundStyle(Color.ctSuccess) } }; Text(item.subject ?? "未分类").font(.caption).foregroundStyle(Color.ctTextSecondary); Text(item.analysis ?? item.content ?? "").lineLimit(2) } } }.overlay { if mistakes.isEmpty { CTStateView(kind: .empty, title: "暂无错题", message: "整理错题并标记掌握状态") } } }
    }
    @MainActor private func load() async {
        isLoading = true; defer { isLoading = false }; errorMessage = nil
        let repository = ClassTraceRepository(client: dependencies.client)
        do { async let h = repository.homework(); async let m = repository.materials(); async let p = repository.plans(); async let w = repository.mistakes(); async let s = repository.points(); async let c = repository.classes(); async let t = repository.students(); (homework, materials, plans, mistakes, points, classes, students) = try await (h, m, p, w, s, c, t) }
        catch { errorMessage = error.localizedDescription }
    }
    @MainActor private func checkIn(_ id: String) async { do { _ = try await ClassTraceRepository(client: dependencies.client).checkIn(planId: id, note: nil); await load() } catch { errorMessage = error.localizedDescription } }
    @MainActor private func open(_ material: APIMaterial) async { do { let url = try await FileTransferService(client: dependencies.client).downloadURL(objectKey: material.objectKey); await UIApplication.shared.open(url) } catch { errorMessage = error.localizedDescription } }
}
