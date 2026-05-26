import Foundation

/// One row from `assignments.list` — heads/admin variant of
/// `assignments.listOwn`. Mirrors columns + the joined opportunity,
/// project, member, and (for multi-role) the specific role name.
struct AssignmentRow: Codable, Identifiable, Equatable {
    let id: String                       // assignment_id (ASG_…)
    let opportunityId: String
    let roleId: Int64?
    let memberId: String?
    let volunteerName: String?
    let volunteerEmail: String?
    let attendanceStatus: String?        // "Pending" | "Attended" | "Absent" | "Excused"
    let attendanceNotes: String?
    let projectName: String?
    let eventDate: String?
    let roleName: String?                // legacy single-role mirror
    let assignedRoleName: String?        // multi-role: opportunity_roles.role_name
    let memberFullName: String?
    let memberPreferredName: String?
    let memberEmail: String?

    var displayName: String {
        memberPreferredName ?? memberFullName ?? volunteerName ?? memberId ?? id
    }

    enum CodingKeys: String, CodingKey {
        case id                  = "assignment_id"
        case opportunityId       = "opportunity_id"
        case roleId              = "role_id"
        case memberId            = "member_id"
        case volunteerName       = "volunteer_name"
        case volunteerEmail      = "volunteer_email"
        case attendanceStatus    = "attendance_status"
        case attendanceNotes     = "attendance_notes"
        case projectName         = "project_name"
        case eventDate           = "event_date"
        case roleName            = "role_name"
        case assignedRoleName    = "assigned_role_name"
        case memberFullName      = "member_full_name"
        case memberPreferredName = "member_preferred_name"
        case memberEmail         = "member_email"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id            = try c.decode(String.self, forKey: .id)
        opportunityId = try c.decode(String.self, forKey: .opportunityId)
        if let n = try? c.decode(Int64.self, forKey: .roleId) {
            roleId = n
        } else if let s = try c.decodeIfPresent(String.self, forKey: .roleId), let n = Int64(s) {
            roleId = n
        } else {
            roleId = nil
        }
        memberId            = try c.decodeIfPresent(String.self, forKey: .memberId)
        volunteerName       = try c.decodeIfPresent(String.self, forKey: .volunteerName)
        volunteerEmail      = try c.decodeIfPresent(String.self, forKey: .volunteerEmail)
        attendanceStatus    = try c.decodeIfPresent(String.self, forKey: .attendanceStatus)
        attendanceNotes     = try c.decodeIfPresent(String.self, forKey: .attendanceNotes)
        projectName         = try c.decodeIfPresent(String.self, forKey: .projectName)
        eventDate           = try c.decodeIfPresent(String.self, forKey: .eventDate)
        roleName            = try c.decodeIfPresent(String.self, forKey: .roleName)
        assignedRoleName    = try c.decodeIfPresent(String.self, forKey: .assignedRoleName)
        memberFullName      = try c.decodeIfPresent(String.self, forKey: .memberFullName)
        memberPreferredName = try c.decodeIfPresent(String.self, forKey: .memberPreferredName)
        memberEmail         = try c.decodeIfPresent(String.self, forKey: .memberEmail)
    }
}
