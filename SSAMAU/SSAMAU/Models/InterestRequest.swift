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
}
