import Foundation

/// One row from `hours.listOwn` — a recorded hours entry for the
/// current member. Mirrors the SELECT in the server's handler.
///
/// Status values: "Draft" | "PrimaryApproved" | "FinalApproved" | "Rejected"
struct HoursRow: Codable, Identifiable, Equatable {
    let id: Int                            // hours_id
    let memberId: String?
    let projectId: String?
    let assignmentId: String?
    let hoursBefore: Double
    let hoursDuring: Double
    let hoursAfter: Double
    let totalHours: Double
    let approvalStatus: String
    let recordedAt: String?
    let notes: String?
    // Joined
    let projectName: String?
    let eventDate: String?
    let opportunityRoleName: String?
    let meetingTitle: String?
    let meetingDate: String?

    /// True when this row was auto-mirrored from a meeting attendance
    /// entry (notes prefix `auto:meeting:`). UI shows a 📅 badge.
    var isAutoMeetingRow: Bool {
        notes?.hasPrefix("auto:meeting:") == true
    }

    var displayTitle: String {
        if isAutoMeetingRow, let t = meetingTitle, !t.isEmpty { return t }
        return projectName ?? "—"
    }

    var displayDate: String? {
        eventDate ?? meetingDate
    }

    enum CodingKeys: String, CodingKey {
        case notes
        case id                   = "hours_id"
        case memberId             = "member_id"
        case projectId            = "project_id"
        case assignmentId         = "assignment_id"
        case hoursBefore          = "hours_before"
        case hoursDuring          = "hours_during"
        case hoursAfter           = "hours_after"
        case totalHours           = "total_hours"
        case approvalStatus       = "approval_status"
        case recordedAt           = "recorded_at"
        case projectName          = "project_name"
        case eventDate            = "event_date"
        case opportunityRoleName  = "opportunity_role_name"
        case meetingTitle         = "meeting_title"
        case meetingDate          = "meeting_date"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        // hours_id is INT — accept Int or String
        if let n = try? c.decode(Int.self, forKey: .id) {
            id = n
        } else if let s = try? c.decode(String.self, forKey: .id), let n = Int(s) {
            id = n
        } else {
            id = 0
        }
        memberId            = try c.decodeIfPresent(String.self, forKey: .memberId)
        projectId           = try c.decodeIfPresent(String.self, forKey: .projectId)
        // Same int-or-string flexibility as Assignment.id — the column
        // is a SERIAL int and comes back as a number.
        if let n = try? c.decode(Int.self, forKey: .assignmentId) {
            assignmentId = String(n)
        } else {
            assignmentId = try c.decodeIfPresent(String.self, forKey: .assignmentId)
        }
        hoursBefore         = Self.doubleOrZero(c, .hoursBefore)
        hoursDuring         = Self.doubleOrZero(c, .hoursDuring)
        hoursAfter          = Self.doubleOrZero(c, .hoursAfter)
        totalHours          = Self.doubleOrZero(c, .totalHours)
        approvalStatus      = try c.decodeIfPresent(String.self, forKey: .approvalStatus) ?? "Draft"
        recordedAt          = try c.decodeIfPresent(String.self, forKey: .recordedAt)
        notes               = try c.decodeIfPresent(String.self, forKey: .notes)
        projectName         = try c.decodeIfPresent(String.self, forKey: .projectName)
        eventDate           = try c.decodeIfPresent(String.self, forKey: .eventDate)
        opportunityRoleName = try c.decodeIfPresent(String.self, forKey: .opportunityRoleName)
        meetingTitle        = try c.decodeIfPresent(String.self, forKey: .meetingTitle)
        meetingDate         = try c.decodeIfPresent(String.self, forKey: .meetingDate)
    }

    private static func doubleOrZero(_ c: KeyedDecodingContainer<CodingKeys>, _ key: CodingKeys) -> Double {
        if let d = try? c.decode(Double.self, forKey: key) { return d }
        if let s = try? c.decode(String.self, forKey: key), let d = Double(s) { return d }
        return 0
    }
}
