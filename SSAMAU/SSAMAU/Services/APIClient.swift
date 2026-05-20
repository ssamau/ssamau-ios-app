import Foundation

/// Errors surfaced by `APIClient`. See spec §5 + §14.
enum APIError: Error, Equatable {
    case unauthorized
    case server(code: String, params: [String: String]?)
    case network(URLError)
    case decoding(String)
    case emptyResponse
    case upgradeRequired

    var localizedMessage: String {
        switch self {
        case .unauthorized:
            return ErrorLocalization.localize("err.session.expired")
        case let .server(code, params):
            return ErrorLocalization.localize(code, params: params)
        case .network:
            return ErrorLocalization.localize("err.network")
        case .decoding, .emptyResponse:
            return ErrorLocalization.localize("err.unknown")
        case .upgradeRequired:
            return ErrorLocalization.localize("err.app.upgrade_required")
        }
    }

    static func == (lhs: APIError, rhs: APIError) -> Bool {
        switch (lhs, rhs) {
        case (.unauthorized, .unauthorized),
             (.network, .network),
             (.decoding, .decoding),
             (.emptyResponse, .emptyResponse),
             (.upgradeRequired, .upgradeRequired):
            return true
        case let (.server(c1, _), .server(c2, _)):
            return c1 == c2
        default:
            return false
        }
    }
}

/// Action-dispatching HTTP client for the Supabase Edge Function.
/// Single endpoint, body shape `{ "action": "<name>", ...params }`.
/// See spec §5.
struct APIClient {
    static let shared = APIClient()

    static let baseURL = URL(string: "https://pfibxvwiulwiiuwerawe.supabase.co/functions/v1/api")!

    // Public Supabase anon key — identifies the project, no auth grant.
    // Safe to ship in the client per spec + handoff.
    static let supabaseAnonKey = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InBmaWJ4dndpdWx3aWl1d2VyYXdlIiwicm9sZSI6ImFub24iLCJpYXQiOjE3Nzg1ODI2NzEsImV4cCI6MjA5NDE1ODY3MX0.A0_w-iQQK-ozDiRWBS62ho_THvxEhzHWO-zgBcvfk78"

    static var appVersion: String {
        let info = Bundle.main.infoDictionary
        let short = info?["CFBundleShortVersionString"] as? String ?? "0.0.0"
        let build = info?["CFBundleVersion"] as? String ?? "0"
        return "\(short)+\(build)"
    }

    let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

    /// Calls an action and decodes `data` into `Response`.
    /// `params` is merged into the request body alongside `action`.
    /// Values must be JSON-primitives (`String`, `Int`, `Double`, `Bool`,
    /// `[Any]`, `[String: Any]`, or `NSNull`).
    func call<Response: Decodable>(
        _ action: String,
        params: [String: Any] = [:],
        as: Response.Type = Response.self
    ) async throws -> Response {
        var body = params
        body["action"] = action

        var request = URLRequest(url: Self.baseURL)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(Self.supabaseAnonKey, forHTTPHeaderField: "apikey")
        request.setValue(Self.appVersion, forHTTPHeaderField: "X-App-Version")
        if let token = KeychainService.token() {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let data: Data
        let httpResponse: URLResponse
        do {
            (data, httpResponse) = try await session.data(for: request)
        } catch let urlError as URLError {
            throw APIError.network(urlError)
        }

        if let http = httpResponse as? HTTPURLResponse, http.statusCode == 401 {
            SessionStore.shared.handleUnauthorized()
            throw APIError.unauthorized
        }

        let envelope: APIEnvelope<Response>
        do {
            envelope = try JSONDecoder.api.decode(APIEnvelope<Response>.self, from: data)
        } catch {
            throw APIError.decoding(String(describing: error))
        }

        if !envelope.success {
            let code = envelope.error ?? "err.unknown"
            if code == "err.app.upgrade_required" {
                throw APIError.upgradeRequired
            }
            throw APIError.server(code: code, params: envelope.errorParams)
        }

        guard let payload = envelope.data else {
            // Some actions legitimately return no `data` (e.g. signOut).
            // Allow EmptyResponse to satisfy that case.
            if Response.self == EmptyResponse.self {
                return EmptyResponse() as! Response
            }
            throw APIError.emptyResponse
        }
        return payload
    }
}

extension JSONDecoder {
    static let api: JSONDecoder = {
        let decoder = JSONDecoder()
        // Server already uses snake_case for fields the Codable models map
        // explicitly via CodingKeys — don't auto-convert here.
        return decoder
    }()
}
