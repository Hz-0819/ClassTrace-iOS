import SwiftUI

struct PointsCenterView: View {
    @Environment(AppDependencies.self) private var dependencies
    @State private var points: APIPoints?
    @State private var filter: Filter = .all
    @State private var errorMessage: String?

    private enum Filter: String, CaseIterable, Identifiable {
        case all = "全部", checkIn = "打卡", homework = "作业", attendance = "考勤"
        var id: String { rawValue }
    }

    private var entries: [APIPointEntry] { points?.entries.sorted { $0.createdAt > $1.createdAt } ?? [] }
    private var filteredEntries: [APIPointEntry] {
        entries.filter { entry in
            switch filter {
            case .all: true
            case .checkIn: contains(entry, ["打卡", "计划", "签到"])
            case .homework: contains(entry, ["作业", "提交", "优秀"])
            case .attendance: contains(entry, ["考勤", "出勤", "上课"])
            }
        }
    }
    private var todayPoints: Int { positivePoints(since: Calendar.current.startOfDay(for: Date())) }
    private var weekPoints: Int { positivePoints(since: Calendar.current.dateInterval(of: .weekOfYear, for: Date())?.start ?? Date()) }
    private var monthPoints: Int { positivePoints(since: Calendar.current.dateInterval(of: .month, for: Date())?.start ?? Date()) }
    private var streakDays: Int {
        let days = Set(entries.filter { $0.delta > 0 }.map { Calendar.current.startOfDay(for: $0.createdAt) })
        var count = 0; var cursor = Calendar.current.startOfDay(for: Date())
        while days.contains(cursor) { count += 1; cursor = Calendar.current.date(byAdding: .day, value: -1, to: cursor) ?? cursor.addingTimeInterval(-86_400) }
        return count
    }
    private var growth: (name: String, floor: Int, ceiling: Int) {
        let balance = points?.balance ?? 0
        return switch balance {
        case ..<100: ("成长树苗", 0, 100)
        case ..<300: ("成长小树", 100, 300)
        case ..<600: ("成长大树", 300, 600)
        default: ("学习之星", 600, 1_000)
        }
    }
    private var growthProgress: Double {
        let current = max(0, (points?.balance ?? 0) - growth.floor)
        return min(1, Double(current) / Double(max(1, growth.ceiling - growth.floor)))
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            LazyVStack(spacing: 16) {
                overviewCard
                periodStats
                growthCard
                filterBar
                recordSection
                if let errorMessage { Text(errorMessage).font(.footnote).foregroundStyle(MPColor.red).padding(.horizontal, 16) }
            }.padding(.vertical, 16)
        }
        .background(MPColor.page).navigationTitle("我的积分")
        .task { await load() }.refreshable { await load() }
    }

    private var overviewCard: some View {
        ZStack {
            LinearGradient(colors: [MPColor.gold, MPColor.coral], startPoint: .topLeading, endPoint: .bottomTrailing)
            Circle().fill(.white.opacity(0.10)).frame(width: 130, height: 130).offset(x: 150, y: -40)
            HStack {
                VStack(alignment: .leading, spacing: 7) {
                    Text("总积分").font(.system(size: 13))
                    Text("\(points?.balance ?? 0)").font(.system(size: 40, weight: .bold))
                    if streakDays > 0 { Label("连续活跃 \(streakDays) 天", systemImage: "flame.fill").font(.system(size: 12, weight: .semibold)) }
                    else { Text("完成学习任务即可获得积分").font(.system(size: 12)).opacity(0.85) }
                }
                Spacer(); MPLegacyImage(name: "points-red", size: 68)
            }.foregroundStyle(.white).padding(22)
        }.frame(height: 164).clipShape(RoundedRectangle(cornerRadius: 20)).padding(.horizontal, 16)
    }

    private var periodStats: some View {
        MPCard {
            HStack {
                stat("今日", todayPoints)
                divider
                stat("本周", weekPoints)
                divider
                stat("本月", monthPoints)
            }
        }.padding(.horizontal, 16)
    }

    private var growthCard: some View {
        MPCard {
            HStack(spacing: 12) {
                MPIconTile(image: "fourstar", color: MPColor.green, size: 48)
                VStack(alignment: .leading, spacing: 7) {
                    HStack {
                        Text(growth.name).font(.system(size: 14, weight: .bold))
                        Spacer()
                        Text("距离下一等级还差 \(max(0, growth.ceiling - (points?.balance ?? 0))) 分")
                            .font(.system(size: 10)).foregroundStyle(MPColor.secondary)
                    }
                    ProgressView(value: growthProgress).tint(MPColor.green)
                }
            }
        }.padding(.horizontal, 16)
    }

    private func stat(_ title: String, _ value: Int) -> some View {
        VStack(spacing: 5) { Text("+\(value)").font(.system(size: 19, weight: .bold)).foregroundStyle(MPColor.gold); Text(title).font(.system(size: 11)).foregroundStyle(MPColor.secondary) }.frame(maxWidth: .infinity)
    }
    private var divider: some View { Rectangle().fill(.black.opacity(0.07)).frame(width: 0.5, height: 36) }

    private var filterBar: some View {
        HStack(spacing: 8) {
            ForEach(Filter.allCases) { item in
                Button(item.rawValue) { filter = item }
                    .font(.system(size: 13, weight: .semibold)).foregroundStyle(filter == item ? .white : MPColor.text)
                    .frame(maxWidth: .infinity).padding(.vertical, 9)
                    .background(filter == item ? MPColor.blue : .white, in: Capsule())
            }
        }.padding(.horizontal, 16)
    }

    private var recordSection: some View {
        VStack(spacing: 12) {
            MPSectionHeader(title: "积分明细")
            if filteredEntries.isEmpty { MPCard { MPEmptyView(image: "points-red", title: "暂无积分记录", detail: "该分类下还没有积分变化") } }
            ForEach(filteredEntries) { entry in pointRow(entry) }
        }.padding(.horizontal, 16)
    }

    private func pointRow(_ entry: APIPointEntry) -> some View {
        HStack(spacing: 12) {
            MPIconTile(image: icon(entry), color: color(entry).opacity(0.95), size: 44)
            VStack(alignment: .leading, spacing: 4) {
                Text(entry.reason).font(.system(size: 14, weight: .semibold)).foregroundStyle(MPColor.text)
                HStack(spacing: 6) { Text(category(entry)); Text(timeText(entry.createdAt)) }.font(.system(size: 11)).foregroundStyle(MPColor.secondary)
            }
            Spacer(); Text("\(entry.delta >= 0 ? "+" : "")\(entry.delta)").font(.system(size: 17, weight: .bold)).foregroundStyle(entry.delta >= 0 ? MPColor.green : MPColor.red)
        }.padding(14).background(.white, in: RoundedRectangle(cornerRadius: 15))
    }

    private func contains(_ entry: APIPointEntry, _ values: [String]) -> Bool { values.contains { entry.reason.localizedCaseInsensitiveContains($0) } }
    private func category(_ entry: APIPointEntry) -> String {
        if contains(entry, ["打卡", "计划", "签到"]) { return "打卡" }
        if contains(entry, ["作业", "提交", "优秀"]) { return "作业" }
        if contains(entry, ["考勤", "出勤", "上课"]) { return "考勤" }
        return "其他"
    }
    private func icon(_ entry: APIPointEntry) -> String {
        switch category(entry) { case "打卡": "plan-brown"; case "作业": "file-red"; case "考勤": "timetable-blue"; default: entry.delta >= 0 ? "points-red" : "bill-red" }
    }
    private func color(_ entry: APIPointEntry) -> Color {
        switch category(entry) { case "打卡": MPColor.gold; case "作业": MPColor.red; case "考勤": MPColor.blue; default: MPColor.green }
    }
    private func positivePoints(since date: Date) -> Int { entries.filter { $0.createdAt >= date && $0.delta > 0 }.reduce(0) { $0 + $1.delta } }
    private func timeText(_ date: Date) -> String {
        if Calendar.current.isDateInToday(date) { return "今天 \(date.formatted(date: .omitted, time: .shortened))" }
        if Calendar.current.isDateInYesterday(date) { return "昨天 \(date.formatted(date: .omitted, time: .shortened))" }
        return date.formatted(date: .abbreviated, time: .shortened)
    }

    @MainActor private func load() async {
        do { points = try await ClassTraceRepository(client: dependencies.client).points(); errorMessage = nil }
        catch { errorMessage = error.localizedDescription }
    }
}
