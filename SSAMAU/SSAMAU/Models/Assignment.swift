import Foundation

/// One row from `assignments.listOwn`. The assignment itself + joined
/// opportunity / project / committee context the row needs to render.
struct Assignment: Codable, Identifiable, Equatable {
    let id: String                          // assignment_id (UUID-ish string)
    let memberId: String?
    let opportunityId: String
    let roleId: Int64?
    let attendanceStatus: String?           // "Pending" | "Attended" | "Absent" | "Excused"
    let hoursLogged: Double?
    let volunteerName: String?
    let volunteerEmail: String?
    let createdAt: String?

    // Joined from opportunities
    let roleName: String?
    let roleKey: String?
    let estimatedHours: Double?
    let projectId: String?
    let owningCommitteeId: String?

    // Joined from projects
    let projectName: String?
    let projectType: String?
    let eventDate: String?                  // ISO timestamp / date
    let startTime: String?
    let endTime: String?
    let location: String?

    // Joined from committees
    let committeeName: String?

    var displayRole: String { roleName ?? "—" }
    var displayProject: String { projectName ?? "—" }

    enum CodingKeys: String, CodingKey {
        case id                = "assignment_id"
        case memberId          = "member_id"
        case opportunityId     = "opportunity_id"
        case roleId            = "role_id"
        case attendanceStatus  = "attendance_status"
        case hoursLogged       = "hours_logged"
        case volunteerName     = "volunteer_name"
        case volunteerEmail    = "volunteer_email"
        case createdAt         = "created_at"
        case roleName          = "role_name"
        case roleKey           = "role_key"
        case estimatedHours    = "estimated_hours"
        case projectId         = "project_id"
        case owningCommitteeId = "owning_committee_id"
        case projectName       = "project_name"
        case projectType       = "project_type"
        case eventDate         = "event_date"
        case startTime         = "start_time"
        case endTime           = "end_time"
        case location
        case committeeName     = "committee_name"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        // assignment_id is a SERIAL int on the server, not a UUID — comes
        // back as `23` not `"23"`. Accept either form and store as String
        // so downstream comparisons (HoursRow.assignmentId, set membership
        // in HoursViewModel.loggableAssignments) stay consistent.
        if let n = try? c.decode(Int.self, forKey: .id) {
            id = String(n)
        } else if let s = try? c.decode(String.self, forKey: .id) {
            id = s
        } else {
            id = ""
        }
        memberId          = try c.decodeIfPresent(String.self, forKey: .memberId)
        opportunityId     = try c.decode(String.self, forKey: .opportunityId)
        if let n = try? c.decode(Int64.self, forKey: .roleId) {
            roleId = n
        } else if let s = try c.decodeIfPresent(String.self, forKey: .roleId),
                  let n = Int64(s) {
            roleId = n
        } else {
            roleId = nil
        }
        attendanceStatus  = try c.decodeIfPresent(String.self, forKey: .attendanceStatus)
        hoursLogged       = Self.doubleOrNil(c, .hoursLogged)
        volunteerName     = try c.decodeIfPresent(String.self, forKey: .volunteerName)
        volunteerEmail    = try c.decodeIfPresent(String.self, forKey: .volunteerEmail)
        createdAt         = try c.decodeIfPresent(String.self, forKey: .createdAt)
        roleName          = try c.decodeIfPresent(String.self, forKey: .roleName)
        roleKey           = try c.decodeIfPresent(String.self, forKey: .roleKey)
        estimatedHours    = Self.doubleOrNil(c, .estimatedHours)
        projectId         = try c.decodeIfPresent(String.self, forKey: .projectId)
        owningCommitteeId = try c.decodeIfPresent(String.self, forKey: .owningCommitteeId)
        projectName       = try c.decodeIfPresent(String.self, forKey: .projectName)
        projectType       = try c.decodeIfPresent(String.self, forKey: .projectType)
        eventDate         = try c.decodeIfPresent(String.self, forKey: .eventDate)
        startTime         = try c.decodeIfPresent(String.self, forKey: .startTime)
        endTime           = try c.decodeIfPresent(String.self, forKey: .endTime)
        location          = try c.decodeIfPresent(String.self, forKey: .location)
        committeeName     = try c.decodeIfPresent(String.self, forKey: .committeeName)
    }

    /// Postgres NUMERIC can serialize as String or Double — accept both.
    private static func doubleOrNil(_ c: KeyedDecodingContainer<CodingKeys>, _ key: CodingKeys) -> Double? {
        if let d = try? c.decode(Double.self, forKey: key) { return d }
        if let s = try? c.decode(String.self, forKey: key), let d = Double(s) { return d }
        return nil
    }
}
