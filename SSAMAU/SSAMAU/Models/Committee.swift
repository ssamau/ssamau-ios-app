import Foundation

/// One row from `getCommittees`. Lightweight — used by pickers and
/// admin views. Member count is denormalised in the SQL view.
struct Committee: Codable, Identifiable, Equatable {
    let id: String                        // committee_id (COM_XXXX)
    let name: String
    let description: String?
    let status: String?                   // "Active" | "Inactive"
    let headMemberId: String?
    let viceHeadMemberId: String?
    let memberCount: Int

    enum CodingKeys: String, CodingKey {
        case id              = "committee_id"
        case name            = "committee_name"
        case description     = "committee_description"
        case status
        case headMemberId    = "committee_head_member_id"
        case viceHeadMemberId = "committee_vice_head_member_id"
        case memberCount     = "member_count"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id              = try c.decode(String.self, forKey: .id)
        name            = try c.decode(String.self, forKey: .name)
        description     = try c.decodeIfPresent(String.self, forKey: .description)
        status          = try c.decodeIfPresent(String.self, forKey: .status)
        headMemberId    = try c.decodeIfPresent(String.self, forKey: .headMemberId)
        viceHeadMemberId = try c.decodeIfPresent(String.self, forKey: .viceHeadMemberId)
        // Postgres BIGINT COUNT — accept Int or String.
        if let i = try? c.decode(Int.self, forKey: .memberCount) {
            memberCount = i
        } else if let s = try? c.decode(String.self, forKey: .memberCount), let i = Int(s) {
            memberCount = i
        } else {
            memberCount = 0
        }
    }
}
