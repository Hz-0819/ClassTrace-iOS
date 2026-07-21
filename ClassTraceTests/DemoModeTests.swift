import XCTest
@testable import ClassTrace

@MainActor
final class DemoModeTests: XCTestCase {
    private let client = HTTPClient(baseURL: URL(string: "https://demo.invalid/v1/")!)

    func testDemoModeBypassesAuthenticationAndDecodesCoreDomains() async throws {
        XCTAssertTrue(DemoMode.isEnabled)

        let user: APIUser = try await client.send(HTTPRequest(method: .get, path: "me"))
        let home: APIHome = try await client.send(HTTPRequest(method: .get, path: "home"))
        let students: [APIStudent] = try await client.send(HTTPRequest(method: .get, path: "students"))
        let courses: [APICourse] = try await client.send(HTTPRequest(method: .get, path: "courses"))
        let classes: [APIClassroom] = try await client.send(HTTPRequest(method: .get, path: "classes"))
        let sessions: [APISession] = try await client.send(HTTPRequest(method: .get, path: "sessions"))
        let homework: [APIHomework] = try await client.send(HTTPRequest(method: .get, path: "homework"))
        let materials: [APIMaterial] = try await client.send(HTTPRequest(method: .get, path: "materials"))
        let plans: [APIStudyPlan] = try await client.send(HTTPRequest(method: .get, path: "plans"))
        let mistakes: [APIMistake] = try await client.send(HTTPRequest(method: .get, path: "mistakes"))
        let orders: [APIOrder] = try await client.send(HTTPRequest(method: .get, path: "orders"))

        XCTAssertEqual(user.displayName, "演示教师")
        XCTAssertFalse(home.sessions.isEmpty)
        XCTAssertFalse(students.isEmpty)
        XCTAssertFalse(courses.isEmpty)
        XCTAssertFalse(classes.isEmpty)
        XCTAssertFalse(sessions.isEmpty)
        XCTAssertFalse(homework.isEmpty)
        XCTAssertNotNil(materials)
        XCTAssertFalse(plans.isEmpty)
        XCTAssertFalse(mistakes.isEmpty)
        XCTAssertNotNil(orders)
    }

    func testDemoModeAcceptsRepresentativeWriteOperations() async throws {
        let name = "本地学生-\(UUID().uuidString.prefix(6))"
        let studentRequest = try HTTPRequest.json(method: .post, path: "students", body: ["name": name, "grade": "三年级"])
        let createdStudent: APIStudent = try await client.send(studentRequest)
        let feedbackRequest = try HTTPRequest.json(method: .patch, path: "sessions/session-demo-1/feedback", body: ["summary": "课堂表现良好"])
        let sessionFeedback: APISessionFeedback = try await client.send(feedbackRequest)
        let checkInRequest = try HTTPRequest.json(method: .post, path: "plans/plan-demo-1/check-ins", body: ["note": "今日完成"])
        let checkIn: APIPlanCheckIn = try await client.send(checkInRequest)
        let readResult: CountPayload = try await client.send(HTTPRequest(method: .post, path: "notifications/read-all"))
        let savedStudents: [APIStudent] = try await client.send(HTTPRequest(method: .get, path: "students"))

        XCTAssertEqual(createdStudent.name, name)
        XCTAssertTrue(savedStudents.contains(where: { $0.id == createdStudent.id }))
        XCTAssertEqual(sessionFeedback.sessionId, "session-demo-1")
        XCTAssertEqual(checkIn.planId, "plan-demo-1")
        XCTAssertEqual(readResult.count, 1)
    }

    func testLegacyMiniProgramIconsResolveFromApplicationBundle() {
        for name in ["home-blue", "class-blue", "user-blue", "notice", "timetable-blue", "file-red"] {
            XCTAssertNotNil(LegacyImageLoader.image(named: name), "Missing bundled mini-program icon: \(name)")
        }
    }

    func testFixedScheduleCreatesPersistentSessions() async throws {
        let repository = ClassTraceRepository(client: client)
        let schedule = APIClassSchedule(mode: "weekly", text: "周一 10:00-11:00", days: ["monday"], items: [APIClassScheduleItem(id: UUID().uuidString, day: "周一", dayEn: "monday", date: nil, startTime: "10:00", endTime: "11:00", time: "10:00-11:00")])
        let classroom = try await repository.createClass(name: "排课回归-\(UUID().uuidString.prefix(6))", type: "SMALL_GROUP", billingMode: "PREPAID", location: "测试教室", schedule: schedule, price: 100, totalHours: 10, lessonDurationMinutes: 60, startDate: Date())
        let end = Calendar.current.date(byAdding: .day, value: 14, to: Date())!
        let result = try await repository.generateSessions(classId: classroom.id, from: Date(), to: end, weekdays: [1,2,3,4,5,6,7], startTime: "10:00", durationMinutes: 60)
        let sessions = try await repository.sessions(classId: classroom.id)
        XCTAssertGreaterThan(result.created, 0)
        XCTAssertEqual(sessions.count, result.created)
        XCTAssertTrue(sessions.allSatisfy { $0.classId == classroom.id })
    }

    func testUndoAttendanceRestoresMemberHoursAndRemovesConsumptionLedger() async throws {
        let repository = ClassTraceRepository(client: client)
        let student = try await repository.createStudent(name: "撤销点名学生-\(UUID().uuidString.prefix(4))", grade: "四年级", linkAsGuardian: false)
        let classroom = try await repository.createClass(name: "撤销点名班级-\(UUID().uuidString.prefix(4))", type: "ONE_ON_ONE", billingMode: "PREPAID", location: nil)
        let member = try await repository.addMember(classId: classroom.id, studentId: student.id, initialHours: 10, pricePerHour: 120)
        let session = try await repository.createSession(classId: classroom.id, startsAt: Date(), endsAt: Date().addingTimeInterval(3600))

        _ = try await repository.confirmSession(
            id: session.id,
            attendances: [ConfirmAttendanceRequest(studentId: student.id, status: "PRESENT", deductHours: 1, remark: nil)]
        )
        let deducted = try await repository.classDetail(classroom.id)
        let ledgerAfterConfirmation = try await repository.hourLedger()
        XCTAssertEqual(deducted.members?.first(where: { $0.id == member.id })?.remainingHours.doubleValue, 9)
        XCTAssertTrue(ledgerAfterConfirmation.contains(where: { $0.sessionId == session.id }))

        _ = try await repository.undoSession(id: session.id)
        let restored = try await repository.classDetail(classroom.id)
        let ledgerAfterUndo = try await repository.hourLedger()
        XCTAssertEqual(restored.members?.first(where: { $0.id == member.id })?.remainingHours.doubleValue, 10)
        XCTAssertEqual(restored.members?.first(where: { $0.id == member.id })?.consumedHours.doubleValue, 0)
        XCTAssertFalse(ledgerAfterUndo.contains(where: { $0.sessionId == session.id }))
    }

    func testGuardianInviteBindAndRemovalPersistLocally() async throws {
        let repository = ClassTraceRepository(client: client)
        let student = try await repository.createStudent(name: "绑定监护人-\(UUID().uuidString.prefix(4))", grade: "二年级", linkAsGuardian: false)
        let invite = try await repository.createGuardianInvite(studentId: student.id)
        let bound = try await repository.bindStudent(code: invite.code, relationship: "妈妈")

        XCTAssertEqual(bound.id, student.id)
        XCTAssertEqual(bound.guardians?.first?.relationship, "妈妈")
        let guardianId = try XCTUnwrap(bound.guardians?.first?.id)

        try await repository.removeGuardian(studentId: student.id, guardianId: guardianId)
        let unbound = try await repository.studentDetail(student.id)
        XCTAssertTrue(unbound.guardians?.isEmpty == true)
    }
}
