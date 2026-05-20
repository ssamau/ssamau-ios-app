import Foundation

/// One row from `interest.listOwn` — the current member's existing
/// interest expressions. Used to pre-mark "✓ Expressed" on opportunity
/// rows in OpportunitiesView so the member sees their state without
/// having to remember what they clicked.
struct InterestRequest: Codable, Identifiable, Equatable {
    let id: Int64
    let projectId: String
    let opportunityId: String?
    let roleId: Int64?
    let interested: Bool
    let comment: String?
    let submittedAt: String?
    let reviewedAt: String?

    enum CodingKeys: String, CodingKey {
        case id, interested, comment
        case projectId     = "project_id"
        case opportunityId = "opportunity_id"
        case roleId        = "role_id"
        case submittedAt   = "submitted_at"
        case reviewedAt    = "reviewed_at"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        // Postgres serial PKs may serialize as String (postgres.js
        // default for BIGINT) or as Int. Accept both for forward-compat.
        if let n = try? c.decode(Int64.self, forKey: .id) {
            id = n
        } else if let s = try? c.decode(String.self, forKey: .id),
                  let n = Int64(s) {
            id = n
        } else {
            id = 0
        }
        projectId     = try c.decode(String.self, forKey: .projectId)
        opportunityId = try c.decodeIfPresent(String.self, forKey: .opportunityId)
        if let n = try? c.decode(Int64.self, forKey: .roleId) {
            roleId = n
        } else if let s = try c.decodeIfPresent(String.self, forKey: .roleId),
                  let n = Int64(s) {
            roleId = n
        } else {
            roleId = nil
        }
        interested  = try c.decodeIfPresent(Bool.self, forKey: .interested) ?? false
        comment     = try c.decodeIfPresent(String.self, forKey: .comment)
        submittedAt = try c.decodeIfPresent(String.self, forKey: .submittedAt)
        reviewedAt  = try c.decodeIfPresent(String.self, forKey: .reviewedAt)
    }
}
