import Foundation

/// One row from `thanks.list`. Includes the joined member + project
/// names, the sender's user/member name, and the denormalised
/// recorded_hours subquery the server computes per row.
struct ThanksRow: Codable, Identifiable, Equatable {
    let id: Int
    let memberId: String?
    let memberFullName: String?
    let memberPreferredName: String?
    let projectId: String?
    let projectName: String?
    let recipientEmail: String?
    let subject: String?
    let message: String?
    let status: String?              // "Pending" | "Sent" | "Failed" | "Logged"
    let sentAt: String?
    let sentByUsername: String?
    let sentByMemberName: String?
    let recordedHours: Double

    var displayRecipient: String {
        memberPreferredName ?? memberFullName ?? recipientEmail ?? "—"
    }

    enum CodingKeys: String, CodingKey {
        case id, subject, message, status
        case memberId            = "member_id"
        case memberFullName      = "full_name"
        case memberPreferredName = "preferred_name"
        case projectId           = "project_id"
        case projectName         = "project_name"
        case recipientEmail      = "recipient_email"
        case sentAt              = "sent_at"
        case sentByUsername      = "sent_by_username"
        case sentByMemberName    = "sent_by_member_name"
        case recordedHours       = "recorded_hours"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        if let i = try? c.decode(Int.self, forKey: .id) {
            id = i
        } else if let s = try? c.decode(String.self, forKey: .id), let i = Int(s) {
            id = i
        } else {
            id = 0
        }
        memberId            = try c.decodeIfPresent(String.self, forKey: .memberId)
        memberFullName      = try c.decodeIfPresent(String.self, forKey: .memberFullName)
        memberPreferredName = try c.decodeIfPresent(String.self, forKey: .memberPreferredName)
        projectId           = try c.decodeIfPresent(String.self, forKey: .projectId)
        projectName         = try c.decodeIfPresent(String.self, forKey: .projectName)
        recipientEmail      = try c.decodeIfPresent(String.self, forKey: .recipientEmail)
        subject             = try c.decodeIfPresent(String.self, forKey: .subject)
        message             = try c.decodeIfPresent(String.self, forKey: .message)
        status              = try c.decodeIfPresent(String.self, forKey: .status)
        sentAt              = try c.decodeIfPresent(String.self, forKey: .sentAt)
        sentByUsername      = try c.decodeIfPresent(String.self, forKey: .sentByUsername)
        sentByMemberName    = try c.decodeIfPresent(String.self, forKey: .sentByMemberName)
        if let d = try? c.decode(Double.self, forKey: .recordedHours) {
            recordedHours = d
        } else if let s = try? c.decode(String.self, forKey: .recordedHours), let d = Double(s) {
            recordedHours = d
        } else {
            recordedHours = 0
        }
    }
}
