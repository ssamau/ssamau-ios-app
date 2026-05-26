import Foundation

/// One row from `users.list`. Pivots around the MEMBER (not the
/// account) — `id` (account id) and `username` are nullable: members
/// without an account have no users row. Used by HeadMembersView and
/// AdminMembersView (admin variant returns the same shape, broader scope).
struct MemberAccountRow: Codable, Identifiable, Equatable {
    /// Stable identity for ForEach: members.member_id, always present.
    var id: String { memberId }

    let accountId: Int?              // users.id — nil if no account
    let username: String?
    let accessLevel: String?
    let authUserId: String?           // nil if account exists but signup not completed
    let createdAt: String?
    let lastLoginAt: String?
    let authEmail: String?
    let memberId: String
    let memberFullName: String?
    let memberPreferredName: String?
    let memberCommitteeId: String?
    let memberCommitteeName: String?
    let memberClubRole: String?

    var displayName: String {
        memberPreferredName ?? memberFullName ?? memberId
    }

    /// Three account states:
    enum State {
        case noAccount          // accountId == nil
        case pendingInvite      // accountId != nil, authUserId == nil
        case active             // accountId != nil, authUserId != nil
    }
    var state: State {
        if accountId == nil { return .noAccount }
        if authUserId == nil { return .pendingInvite }
        return .active
    }

    enum CodingKeys: String, CodingKey {
        case username
        case accountId           = "id"
        case accessLevel         = "access_level"
        case authUserId          = "auth_user_id"
        case createdAt           = "created_at"
        case lastLoginAt         = "last_login_at"
        case authEmail           = "auth_email"
        case memberId            = "member_id"
        case memberFullName      = "member_full_name"
        case memberPreferredName = "member_preferred_name"
        case memberCommitteeId   = "member_committee_id"
        case memberCommitteeName = "member_committee_name"
        case memberClubRole      = "member_club_role"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        if let i = try? c.decode(Int.self, forKey: .accountId) {
            accountId = i
        } else if let s = try? c.decode(String.self, forKey: .accountId), let i = Int(s) {
            accountId = i
        } else {
            accountId = nil
        }
        username             = try c.decodeIfPresent(String.self, forKey: .username)
        accessLevel          = try c.decodeIfPresent(String.self, forKey: .accessLevel)
        authUserId           = try c.decodeIfPresent(String.self, forKey: .authUserId)
        createdAt            = try c.decodeIfPresent(String.self, forKey: .createdAt)
        lastLoginAt          = try c.decodeIfPresent(String.self, forKey: .lastLoginAt)
        authEmail            = try c.decodeIfPresent(String.self, forKey: .authEmail)
        memberId             = try c.decode(String.self, forKey: .memberId)
        memberFullName       = try c.decodeIfPresent(String.self, forKey: .memberFullName)
        memberPreferredName  = try c.decodeIfPresent(String.self, forKey: .memberPreferredName)
        memberCommitteeId    = try c.decodeIfPresent(String.self, forKey: .memberCommitteeId)
        memberCommitteeName  = try c.decodeIfPresent(String.self, forKey: .memberCommitteeName)
        memberClubRole       = try c.decodeIfPresent(String.self, forKey: .memberClubRole)
    }
}
