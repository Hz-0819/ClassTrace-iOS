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

    init(initialSelection: Int = 0) {
        _selection = State(initialValue: initialSelection)
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 16) {
                Picker("教学内容", selection: $selection) { Text("作业").tag(0); Text("资料").tag(1); Text("计划").tag(2); Text("错题").tag(3) }.pickerStyle(.segmented).padding(.horizontal, 16)
                if isLoading { ProgressView().tint(MPColor.blue).padding(.vertical, 100) }
                else if let errorMessage { MPCard { MPEmptyView(image: "null", title: "加载失败", detail: errorMessage) }.padding(.horizontal, 16) }
                else { list }
            }.padding(.vertical, 16)
        }
        .background(MPColor.page).navigationTitle("教学与学习").navigationBarTitleDisplayMode(.inline)
        .toolbar { ToolbarItem(placement: .topBarTrailing) { Menu { Button("新建作业") { sheet = .homework }; Button("上传资料") { sheet = .material }; Button("新建计划") { sheet = .plan }; Button("录入错题") { sheet = .mistake } } label: { Label("\(points?.balance ?? 0)", systemImage: "plus.circle.fill") } } }
        .sheet(item: $sheet) { item in switch item { case .homework: NewLearningItemView(kind: .homework, classes: classes, students: students) { await load() }; case .material: MaterialUploadView(classes: classes) { await load() }; case .plan: NewLearningItemView(kind: .plan, classes: classes, students: students) { await load() }; case .mistake: NewLearningItemView(kind: .mistake, classes: classes, students: students) { await load() } } }
        .refreshable { await load() }.task { if homework.isEmpty && plans.isEmpty { await load() } }
    }
    @ViewBuilder private var list: some View {
        VStack(spacing: 12) {
            MPSectionHeader(title: ["作业管理", "资料中心", "学习计划", "错题本"][selection])
            if selection == 0 {
                if homework.isEmpty { MPCard { MPEmptyView(image: "file", title: "暂无作业", detail: "教师发布的作业会显示在这里") } }
                ForEach(homework) { item in NavigationLink { HomeworkDetailView(homework: item, students: students) { await load() } } label: { learningCard(image: "file-red", color: MPColor.red, title: item.title, subtitle: item.content, trailing: item.status.localizedStatus, footnote: item.dueAt.map { "截止：\($0.formatted(date: .abbreviated, time: .shortened))" }) }.buttonStyle(.plain) }
            } else if selection == 1 {
                if materials.isEmpty { MPCard { MPEmptyView(image: "material-brown", title: "暂无资料", detail: "课堂资料会显示在这里") } }
                ForEach(materials) { item in Button { Task { await open(item) } } label: { learningCard(image: "material-brown", color: MPColor.gold, title: item.name, subtitle: item.category ?? "课堂资料", trailing: nil, footnote: ByteCountFormatter.string(fromByteCount: Int64(item.sizeBytes), countStyle: .file)) }.buttonStyle(.plain) }
            } else if selection == 2 {
                if plans.isEmpty { MPCard { MPEmptyView(image: "plan-brown", title: "暂无学习计划", detail: "创建计划并坚持每日打卡") } }
                ForEach(plans) { plan in MPCard { VStack(spacing: 12) { NavigationLink { PlanDetailView(plan: plan) { await load() } } label: { HStack(spacing: 12) { MPIconTile(image: "plan-brown", color: MPColor.gold, size: 46); VStack(alignment: .leading, spacing: 5) { Text(plan.title).font(.system(size: 15, weight: .semibold)); Text(plan.description ?? "").font(.system(size: 12)).foregroundStyle(MPColor.secondary) }; Spacer(); Text(plan.status.localizedStatus).font(.caption).foregroundStyle(MPColor.blue) } }.buttonStyle(.plain); Button("今日打卡") { Task { await checkIn(plan.id) } }.font(.system(size: 13, weight: .medium)).foregroundStyle(.white).frame(maxWidth: .infinity, minHeight: 38).background(MPColor.blue, in: Capsule()).disabled(plan.status != "ACTIVE") } }
            } else {
                if mistakes.isEmpty { MPCard { MPEmptyView(image: "mistakebook-red", title: "暂无错题", detail: "整理错题并标记掌握状态") } }
                ForEach(mistakes) { item in NavigationLink { MistakeDetailView(mistake: item) { await load() } } label: { learningCard(image: "mistakebook-red", color: MPColor.red, title: item.title, subtitle: item.analysis ?? item.content ?? "", trailing: item.masteredAt == nil ? item.subject : "已掌握", footnote: nil) }.buttonStyle(.plain) }
            }
        }.padding(.horizontal, 16)
    }

    private func learningCard(image: String, color: Color, title: String, subtitle: String, trailing: String?, footnote: String?) -> some View {
        MPCard { HStack(spacing: 12) { MPIconTile(image: image, color: color, size: 48); VStack(alignment: .leading, spacing: 5) { HStack { Text(title).font(.system(size: 15, weight: .semibold)).foregroundStyle(MPColor.text); Spacer(); if let trailing { Text(trailing).font(.system(size: 11, weight: .medium)).foregroundStyle(color) } }; Text(subtitle).font(.system(size: 12)).foregroundStyle(MPColor.secondary).lineLimit(2); if let footnote { Text(footnote).font(.system(size: 11)).foregroundStyle(MPColor.secondary) } }; Image(systemName: "chevron.right").font(.caption.bold()).foregroundStyle(MPColor.secondary) } }
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
