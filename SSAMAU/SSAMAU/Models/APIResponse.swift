import Foundation

/// Wire envelope for every Supabase Edge Function response.
/// See spec §5 and `_helpers.ts` in the web repo.
struct APIEnvelope<T: Decodable>: Decodable {
    let success: Bool
    let data: T?
    let error: String?
    let errorParams: [String: String]?
}

/// Sentinel for actions whose `data` we don't care about (e.g. signOut).
struct EmptyResponse: Decodable {}
