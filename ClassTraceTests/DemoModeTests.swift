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
}
