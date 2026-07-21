import Foundation

enum JSONValue: Codable, Sendable {
    case object([String: JSONValue]), array([JSONValue]), string(String), number(Double), bool(Bool), null
    init(from decoder: Decoder) throws { let c = try decoder.singleValueContainer(); if c.decodeNil() { self = .null } else if let v = try? c.decode(Bool.self) { self = .bool(v) } else if let v = try? c.decode(Double.self) { self = .number(v) } else if let v = try? c.decode(String.self) { self = .string(v) } else if let v = try? c.decode([String: JSONValue].self) { self = .object(v) } else { self = .array(try c.decode([JSONValue].self)) } }
    func encode(to encoder: Encoder) throws { var c = encoder.singleValueContainer(); switch self { case let .object(v): try c.encode(v); case let .array(v): try c.encode(v); case let .string(v): try c.encode(v); case let .number(v): try c.encode(v); case let .bool(v): try c.encode(v); case .null: try c.encodeNil() } }
}

struct FlexibleDecimal: Codable, Hashable, Sendable {
    let value: Decimal
    init(_ value: Decimal) { self.value = value }
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let number = try? container.decode(Double.self) { value = Decimal(number) }
        else if let text = try? container.decode(String.self), let parsed = Decimal(string: text) { value = parsed }
        else { throw DecodingError.dataCorruptedError(in: container, debugDescription: "Expected decimal string or number") }
    }
    func encode(to encoder: Encoder) throws { var container = encoder.singleValueContainer(); try container.encode(NSDecimalNumber(decimal: value).stringValue) }
    var doubleValue: Double { NSDecimalNumber(decimal: value).doubleValue }
}

struct APIUser: Codable, Identifiable, Hashable, Sendable {
    let id: String
    var displayName: String
    var avatarUrl: URL?
    var status: String
    var roles: [UserRoleRecord]?
    var identities: [APIIdentity]?
}
struct UserRoleRecord: Codable, Hashable, Sendable { let role: String }
struct APIIdentity: Codable, Hashable, Sendable { let provider: String; let verifiedAt: Date? }
struct AuthSessionPayload: Codable, Sendable {
    let user: APIUser
    let accessToken: String
    let refreshToken: String
    let expiresIn: Int
}
struct PhoneCodePayload: Codable, Sendable { let expiresIn: Int; let developmentCode: String? }

struct APIStudent: Codable, Identifiable, Hashable, Sendable {
    let id: String
    var name: String
    var gender: String?
    var grade: String?
    var status: String
    var guardians: [GuardianLink]?
    var classMembers: [APIClassMember]?
    var attendances: [APIAttendance]?
    var homeworkSubmissions: [APIHomeworkSubmission]?
    var studyPlans: [APIStudyPlan]?
    var mistakes: [APIMistake]?
}
struct GuardianLink: Codable, Identifiable, Hashable, Sendable { let id: String; let guardianUserId: String?; let relationship: String?; let isPrimary: Bool }

struct APICourse: Codable, Identifiable, Hashable, Sendable {
    let id: String; var name: String; var subject: String?; var description: String?; var status: String
}
struct APIClassroom: Codable, Identifiable, Hashable, Sendable {
    let id: String
    var name: String
    var classType: String
    var billingMode: String
    var status: String
    var inviteCode: String
    var location: String?
    var course: APICourse?
    var members: [APIClassMember]?
    var sessions: [APISession]?
    var schedule: APIClassSchedule?
    var color: String?
    var maxStudents: Int?
    var lessonDurationMinutes: Int?
    var startDate: Date?
    var priceSettings: APIPriceSettings?
    var hourSettings: APIHourSettings?
}
struct APIClassSchedule: Codable, Hashable, Sendable {
    var mode: String
    var text: String
    var days: [String]
    var items: [APIClassScheduleItem]
}
struct APIClassScheduleItem: Codable, Identifiable, Hashable, Sendable {
    var id: String
    var day: String?
    var dayEn: String?
    var date: String?
    var startTime: String
    var endTime: String
    var time: String?
}
struct APIPriceSettings: Codable, Hashable, Sendable { var type: String; var price: FlexibleDecimal }
struct APIHourSettings: Codable, Hashable, Sendable { var totalHours: FlexibleDecimal; var warningThreshold: FlexibleDecimal }
struct APIClassMember: Codable, Identifiable, Hashable, Sendable {
    let id: String
    var classId: String
    var studentId: String
    var status: String
    var totalHours: FlexibleDecimal
    var consumedHours: FlexibleDecimal
    var remainingHours: FlexibleDecimal
    var pricePerHour: FlexibleDecimal
    var student: APIStudent?
    var classroom: APIClassroomSummary?
}
struct APIClassroomSummary: Codable, Identifiable, Hashable, Sendable { let id: String; let name: String; let billingMode: String; let status: String }

struct APISession: Codable, Identifiable, Hashable, Sendable {
    let id: String
    let classId: String
    var startsAt: Date
    var endsAt: Date
    var plannedHours: FlexibleDecimal
    var status: String
    var source: String
    var cancelReason: String?
    var completedAt: Date?
    var classroom: APIClassroomSummary?
    var attendances: [APIAttendance]?
    var feedback: APISessionFeedback?
    var hourEntries: [APIHourEntry]?
}
struct APIAttendance: Codable, Identifiable, Hashable, Sendable {
    let id: String; let sessionId: String; let studentId: String; var status: String; var deductHours: FlexibleDecimal; var remark: String?; var student: APIStudent?
}
struct APISessionFeedback: Codable, Identifiable, Hashable, Sendable { let id: String; let sessionId: String; var summary: String?; var performance: String?; var homeworkNote: String? }
struct APIHourEntry: Codable, Identifiable, Hashable, Sendable {
    let id: String; let memberId: String; let studentId: String; let sessionId: String?; let type: String; let delta: FlexibleDecimal; let balanceAfter: FlexibleDecimal; let remark: String?; let createdAt: Date; let student: APIStudent?
}
struct APIAttendanceStats: Codable, Sendable { let total: Int; let counts: [String: Int]; let attendanceRate: Double }

struct APIHomework: Codable, Identifiable, Hashable, Sendable {
    let id: String; let classId: String; var title: String; var content: String; var dueAt: Date?; var status: String; var classroom: APIClassroomSummary?; var submissions: [APIHomeworkSubmission]?
}
struct APIHomeworkSubmission: Codable, Identifiable, Hashable, Sendable {
    let id: String; let homeworkId: String; let studentId: String; var content: String?; var status: String; var score: FlexibleDecimal?; var comment: String?; var submittedAt: Date; var student: APIStudent?
}
struct APIMaterial: Codable, Identifiable, Hashable, Sendable { let id: String; let classId: String?; let name: String; let objectKey: String; let mimeType: String; let sizeBytes: Int; let category: String?; let createdAt: Date }
struct APIStudyPlan: Codable, Identifiable, Hashable, Sendable { let id: String; let studentId: String?; var title: String; var description: String?; var status: String; var startsAt: Date?; var endsAt: Date?; var checkIns: [APIPlanCheckIn]? }
struct APIPlanCheckIn: Codable, Identifiable, Hashable, Sendable { let id: String; let planId: String; let note: String?; let checkedAt: Date }
struct APIMistake: Codable, Identifiable, Hashable, Sendable { let id: String; let studentId: String?; var subject: String?; var title: String; var content: String?; var answer: String?; var analysis: String?; var tags: [String]; var masteredAt: Date?; let createdAt: Date }
struct APIPoints: Codable, Sendable { let balance: Int; let entries: [APIPointEntry] }
struct APIPointEntry: Codable, Identifiable, Hashable, Sendable { let id: String; let delta: Int; let reason: String; let createdAt: Date }

struct APINotification: Codable, Identifiable, Hashable, Sendable { let id: String; let type: String; let title: String; let body: String; let resourceType: String?; let resourceId: String?; let readAt: Date?; let createdAt: Date }
struct APIAnnouncement: Codable, Identifiable, Hashable, Sendable { let id: String; let title: String; let content: String; let publishedAt: Date?; let expiresAt: Date? }
struct APIFeedback: Codable, Identifiable, Hashable, Sendable { let id: String; let category: String; let content: String; let status: String; let reply: String?; let createdAt: Date }
struct APIManualCourse: Codable, Identifiable, Hashable, Sendable { let id: String; var name: String; var startsAt: Date; var endsAt: Date; var location: String?; var note: String? }

struct APIOrder: Codable, Identifiable, Hashable, Sendable {
    let id: String; let orderNumber: String; let studentId: String; let classId: String; var status: String; let settlementPolicy: String; let totalAmountCents: Int; let purchasedHours: FlexibleDecimal; let consumedHours: FlexibleDecimal; let paidAt: Date?; let createdAt: Date; var student: APIStudent?; var classroom: APIClassroomSummary?; var payments: [APIPayment]?; var refunds: [APIRefund]?
}
struct APIPayment: Codable, Identifiable, Hashable, Sendable { let id: String; let provider: String; let providerTransactionId: String; let status: String; let amountCents: Int; let occurredAt: Date }
struct APIRefund: Codable, Identifiable, Hashable, Sendable { let id: String; let amountCents: Int; let hours: FlexibleDecimal; let reason: String?; let status: String; let createdAt: Date }
struct APIEntitlements: Codable, Sendable { let active: Bool; let grants: [APIEntitlementGrant] }
struct APIEntitlementGrant: Codable, Identifiable, Sendable { let id: String; let startsAt: Date; let endsAt: Date? }

struct CountPayload: Codable, Sendable { let count: Int }
struct CreatedCountPayload: Codable, Sendable { let created: Int; let requested: Int }
struct GuardianInvitePayload: Codable, Sendable { let code: String; let expiresIn: Int }
struct ActivationCodePayload: Codable, Sendable { let code: String; let days: Int }
struct APIHome: Codable, Sendable { let sessions: [APISession]; let unreadNotificationCount: Int; let announcements: [APIAnnouncement]; let lowBalances: [APIClassMember]; let homework: [APIHomework] }
struct APIBusinessOverview: Codable, Sendable { let activeClassCount: Int; let completedSessionCount: Int; let consumedHours: Double; let orderCount: Int; let recordedRevenueCents: Int }
struct APISubscription: Codable, Identifiable, Sendable { let id: String; let productId: String; let status: String; let expiresAt: Date? }
struct APIDeviceToken: Codable, Identifiable, Sendable { let id: String; let platform: String; let environment: String; let lastSeenAt: Date }
struct APINotificationPreference: Codable, Identifiable, Sendable { let id: String; let eventType: String; let channel: String; let enabled: Bool }
struct APIUploadIntent: Codable, Sendable { let objectKey: String; let uploadUrl: String; let expiresIn: Int }
struct APIDownloadURL: Codable, Sendable { let url: String; let expiresIn: Int }
