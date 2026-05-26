import Foundation

/// Admin/head view of an interest_requests row. Returned by
/// `interest.list` (per-project) and `interest.listAll` (cross-project).
/// Includes the joined member name + the SPECIFIC role the member
/// picked (NULL = "any role"). Used by HeadOpportunitiesView's assign
/// sheet to populate the candidate list per role.
struct InterestRow: Codable, Identifiable, Equatable {
    let id: Int64
    let projectId: String
    let projectName: String?
    let opportunityId: String?
    let opportunityRoleName: String?     // legacy single-role mirror
    let roleId: Int64?
    let pickedRoleName: String?          // multi-role: the role the member picked
    let memberId: String
    let memberFullName: String?
    let memberPreferredName: String?
    let memberEmail: String?
    let memberCommitteeId: String?
    let memberCommitteeName: String?
    let interested: Bool
    let comment: String?
    let submittedAt: String?
    let reviewedAt: String?

    var displayName: String {
        memberPreferredName ?? memberFullName ?? memberId
    }
    var isAnyRole: Bool { roleId == nil }

    enum CodingKeys: String, CodingKey {
        case id, interested, comment
        case projectId           = "project_id"
        case projectName         = "project_name"
        case opportunityId       = "opportunity_id"
        case opportunityRoleName = "opportunity_role_name"
        case roleId              = "role_id"
        case pickedRoleName      = "picked_role_name"
        case memberId            = "member_id"
        case memberFullName      = "full_name"
        case memberPreferredName = "preferred_name"
        case memberEmail         = "email"
        case memberCommitteeId   = "member_committee_id"
        case memberCommitteeName = "member_committee_name"
        case submittedAt         = "submitted_at"
        case reviewedAt          = "reviewed_at"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        if let n = try? c.decode(Int64.self, forKey: .id) {
            id = n
        } else if let s = try? c.decode(String.self, forKey: .id), let n = Int64(s) {
            id = n
        } else {
            id = 0
        }
        projectId           = try c.decode(String.self, forKey: .projectId)
        projectName         = try c.decodeIfPresent(String.self, forKey: .projectName)
        opportunityId       = try c.decodeIfPresent(String.self, forKey: .opportunityId)
        opportunityRoleName = try c.decodeIfPresent(String.self, forKey: .opportunityRoleName)
        if let n = try? c.decode(Int64.self, forKey: .roleId) {
            roleId = n
        } else if let s = try c.decodeIfPresent(String.self, forKey: .roleId), let n = Int64(s) {
            roleId = n
        } else {
            roleId = nil
        }
        pickedRoleName      = try c.decodeIfPresent(String.self, forKey: .pickedRoleName)
        memberId            = try c.decode(String.self, forKey: .memberId)
        memberFullName      = try c.decodeIfPresent(String.self, forKey: .memberFullName)
        memberPreferredName = try c.decodeIfPresent(String.self, forKey: .memberPreferredName)
        memberEmail         = try c.decodeIfPresent(String.self, forKey: .memberEmail)
        memberCommitteeId   = try c.decodeIfPresent(String.self, forKey: .memberCommitteeId)
        memberCommitteeName = try c.decodeIfPresent(String.self, forKey: .memberCommitteeName)
        interested          = try c.decodeIfPresent(Bool.self, forKey: .interested) ?? false
        comment             = try c.decodeIfPresent(String.self, forKey: .comment)
        submittedAt         = try c.decodeIfPresent(String.self, forKey: .submittedAt)
        reviewedAt          = try c.decodeIfPresent(String.self, forKey: .reviewedAt)
    }
}
