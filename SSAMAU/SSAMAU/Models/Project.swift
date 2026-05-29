import Foundation

/// One row from `getProjects`. Mirrors the projects table + denormalised
/// participant_count subquery. Used by HeadProjectsView, AttendanceView,
/// ThanksView, HeadCertsView, AdminDashboard.
struct Project: Codable, Identifiable, Equatable {
    let id: String                       // project_id (PRJ_…)
    let name: String
    let projectType: String?             // "Event" | "Initiative" | etc.
    let description: String?
    let eventDate: String?               // YYYY-MM-DD
    let startTime: String?               // HH:MM:SS
    let endTime: String?
    let location: String?
    let owningCommitteeId: String?
    let projectStatus: String?           // "Planned" | "Active" | "Completed" | "Cancelled" (canonical; legacy rows may still read "Done")
    let notes: String?
    let participantCount: Int

    enum CodingKeys: String, CodingKey {
        case id                = "project_id"
        case name              = "project_name"
        case projectType       = "project_type"
        case description       = "project_description"
        case eventDate         = "event_date"
        case startTime         = "start_time"
        case endTime           = "end_time"
        case location
        case owningCommitteeId = "owning_committee_id"
        case projectStatus     = "project_status"
        case notes
        case participantCount  = "participant_count"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id                = try c.decode(String.self, forKey: .id)
        name              = try c.decodeIfPresent(String.self, forKey: .name) ?? id
        projectType       = try c.decodeIfPresent(String.self, forKey: .projectType)
        description       = try c.decodeIfPresent(String.self, forKey: .description)
        eventDate         = try c.decodeIfPresent(String.self, forKey: .eventDate)
        startTime         = try c.decodeIfPresent(String.self, forKey: .startTime)
        endTime           = try c.decodeIfPresent(String.self, forKey: .endTime)
        location          = try c.decodeIfPresent(String.self, forKey: .location)
        owningCommitteeId = try c.decodeIfPresent(String.self, forKey: .owningCommitteeId)
        projectStatus     = try c.decodeIfPresent(String.self, forKey: .projectStatus)
        notes             = try c.decodeIfPresent(String.self, forKey: .notes)
        if let i = try? c.decode(Int.self, forKey: .participantCount) {
            participantCount = i
        } else if let s = try? c.decode(String.self, forKey: .participantCount), let i = Int(s) {
            participantCount = i
        } else {
            participantCount = 0
        }
    }
}
