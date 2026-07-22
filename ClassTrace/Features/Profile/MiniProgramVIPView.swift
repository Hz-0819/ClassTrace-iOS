import SwiftUI
import StoreKit

struct VIPCenterView: View {
    @Environment(AppDependencies.self) private var dependencies
    @Environment(AppSession.self) private var session
    @State private var entitlements: APIEntitlements?
    @State private var store = StoreKitManager()
    @State private var activationCode = ""
    @State private var isRedeeming = false
    @State private var message: String?

    private var active: Bool { entitlements?.active == true }
    private var expiry: Date? { entitlements?.grants.compactMap(\.endsAt).max() }

    var body: some View {
        ScrollView(showsIndicators: false) {
            LazyVStack(spacing: 16) {
                hero
                benefits
                plans
                activation
                restore
                if let message { Text(message).font(.system(size: 12)).foregroundStyle(message.contains("失败") ? MPColor.red : MPColor.green).padding(.horizontal, 16) }
                Text("VIP 属于应用内数字服务，正式购买通过 App Store 完成；教学课费不通过 Apple 内购结算。")
                    .font(.system(size: 11)).foregroundStyle(MPColor.secondary).multilineTextAlignment(.center).padding(.horizontal, 28)
            }.padding(.vertical, 16)
        }.background(MPColor.page).navigationTitle("VIP 权益").task { await store.load(); await reload() }
    }

    private var hero: some View {
        ZStack {
            LinearGradient(colors: [MPColor.gold, MPColor.coral], startPoint: .topLeading, endPoint: .bottomTrailing)
            Circle().fill(.white.opacity(0.12)).frame(width: 140, height: 140).offset(x: 155, y: -50)
            HStack(spacing: 16) {
                ZStack { Circle().fill(.white.opacity(0.2)); MPLegacyImage(name: "vip-yellow", size: 58) }.frame(width: 76, height: 76)
                VStack(alignment: .leading, spacing: 7) { Text(active ? "VIP 权益已生效" : "开通课迹 VIP").font(.system(size: 23, weight: .bold)); Text(active ? expiry.map { "有效期至 \($0.formatted(date: .abbreviated, time: .omitted))" } ?? "长期有效" : "解锁更完整的教学管理能力").font(.system(size: 12)).opacity(0.85) }
                Spacer()
            }.foregroundStyle(.white).padding(22)
        }.frame(height: 145).clipShape(RoundedRectangle(cornerRadius: 20)).padding(.horizontal, 16)
    }

    private var benefits: some View {
        section("会员权益") {
            benefit("bar chart-orange", "完整经营分析", "查看更多月份、班级和学员维度的数据")
            benefit("file-blue", "更大资料空间", "保存更多课程资料与作业附件")
            benefit("report-blue", "教学数据导出", "导出课时、考勤和账号数据副本")
            benefit("notice", "高级提醒", "低课时、作业与课程提醒统一管理")
        }
    }

    private var plans: some View {
        section("订阅方案") {
            if store.products.isEmpty {
                Text(DemoMode.isEnabled ? "测试版本未连接 App Store 商品，可使用下方测试激活码验证完整权益流程。" : "订阅商品暂不可用，请稍后刷新或检查 App Store 账号。")
                    .font(.system(size: 12)).foregroundStyle(MPColor.secondary).frame(maxWidth: .infinity, alignment: .leading)
            }
            ForEach(store.products, id: \.id) { product in
                Button { Task { await purchase(product) } } label: {
                    HStack { VStack(alignment: .leading, spacing: 4) { Text(product.displayName).font(.system(size: 15, weight: .bold)).foregroundStyle(MPColor.text); Text(product.description).font(.system(size: 11)).foregroundStyle(MPColor.secondary) }; Spacer(); Text(product.displayPrice).font(.system(size: 15, weight: .bold)).foregroundStyle(MPColor.gold) }
                        .padding(12).background(MPColor.gold.opacity(0.08), in: RoundedRectangle(cornerRadius: 11))
                }.buttonStyle(.plain).disabled(store.isWorking)
            }
        }
    }

    private var activation: some View {
        section("测试与内部激活码") {
            TextField("输入激活码", text: $activationCode).textInputAutocapitalization(.characters).autocorrectionDisabled().padding(12).background(MPColor.page, in: RoundedRectangle(cornerRadius: 10))
            Button { Task { await redeem() } } label: { Group { if isRedeeming { ProgressView().tint(.white) } else { Text("兑换权益").fontWeight(.semibold) } }.frame(maxWidth: .infinity).padding(12).foregroundStyle(.white).background(MPColor.gold, in: RoundedRectangle(cornerRadius: 10)) }.disabled(activationCode.count < 8 || isRedeeming)
            if DemoMode.isEnabled { Button("填入测试激活码") { activationCode = "VIPDEMO2026" }.font(.system(size: 12, weight: .semibold)).foregroundStyle(MPColor.blue) }
        }
    }

    private var restore: some View {
        Button { Task { await restorePurchases() } } label: { Label("恢复 App Store 购买", systemImage: "arrow.clockwise").font(.system(size: 14, weight: .semibold)).frame(maxWidth: .infinity).padding(14).background(.white, in: RoundedRectangle(cornerRadius: 14)) }
            .buttonStyle(.plain).padding(.horizontal, 16).disabled(store.isWorking)
    }

    private func section<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View { VStack(spacing: 12) { MPSectionHeader(title: title); MPCard { VStack(spacing: 12) { content() } } }.padding(.horizontal, 16) }
    private func benefit(_ image: String, _ title: String, _ detail: String) -> some View { HStack(spacing: 12) { MPIconTile(image: image, color: MPColor.gold, size: 42); VStack(alignment: .leading, spacing: 3) { Text(title).font(.system(size: 14, weight: .semibold)); Text(detail).font(.system(size: 10)).foregroundStyle(MPColor.secondary) }; Spacer() } }

    @MainActor private func purchase(_ product: Product) async { guard let userId = session.user?.id else { return }; if await store.purchase(product, repository: ClassTraceRepository(client: dependencies.client), userId: userId) { message = "购买成功，权益已更新"; await reload() } else if let error = store.errorMessage { message = "购买失败：\(error)" } }
    @MainActor private func redeem() async { isRedeeming = true; defer { isRedeeming = false }; do { _ = try await ClassTraceRepository(client: dependencies.client).redeemActivationCode(activationCode); activationCode = ""; message = "激活成功，VIP 权益已生效"; await reload() } catch { message = "激活失败：\(error.localizedDescription)" } }
    @MainActor private func restorePurchases() async { if await store.restore(repository: ClassTraceRepository(client: dependencies.client)) { message = "购买记录已恢复"; await reload() } else { message = "恢复失败：\(store.errorMessage ?? "未找到可恢复的购买")" } }
    @MainActor private func reload() async { entitlements = try? await ClassTraceRepository(client: dependencies.client).entitlements() }
}
