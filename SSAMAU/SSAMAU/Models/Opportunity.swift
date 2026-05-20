import Foundation

/// Single role within a multi-role opportunity. Returned as an array
/// under `roles` in the `opportunities.list` response.
struct OpportunityRole: Codable, Identifiable, Equatable {
    let id: Int64
    let roleName: String
    let roleKey: String?
    let estimatedHours: Double
    let headcountNeeded: Int
    let notes: String?
    let sortOrder: Int
    let taken: Int

    var remaining: Int { max(0, headcountNeeded - taken) }
    var isFull: Bool { taken >= headcountNeeded }

    enum CodingKeys: String, CodingKey {
        case id
        case roleName        = "role_name"
        case roleKey         = "role_key"
        case estimatedHours  = "estimated_hours"
        case headcountNeeded = "headcount_needed"
        case notes
        case sortOrder       = "sort_order"
        case taken
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id              = try c.decode(Int64.self, forKey: .id)
        roleName        = try c.decode(String.self, forKey: .roleName)
        roleKey         = try c.decodeIfPresent(String.self, forKey: .roleKey)
        headcountNeeded = try c.decodeIfPresent(Int.self, forKey: .headcountNeeded) ?? 1
        notes           = try c.decodeIfPresent(String.self, forKey: .notes)
        sortOrder       = try c.decodeIfPresent(Int.self, forKey: .sortOrder) ?? 0
        taken           = try c.decodeIfPresent(Int.self, forKey: .taken) ?? 0
        // Postgres NUMERIC → may come back as String
        if let d = try? c.decode(Double.self, forKey: .estimatedHours) {
            estimatedHours = d
        } else if let s = try? c.decode(String.self, forKey: .estimatedHours),
                  let d = Double(s) {
            estimatedHours = d
        } else {
            estimatedHours = 0
        }
    }
}

/// One row from `opportunities.list`. Mirrors `opportunities` columns
/// + joined project + committee + per-role nested array.
struct Opportunity: Codable, Identifiable, Equatable {
    let id: String                              // opportunity_id, OPP_XXXX
    let projectId: String
    let projectName: String?
    let projectType: String?
    let eventDate: String?                      // ISO timestamp
    let owningCommitteeId: String?
    let owningCommitteeName: String?
    let status: String                          // "Open" | "Filled" | "NeedsHelp" | "Cancelled" | "Done"
    let notes: String?
    let assignedCount: Int
    let attendedCount: Int
    let roles: [OpportunityRole]

    var isOpenForInterest: Bool {
        status == "Open" || status == "NeedsHelp"
    }

    /// Aggregate taken / needed across all roles. Useful for the row
    /// summary chip in OpportunitiesView.
    var totalTaken: Int { roles.reduce(0) { $0 + $1.taken } }
    var totalNeeded: Int { roles.reduce(0) { $0 + $1.headcountNeeded } }

    enum CodingKeys: String, CodingKey {
        case status, notes, roles
        case id                   = "opportunity_id"
        case projectId            = "project_id"
        case projectName          = "project_name"
        case projectType          = "project_type"
        case eventDate            = "event_date"
        case owningCommitteeId    = "owning_committee_id"
        case owningCommitteeName  = "owning_committee_name"
        case assignedCount        = "assigned_count"
        case attendedCount        = "attended_count"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id                  = try c.decode(String.self, forKey: .id)
        projectId           = try c.decode(String.self, forKey: .projectId)
        projectName         = try c.decodeIfPresent(String.self, forKey: .projectName)
        projectType         = try c.decodeIfPresent(String.self, forKey: .projectType)
        eventDate           = try c.decodeIfPresent(String.self, forKey: .eventDate)
        owningCommitteeId   = try c.decodeIfPresent(String.self, forKey: .owningCommitteeId)
        owningCommitteeName = try c.decodeIfPresent(String.self, forKey: .owningCommitteeName)
        status              = try c.decodeIfPresent(String.self, forKey: .status) ?? "Open"
        notes               = try c.decodeIfPresent(String.self, forKey: .notes)
        // assigned_count / attended_count come from Postgres COUNT(*)
        // which is BIGINT — may serialize as String. Accept both.
        assignedCount       = Self.intOrZero(c, .assignedCount)
        attendedCount       = Self.intOrZero(c, .attendedCount)
        roles               = (try? c.decode([OpportunityRole].self, forKey: .roles)) ?? []
    }

    private static func intOrZero(_ c: KeyedDecodingContainer<CodingKeys>, _ key: CodingKeys) -> Int {
        if let i = try? c.decode(Int.self, forKey: key) { return i }
        if let s = try? c.decode(String.self, forKey: key), let i = Int(s) { return i }
        return 0
    }
}
