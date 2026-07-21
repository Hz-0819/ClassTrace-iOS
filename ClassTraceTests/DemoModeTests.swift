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
        XCTAssertFalse(materials.isEmpty)
        XCTAssertFalse(plans.isEmpty)
        XCTAssertFalse(mistakes.isEmpty)
        XCTAssertFalse(orders.isEmpty)
    }

    func testDemoModeAcceptsRepresentativeWriteOperations() async throws {
        let createdStudent: APIStudent = try await client.send(HTTPRequest(method: .post, path: "students"))
        let sessionFeedback: APISessionFeedback = try await client.send(HTTPRequest(method: .patch, path: "sessions/session-demo-1/feedback"))
        let checkIn: APIPlanCheckIn = try await client.send(HTTPRequest(method: .post, path: "plans/plan-demo-1/check-ins"))
        let readResult: CountPayload = try await client.send(HTTPRequest(method: .post, path: "notifications/read-all"))

        XCTAssertEqual(createdStudent.id, "student-demo-1")
        XCTAssertEqual(sessionFeedback.sessionId, "session-demo-1")
        XCTAssertEqual(checkIn.planId, "plan-demo-1")
        XCTAssertEqual(readResult.count, 1)
    }
}
