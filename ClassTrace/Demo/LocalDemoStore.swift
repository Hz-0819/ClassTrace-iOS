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
            if path == "sessions" { return try envelope(filteredSessions(request.query)) }
            if path == "hour-ledger" { return try envelope(state["hour-ledger"] as? [[String: Any]] ?? []) }
            if let key = collectionKey(for: path), path == key { return try envelope(items(key)) }
            if let (key, id) = detailPath(path), let item = items(key).first(where: { $0["id"] as? String == id }) {
                if key == "classes" { return try envelope(enrichedClass(item)) }
                return try envelope(item)
            }
        }

        if request.method == .post, let key = collectionKey(for: path), path == key {
            let item = makeItem(key: key, input: try body(request))
            var values = items(key); values.insert(item, at: 0); state[key] = values
            try save(); return try envelope(item)
        }

        if request.method == .post, path == "sessions/generate" {
            let input = try body(request)
            guard let classId = input["classId"] as? String,
                  let fromText = input["from"] as? String,
                  let toText = input["to"] as? String,
                  let startTime = input["startTime"] as? String else { return nil }
            let weekdays = input["weekdays"] as? [Int] ?? []
            let duration = input["durationMinutes"] as? Int ?? 60
            let formatter = DateFormatter(); formatter.calendar = Calendar(identifier: .gregorian); formatter.locale = Locale(identifier: "en_US_POSIX"); formatter.dateFormat = "yyyy-MM-dd"
            guard var day = formatter.date(from: fromText), let endDay = formatter.date(from: toText) else { return nil }
            let timeParts = startTime.split(separator: ":").compactMap { Int($0) }
            var sessions = items("sessions"); var created = 0
            while day <= endDay {
                let calendarDay = Calendar.current.component(.weekday, from: day)
                let mondayBased = ((calendarDay + 5) % 7) + 1
                if weekdays.contains(mondayBased), timeParts.count == 2,
                   let startsAt = Calendar.current.date(bySettingHour: timeParts[0], minute: timeParts[1], second: 0, of: day) {
                    let input: [String: Any] = ["classId": classId, "startsAt": Self.date(startsAt), "endsAt": Self.date(startsAt.addingTimeInterval(Double(duration * 60)))]
                    sessions.append(makeItem(key: "sessions", input: input)); created += 1
                }
                day = Calendar.current.date(byAdding: .day, value: 1, to: day) ?? endDay.addingTimeInterval(1)
            }
            state["sessions"] = sessions; try save(); return try envelope(["created": created, "requested": created])
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
        if request.method == .post, parts.count == 3, parts[0] == "classes", parts[2] == "members" {
            let input = try body(request); guard let studentId = input["studentId"] as? String else { return nil }
            let initial = Self.number(input["initialHours"]); let price = Self.number(input["pricePerHour"])
            var member: [String: Any] = ["id":UUID().uuidString,"classId":parts[1],"studentId":studentId,"status":"APPROVED","totalHours":initial,"consumedHours":0,"remainingHours":initial,"pricePerHour":price]
            member["student"] = items("students").first { $0["id"] as? String == studentId }
            _ = try updateItem("classes", id: parts[1]) { item in var copy=item;var values=copy["members"] as? [[String:Any]] ?? [];values.append(member);copy["members"]=values;return copy }
            return try envelope(member)
        }
        if (request.method == .patch || request.method == .delete), parts.count == 4, parts[0] == "classes", parts[2] == "members" {
            let input = try body(request); var returned: [String:Any] = [:]
            _ = try updateItem("classes", id: parts[1]) { item in var copy=item;var values=copy["members"] as? [[String:Any]] ?? [];if request.method == .delete { values.removeAll { $0["id"] as? String == parts[3] } } else if let i=values.firstIndex(where:{$0["id"] as? String == parts[3]}) { for(k,v) in input where !(v is NSNull){values[i][k]=v};returned=values[i] };copy["members"]=values;return copy }
            return try envelope(request.method == .delete ? NSNull() : returned)
        }
        if request.method == .post, path == "classes/join" {
            let input=try body(request);guard let code=input["inviteCode"] as? String,let studentId=input["studentId"] as? String,let classroom=items("classes").first(where:{($0["inviteCode"] as? String)?.uppercased()==code.uppercased()}),let classId=classroom["id"] as? String else{return nil}
            var member:[String:Any]=["id":UUID().uuidString,"classId":classId,"studentId":studentId,"status":"APPROVED","totalHours":0,"consumedHours":0,"remainingHours":0,"pricePerHour":0];member["student"]=items("students").first{$0["id"] as? String==studentId}
            _=try updateItem("classes",id:classId){item in var copy=item;var values=copy["members"] as? [[String:Any]] ?? [];values.append(member);copy["members"]=values;return copy};return try envelope(member)
        }
        if request.method == .post, parts.count == 3, parts[0] == "orders", parts[2] == "payments" {
            let input=try body(request);let payment:[String:Any]=["id":UUID().uuidString,"provider":input["provider"] ?? "OTHER","providerTransactionId":input["providerTransactionId"] ?? UUID().uuidString,"status":"SUCCEEDED","amountCents":input["amountCents"] ?? 0,"occurredAt":Self.date(Date())]
            let order=try updateItem("orders",id:parts[1]){item in var copy=item;var values=copy["payments"] as? [[String:Any]] ?? [];values.append(payment);copy["payments"]=values;copy["status"]="PAID";copy["paidAt"]=Self.date(Date());return copy};return try envelope(order)
        }
        if request.method == .post, parts.count == 3, parts[0] == "orders", parts[2] == "refunds" {
            let input=try body(request);let refund:[String:Any]=["id":UUID().uuidString,"amountCents":input["amountCents"] ?? 0,"hours":input["hours"] ?? 0,"reason":input["reason"] ?? NSNull(),"status":"REQUESTED","createdAt":Self.date(Date())]
            _=try updateItem("orders",id:parts[1]){item in var copy=item;var values=copy["refunds"] as? [[String:Any]] ?? [];values.append(refund);copy["refunds"]=values;return copy};return try envelope(refund)
        }
        if request.method == .post, parts.count == 3, parts[0] == "refunds", parts[2] == "resolve" {
            let input=try body(request);var resolved:[String:Any]?
            var orders=items("orders");for oi in orders.indices{var refunds=orders[oi]["refunds"] as? [[String:Any]] ?? [];if let ri=refunds.firstIndex(where:{$0["id"] as? String==parts[1]}){refunds[ri]["status"]=input["status"] ?? "REJECTED";orders[oi]["refunds"]=refunds;resolved=refunds[ri];break}};state["orders"]=orders;try save();guard let resolved else{throw LocalStoreError.notFound};return try envelope(resolved)
        }
        if request.method == .post, parts.count == 4, parts[0] == "class-members", parts[2] == "hours", parts[3] == "recharge" {
            let input=try body(request),hours=Self.number(input["hours"]);var updated:[String:Any]?
            var classes=items("classes");for ci in classes.indices { var members=classes[ci]["members"] as? [[String:Any]] ?? [];if let mi=members.firstIndex(where:{$0["id"] as? String==parts[1]}) { let total=Self.number(members[mi]["totalHours"])+hours;let balance=Self.number(members[mi]["remainingHours"])+hours;members[mi]["totalHours"]=total;members[mi]["remainingHours"]=balance;classes[ci]["members"]=members;let entry:[String:Any]=["id":UUID().uuidString,"memberId":parts[1],"studentId":members[mi]["studentId"] ?? "","type":"RECHARGE","delta":hours,"balanceAfter":balance,"remark":input["remark"] ?? NSNull(),"createdAt":Self.date(Date()),"student":members[mi]["student"] ?? NSNull()];var ledger=state["hour-ledger"] as? [[String:Any]] ?? [];ledger.insert(entry,at:0);state["hour-ledger"]=ledger;updated=entry;break } };state["classes"]=classes;try save();guard let updated else{throw LocalStoreError.notFound};return try envelope(updated)
        }
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
            let normalizedRows = parts[2] == "confirm" ? normalizedAttendances(sessionId: parts[1], rows: changes["attendances"] as? [[String: Any]] ?? []) : []
            let item = try updateItem("sessions", id: parts[1]) { item in
                var copy = item
                if parts[2] == "cancel" { copy["status"] = "CANCELLED"; copy["cancelReason"] = changes["reason"] ?? NSNull() }
                else if parts[2] == "reschedule" { copy["startsAt"] = changes["startsAt"]; copy["endsAt"] = changes["endsAt"]; copy["status"] = "RESCHEDULED" }
                else { copy["status"] = "COMPLETED"; copy["completedAt"] = Self.date(Date()); copy["attendances"] = normalizedRows }
                return copy
            }
            if parts[2] == "confirm" { try applyAttendanceDeductions(session: item, rows: normalizedRows) }
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

    private func filteredSessions(_ query: [URLQueryItem]) -> [[String: Any]] {
        let from = query.first(where: { $0.name == "from" })?.value.flatMap(Self.parse)
        let to = query.first(where: { $0.name == "to" })?.value.flatMap(Self.parse)
        let classId = query.first(where: { $0.name == "classId" })?.value
        return items("sessions").filter { item in
            guard let text = item["startsAt"] as? String, let date = Self.parse(text) else { return false }
            if let from, date < from { return false }
            if let to, date >= to { return false }
            if let classId, item["classId"] as? String != classId { return false }
            return true
        }
    }

    private func enrichedClass(_ item: [String: Any]) -> [String: Any] {
        var value = item
        if let id = item["id"] as? String { value["sessions"] = items("sessions").filter { $0["classId"] as? String == id } }
        return value
    }

    private func normalizedAttendances(sessionId: String, rows: [[String: Any]]) -> [[String: Any]] {
        rows.map { row in
            let studentId = row["studentId"] as? String ?? ""
            var value: [String: Any] = ["id": UUID().uuidString, "sessionId": sessionId, "studentId": studentId, "status": row["status"] ?? "PRESENT", "deductHours": Self.number(row["deductHours"]), "remark": row["remark"] ?? NSNull()]
            if let student = items("students").first(where: { $0["id"] as? String == studentId }) { value["student"] = student }
            else { value["student"] = NSNull() }
            return value
        }
    }

    private func applyAttendanceDeductions(session: [String: Any], rows: [[String: Any]]) throws {
        guard let classId = session["classId"] as? String else { return }
        var ledger = state["hour-ledger"] as? [[String: Any]] ?? []
        _ = try updateItem("classes", id: classId) { classroom in
            var copy = classroom; var members = copy["members"] as? [[String: Any]] ?? []
            for row in rows where row["status"] as? String == "PRESENT" {
                guard let studentId = row["studentId"] as? String, let index = members.firstIndex(where: { $0["studentId"] as? String == studentId }) else { continue }
                let requested = Self.number(row["deductHours"]), balance = Self.number(members[index]["remainingHours"]), deducted = min(requested, balance)
                let next = max(0, balance - deducted); members[index]["remainingHours"] = next; members[index]["consumedHours"] = Self.number(members[index]["consumedHours"]) + deducted
                ledger.insert(["id":UUID().uuidString,"memberId":members[index]["id"] ?? "","studentId":studentId,"sessionId":session["id"] ?? "","type":"CONSUME","delta":-deducted,"balanceAfter":next,"remark":"确认上课自动扣减","createdAt":Self.date(Date()),"student":members[index]["student"] ?? NSNull()], at: 0)
            }
            copy["members"] = members; return copy
        }
        state["hour-ledger"] = ledger; try save()
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
            "feedback":[], "manual-courses":[], "orders":[], "hour-ledger":[],
            "notifications":[["id":"notice-demo-1","type":"SESSION_REMINDER","title":"明天有课","body":"周末数学小班将在明天开课","resourceType":"SESSION","resourceId":"session-demo-1","createdAt":now]],
            "announcements":[["id":"announcement-demo-1","title":"暑期课程安排","content":"暑期课程时间已经更新，请在课表中查看。","publishedAt":now]]
        ]
    }

    private static func code() -> String { String(UUID().uuidString.replacingOccurrences(of: "-", with: "").prefix(8)).uppercased() }
    private static func number(_ value: Any?) -> Double { if let value=value as? Double{return value};if let value=value as? Int{return Double(value)};if let value=value as? String{return Double(value) ?? 0};if let value=value as? NSNumber{return value.doubleValue};return 0 }
    private static func date(_ value: Date) -> String { let f = ISO8601DateFormatter(); f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]; return f.string(from: value) }
    private static func parse(_ value: String) -> Date? { let a = ISO8601DateFormatter(); a.formatOptions = [.withInternetDateTime, .withFractionalSeconds]; return a.date(from: value) ?? ISO8601DateFormatter().date(from: value) }
}

private enum LocalStoreError: LocalizedError {
    case notFound
    var errorDescription: String? { "本地数据不存在或已被删除" }
}
