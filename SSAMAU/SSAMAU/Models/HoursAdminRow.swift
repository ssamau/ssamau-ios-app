import Foundation

/// One row from `getMemberHours` — admin/head facing variant.
/// Richer than `HoursRow` (which is for member-self listing):
/// includes member-name fields, owning_committee_id, and approver
/// name strings. Used by HoursApprovalView + admin tools.
struct HoursAdminRow: Codable, Identifiable, Equatable {
    let id: Int                          // hours_id
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
    let rejectedReason: String?
    // Joined
    let projectName: String?
    let eventDate: String?
    let memberFullName: String?
    let memberPreferredName: String?
    let opportunityRoleName: String?
    let opportunityCommitteeId: String?
    let primaryApproverName: String?
    let finalApproverName: String?
    let meetingTitle: String?
    let meetingDate: String?

    var displayMember: String {
        memberPreferredName ?? memberFullName ?? "—"
    }
    var displayTitle: String {
        if let meeting = meetingTitle, !meeting.isEmpty { return meeting }
        return projectName ?? "—"
    }
    var displayDate: String? { eventDate ?? meetingDate }
    var isAutoMeetingRow: Bool { notes?.hasPrefix("auto:meeting:") == true }

    enum CodingKeys: String, CodingKey {
        case notes
        case id                      = "hours_id"
        case memberId                = "member_id"
        case projectId               = "project_id"
        case assignmentId            = "assignment_id"
        case hoursBefore             = "hours_before"
        case hoursDuring             = "hours_during"
        case hoursAfter              = "hours_after"
        case totalHours              = "total_hours"
        case approvalStatus          = "approval_status"
        case recordedAt              = "recorded_at"
        case rejectedReason          = "rejected_reason"
        case projectName             = "project_name"
        case eventDate               = "event_date"
        case memberFullName          = "member_full_name"
        case memberPreferredName     = "member_preferred_name"
        case opportunityRoleName     = "opportunity_role_name"
        case opportunityCommitteeId  = "opportunity_committee_id"
        case primaryApproverName     = "primary_approver_name"
        case finalApproverName       = "final_approver_name"
        case meetingTitle            = "meeting_title"
        case meetingDate             = "meeting_date"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        if let n = try? c.decode(Int.self, forKey: .id) { id = n }
        else if let s = try? c.decode(String.self, forKey: .id), let n = Int(s) { id = n }
        else { id = 0 }
        memberId               = try c.decodeIfPresent(String.self, forKey: .memberId)
        projectId              = try c.decodeIfPresent(String.self, forKey: .projectId)
        if let i = try? c.decode(Int.self, forKey: .assignmentId) {
            assignmentId = String(i)
        } else {
            assignmentId = try c.decodeIfPresent(String.self, forKey: .assignmentId)
        }
        hoursBefore            = Self.doubleOrZero(c, .hoursBefore)
        hoursDuring            = Self.doubleOrZero(c, .hoursDuring)
        hoursAfter             = Self.doubleOrZero(c, .hoursAfter)
        totalHours             = Self.doubleOrZero(c, .totalHours)
        approvalStatus         = try c.decodeIfPresent(String.self, forKey: .approvalStatus) ?? "Draft"
        recordedAt             = try c.decodeIfPresent(String.self, forKey: .recordedAt)
        notes                  = try c.decodeIfPresent(String.self, forKey: .notes)
        rejectedReason         = try c.decodeIfPresent(String.self, forKey: .rejectedReason)
        projectName            = try c.decodeIfPresent(String.self, forKey: .projectName)
        eventDate              = try c.decodeIfPresent(String.self, forKey: .eventDate)
        memberFullName         = try c.decodeIfPresent(String.self, forKey: .memberFullName)
        memberPreferredName    = try c.decodeIfPresent(String.self, forKey: .memberPreferredName)
        opportunityRoleName    = try c.decodeIfPresent(String.self, forKey: .opportunityRoleName)
        opportunityCommitteeId = try c.decodeIfPresent(String.self, forKey: .opportunityCommitteeId)
        primaryApproverName    = try c.decodeIfPresent(String.self, forKey: .primaryApproverName)
        finalApproverName      = try c.decodeIfPresent(String.self, forKey: .finalApproverName)
        meetingTitle           = try c.decodeIfPresent(String.self, forKey: .meetingTitle)
        meetingDate            = try c.decodeIfPresent(String.self, forKey: .meetingDate)
    }

    private static func doubleOrZero(_ c: KeyedDecodingContainer<CodingKeys>, _ key: CodingKeys) -> Double {
        if let d = try? c.decode(Double.self, forKey: key) { return d }
        if let s = try? c.decode(String.self, forKey: key), let d = Double(s) { return d }
        return 0
    }
}
