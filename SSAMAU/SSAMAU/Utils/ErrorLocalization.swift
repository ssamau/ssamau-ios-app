import Foundation

/// Maps server `err.*` codes (plus optional `errorParams` interpolation)
/// to human-readable, localized messages. See spec §14.
enum ErrorLocalization {
    static func localize(_ code: String, params: [String: String]? = nil) -> String {
        var msg = NSLocalizedString(code, comment: "")
        // NSLocalizedString returns the key itself when no match — fall back to err.unknown.
        if msg == code {
            let unknown = NSLocalizedString("err.unknown", comment: "")
            msg = unknown == "err.unknown" ? "Something went wrong." : unknown
        }
        params?.forEach { key, value in
            msg = msg.replacingOccurrences(of: "{\(key)}", with: value)
            msg = msg.replacingOccurrences(of: "%@", with: value)
        }
        return msg
    }
}
