import XCTest
@testable import ClassTrace

final class DomainModelTests: XCTestCase {
    func testFlexibleDecimalDecodesStringsAndNumbers() throws {
        let decoder = JSONDecoder()
        XCTAssertEqual(try decoder.decode(FlexibleDecimal.self, from: Data("\"1.25\"".utf8)).doubleValue, 1.25)
        XCTAssertEqual(try decoder.decode(FlexibleDecimal.self, from: Data("2.5".utf8)).doubleValue, 2.5)
    }

    func testConfirmationRequestCarriesStableStudentIdentity() throws {
        let value = ConfirmAttendanceRequest(studentId: "student-1", status: "PRESENT", deductHours: 1, remark: nil)
        let object = try JSONSerialization.jsonObject(with: JSONEncoder().encode(value)) as? [String: Any]
        XCTAssertEqual(object?["studentId"] as? String, "student-1")
        XCTAssertEqual(object?["status"] as? String, "PRESENT")
        XCTAssertEqual(object?["deductHours"] as? Double, 1)
    }
}
