import Foundation

/// Response from `auth.resolveIdentifier`. The server returns
/// `{ found: false }` for unknown identifiers (no enumeration leak)
/// and `{ found: true, auth_provider, email?, username? }` for known ones.
struct ResolveIdentifierResponse: Decodable {
    let found: Bool
    let authProvider: AuthProvider?
    let email: String?
    let username: String?

    enum CodingKeys: String, CodingKey {
        case found
        case authProvider = "auth_provider"
        case email
        case username
    }
}

enum AuthProvider: String, Decodable {
    case supabase
    case legacy
}

/// Common shape for `auth` (legacy) and `auth.exchangeSupabaseToken`
/// after the 2026-05-21 web fix.
struct AuthResponse: Decodable {
    let token: String
    let user: SessionUser
}

/// Response from Supabase Auth REST endpoint
/// `/auth/v1/token?grant_type=password`. We only consume `access_token`.
struct SupabaseTokenResponse: Decodable {
    let accessToken: String

    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
    }
}
