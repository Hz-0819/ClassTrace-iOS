import Foundation

actor DemoAPI {
    static let shared = DemoAPI()

    func response(for request: HTTPRequest) async throws -> Data {
        if let local = try await LocalDemoStore.shared.response(for: request) {
            return local
        }
        let payload = try payload(for: request)
        return try JSONSerialization.data(withJSONObject: [
            "data": payload,
            "requestId": "demo-\(UUID().uuidString)"
        ])
    }

    private func payload(for request: HTTPRequest) throws -> Any {
        let path = request.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))

        if request.method == .delete { return NSNull() }

        if request.method == .get {
            switch path {
            case "me": return user
            case "home": return home
            case "students": return students
            case "courses": return [course]
            case "classes": return [classroom]
            case "sessions": return [upcomingSession, completedSession]
            case "hour-ledger": return [hourEntry]
            case "homework": return [homework]
            case "materials": return [material]
            case "plans": return [plan]
            case "mistakes": return [mistake]
            case "points": return points
            case "notifications": return notifications
            case "announcements": return [announcement]
            case "feedback", "admin/feedback": return [feedback]
            case "manual-courses": return [manualCourse]
            case "orders": return [order]
            case "entitlements": return entitlements
            case "business/overview": return business
            case "notification-preferences": return preferences
            case "storage/download-url": return ["url": "https://www.example.com", "expiresIn": 900]
            default:
                if path.hasPrefix("attendance/students/") && path.hasSuffix("/stats") { return attendanceStats }
                if path.hasPrefix("students/") { return student }
                if path.hasPrefix("classes/") { return classroom }
                if path.hasPrefix("sessions/") { return upcomingSession }
                if path.hasPrefix("homework/") { return homework }
            }
        }

        if path == "devices" { return device }
        if path == "storage/upload-intents" { return ["objectKey": "demo/upload", "uploadUrl": "https://www.example.com", "expiresIn": 900] }
        if path == "students" || path == "students/bind" || path.hasSuffix("/guardians") { return student }
        if path.hasSuffix("/guardian-invites") { return ["code": "DEMO2026", "expiresIn": 3600] }
        if path == "courses" || path.hasPrefix("courses/") { return course }
        if path == "classes/join" || path.contains("/members") { return member }
        if path == "classes" || path.hasPrefix("classes/") { return classroom }
        if path == "sessions/generate" { return ["created": 4, "requested": 4] }
        if path.hasSuffix("/feedback") && path.hasPrefix("sessions/") { return sessionFeedback }
        if path == "sessions" || path.hasPrefix("sessions/") { return upcomingSession }
        if path.contains("/hours/recharge") { return hourEntry }
        if path == "homework" || (path.hasPrefix("homework/") && !path.hasSuffix("/submissions")) { return homework }
        if path.hasSuffix("/submissions") || path.hasPrefix("homework-submissions/") { return submission }
        if path == "materials" || path.hasPrefix("materials/") { return material }
        if path == "plans" || (path.hasPrefix("plans/") && !path.hasSuffix("/check-ins")) { return plan }
        if path.hasSuffix("/check-ins") { return checkIn }
        if path == "mistakes" || path.hasPrefix("mistakes/") { return mistake }
        if path.hasPrefix("notifications/") { return ["count": 1] }
        if path == "notification-preferences" { return preference }
        if path == "feedback" || path.hasPrefix("feedback/") { return feedback }
        if path == "manual-courses" || path.hasPrefix("manual-courses/") { return manualCourse }
        if path == "orders" || path.contains("/payments") { return order }
        if path.contains("/refunds") || path.hasPrefix("refunds/") { return refund }
        if path == "storekit/transactions" || path == "activation-codes/redeem" { return subscription }
        if path == "me" || path == "me/roles" || path == "me/phone" { return user }
        if path == "me/export" { return ["mode": "demo", "message": "演示数据不会导出真实账号信息"] }
        if path == "auth/phone/code" { return ["expiresIn": 300, "developmentCode": "123456"] }
        if path == "announcements" { return announcement }
        if path == "activation-codes" { return ["code": "VIPDEMO2026", "days": 30] }

        throw DemoAPIError.unsupported(method: request.method.rawValue, path: path)
    }

    private var now: String { "2026-07-22T09:00:00.000Z" }
    private var tomorrow: String { "2026-07-23T10:00:00.000Z" }
    private var tomorrowEnd: String { "2026-07-23T11:30:00.000Z" }
    private var user: [String: Any] { [
        "id": "00000000-0000-0000-0000-000000000001", "displayName": "演示教师", "status": "ACTIVE",
        "roles": [["role": "TEACHER"], ["role": "GUARDIAN"], ["role": "ADMIN"]], "identities": []
    ] }
    private var student: [String: Any] { ["id": "student-demo-1", "name": "林小满", "gender": "FEMALE", "grade": "五年级", "status": "ACTIVE", "guardians": []] }
    private var secondStudent: [String: Any] { ["id": "student-demo-2", "name": "周一鸣", "gender": "MALE", "grade": "六年级", "status": "ACTIVE", "guardians": []] }
    private var students: [[String: Any]] { [student, secondStudent] }
    private var course: [String: Any] { ["id": "course-demo-1", "name": "小学数学提升", "subject": "数学", "description": "计算、应用题与思维训练", "status": "ACTIVE"] }
    private var classroomSummary: [String: Any] { ["id": "class-demo-1", "name": "周末数学小班", "billingMode": "PREPAID", "status": "ACTIVE"] }
    private var member: [String: Any] { [
        "id": "member-demo-1", "classId": "class-demo-1", "studentId": "student-demo-1", "status": "APPROVED",
        "totalHours": 20, "consumedHours": 6, "remainingHours": 14, "pricePerHour": 180, "student": student, "classroom": classroomSummary
    ] }
    private var classroom: [String: Any] { [
        "id": "class-demo-1", "name": "周末数学小班", "classType": "SMALL_GROUP", "billingMode": "PREPAID",
        "status": "ACTIVE", "inviteCode": "MATH2026", "location": "市南区教室", "course": course, "members": [member], "sessions": [upcomingSession]
    ] }
    private var upcomingSession: [String: Any] { [
        "id": "session-demo-1", "classId": "class-demo-1", "startsAt": tomorrow, "endsAt": tomorrowEnd,
        "plannedHours": 1.5, "status": "SCHEDULED", "source": "RECURRING", "classroom": classroomSummary, "attendances": []
    ] }
    private var completedSession: [String: Any] { [
        "id": "session-demo-2", "classId": "class-demo-1", "startsAt": "2026-07-19T10:00:00.000Z", "endsAt": "2026-07-19T11:30:00.000Z",
        "plannedHours": 1.5, "status": "COMPLETED", "source": "MANUAL", "completedAt": "2026-07-19T11:30:00.000Z", "classroom": classroomSummary
    ] }
    private var hourEntry: [String: Any] { [
        "id": "hour-demo-1", "memberId": "member-demo-1", "studentId": "student-demo-1", "type": "RECHARGE",
        "delta": 10, "balanceAfter": 14, "remark": "演示充值", "createdAt": now, "student": student
    ] }
    private var sessionFeedback: [String: Any] { ["id": "feedback-session-demo-1", "sessionId": "session-demo-1", "summary": "完成本节核心练习", "performance": "课堂参与积极", "homeworkNote": "完成分数专题练习"] }
    private var submission: [String: Any] { [
        "id": "submission-demo-1", "homeworkId": "homework-demo-1", "studentId": "student-demo-1", "content": "已完成练习并上传图片",
        "status": "SUBMITTED", "submittedAt": now, "student": student
    ] }
    private var homework: [String: Any] { [
        "id": "homework-demo-1", "classId": "class-demo-1", "title": "分数应用题练习", "content": "完成练习册第 18～20 页",
        "dueAt": tomorrow, "status": "PUBLISHED", "classroom": classroomSummary, "submissions": [submission]
    ] }
    private var material: [String: Any] { [
        "id": "material-demo-1", "classId": "class-demo-1", "name": "本周知识点.pdf", "objectKey": "demo/material.pdf",
        "mimeType": "application/pdf", "sizeBytes": 245760, "category": "课堂资料", "createdAt": now
    ] }
    private var checkIn: [String: Any] { ["id": "checkin-demo-1", "planId": "plan-demo-1", "note": "今日完成", "checkedAt": now] }
    private var plan: [String: Any] { [
        "id": "plan-demo-1", "studentId": "student-demo-1", "title": "每日口算 15 分钟", "description": "连续坚持四周",
        "status": "ACTIVE", "startsAt": now, "endsAt": "2026-08-22T09:00:00.000Z", "checkIns": [checkIn]
    ] }
    private var mistake: [String: Any] { [
        "id": "mistake-demo-1", "studentId": "student-demo-1", "subject": "数学", "title": "工程问题", "content": "两人合作完成工程需要多久？",
        "answer": "6 天", "analysis": "先求两人的工作效率之和", "tags": ["应用题", "工程问题"], "createdAt": now
    ] }
    private var points: [String: Any] { ["balance": 86, "entries": [["id": "point-demo-1", "delta": 5, "reason": "完成学习计划", "createdAt": now]]] }
    private var announcement: [String: Any] { ["id": "announcement-demo-1", "title": "暑期课程安排", "content": "暑期课程时间已经更新，请在课表中查看。", "publishedAt": now] }
    private var notifications: [[String: Any]] { [["id": "notice-demo-1", "type": "SESSION_REMINDER", "title": "明天有课", "body": "周末数学小班将在明天 10:00 开课", "resourceType": "SESSION", "resourceId": "session-demo-1", "createdAt": now]] }
    private var feedback: [String: Any] { ["id": "feedback-demo-1", "category": "功能建议", "content": "希望课表支持周视图", "status": "PROCESSING", "reply": "已进入产品计划", "createdAt": now] }
    private var manualCourse: [String: Any] { ["id": "manual-demo-1", "name": "备课时间", "startsAt": tomorrow, "endsAt": tomorrowEnd, "location": "书房", "note": "准备分数专题"] }
    private var payment: [String: Any] { ["id": "payment-demo-1", "provider": "WECHAT", "providerTransactionId": "DEMO-TRADE-001", "status": "SUCCEEDED", "amountCents": 360000, "occurredAt": now] }
    private var refund: [String: Any] { ["id": "refund-demo-1", "amountCents": 36000, "hours": 2, "reason": "演示退款", "status": "REQUESTED", "createdAt": now] }
    private var order: [String: Any] { [
        "id": "order-demo-1", "orderNumber": "CT202607220001", "studentId": "student-demo-1", "classId": "class-demo-1", "status": "PAID",
        "settlementPolicy": "DIRECT_FULL", "totalAmountCents": 360000, "purchasedHours": 20, "consumedHours": 6, "paidAt": now, "createdAt": now,
        "student": student, "classroom": classroomSummary, "payments": [payment], "refunds": [refund]
    ] }
    private var entitlements: [String: Any] { ["active": true, "grants": [["id": "grant-demo-1", "startsAt": now, "endsAt": "2027-07-22T09:00:00.000Z"]]] }
    private var business: [String: Any] { ["activeClassCount": 3, "completedSessionCount": 28, "consumedHours": 42.5, "orderCount": 8, "recordedRevenueCents": 1260000] }
    private var attendanceStats: [String: Any] { ["total": 12, "counts": ["PRESENT": 11, "LEAVE": 1], "attendanceRate": 0.9167] }
    private var preference: [String: Any] { ["id": "pref-demo-1", "eventType": "SESSION_REMINDER", "channel": "APNS", "enabled": true] }
    private var preferences: [[String: Any]] { [preference, ["id": "pref-demo-2", "eventType": "HOMEWORK_PUBLISHED", "channel": "IN_APP", "enabled": true]] }
    private var subscription: [String: Any] { ["id": "subscription-demo-1", "productId": "com.classtrace.vip.monthly", "status": "ACTIVE", "expiresAt": "2026-08-22T09:00:00.000Z"] }
    private var device: [String: Any] { ["id": "device-demo-1", "platform": "IOS", "environment": "development", "lastSeenAt": now] }
    private var home: [String: Any] { ["sessions": [upcomingSession], "unreadNotificationCount": 1, "announcements": [announcement], "lowBalances": [member], "homework": [homework]] }
}

enum DemoAPIError: LocalizedError {
    case unsupported(method: String, path: String)

    var errorDescription: String? {
        switch self {
        case let .unsupported(method, path): "演示模式暂不支持 \(method) /\(path)"
        }
    }
}
