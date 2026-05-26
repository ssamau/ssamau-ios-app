import Foundation

/// Response from `head.dashboardSummary`. Bundles the committee meta,
/// four headline KPI counts, plus the top 5 pending applications and
/// top 5 hours awaiting head action.
struct HeadDashboardSummary: Decodable {
    let committee: HeadCommitteeMeta
    let counts: HeadDashboardCounts
    let pendingApplications: [PendingApplicationRow]
    let hoursPending: [PendingHoursRow]

    enum CodingKeys: String, CodingKey {
        case committee, counts
        case pendingApplications = "pending_applications"
        case hoursPending = "hours_pending"
    }
}

struct HeadCommitteeMeta: Decodable {
    let committeeId: String
    let committeeName: String
    let category: String?
    let headFullName: String?

    enum CodingKeys: String, CodingKey {
        case committeeId   = "committee_id"
        case committeeName = "committee_name"
        case category
        case headFullName  = "head_full_name"
    }
}

struct HeadDashboardCounts: Decodable {
    let membersCount: Int
    let pendingApplicationsCount: Int
    let hoursPendingCount: Int
    let openOpportunitiesCount: Int

    enum CodingKeys: String, CodingKey {
        case membersCount             = "members_count"
        case pendingApplicationsCount = "pending_applications_count"
        case hoursPendingCount        = "hours_pending_count"
        case openOpportunitiesCount   = "open_opportunities_count"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        membersCount             = Self.intOrZero(c, .membersCount)
        pendingApplicationsCount = Self.intOrZero(c, .pendingApplicationsCount)
        hoursPendingCount        = Self.intOrZero(c, .hoursPendingCount)
        openOpportunitiesCount   = Self.intOrZero(c, .openOpportunitiesCount)
    }

    private static func intOrZero(_ c: KeyedDecodingContainer<CodingKeys>, _ key: CodingKeys) -> Int {
        if let i = try? c.decode(Int.self, forKey: key) { return i }
        if let s = try? c.decode(String.self, forKey: key), let i = Int(s) { return i }
        return 0
    }
}

struct PendingApplicationRow: Decodable, Identifiable {
    let id: String
    let fullName: String
    let preferredName: String?
    let email: String?
    let status: String?
    let createdAt: String?

    var displayName: String { preferredName ?? fullName }

    enum CodingKeys: String, CodingKey {
        case id            = "application_id"
        case fullName      = "full_name"
        case preferredName = "preferred_name"
        case email, status
        case createdAt     = "created_at"
    }
}

struct PendingHoursRow: Decodable, Identifiable {
    let id: Int                       // hours_id
    let totalHours: Double
    let recordedAt: String?
    let approvalStatus: String?
    let memberFullName: String?
    let memberPreferredName: String?
    let projectName: String?
    let eventDate: String?

    var displayMember: String { memberPreferredName ?? memberFullName ?? "—" }

    enum CodingKeys: String, CodingKey {
        case id                  = "hours_id"
        case totalHours          = "total_hours"
        case recordedAt          = "recorded_at"
        case approvalStatus      = "approval_status"
        case memberFullName      = "member_full_name"
        case memberPreferredName = "member_preferred_name"
        case projectName         = "project_name"
        case eventDate           = "event_date"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        if let i = try? c.decode(Int.self, forKey: .id) { id = i }
        else if let s = try? c.decode(String.self, forKey: .id), let i = Int(s) { id = i }
        else { id = 0 }
        if let d = try? c.decode(Double.self, forKey: .totalHours) { totalHours = d }
        else if let s = try? c.decode(String.self, forKey: .totalHours), let d = Double(s) { totalHours = d }
        else { totalHours = 0 }
        recordedAt          = try c.decodeIfPresent(String.self, forKey: .recordedAt)
        approvalStatus      = try c.decodeIfPresent(String.self, forKey: .approvalStatus)
        memberFullName      = try c.decodeIfPresent(String.self, forKey: .memberFullName)
        memberPreferredName = try c.decodeIfPresent(String.self, forKey: .memberPreferredName)
        projectName         = try c.decodeIfPresent(String.self, forKey: .projectName)
        eventDate           = try c.decodeIfPresent(String.self, forKey: .eventDate)
    }
}
