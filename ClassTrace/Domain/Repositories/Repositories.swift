import Foundation

struct AuthRepository: Sendable {
    let client: HTTPClient
    let vault: SessionVault

    func requestCode(phone: String) async throws -> PhoneCodePayload {
        try await client.send(.json(method: .post, path: "auth/phone/code", body: PhoneCodeRequest(phone: phone, purpose: "login")))
    }
    func verify(phone: String, code: String, displayName: String?, role: String) async throws -> AuthSessionPayload {
        let payload: AuthSessionPayload = try await client.send(.json(method: .post, path: "auth/phone/verify", body: PhoneVerifyRequest(phone: phone, code: code, purpose: "login", displayName: displayName, role: role)))
        await vault.save(accessToken: payload.accessToken, refreshToken: payload.refreshToken)
        await PushNotificationManager.shared.retryPendingRegistration()
        return payload
    }
    func signInWithApple(identityToken: String, authorizationCode: String?, nonce: String, fullName: String?, role: String) async throws -> AuthSessionPayload {
        let payload: AuthSessionPayload = try await client.send(.json(method: .post, path: "auth/apple", body: AppleAuthRequest(identityToken: identityToken, nonce: nonce, authorizationCode: authorizationCode, fullName: fullName, role: role)))
        await vault.save(accessToken: payload.accessToken, refreshToken: payload.refreshToken)
        await PushNotificationManager.shared.retryPendingRegistration()
        return payload
    }
    func me() async throws -> APIUser { try await client.send(HTTPRequest(method: .get, path: "me")) }
    func logout() async {
        await PushNotificationManager.shared.unregister()
        guard let refreshToken = await vault.refreshToken() else { await vault.clear(); return }
        try? await client.sendWithoutResponse(.json(method: .post, path: "auth/logout", body: RefreshTokenRequest(refreshToken: refreshToken)))
        await vault.clear()
    }
}

struct ClassTraceRepository: Sendable {
    let client: HTTPClient
    func students() async throws -> [APIStudent] { try await get("students") }
    func studentDetail(_ id: String) async throws -> APIStudent { try await get("students/\(id)") }
    func attendanceStats(studentId: String) async throws -> APIAttendanceStats { try await get("attendance/students/\(studentId)/stats") }
    func classes() async throws -> [APIClassroom] { try await get("classes") }
    func courses() async throws -> [APICourse] { try await get("courses") }
    func sessions(from: Date? = nil, to: Date? = nil, classId: String? = nil) async throws -> [APISession] {
        let formatter = ISO8601DateFormatter()
        var query: [URLQueryItem] = []
        if let from { query.append(.init(name: "from", value: formatter.string(from: from))) }
        if let to { query.append(.init(name: "to", value: formatter.string(from: to))) }
        if let classId { query.append(.init(name: "classId", value: classId)) }
        return try await client.send(HTTPRequest(method: .get, path: "sessions", query: query))
    }
    func hourLedger(classId: String? = nil, studentId: String? = nil) async throws -> [APIHourEntry] {
        var query: [URLQueryItem] = []
        if let classId { query.append(.init(name: "classId", value: classId)) }
        if let studentId { query.append(.init(name: "studentId", value: studentId)) }
        return try await client.send(HTTPRequest(method: .get, path: "hour-ledger", query: query))
    }
    func homework(classId: String? = nil) async throws -> [APIHomework] { try await get("homework", query: classId.map { [.init(name: "classId", value: $0)] } ?? []) }
    func homeworkDetail(_ id: String) async throws -> APIHomework { try await get("homework/\(id)") }
    func materials(classId: String? = nil) async throws -> [APIMaterial] { try await get("materials", query: classId.map { [.init(name: "classId", value: $0)] } ?? []) }
    func plans(studentId: String? = nil) async throws -> [APIStudyPlan] { try await get("plans", query: studentId.map { [.init(name: "studentId", value: $0)] } ?? []) }
    func mistakes(studentId: String? = nil) async throws -> [APIMistake] { try await get("mistakes", query: studentId.map { [.init(name: "studentId", value: $0)] } ?? []) }
    func points() async throws -> APIPoints { try await get("points") }
    func notifications() async throws -> [APINotification] { try await get("notifications") }
    func announcements() async throws -> [APIAnnouncement] { try await get("announcements") }
    func feedback() async throws -> [APIFeedback] { try await get("feedback") }
    func manualCourses() async throws -> [APIManualCourse] { try await get("manual-courses") }
    func orders() async throws -> [APIOrder] { try await get("orders") }
    func entitlements() async throws -> APIEntitlements { try await get("entitlements") }
    func home() async throws -> APIHome { try await get("home") }
    func businessOverview(from: Date? = nil, to: Date? = nil) async throws -> APIBusinessOverview { let f = ISO8601DateFormatter(); var query: [URLQueryItem] = []; if let from { query.append(.init(name: "from", value: f.string(from: from))) }; if let to { query.append(.init(name: "to", value: f.string(from: to))) }; return try await get("business/overview", query: query) }
    func classDetail(_ id: String) async throws -> APIClassroom { try await get("classes/\(id)") }
    func sessionDetail(_ id: String) async throws -> APISession { try await get("sessions/\(id)") }

    func createStudent(name: String, grade: String?, linkAsGuardian: Bool) async throws -> APIStudent {
        try await post("students", CreateStudentRequest(name: name, grade: grade, linkAsGuardian: linkAsGuardian))
    }
    func createClass(name: String, type: String, billingMode: String, location: String?, courseId: String? = nil, schedule: APIClassSchedule? = nil, price: Double? = nil, totalHours: Double? = nil, lessonDurationMinutes: Int? = nil, startDate: Date? = nil, color: String? = nil) async throws -> APIClassroom {
        let formatter = ISO8601DateFormatter()
        return try await post("classes", CreateClassRequest(name: name, classType: type, billingMode: billingMode, location: location, courseId: courseId, schedule: schedule, priceSettings: price.map { APIPriceSettings(type: "session", price: FlexibleDecimal(Decimal($0))) }, hourSettings: totalHours.map { APIHourSettings(totalHours: FlexibleDecimal(Decimal($0)), warningThreshold: FlexibleDecimal(3)) }, lessonDurationMinutes: lessonDurationMinutes, startDate: startDate.map { formatter.string(from: $0) }, color: color, maxStudents: type == "ONE_ON_ONE" ? 1 : 20))
    }
    func joinClass(inviteCode: String, studentId: String) async throws -> APIClassMember {
        try await post("classes/join", JoinClassRequest(inviteCode: inviteCode, studentId: studentId))
    }
    func createSession(classId: String, startsAt: Date, endsAt: Date) async throws -> APISession {
        let formatter = ISO8601DateFormatter()
        return try await post("sessions", CreateSessionRequest(classId: classId, startsAt: formatter.string(from: startsAt), endsAt: formatter.string(from: endsAt)))
    }
    func generateSessions(classId: String, from: Date, to: Date, weekdays: [Int], startTime: String, durationMinutes: Int) async throws -> CreatedCountPayload {
        let f = DateFormatter(); f.calendar = Calendar(identifier: .gregorian); f.locale = Locale(identifier: "en_US_POSIX"); f.timeZone = .current; f.dateFormat = "yyyy-MM-dd"
        return try await post("sessions/generate", GenerateSessionsRequest(classId: classId, from: f.string(from: from), to: f.string(from: to), weekdays: weekdays, startTime: startTime, durationMinutes: durationMinutes, timezoneOffsetMinutes: TimeZone.current.secondsFromGMT() / 60))
    }
    func confirmSession(id: String, attendances: [ConfirmAttendanceRequest]) async throws -> APISession {
        let request = try HTTPRequest.json(method: .post, path: "sessions/\(id)/confirm", body: ConfirmSessionRequest(attendances: attendances), idempotencyKey: UUID().uuidString)
        return try await client.send(request)
    }
    func undoSession(id: String) async throws -> APISession {
        let request = try HTTPRequest.json(method: .post, path: "sessions/\(id)/undo", body: EmptyRequest(), idempotencyKey: UUID().uuidString)
        return try await client.send(request)
    }
    func recharge(memberId: String, hours: Double, remark: String?) async throws -> APIHourEntry {
        let request = try HTTPRequest.json(method: .post, path: "class-members/\(memberId)/hours/recharge", body: RechargeRequest(hours: hours, remark: remark), idempotencyKey: UUID().uuidString)
        return try await client.send(request)
    }
    func checkIn(planId: String, note: String?) async throws -> APIPlanCheckIn { try await post("plans/\(planId)/check-ins", CheckInRequest(note: note)) }
    func markNotificationRead(_ id: String) async throws -> CountPayload { try await post("notifications/\(id)/read", EmptyRequest()) }
    func submitFeedback(category: String, content: String, contact: String?) async throws -> APIFeedback { try await post("feedback", SubmitFeedbackRequest(category: category, content: content, contact: contact)) }
    func createManualCourse(name: String, startsAt: Date, endsAt: Date, location: String?, note: String?) async throws -> APIManualCourse { let f = ISO8601DateFormatter(); return try await post("manual-courses", ManualCourseMutation(name: name, startsAt: f.string(from: startsAt), endsAt: f.string(from: endsAt), location: location, note: note)) }
    func updateManualCourse(_ id: String, name: String, startsAt: Date, endsAt: Date, location: String?, note: String?) async throws -> APIManualCourse { let f = ISO8601DateFormatter(); return try await patch("manual-courses/\(id)", ManualCourseMutation(name: name, startsAt: f.string(from: startsAt), endsAt: f.string(from: endsAt), location: location, note: note)) }
    func deleteManualCourse(_ id: String) async throws { try await delete("manual-courses/\(id)") }
    func verifyStoreKit(signedTransaction: String) async throws -> APISubscription { try await post("storekit/transactions", StoreKitRequest(signedTransaction: signedTransaction)) }
    func redeemActivationCode(_ code: String) async throws -> APISubscription { try await post("activation-codes/redeem", ActivationCodeRequest(code: code)) }

    func createCourse(name: String, subject: String?, description: String?) async throws -> APICourse { try await post("courses", CourseMutation(name: name, subject: subject, description: description)) }
    func updateCourse(_ id: String, name: String, subject: String?, description: String?) async throws -> APICourse { try await patch("courses/\(id)", CourseMutation(name: name, subject: subject, description: description)) }
    func deleteCourse(_ id: String) async throws { try await delete("courses/\(id)") }
    func updateClass(_ id: String, name: String?, status: String?, location: String?) async throws -> APIClassroom { try await patch("classes/\(id)", ClassMutation(name: name, status: status, location: location)) }
    func deleteClass(_ id: String) async throws { try await delete("classes/\(id)") }
    func addMember(classId: String, studentId: String, initialHours: Double, pricePerHour: Double) async throws -> APIClassMember { try await post("classes/\(classId)/members", MemberCreate(studentId: studentId, initialHours: initialHours, pricePerHour: pricePerHour)) }
    func updateMember(classId: String, memberId: String, status: String?, pricePerHour: Double?) async throws -> APIClassMember { try await patch("classes/\(classId)/members/\(memberId)", MemberMutation(status: status, pricePerHour: pricePerHour)) }
    func removeMember(classId: String, memberId: String) async throws { try await delete("classes/\(classId)/members/\(memberId)") }
    func updateStudent(_ id: String, name: String, grade: String?, gender: String?) async throws -> APIStudent { try await patch("students/\(id)", StudentMutation(name: name, grade: grade, gender: gender)) }
    func deleteStudent(_ id: String) async throws { try await delete("students/\(id)") }
    func createGuardianInvite(studentId: String) async throws -> GuardianInvitePayload { try await post("students/\(studentId)/guardian-invites", EmptyRequest()) }
    func bindStudent(code: String, relationship: String?) async throws -> APIStudent { try await post("students/bind", GuardianBind(code: code, relationship: relationship)) }
    func removeGuardian(studentId: String, guardianId: String) async throws { try await delete("students/\(studentId)/guardians/\(guardianId)") }
    func rescheduleSession(_ id: String, startsAt: Date, endsAt: Date) async throws -> APISession { let f = ISO8601DateFormatter(); return try await patch("sessions/\(id)/reschedule", TimeMutation(startsAt: f.string(from: startsAt), endsAt: f.string(from: endsAt))) }
    func cancelSession(_ id: String, reason: String?) async throws -> APISession { try await post("sessions/\(id)/cancel", ReasonMutation(reason: reason)) }
    func saveSessionFeedback(_ id: String, summary: String?, performance: String?, homeworkNote: String?) async throws -> APISessionFeedback { try await patch("sessions/\(id)/feedback", SessionFeedbackMutation(summary: summary, performance: performance, homeworkNote: homeworkNote)) }
    func createHomework(classId: String, title: String, content: String, dueAt: Date?, publish: Bool) async throws -> APIHomework { let f = ISO8601DateFormatter(); return try await post("homework", HomeworkMutation(classId: classId, title: title, content: content, dueAt: dueAt.map { f.string(from: $0) }, status: publish ? "PUBLISHED" : "DRAFT")) }
    func updateHomework(_ id: String, title: String?, content: String?, status: String?) async throws -> APIHomework { try await patch("homework/\(id)", HomeworkUpdate(title: title, content: content, status: status)) }
    func deleteHomework(_ id: String) async throws { try await delete("homework/\(id)") }
    func submitHomework(_ id: String, studentId: String, content: String?) async throws -> APIHomeworkSubmission { try await post("homework/\(id)/submissions", HomeworkSubmit(studentId: studentId, content: content)) }
    func reviewSubmission(_ id: String, status: String, score: Double?, comment: String?) async throws -> APIHomeworkSubmission { try await patch("homework-submissions/\(id)/review", HomeworkReview(status: status, score: score, comment: comment)) }
    func createMaterial(classId: String?, name: String, objectKey: String, mimeType: String, sizeBytes: Int, category: String?) async throws -> APIMaterial { try await post("materials", MaterialCreate(classId: classId, name: name, objectKey: objectKey, mimeType: mimeType, sizeBytes: sizeBytes, category: category)) }
    func deleteMaterial(_ id: String) async throws { try await delete("materials/\(id)") }
    func createPlan(studentId: String?, title: String, description: String?) async throws -> APIStudyPlan { try await post("plans", PlanMutation(studentId: studentId, title: title, description: description, status: nil)) }
    func updatePlan(_ id: String, title: String?, description: String?, status: String?) async throws -> APIStudyPlan { try await patch("plans/\(id)", PlanMutation(studentId: nil, title: title, description: description, status: status)) }
    func deletePlan(_ id: String) async throws { try await delete("plans/\(id)") }
    func createMistake(studentId: String?, subject: String?, title: String, content: String?, answer: String?, analysis: String?) async throws -> APIMistake { try await post("mistakes", MistakeMutation(studentId: studentId, subject: subject, title: title, content: content, answer: answer, analysis: analysis)) }
    func updateMistake(_ id: String, subject: String?, title: String, content: String?, answer: String?, analysis: String?) async throws -> APIMistake { try await patch("mistakes/\(id)", MistakeMutation(studentId: nil, subject: subject, title: title, content: content, answer: answer, analysis: analysis)) }
    func markMistakeMastered(_ id: String) async throws -> APIMistake { try await post("mistakes/\(id)/mastered", EmptyRequest()) }
    func deleteMistake(_ id: String) async throws { try await delete("mistakes/\(id)") }
    func markAllNotificationsRead() async throws -> CountPayload { try await post("notifications/read-all", EmptyRequest()) }
    func notificationPreferences() async throws -> [APINotificationPreference] { try await get("notification-preferences") }
    func setNotificationPreference(eventType: String, channel: String, enabled: Bool) async throws -> APINotificationPreference { try await post("notification-preferences", PreferenceMutation(eventType: eventType, channel: channel, enabled: enabled)) }
    func createOrder(studentId: String, classId: String, amountCents: Int, hours: Double) async throws -> APIOrder { try await post("orders", OrderCreate(studentId: studentId, classId: classId, totalAmountCents: amountCents, purchasedHours: hours, settlementPolicy: "DIRECT_FULL")) }
    func recordPayment(orderId: String, amountCents: Int, provider: String, transactionId: String) async throws -> APIOrder { try await post("orders/\(orderId)/payments", PaymentCreate(provider: provider, providerTransactionId: transactionId, amountCents: amountCents)) }
    func requestRefund(orderId: String, amountCents: Int, hours: Double, reason: String?) async throws -> APIRefund { try await post("orders/\(orderId)/refunds", RefundCreate(amountCents: amountCents, hours: hours, reason: reason)) }
    func resolveRefund(_ id: String, status: String, providerRefundId: String?) async throws -> APIRefund { try await post("refunds/\(id)/resolve", RefundResolve(status: status, providerRefundId: providerRefundId)) }
    func updateProfile(displayName: String, avatarURL: String?) async throws -> APIUser { try await patch("me", ProfileMutation(displayName: displayName, avatarUrl: avatarURL)) }
    func ensureRole(_ role: String) async throws -> APIUser { try await post("me/roles", RoleMutation(role: role)) }
    func deleteAccount() async throws { try await delete("me") }
    func exportAccount() async throws -> JSONValue { try await get("me/export") }
    func requestBindPhoneCode(_ phone: String) async throws -> PhoneCodePayload { try await post("auth/phone/code", BindCodeRequest(phone: phone, purpose: "bind")) }
    func linkPhone(_ phone: String, code: String) async throws -> APIUser { try await post("me/phone", LinkPhoneRequest(phone: phone, code: code)) }
    func createAnnouncement(title: String, content: String, audience: [String]) async throws -> APIAnnouncement { try await post("announcements", AnnouncementCreate(title: title, content: content, audience: audience)) }
    func createActivationCode(days: Int) async throws -> ActivationCodePayload { try await post("activation-codes", ActivationCreate(days: days)) }
    func replyFeedback(_ id: String, reply: String, status: String) async throws -> APIFeedback { try await patch("feedback/\(id)/reply", FeedbackReply(reply: reply, status: status)) }
    func adminFeedback() async throws -> [APIFeedback] { try await get("admin/feedback") }

    private func get<Value: Decodable & Sendable>(_ path: String, query: [URLQueryItem] = []) async throws -> Value { try await client.send(HTTPRequest(method: .get, path: path, query: query)) }
    private func post<Body: Encodable, Value: Decodable & Sendable>(_ path: String, _ body: Body) async throws -> Value { try await client.send(.json(method: .post, path: path, body: body)) }
    private func patch<Body: Encodable, Value: Decodable & Sendable>(_ path: String, _ body: Body) async throws -> Value { try await client.send(.json(method: .patch, path: path, body: body)) }
    private func delete(_ path: String) async throws { try await client.sendWithoutResponse(HTTPRequest(method: .delete, path: path)) }
}

private struct PhoneCodeRequest: Encodable { let phone: String; let purpose: String }
private struct PhoneVerifyRequest: Encodable { let phone: String; let code: String; let purpose: String; let displayName: String?; let role: String }
private struct RefreshTokenRequest: Encodable { let refreshToken: String }
private struct AppleAuthRequest: Encodable { let identityToken: String; let nonce: String; let authorizationCode: String?; let fullName: String?; let role: String }
private struct CreateStudentRequest: Encodable { let name: String; let grade: String?; let linkAsGuardian: Bool }
private struct CreateClassRequest: Encodable { let name: String; let classType: String; let billingMode: String; let location: String?; let courseId: String?; let schedule: APIClassSchedule?; let priceSettings: APIPriceSettings?; let hourSettings: APIHourSettings?; let lessonDurationMinutes: Int?; let startDate: String?; let color: String?; let maxStudents: Int? }
private struct JoinClassRequest: Encodable { let inviteCode: String; let studentId: String }
private struct CreateSessionRequest: Encodable { let classId: String; let startsAt: String; let endsAt: String }
private struct GenerateSessionsRequest: Encodable { let classId: String; let from: String; let to: String; let weekdays: [Int]; let startTime: String; let durationMinutes: Int; let timezoneOffsetMinutes: Int }
struct ConfirmAttendanceRequest: Encodable, Sendable { let studentId: String; let status: String; let deductHours: Double?; let remark: String? }
private struct ConfirmSessionRequest: Encodable { let attendances: [ConfirmAttendanceRequest] }
private struct RechargeRequest: Encodable { let hours: Double; let remark: String? }
private struct CheckInRequest: Encodable { let note: String? }
private struct SubmitFeedbackRequest: Encodable { let category: String; let content: String; let contact: String? }
private struct ManualCourseMutation: Encodable { let name: String; let startsAt: String; let endsAt: String; let location: String?; let note: String? }
private struct StoreKitRequest: Encodable { let signedTransaction: String }
private struct ActivationCodeRequest: Encodable { let code: String }
private struct EmptyRequest: Encodable {}
private struct CourseMutation: Encodable { let name: String; let subject: String?; let description: String? }
private struct ClassMutation: Encodable { let name: String?; let status: String?; let location: String? }
private struct MemberCreate: Encodable { let studentId: String; let initialHours: Double; let pricePerHour: Double }
private struct MemberMutation: Encodable { let status: String?; let pricePerHour: Double? }
private struct StudentMutation: Encodable { let name: String; let grade: String?; let gender: String? }
private struct GuardianBind: Encodable { let code: String; let relationship: String? }
private struct TimeMutation: Encodable { let startsAt: String; let endsAt: String }
private struct ReasonMutation: Encodable { let reason: String? }
private struct SessionFeedbackMutation: Encodable { let summary: String?; let performance: String?; let homeworkNote: String? }
private struct HomeworkMutation: Encodable { let classId: String; let title: String; let content: String; let dueAt: String?; let status: String }
private struct HomeworkUpdate: Encodable { let title: String?; let content: String?; let status: String? }
private struct HomeworkSubmit: Encodable { let studentId: String; let content: String? }
private struct HomeworkReview: Encodable { let status: String; let score: Double?; let comment: String? }
private struct MaterialCreate: Encodable { let classId: String?; let name: String; let objectKey: String; let mimeType: String; let sizeBytes: Int; let category: String? }
private struct PlanMutation: Encodable { let studentId: String?; let title: String?; let description: String?; let status: String? }
private struct MistakeMutation: Encodable { let studentId: String?; let subject: String?; let title: String; let content: String?; let answer: String?; let analysis: String? }
private struct PreferenceMutation: Encodable { let eventType: String; let channel: String; let enabled: Bool }
private struct OrderCreate: Encodable { let studentId: String; let classId: String; let totalAmountCents: Int; let purchasedHours: Double; let settlementPolicy: String }
private struct PaymentCreate: Encodable { let provider: String; let providerTransactionId: String; let amountCents: Int }
private struct RefundCreate: Encodable { let amountCents: Int; let hours: Double; let reason: String? }
private struct RefundResolve: Encodable { let status: String; let providerRefundId: String? }
private struct ProfileMutation: Encodable { let displayName: String; let avatarUrl: String? }
private struct RoleMutation: Encodable { let role: String }
private struct BindCodeRequest: Encodable { let phone: String; let purpose: String }
private struct LinkPhoneRequest: Encodable { let phone: String; let code: String }
private struct AnnouncementCreate: Encodable { let title: String; let content: String; let audience: [String] }
private struct ActivationCreate: Encodable { let days: Int }
private struct FeedbackReply: Encodable { let reply: String; let status: String }
