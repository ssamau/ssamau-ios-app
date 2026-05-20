import Foundation

/// One row from `certs.list`. The cert record + joined member name +
/// project name. Spec §8.8.
struct Certificate: Codable, Identifiable, Equatable {
    let id: Int                    // certificates.id (SERIAL)
    let certCode: String           // unique short code used for verify URL
    let memberId: String?
    let projectId: String?
    let recipientName: String?
    let recipientEmail: String?
    let role: String?
    let hours: Double?
    let issuedAt: String?          // ISO timestamp
    let memberFullName: String?
    let memberPreferredName: String?
    let projectName: String?

    var displayRecipient: String {
        memberPreferredName ?? memberFullName ?? recipientName ?? "—"
    }
    var displayProject: String { projectName ?? "—" }

    /// Public verification URL — what the share sheet sends out.
    var verifyURL: URL? {
        URL(string: "https://ssamau.com/verify-cert.html?code=\(certCode)")
    }

    enum CodingKeys: String, CodingKey {
        case id, role, hours
        case certCode             = "cert_code"
        case memberId             = "member_id"
        case projectId            = "project_id"
        case recipientName        = "recipient_name"
        case recipientEmail       = "recipient_email"
        case issuedAt             = "issued_at"
        case memberFullName       = "member_full_name"
        case memberPreferredName  = "member_preferred_name"
        case projectName          = "project_name"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        if let n = try? c.decode(Int.self, forKey: .id) {
            id = n
        } else if let s = try? c.decode(String.self, forKey: .id), let n = Int(s) {
            id = n
        } else {
            id = 0
        }
        certCode             = try c.decode(String.self, forKey: .certCode)
        memberId             = try c.decodeIfPresent(String.self, forKey: .memberId)
        projectId            = try c.decodeIfPresent(String.self, forKey: .projectId)
        recipientName        = try c.decodeIfPresent(String.self, forKey: .recipientName)
        recipientEmail       = try c.decodeIfPresent(String.self, forKey: .recipientEmail)
        role                 = try c.decodeIfPresent(String.self, forKey: .role)
        if let d = try? c.decode(Double.self, forKey: .hours) {
            hours = d
        } else if let s = try? c.decode(String.self, forKey: .hours), let d = Double(s) {
            hours = d
        } else {
            hours = nil
        }
        issuedAt             = try c.decodeIfPresent(String.self, forKey: .issuedAt)
        memberFullName       = try c.decodeIfPresent(String.self, forKey: .memberFullName)
        memberPreferredName  = try c.decodeIfPresent(String.self, forKey: .memberPreferredName)
        projectName          = try c.decodeIfPresent(String.self, forKey: .projectName)
    }
}
