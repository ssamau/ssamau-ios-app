import Foundation

/// Response shape for `getDashboardStats` — admin landing page.
struct DashboardStats: Decodable {
    let stats: Counts
    let topVolunteers: [TopVolunteer]
    let committeeHours: [CommitteeHours]
    let recentProjects: [RecentProject]

    enum CodingKeys: String, CodingKey {
        case stats
        case topVolunteers  = "top_volunteers"
        case committeeHours = "committee_hours"
        case recentProjects = "recent_projects"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        stats          = (try? c.decode(Counts.self, forKey: .stats)) ?? Counts.empty
        topVolunteers  = (try? c.decode([TopVolunteer].self, forKey: .topVolunteers)) ?? []
        committeeHours = (try? c.decode([CommitteeHours].self, forKey: .committeeHours)) ?? []
        recentProjects = (try? c.decode([RecentProject].self, forKey: .recentProjects)) ?? []
    }

    struct Counts: Decodable {
        let activeMembers: Int
        let totalMembers: Int
        let totalProjects: Int
        let totalHours: Double
        let totalCommittees: Int

        static let empty = Counts(
            activeMembers: 0, totalMembers: 0, totalProjects: 0,
            totalHours: 0, totalCommittees: 0
        )

        enum CodingKeys: String, CodingKey {
            case activeMembers    = "active_members"
            case totalMembers     = "total_members"
            case totalProjects    = "total_projects"
            case totalHours       = "total_hours"
            case totalCommittees  = "total_committees"
        }
        init(activeMembers: Int, totalMembers: Int, totalProjects: Int,
             totalHours: Double, totalCommittees: Int) {
            self.activeMembers = activeMembers
            self.totalMembers = totalMembers
            self.totalProjects = totalProjects
            self.totalHours = totalHours
            self.totalCommittees = totalCommittees
        }
        init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            activeMembers   = Self.intOrZero(c, .activeMembers)
            totalMembers    = Self.intOrZero(c, .totalMembers)
            totalProjects   = Self.intOrZero(c, .totalProjects)
            totalCommittees = Self.intOrZero(c, .totalCommittees)
            if let d = try? c.decode(Double.self, forKey: .totalHours) {
                totalHours = d
            } else if let s = try? c.decode(String.self, forKey: .totalHours), let d = Double(s) {
                totalHours = d
            } else { totalHours = 0 }
        }
        private static func intOrZero(_ c: KeyedDecodingContainer<CodingKeys>, _ k: CodingKeys) -> Int {
            if let i = try? c.decode(Int.self, forKey: k) { return i }
            if let s = try? c.decode(String.self, forKey: k), let i = Int(s) { return i }
            return 0
        }
    }

    struct TopVolunteer: Decodable, Identifiable {
        let memberId: String
        let name: String
        let hours: Double
        var id: String { memberId }
        enum CodingKeys: String, CodingKey {
            case memberId = "member_id"
            case name, hours
        }
        init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            memberId = try c.decodeIfPresent(String.self, forKey: .memberId) ?? UUID().uuidString
            name     = try c.decodeIfPresent(String.self, forKey: .name) ?? memberId
            if let d = try? c.decode(Double.self, forKey: .hours) {
                hours = d
            } else if let s = try? c.decode(String.self, forKey: .hours), let d = Double(s) {
                hours = d
            } else { hours = 0 }
        }
    }

    struct CommitteeHours: Decodable, Identifiable {
        let committeeId: String
        let committeeName: String
        let hours: Double
        var id: String { committeeId }
        enum CodingKeys: String, CodingKey {
            case committeeId   = "committee_id"
            case committeeName = "committee_name"
            case hours
        }
        init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            committeeId   = try c.decodeIfPresent(String.self, forKey: .committeeId) ?? UUID().uuidString
            committeeName = try c.decodeIfPresent(String.self, forKey: .committeeName) ?? committeeId
            if let d = try? c.decode(Double.self, forKey: .hours) {
                hours = d
            } else if let s = try? c.decode(String.self, forKey: .hours), let d = Double(s) {
                hours = d
            } else { hours = 0 }
        }
    }

    struct RecentProject: Decodable, Identifiable {
        let projectId: String
        let projectName: String
        let projectType: String?
        let eventDate: String?
        let projectStatus: String?
        var id: String { projectId }
        enum CodingKeys: String, CodingKey {
            case projectId    = "project_id"
            case projectName  = "project_name"
            case projectType  = "project_type"
            case eventDate    = "event_date"
            case projectStatus = "project_status"
        }
        init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            projectId     = try c.decode(String.self, forKey: .projectId)
            projectName   = try c.decodeIfPresent(String.self, forKey: .projectName) ?? projectId
            projectType   = try c.decodeIfPresent(String.self, forKey: .projectType)
            eventDate     = try c.decodeIfPresent(String.self, forKey: .eventDate)
            projectStatus = try c.decodeIfPresent(String.self, forKey: .projectStatus)
        }
    }
}
