import Foundation

/// On-device JSON database used by test builds. The repository/API boundary stays
/// identical to the future server implementation, so switching backends does not
/// require rebuilding screens.
actor LocalDemoStore {
    static let shared = LocalDemoStore()

    private var state: [String: Any] = [:]
    private var isLoaded = false
    private var loadedAccount = ""

    func response(for request: HTTPRequest) throws -> Data? {
        try loadIfNeeded()
        let path = request.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))

        if request.method == .get {
            if path == "home" { return try envelope(homePayload()) }
            if path == "business/overview" { return try envelope(businessPayload()) }
            if let key = collectionKey(for: path), path == key { return try envelope(items(key)) }
            if let (key, id) = detailPath(path), let item = items(key).first(where: { $0["id"] as? String == id }) { return try envelope(item) }
        }

        if request.method == .post, let key = collectionKey(for: path), path == key {
            let item = makeItem(key: key, input: try body(request))
            var values = items(key); values.insert(item, at: 0); state[key] = values
            try save(); return try envelope(item)
        }

        if request.method == .patch, let (key, id) = detailPath(path) {
            var values = items(key)
            guard let index = values.firstIndex(where: { $0["id"] as? String == id }) else { return nil }
            let changes = try body(request)
            for (name, value) in changes where !(value is NSNull) { values[index][name] = value }
            state[key] = values; try save(); return try envelope(values[index])
        }

        if request.method == .delete, let (key, id) = detailPath(path) {
            state[key] = items(key).filter { $0["id"] as? String != id }
            try save(); return try envelope(NSNull())
        }

        let parts = path.split(separator: "/").map(String.init)
        if request.method == .post, parts.count == 3, parts[0] == "plans", parts[2] == "check-ins" {
            let input = try body(request)
            let checkIn: [String: Any] = ["id": UUID().uuidString, "planId": parts[1], "note": input["note"] ?? NSNull(), "checkedAt": Self.date(Date())]
            try updateItem("plans", id: parts[1]) { item in var copy = item; var values = copy["checkIns"] as? [[String: Any]] ?? []; values.insert(checkIn, at: 0); copy["checkIns"] = values; return copy }
            return try envelope(checkIn)
        }
        if request.method == .post, parts.count == 3, parts[0] == "mistakes", parts[2] == "mastered" {
            let item = try updateItem("mistakes", id: parts[1]) { item in var copy = item; copy["masteredAt"] = Self.date(Date()); return copy }
            return try envelope(item)
        }
        if request.method == .post, path == "notifications/read-all" {
            let now = Self.date(Date()); var values = state["notifications"] as? [[String: Any]] ?? []
            for index in values.indices { values[index]["readAt"] = now }
            state["notifications"] = values; try save(); return try envelope(["count": values.count])
        }
        if request.method == .post, parts.count == 3, parts[0] == "notifications", parts[2] == "read" {
            var values = state["notifications"] as? [[String: Any]] ?? []; var count = 0
            if let index = values.firstIndex(where: { $0["id"] as? String == parts[1] }) { values[index]["readAt"] = Self.date(Date()); count = 1 }
            state["notifications"] = values; try save(); return try envelope(["count": count])
        }
        if (request.method == .post || request.method == .patch), parts.count == 3, parts[0] == "sessions", ["cancel", "reschedule", "confirm"].contains(parts[2]) {
            let changes = try body(request)
            let item = try updateItem("sessions", id: parts[1]) { item in
                var copy = item
                if parts[2] == "cancel" { copy["status"] = "CANCELLED"; copy["cancelReason"] = changes["reason"] ?? NSNull() }
                else if parts[2] == "reschedule" { copy["startsAt"] = changes["startsAt"]; copy["endsAt"] = changes["endsAt"]; copy["status"] = "RESCHEDULED" }
                else { copy["status"] = "COMPLETED"; copy["completedAt"] = Self.date(Date()); copy["attendances"] = changes["attendances"] ?? [] }
                return copy
            }
            return try envelope(item)
        }
        if request.method == .patch, parts.count == 3, parts[0] == "sessions", parts[2] == "feedback" {
            let input = try body(request)
            var value = input; value["id"] = UUID().uuidString; value["sessionId"] = parts[1]
            _ = try updateItem("sessions", id: parts[1]) { item in var copy = item; copy["feedback"] = value; return copy }
            return try envelope(value)
        }
        if request.method == .post, parts.count == 3, parts[0] == "homework", parts[2] == "submissions" {
            let input = try body(request)
            var submission = input; submission["id"] = UUID().uuidString; submission["homeworkId"] = parts[1]; submission["status"] = "SUBMITTED"; submission["submittedAt"] = Self.date(Date())
            if let studentId = input["studentId"] as? String { submission["student"] = items("students").first { $0["id"] as? String == studentId } }
            _ = try updateItem("homework", id: parts[1]) { item in var copy = item; var values = copy["submissions"] as? [[String: Any]] ?? []; values.insert(submission, at: 0); copy["submissions"] = values; return copy }
            return try envelope(submission)
        }

        return nil
    }

    private func collectionKey(for path: String) -> String? {
        let allowed = ["students", "courses", "classes", "sessions", "homework", "materials", "plans", "mistakes", "feedback", "manual-courses", "orders"]
        return allowed.first { path == $0 }
    }

    private func detailPath(_ path: String) -> (String, String)? {
        let parts = path.split(separator: "/").map(String.init)
        guard parts.count == 2, collectionKey(for: parts[0]) != nil else { return nil }
        return (parts[0], parts[1])
    }

    private func items(_ key: String) -> [[String: Any]] { state[key] as? [[String: Any]] ?? [] }

    private func body(_ request: HTTPRequest) throws -> [String: Any] {
        guard let data = request.body else { return [:] }
        return try JSONSerialization.jsonObject(with: data) as? [String: Any] ?? [:]
    }

    private func makeItem(key: String, input: [String: Any]) -> [String: Any] {
        var item = input
        item["id"] = UUID().uuidString
        let now = Self.date(Date())
        switch key {
        case "students":
            item["status"] = "ACTIVE"; item["guardians"] = []
        case "courses":
            item["status"] = "ACTIVE"
        case "classes":
            item["status"] = "ACTIVE"; item["inviteCode"] = Self.code(); item["members"] = []; item["sessions"] = []
        case "sessions":
            item["plannedHours"] = plannedHours(input); item["status"] = "SCHEDULED"; item["source"] = "MANUAL"; item["attendances"] = []
            if let classId = input["classId"] as? String, let classroom = items("classes").first(where: { $0["id"] as? String == classId }) { item["classroom"] = classSummary(classroom) }
        case "homework":
            item["submissions"] = []
            if let classId = input["classId"] as? String, let classroom = items("classes").first(where: { $0["id"] as? String == classId }) { item["classroom"] = classSummary(classroom) }
        case "materials": item["createdAt"] = now
        case "plans": item["status"] = item["status"] ?? "ACTIVE"; item["checkIns"] = []
        case "mistakes": item["tags"] = []; item["createdAt"] = now
        case "feedback": item["status"] = "PENDING"; item["createdAt"] = now
        case "manual-courses": break
        case "orders":
            item["orderNumber"] = "CT\(Int(Date().timeIntervalSince1970))"; item["status"] = "PENDING"; item["consumedHours"] = 0; item["createdAt"] = now; item["payments"] = []; item["refunds"] = []
            if let id = input["studentId"] as? String { item["student"] = items("students").first { $0["id"] as? String == id } }
            if let id = input["classId"] as? String, let value = items("classes").first(where: { $0["id"] as? String == id }) { item["classroom"] = classSummary(value) }
        default: break
        }
        return item
    }

    private func homePayload() -> [String: Any] {
        let notices = state["notifications"] as? [[String: Any]] ?? []
        let unread = notices.filter { $0["readAt"] == nil || $0["readAt"] is NSNull }.count
        return [
            "sessions": items("sessions"), "unreadNotificationCount": unread,
            "announcements": state["announcements"] as? [[String: Any]] ?? [],
            "lowBalances": [], "homework": items("homework")
        ]
    }

    private func businessPayload() -> [String: Any] {
        let completed = items("sessions").filter { $0["status"] as? String == "COMPLETED" }
        let revenue = items("orders").reduce(0) { $0 + ($1["totalAmountCents"] as? Int ?? 0) }
        return ["activeClassCount": items("classes").filter { $0["status"] as? String == "ACTIVE" }.count,
                "completedSessionCount": completed.count, "consumedHours": Double(completed.count),
                "orderCount": items("orders").count, "recordedRevenueCents": revenue]
    }

    private func plannedHours(_ input: [String: Any]) -> Double {
        guard let start = input["startsAt"] as? String, let end = input["endsAt"] as? String,
              let a = Self.parse(start), let b = Self.parse(end) else { return 1 }
        return max(b.timeIntervalSince(a) / 3600, 0.5)
    }

    private func classSummary(_ value: [String: Any]) -> [String: Any] {
        ["id": value["id"] ?? "", "name": value["name"] ?? "课程", "billingMode": value["billingMode"] ?? "PREPAID", "status": value["status"] ?? "ACTIVE"]
    }

    @discardableResult
    private func updateItem(_ key: String, id: String, transform: ([String: Any]) -> [String: Any]) throws -> [String: Any] {
        var values = items(key)
        guard let index = values.firstIndex(where: { $0["id"] as? String == id }) else { throw LocalStoreError.notFound }
        values[index] = transform(values[index]); state[key] = values; try save(); return values[index]
    }

    private func loadIfNeeded() throws {
        let account = Self.currentAccount()
        guard !isLoaded || loadedAccount != account else { return }
        loadedAccount = account
        defer { isLoaded = true }
        let url = try Self.databaseURL(account: account)
        if FileManager.default.fileExists(atPath: url.path) {
            let object = try JSONSerialization.jsonObject(with: Data(contentsOf: url))
            if let saved = object as? [String: Any] { state = saved; return }
        }
        state = Self.seed()
        try save()
    }

    private func save() throws {
        let data = try JSONSerialization.data(withJSONObject: state, options: [.prettyPrinted, .sortedKeys])
        try data.write(to: Self.databaseURL(account: loadedAccount.isEmpty ? Self.currentAccount() : loadedAccount), options: .atomic)
    }

    private func envelope(_ payload: Any) throws -> Data {
        try JSONSerialization.data(withJSONObject: ["data": payload, "requestId": "local-\(UUID().uuidString)"])
    }

    private static func currentAccount() -> String {
        UserDefaults.standard.string(forKey: "classtrace.local.active-account") ?? "demo"
    }

    private static func databaseURL(account: String) throws -> URL {
        let root = try FileManager.default.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
            .appendingPathComponent("ClassTrace", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let safe = account.replacingOccurrences(of: "/", with: "-")
        return root.appendingPathComponent("local-database-\(safe)-v1.json")
    }

    private static func seed() -> [String: Any] {
        let now = date(Date()), tomorrowDate = Calendar.current.date(byAdding: .day, value: 1, to: Date()) ?? Date()
        let tomorrow = date(tomorrowDate), tomorrowEnd = date(tomorrowDate.addingTimeInterval(5400))
        let student: [String: Any] = ["id":"student-demo-1","name":"林小满","gender":"FEMALE","grade":"五年级","status":"ACTIVE","guardians":[]]
        let course: [String: Any] = ["id":"course-demo-1","name":"小学数学提升","subject":"数学","description":"计算、应用题与思维训练","status":"ACTIVE"]
        let summary: [String: Any] = ["id":"class-demo-1","name":"周末数学小班","billingMode":"PREPAID","status":"ACTIVE"]
        let classroom: [String: Any] = ["id":"class-demo-1","name":"周末数学小班","classType":"SMALL_GROUP","billingMode":"PREPAID","status":"ACTIVE","inviteCode":"MATH2026","location":"市南区教室","course":course,"members":[],"sessions":[]]
        let session: [String: Any] = ["id":"session-demo-1","classId":"class-demo-1","startsAt":tomorrow,"endsAt":tomorrowEnd,"plannedHours":1.5,"status":"SCHEDULED","source":"RECURRING","classroom":summary,"attendances":[]]
        let homework: [String: Any] = ["id":"homework-demo-1","classId":"class-demo-1","title":"分数应用题练习","content":"完成练习册第 18～20 页","dueAt":tomorrow,"status":"PUBLISHED","classroom":summary,"submissions":[]]
        return [
            "students":[student], "courses":[course], "classes":[classroom], "sessions":[session], "homework":[homework],
            "materials":[],
            "plans":[["id":"plan-demo-1","studentId":"student-demo-1","title":"每日口算 15 分钟","description":"连续坚持四周","status":"ACTIVE","startsAt":now,"checkIns":[]]],
            "mistakes":[["id":"mistake-demo-1","studentId":"student-demo-1","subject":"数学","title":"工程问题","content":"两人合作完成工程需要多久？","answer":"6 天","analysis":"先求两人的工作效率之和","tags":["应用题"],"createdAt":now]],
            "feedback":[], "manual-courses":[], "orders":[],
            "notifications":[["id":"notice-demo-1","type":"SESSION_REMINDER","title":"明天有课","body":"周末数学小班将在明天开课","resourceType":"SESSION","resourceId":"session-demo-1","createdAt":now]],
            "announcements":[["id":"announcement-demo-1","title":"暑期课程安排","content":"暑期课程时间已经更新，请在课表中查看。","publishedAt":now]]
        ]
    }

    private static func code() -> String { String(UUID().uuidString.replacingOccurrences(of: "-", with: "").prefix(8)).uppercased() }
    private static func date(_ value: Date) -> String { let f = ISO8601DateFormatter(); f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]; return f.string(from: value) }
    private static func parse(_ value: String) -> Date? { let a = ISO8601DateFormatter(); a.formatOptions = [.withInternetDateTime, .withFractionalSeconds]; return a.date(from: value) ?? ISO8601DateFormatter().date(from: value) }
}

private enum LocalStoreError: LocalizedError {
    case notFound
    var errorDescription: String? { "本地数据不存在或已被删除" }
}
