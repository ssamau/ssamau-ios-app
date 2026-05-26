import Foundation

/// One row from `support.list` (superadmin only).
struct SupportTicket: Codable, Identifiable, Equatable {
    let id: Int
    let ticketId: String
    let reporterName: String?
    let reporterEmail: String?
    let reporterAccess: String?
    let category: String?
    let title: String
    let description: String?
    let reproSteps: String?
    let pageUrl: String?
    let userAgent: String?
    let viewport: String?
    let attachmentPath: String?
    let status: String?
    let resolutionNote: String?
    let createdAt: String?
    let resolvedAt: String?

    enum CodingKeys: String, CodingKey {
        case id, category, title, description, status, viewport
        case ticketId          = "ticket_id"
        case reporterName      = "reporter_name"
        case reporterEmail     = "reporter_email"
        case reporterAccess    = "reporter_access"
        case reproSteps        = "repro_steps"
        case pageUrl           = "page_url"
        case userAgent         = "user_agent"
        case attachmentPath    = "attachment_path"
        case resolutionNote    = "resolution_note"
        case createdAt         = "created_at"
        case resolvedAt        = "resolved_at"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        if let i = try? c.decode(Int.self, forKey: .id) { id = i }
        else if let s = try? c.decode(String.self, forKey: .id), let i = Int(s) { id = i }
        else { id = 0 }
        ticketId       = try c.decode(String.self, forKey: .ticketId)
        reporterName   = try c.decodeIfPresent(String.self, forKey: .reporterName)
        reporterEmail  = try c.decodeIfPresent(String.self, forKey: .reporterEmail)
        reporterAccess = try c.decodeIfPresent(String.self, forKey: .reporterAccess)
        category       = try c.decodeIfPresent(String.self, forKey: .category)
        title          = try c.decodeIfPresent(String.self, forKey: .title) ?? "—"
        description    = try c.decodeIfPresent(String.self, forKey: .description)
        reproSteps     = try c.decodeIfPresent(String.self, forKey: .reproSteps)
        pageUrl        = try c.decodeIfPresent(String.self, forKey: .pageUrl)
        userAgent      = try c.decodeIfPresent(String.self, forKey: .userAgent)
        viewport       = try c.decodeIfPresent(String.self, forKey: .viewport)
        attachmentPath = try c.decodeIfPresent(String.self, forKey: .attachmentPath)
        status         = try c.decodeIfPresent(String.self, forKey: .status)
        resolutionNote = try c.decodeIfPresent(String.self, forKey: .resolutionNote)
        createdAt      = try c.decodeIfPresent(String.self, forKey: .createdAt)
        resolvedAt     = try c.decodeIfPresent(String.self, forKey: .resolvedAt)
    }
}
