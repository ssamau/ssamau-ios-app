import Foundation

/// One row from `getAdvisors`. SERIAL id; total_hours added by Phase D.
struct Advisor: Codable, Identifiable, Equatable {
    let id: Int
    let fullName: String
    let advisoryRole: String?
    let email: String?
    let phone: String?
    let notes: String?
    let status: String?
    let totalHours: Double

    enum CodingKeys: String, CodingKey {
        case id
        case fullName     = "full_name"
        case advisoryRole = "advisory_role"
        case email, phone, notes, status
        case totalHours   = "total_hours"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        if let i = try? c.decode(Int.self, forKey: .id) {
            id = i
        } else if let s = try? c.decode(String.self, forKey: .id), let i = Int(s) {
            id = i
        } else { id = 0 }
        fullName     = try c.decodeIfPresent(String.self, forKey: .fullName) ?? "—"
        advisoryRole = try c.decodeIfPresent(String.self, forKey: .advisoryRole)
        email        = try c.decodeIfPresent(String.self, forKey: .email)
        phone        = try c.decodeIfPresent(String.self, forKey: .phone)
        notes        = try c.decodeIfPresent(String.self, forKey: .notes)
        status       = try c.decodeIfPresent(String.self, forKey: .status)
        if let d = try? c.decode(Double.self, forKey: .totalHours) {
            totalHours = d
        } else if let s = try? c.decode(String.self, forKey: .totalHours), let d = Double(s) {
            totalHours = d
        } else { totalHours = 0 }
    }
}
