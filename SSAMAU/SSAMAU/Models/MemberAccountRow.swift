import Foundation

/// One row from `users.list`.
///
/// Two server queries land here:
///   * HEAD path: `FROM members LEFT JOIN users` — every row has a
///     non-null `member_id`; account fields may be null (member has
///     no portal account yet).
///   * ADMIN path: `FROM users LEFT JOIN members` — every row has a
///     non-null account id; `member_id` may be null (the dev account
///     and any system-level account with no linked member).
///
/// To survive both shapes, `memberId` is optional. We synthesise a
/// stable `id` for ForEach from whichever side is present.
struct MemberAccountRow: Codable, Identifiable, Equatable {
    /// Stable identity for ForEach. Prefer the member id (consistent
    /// across both query paths); fall back to the account id when the
    /// row is a member-less admin/dev account. NEVER use a fresh UUID
    /// per call — SwiftUI re-evaluates `id` on every diff, and a
    /// non-stable id breaks scroll position + selection.
    var id: String {
        if let m = memberId { return m }
        if let a = accountId { return "acct-\(a)" }
        // Synthesised on the username when the row truly has no id
        // (vanishingly rare — dev account with no member link AND no
        // numeric account id). Falls through to a fixed sentinel as a
        // last resort; collisions here only happen if there are
        // multiple such rows, which is impossible per the DB schema.
        return "row-\(username ?? "unknown")"
    }

    let accountId: Int?              // users.id — nil if no account
    let username: String?
    let accessLevel: String?
    let authUserId: String?           // nil if account exists but signup not completed
    let createdAt: String?
    let lastLoginAt: String?
    let authEmail: String?
    let memberId: String?             // nil for admin-path rows w/ no linked member
    let memberFullName: String?
    let memberPreferredName: String?
    let memberCommitteeId: String?
    let memberCommitteeName: String?
    let memberClubRole: String?

    var displayName: String {
        memberPreferredName
            ?? memberFullName
            ?? username
            ?? memberId
            ?? "—"
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
        memberId             = try c.decodeIfPresent(String.self, forKey: .memberId)
        memberFullName       = try c.decodeIfPresent(String.self, forKey: .memberFullName)
        memberPreferredName  = try c.decodeIfPresent(String.self, forKey: .memberPreferredName)
        memberCommitteeId    = try c.decodeIfPresent(String.self, forKey: .memberCommitteeId)
        memberCommitteeName  = try c.decodeIfPresent(String.self, forKey: .memberCommitteeName)
        memberClubRole       = try c.decodeIfPresent(String.self, forKey: .memberClubRole)
    }
}
