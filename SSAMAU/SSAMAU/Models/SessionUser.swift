import Foundation

/// The authenticated user. Returned by `auth` / `auth.exchangeSupabaseToken`
/// and cached in `SessionStore`. Mirrors the `user` object the web app
/// stores in its session cookie payload.
struct SessionUser: Codable, Identifiable, Equatable {
    let id: Int
    let username: String
    let name: String
    let role: String
    let access: String
    let memberId: String?
    let committeeId: String?
    let email: String?

    var isMember: Bool { access == "member" || access == "volunteer" }
    var isHead: Bool { access == "head" }
    var isAdmin: Bool { access == "admin" }
    var isSuperadmin: Bool { access == "superadmin" }
    var hasAdminScope: Bool { isAdmin || isSuperadmin }

    enum CodingKeys: String, CodingKey {
        case id, username, name, role, access, email
        case memberId = "member_id"
        case committeeId = "committee_id"
    }
}
