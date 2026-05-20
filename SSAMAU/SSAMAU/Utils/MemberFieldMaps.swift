import Foundation

/// Mirrors the canonical enum-key → display-label maps in the web app's
/// `assets/js/member/tabs/profile.js`. Keep in lockstep with that file.
enum MemberFieldMaps {

    /// Each `(value, label)`. `label` is either a Localizable.strings key
    /// (resolved via NSLocalizedString) or a literal English string
    /// (used as-is — the web has the same pattern for university names).
    typealias Option = (value: String, label: String)

    static let scholarshipOpts: [Option] = [
        ("khadem_alharamain",     "apply.s3.opt.khadem_alharamain"),
        ("job_sponsored",         "apply.s3.opt.job_sponsored"),
        ("private_sector",        "apply.s3.opt.private_sector"),
        ("cultural_tourism",      "apply.s3.opt.cultural_tourism"),
        ("companion_student",     "apply.s3.opt.companion_student"),
        ("self_funded",           "apply.s3.opt.self_funded"),
        ("companion_non_student", "apply.s3.opt.companion_non_student"),
    ]

    static let universityOpts: [Option] = [
        ("melbourne", "Melbourne University"),
        ("monash",    "Monash University"),
        ("rmit",      "RMIT"),
        ("deakin",    "Deakin University"),
        ("latrobe",   "La Trobe University"),
        ("swinburne", "Swinburne University"),
        ("victoria",  "Victoria University"),
        ("acu",       "Australian Catholic University"),
    ]

    static let studyLevelOpts: [Option] = [
        ("PhD",      "apply.s4.opt.phd"),
        ("Masters",  "apply.s4.opt.masters"),
        ("Bachelor", "apply.s4.opt.bachelor"),
        ("Diploma",  "apply.s4.opt.diploma"),
        ("Language", "apply.s4.opt.language"),
    ]

    static let studyStartOpts: [Option] = [
        ("<6mo",   "apply.s4.opt.started_lt6"),
        ("6mo-1y", "apply.s4.opt.started_6mo_1y"),
        (">1y",    "apply.s4.opt.started_gt1y"),
    ]

    static let graduationOpts: [Option] = [
        ("Jul2027", "apply.s4.opt.grad_jul2027"),
        ("Dec2027", "apply.s4.opt.grad_dec2027"),
        ("2028+",   "apply.s4.opt.grad_2028"),
    ]

    // Read-only role display — mirrors READONLY_ROLE_KEY in the web's
    // profile.js. Stored canonical values are the English role names.
    static let roleOpts: [Option] = [
        ("President",           "ap.role.president"),
        ("Vice President",      "ap.role.vice_president"),
        ("Deputy Vice Head",    "ap.role.deputy_vice_head"),
        ("Committee Head",      "ap.role.committee_head"),
        ("Committee Vice Head", "ap.role.committee_vice_head"),
        ("Project Manager",     "ap.role.project_manager"),
        ("Event Manager",       "ap.role.event_manager"),
        ("Member",              "ap.role.member"),
        ("Volunteer",           "ap.role.volunteer"),
    ]

    static let statusOpts: [Option] = [
        ("Active",   "ap.status.active"),
        ("Inactive", "ap.status.inactive"),
    ]

    // MARK: - Lookup helpers

    /// Resolve a raw enum value to a human-readable label using the
    /// supplied options table. Falls back to the raw value if no
    /// mapping is found (forward-compatible with values added on the
    /// server before the iOS map catches up).
    static func label(for value: String?, in opts: [Option]) -> String? {
        guard let value, !value.isEmpty else { return nil }
        guard let opt = opts.first(where: { $0.value == value }) else { return value }
        // Localizable keys look like "apply.s3.opt.foo". Resolve them;
        // anything else is a literal label.
        if opt.label.contains(".") {
            let localized = NSLocalizedString(opt.label, comment: "")
            return localized == opt.label ? value : localized
        }
        return opt.label
    }

    static func scholarshipLabel(_ value: String?) -> String? {
        label(for: value, in: scholarshipOpts)
    }

    static func universityLabel(_ value: String?) -> String? {
        label(for: value, in: universityOpts)
    }

    static func studyLevelLabel(_ value: String?) -> String? {
        label(for: value, in: studyLevelOpts)
    }

    static func roleLabel(_ value: String?) -> String? {
        label(for: value, in: roleOpts)
    }

    static func statusLabel(_ value: String?) -> String? {
        label(for: value, in: statusOpts)
    }

    // MARK: - Date formatting

    private static let serverDateFormatter: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()

    private static let serverDateOnlyFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = TimeZone(identifier: "UTC")
        return f
    }()

    private static let displayDateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .none
        return f
    }()

    /// Accepts either `2004-08-05` or `2004-08-05T00:00:00.000Z` and
    /// returns a locale-aware medium date like "5 Aug 2004".
    static func displayDate(_ raw: String?) -> String? {
        guard let raw, !raw.isEmpty else { return nil }
        if let d = serverDateFormatter.date(from: raw) {
            return displayDateFormatter.string(from: d)
        }
        if let d = serverDateOnlyFormatter.date(from: raw) {
            return displayDateFormatter.string(from: d)
        }
        return raw
    }

    /// Parse an incoming server date string to a `Date`, for DatePicker
    /// bindings. Returns nil if the string isn't a recognised format.
    static func parseServerDate(_ raw: String?) -> Date? {
        guard let raw, !raw.isEmpty else { return nil }
        return serverDateFormatter.date(from: raw)
            ?? serverDateOnlyFormatter.date(from: raw)
    }

    /// Format a `Date` for sending to the server (YYYY-MM-DD).
    static func serverDateString(_ date: Date) -> String {
        serverDateOnlyFormatter.string(from: date)
    }
}
