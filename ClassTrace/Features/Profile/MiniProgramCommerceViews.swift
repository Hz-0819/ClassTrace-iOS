import SwiftUI

struct CommerceCenterView: View {
    @Environment(AppDependencies.self) private var dependencies
    @Environment(AppSession.self) private var appSession
    @State private var orders: [APIOrder] = []
    @State private var classes: [APIClassroom] = []
    @State private var students: [APIStudent] = []
    @State private var filter = "ALL"
    @State private var showCreate = false
    @State private var errorMessage: String?

    private var isTeacher: Bool { appSession.activeRole == "TEACHER" }
    private var filteredOrders: [APIOrder] { filter == "ALL" ? orders : orders.filter { $0.status == filter } }
    private var totalAmount: Int { orders.reduce(0) { $0 + $1.totalAmountCents } }
    private var paidAmount: Int { orders.filter { ["PAID", "PARTIALLY_REFUNDED", "REFUNDED"].contains($0.status) }.reduce(0) { $0 + $1.totalAmountCents } }
    private var pendingRefunds: Int { orders.flatMap { $0.refunds ?? [] }.filter { $0.status == "REQUESTED" }.count }

    var body: some View {
        ScrollView(showsIndicators: false) {
            LazyVStack(spacing: 16) {
                summaryCard
                filterBar
                if filteredOrders.isEmpty { MPCard { MPEmptyView(image: "wallet-brown", title: "暂无账单", detail: isTeacher ? "家长建立购课记录后可在这里确认外部收款" : "可记录双方已经商定的整期课费与课时") }.padding(.horizontal, 16) }
                ForEach(filteredOrders) { order in
                    NavigationLink { CommerceOrderDetailView(orderId: order.id) { await load() } } label: { orderCard(order) }
                        .buttonStyle(.plain).padding(.horizontal, 16)
                }
                MPCard { Text("课费由教师与家长通过微信、支付宝、现金或银行转账直接结算；课迹只记录双方确认的账单与退款，不代收或保管教学资金。")
                    .font(.system(size: 11)).foregroundStyle(MPColor.secondary).lineSpacing(4) }.padding(.horizontal, 16)
                if let errorMessage { Text(errorMessage).font(.footnote).foregroundStyle(MPColor.red).padding(.horizontal, 16) }
            }.padding(.vertical, 16)
        }
        .background(MPColor.page).navigationTitle("账单与退款")
        .toolbar { if !isTeacher { Button { showCreate = true } label: { Image(systemName: "plus") } } }
        .sheet(isPresented: $showCreate) { CommerceCreateOrderView(classes: classes, students: students) { await load() } }
        .task { await load() }.refreshable { await load() }
    }

    private var summaryCard: some View {
        MPCard {
            VStack(spacing: 14) {
                HStack { Text(isTeacher ? "教学课费记录" : "购课与开销记录").font(.system(size: 17, weight: .bold)); Spacer(); Text("外部直接结算").font(.system(size: 10, weight: .semibold)).foregroundStyle(MPColor.blue).padding(.horizontal, 8).padding(.vertical, 4).background(MPColor.blue.opacity(0.1), in: Capsule()) }
                HStack { commerceMetric("账单总额", totalAmount.currency); commerceMetric("已确认", paidAmount.currency); commerceMetric("待处理退款", "\(pendingRefunds)", warning: pendingRefunds > 0) }
            }
        }.padding(.horizontal, 16)
    }

    private func commerceMetric(_ title: String, _ value: String, warning: Bool = false) -> some View {
        VStack(alignment: .leading, spacing: 5) { Text(value).font(.system(size: 17, weight: .bold)).foregroundStyle(warning ? MPColor.red : MPColor.text); Text(title).font(.system(size: 10)).foregroundStyle(MPColor.secondary) }.frame(maxWidth: .infinity, alignment: .leading)
    }

    private var filterBar: some View {
        HStack(spacing: 8) {
            ForEach(["ALL", "PENDING", "PAID"], id: \.self) { value in
                Button(filterTitle(value)) { filter = value }.font(.system(size: 12, weight: .semibold)).foregroundStyle(filter == value ? .white : MPColor.text)
                    .frame(maxWidth: .infinity).padding(.vertical, 9).background(filter == value ? MPColor.blue : .white, in: Capsule())
            }
        }.padding(.horizontal, 16)
    }

    private func orderCard(_ order: APIOrder) -> some View {
        MPCard {
            VStack(spacing: 11) {
                HStack { Text(order.student?.name ?? "学生").font(.system(size: 16, weight: .bold)).foregroundStyle(MPColor.text); Spacer(); Text(order.status.localizedStatus).font(.system(size: 10, weight: .semibold)).foregroundStyle(statusColor(order.status)).padding(.horizontal, 8).padding(.vertical, 4).background(statusColor(order.status).opacity(0.1), in: Capsule()) }
                HStack { Text(order.classroom?.name ?? "课程").font(.system(size: 12)).foregroundStyle(MPColor.secondary); Spacer(); Text(order.totalAmountCents.currency).font(.system(size: 19, weight: .bold)).foregroundStyle(MPColor.text) }
                HStack { Text("\(order.purchasedHours.doubleValue.compactNumber) 课时 · \(order.settlementPolicy.localizedStatus)"); Spacer(); Text(order.createdAt.formatted(date: .abbreviated, time: .omitted)) }.font(.system(size: 10)).foregroundStyle(MPColor.secondary)
                if let refunds = order.refunds, !refunds.isEmpty { HStack { Image(systemName: "arrow.uturn.backward.circle.fill"); Text("退款记录 \(refunds.count) 条"); Spacer(); if refunds.contains(where: { $0.status == "REQUESTED" }) { Text("待处理") } }.font(.system(size: 11, weight: .semibold)).foregroundStyle(MPColor.gold) }
            }
        }
    }

    private func statusColor(_ status: String) -> Color { status == "PAID" ? MPColor.green : status == "PENDING" ? MPColor.gold : status.contains("REFUND") ? MPColor.coral : MPColor.blue }
    private func filterTitle(_ value: String) -> String { value == "PENDING" ? "待确认" : value == "PAID" ? "已收款" : "全部" }

    @MainActor private func load() async {
        do {
            let repository = ClassTraceRepository(client: dependencies.client)
            async let orderRequest = repository.orders(); async let classRequest = repository.classes(); async let studentRequest = repository.students()
            (orders, classes, students) = try await (orderRequest, classRequest, studentRequest); errorMessage = nil
        } catch { errorMessage = error.localizedDescription }
    }
}

private struct CommerceCreateOrderView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AppDependencies.self) private var dependencies
    let classes: [APIClassroom]
    let students: [APIStudent]
    let onSaved: () async -> Void
    @State private var classId = ""
    @State private var studentId = ""
    @State private var amount = 0.0
    @State private var hours = 0.0
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            Form {
                Section("购课对象") { Picker("班级/课程", selection: $classId) { Text("请选择").tag(""); ForEach(classes) { Text($0.name).tag($0.id) } }; Picker("孩子", selection: $studentId) { Text("请选择").tag(""); ForEach(students) { Text($0.name).tag($0.id) } } }
                Section("双方约定") { TextField("整期课费（元）", value: $amount, format: .number).keyboardType(.decimalPad); TextField("购买课时", value: $hours, format: .number).keyboardType(.decimalPad); Text("本记录不会发起应用内扣款。提交后由教师核对外部收款信息。") .font(.footnote).foregroundStyle(MPColor.secondary) }
                if let errorMessage { Text(errorMessage).foregroundStyle(MPColor.red) }
            }.mpFormChrome().navigationTitle("建立购课记录")
                .toolbar { ToolbarItem(placement: .cancellationAction) { Button("取消") { dismiss() } }; ToolbarItem(placement: .confirmationAction) { Button("提交") { Task { await save() } }.disabled(classId.isEmpty || studentId.isEmpty || amount <= 0 || hours <= 0) } }
        }
    }

    @MainActor private func save() async {
        do { _ = try await ClassTraceRepository(client: dependencies.client).createOrder(studentId: studentId, classId: classId, amountCents: Int((amount * 100).rounded()), hours: hours); await onSaved(); dismiss() }
        catch { errorMessage = error.localizedDescription }
    }
}

private struct CommerceOrderDetailView: View {
    @Environment(AppDependencies.self) private var dependencies
    @Environment(AppSession.self) private var appSession
    let orderId: String
    let onSaved: () async -> Void
    @State private var order: APIOrder?
    @State private var provider = "WECHAT"
    @State private var transactionId = ""
    @State private var refundAmount = 0.0
    @State private var refundHours = 0.0
    @State private var reason = ""
    @State private var errorMessage: String?
    @State private var isWorking = false

    private var isTeacher: Bool { appSession.activeRole == "TEACHER" }

    var body: some View {
        Form {
            if let order {
                Section("账单信息") { LabeledContent("订单号", value: order.orderNumber); LabeledContent("学生", value: order.student?.name ?? "学生"); LabeledContent("班级", value: order.classroom?.name ?? "课程"); LabeledContent("总课费", value: order.totalAmountCents.currency); LabeledContent("购买课时", value: order.purchasedHours.doubleValue.compactNumber); LabeledContent("状态", value: order.status.localizedStatus) }
                if let payments = order.payments, !payments.isEmpty { Section("收款记录") { ForEach(payments) { payment in VStack(alignment: .leading, spacing: 4) { HStack { Text(payment.provider.localizedStatus).font(.headline); Spacer(); Text(payment.amountCents.currency) }; Text("流水号：\(payment.providerTransactionId)").font(.caption).foregroundStyle(MPColor.secondary); Text(payment.occurredAt.formatted(date: .abbreviated, time: .shortened)).font(.caption2).foregroundStyle(MPColor.secondary) } } } }
                if isTeacher && order.status == "PENDING" { teacherPaymentSection(order) }
                if !isTeacher && order.status == "PAID" { guardianRefundSection(order) }
                if let refunds = order.refunds, !refunds.isEmpty { refundRecords(refunds) }
                Section { Text("教师与家长在线下完成真实资金结算；这里的确认只用于形成双方可核对的教学账单。") .font(.footnote).foregroundStyle(MPColor.secondary) }
            } else { ProgressView() }
            if let errorMessage { Text(errorMessage).foregroundStyle(MPColor.red) }
        }.mpFormChrome().navigationTitle("账单详情").task { await load() }.refreshable { await load() }
    }

    private func teacherPaymentSection(_ order: APIOrder) -> some View {
        Section("教师确认外部收款") {
            Picker("收款渠道", selection: $provider) { Text("微信").tag("WECHAT"); Text("支付宝").tag("ALIPAY"); Text("现金").tag("CASH"); Text("银行转账").tag("BANK") }
            TextField(provider == "CASH" ? "收款备注（选填）" : "外部流水号", text: $transactionId)
            Button("确认已全额收款") { Task { await payment(order) } }.disabled(isWorking || (provider != "CASH" && transactionId.trimmingCharacters(in: .whitespaces).isEmpty))
        }
    }

    private func guardianRefundSection(_ order: APIOrder) -> some View {
        Section("申请退款") {
            TextField("退款金额（元）", value: $refundAmount, format: .number).keyboardType(.decimalPad)
            TextField("退回课时", value: $refundHours, format: .number).keyboardType(.decimalPad)
            TextField("退款原因", text: $reason, axis: .vertical)
            Button("提交退款申请") { Task { await refund(order) } }.disabled(isWorking || refundAmount <= 0 || refundAmount * 100 > Double(order.totalAmountCents) || refundHours < 0 || refundHours > order.purchasedHours.doubleValue || reason.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
    }

    private func refundRecords(_ refunds: [APIRefund]) -> some View {
        Section("退款记录") {
            ForEach(refunds) { item in
                VStack(alignment: .leading, spacing: 7) {
                    HStack { Text(item.amountCents.currency).font(.headline); Spacer(); Text(item.status.localizedStatus).foregroundStyle(item.status == "REQUESTED" ? MPColor.gold : MPColor.green) }
                    Text("退回 \(item.hours.doubleValue.compactNumber) 课时 · \(item.reason ?? "无原因")").font(.caption).foregroundStyle(MPColor.secondary)
                    if isTeacher && item.status == "REQUESTED" { HStack { Button("确认已退款") { Task { await resolve(item.id, "REFUNDED") } }; Button("拒绝", role: .destructive) { Task { await resolve(item.id, "REJECTED") } } }.buttonStyle(.bordered) }
                }.padding(.vertical, 4)
            }
        }
    }

    @MainActor private func load() async { do { order = try await ClassTraceRepository(client: dependencies.client).orderDetail(orderId); errorMessage = nil } catch { errorMessage = error.localizedDescription } }
    @MainActor private func payment(_ order: APIOrder) async { isWorking = true; defer { isWorking = false }; do { let reference = transactionId.nilIfEmpty ?? "CASH-\(Int(Date().timeIntervalSince1970))"; _ = try await ClassTraceRepository(client: dependencies.client).recordPayment(orderId: order.id, amountCents: order.totalAmountCents, provider: provider, transactionId: reference); await load(); await onSaved() } catch { errorMessage = error.localizedDescription } }
    @MainActor private func refund(_ order: APIOrder) async { isWorking = true; defer { isWorking = false }; do { _ = try await ClassTraceRepository(client: dependencies.client).requestRefund(orderId: order.id, amountCents: Int((refundAmount * 100).rounded()), hours: refundHours, reason: reason); refundAmount = 0; refundHours = 0; reason = ""; await load(); await onSaved() } catch { errorMessage = error.localizedDescription } }
    @MainActor private func resolve(_ id: String, _ status: String) async { isWorking = true; defer { isWorking = false }; do { _ = try await ClassTraceRepository(client: dependencies.client).resolveRefund(id, status: status, providerRefundId: status == "REFUNDED" ? UUID().uuidString : nil); await load(); await onSaved() } catch { errorMessage = error.localizedDescription } }
}

private extension Int {
    var currency: String { (Double(self) / 100).formatted(.currency(code: "CNY").precision(.fractionLength(0...2))) }
}
