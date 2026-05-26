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

/// Permissive decode target for action responses where we don't need to
/// read fields back. Accepts any valid JSON shape (object, array, scalar,
/// null) and succeeds without parsing the contents. Use this when the
/// action returns acks like `{ ok: true }` or `{ id, status }` and we
/// just need the call to succeed without coupling to the exact shape.
struct AnyJSON: Decodable {
    init(from decoder: Decoder) throws {
        // Try each container kind in turn. Any one of them succeeding
        // (with at least a successful nil-check) means the JSON is
        // valid; we throw nothing away because we never expose the bytes.
        if let c = try? decoder.singleValueContainer() {
            _ = c.decodeNil()
            return
        }
        // Defensive — every JSON value is decodable as a singleValueContainer,
        // so this branch shouldn't fire. Kept for safety.
        _ = try decoder.container(keyedBy: AnyKey.self)
    }
    private struct AnyKey: CodingKey {
        var stringValue: String; var intValue: Int?
        init?(stringValue: String) { self.stringValue = stringValue; self.intValue = nil }
        init?(intValue: Int) { self.intValue = intValue; self.stringValue = String(intValue) }
    }
}
