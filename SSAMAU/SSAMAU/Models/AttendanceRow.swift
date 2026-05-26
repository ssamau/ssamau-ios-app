import Foundation

/// One row from `head.attendance.list` (also reused for the admin
/// attendance list). Carries both project-linked and meeting-linked
/// fields — the row is one or the other depending on what was recorded.
struct AttendanceRow: Codable, Identifiable, Equatable {
    let id: Int                  // attendance_id
    let projectId: String?
    let projectName: String?
    let projectEventDate: String?
    let memberId: String?
    let memberFullName: String?
    let memberPreferredName: String?
    let memberCommitteeId: String?
    let volunteerName: String?
    let volunteerEmail: String?
    let attendanceStatus: String?
    let notes: String?
    let meetingTitle: String?
    let meetingType: String?
    let meetingDate: String?
    let meetingStartTime: String?
    let meetingLocation: String?
    let meetingHours: Double?
    let recordedAt: String?
    let recordedBy: Int?

    var displayName: String {
        memberPreferredName ?? memberFullName ?? volunteerName ?? "—"
    }
    var isMeeting: Bool { meetingTitle != nil && !(meetingTitle?.isEmpty ?? true) }

    enum CodingKeys: String, CodingKey {
        case id = "attendance_id"
        case projectId           = "project_id"
        case projectName         = "project_name"
        case projectEventDate    = "project_event_date"
        case memberId            = "member_id"
        case memberFullName      = "member_full_name"
        case memberPreferredName = "member_preferred_name"
        case memberCommitteeId   = "member_committee_id"
        case volunteerName       = "volunteer_name"
        case volunteerEmail      = "volunteer_email"
        case attendanceStatus    = "attendance_status"
        case notes
        case meetingTitle        = "meeting_title"
        case meetingType         = "meeting_type"
        case meetingDate         = "meeting_date"
        case meetingStartTime    = "meeting_start_time"
        case meetingLocation     = "meeting_location"
        case meetingHours        = "meeting_hours"
        case recordedAt          = "recorded_at"
        case recordedBy          = "recorded_by"
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
        projectId           = try c.decodeIfPresent(String.self, forKey: .projectId)
        projectName         = try c.decodeIfPresent(String.self, forKey: .projectName)
        projectEventDate    = try c.decodeIfPresent(String.self, forKey: .projectEventDate)
        memberId            = try c.decodeIfPresent(String.self, forKey: .memberId)
        memberFullName      = try c.decodeIfPresent(String.self, forKey: .memberFullName)
        memberPreferredName = try c.decodeIfPresent(String.self, forKey: .memberPreferredName)
        memberCommitteeId   = try c.decodeIfPresent(String.self, forKey: .memberCommitteeId)
        volunteerName       = try c.decodeIfPresent(String.self, forKey: .volunteerName)
        volunteerEmail      = try c.decodeIfPresent(String.self, forKey: .volunteerEmail)
        attendanceStatus    = try c.decodeIfPresent(String.self, forKey: .attendanceStatus)
        notes               = try c.decodeIfPresent(String.self, forKey: .notes)
        meetingTitle        = try c.decodeIfPresent(String.self, forKey: .meetingTitle)
        meetingType         = try c.decodeIfPresent(String.self, forKey: .meetingType)
        meetingDate         = try c.decodeIfPresent(String.self, forKey: .meetingDate)
        meetingStartTime    = try c.decodeIfPresent(String.self, forKey: .meetingStartTime)
        meetingLocation     = try c.decodeIfPresent(String.self, forKey: .meetingLocation)
        if let d = try? c.decode(Double.self, forKey: .meetingHours) {
            meetingHours = d
        } else if let s = try? c.decode(String.self, forKey: .meetingHours), let d = Double(s) {
            meetingHours = d
        } else {
            meetingHours = nil
        }
        recordedAt = try c.decodeIfPresent(String.self, forKey: .recordedAt)
        if let i = try? c.decode(Int.self, forKey: .recordedBy) {
            recordedBy = i
        } else if let s = try? c.decode(String.self, forKey: .recordedBy), let i = Int(s) {
            recordedBy = i
        } else {
            recordedBy = nil
        }
    }
}
