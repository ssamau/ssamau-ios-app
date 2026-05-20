import Foundation

/// Wraps the three-path login flow from spec §4.
///
///   1. `resolveIdentifier(_:)` to learn which provider the user belongs to
///   2a. `loginSupabase(email:password:)` — Supabase Auth REST → exchange
///       for our HS256 → store + return user
///   2b. `loginLegacy(username:password:)` — legacy `auth` action → store
///       + return user
///
/// On success, the token is written to the Keychain and `SessionStore.shared`
/// is flipped to `.loggedIn(user)` — UI watching the store transitions.
enum AuthService {

    static let supabaseAuthURL = URL(
        string: "https://pfibxvwiulwiiuwerawe.supabase.co/auth/v1/token?grant_type=password"
    )!

    // MARK: - Public entry points

    static func resolveIdentifier(_ identifier: String) async throws -> ResolveIdentifierResponse {
        try await APIClient.shared.call(
            "auth.resolveIdentifier",
            params: ["identifier": identifier],
            as: ResolveIdentifierResponse.self
        )
    }

    /// Supabase path. Sign in to Supabase Auth → exchange for our HS256 →
    /// store + return user.
    @discardableResult
    static func loginSupabase(email: String, password: String) async throws -> SessionUser {
        let access = try await supabasePasswordGrant(email: email, password: password)
        let resp = try await APIClient.shared.call(
            "auth.exchangeSupabaseToken",
            params: ["access_token": access],
            as: AuthResponse.self
        )
        try SessionStore.shared.login(resp.user, token: resp.token)
        return resp.user
    }

    /// Legacy path. POST `auth` with `{ username, password }` → store + return user.
    @discardableResult
    static func loginLegacy(username: String, password: String) async throws -> SessionUser {
        let resp = try await APIClient.shared.call(
            "auth",
            params: ["username": username, "password": password],
            as: AuthResponse.self
        )
        try SessionStore.shared.login(resp.user, token: resp.token)
        return resp.user
    }

    // MARK: - Supabase REST helper

    /// Posts to Supabase Auth's password-grant endpoint. Returns the
    /// `access_token`. Any non-200 is translated into
    /// `err.auth.invalid_credentials` so the upstream catch can localize
    /// it like our other auth errors.
    private static func supabasePasswordGrant(email: String, password: String) async throws -> String {
        var req = URLRequest(url: supabaseAuthURL)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue(APIClient.supabaseAnonKey, forHTTPHeaderField: "apikey")
        req.httpBody = try JSONSerialization.data(withJSONObject: [
            "email": email,
            "password": password,
        ])

        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await URLSession.shared.data(for: req)
        } catch let urlError as URLError {
            throw APIError.network(urlError)
        }

        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw APIError.server(code: "err.auth.invalid_credentials", params: nil)
        }

        do {
            return try JSONDecoder().decode(SupabaseTokenResponse.self, from: data).accessToken
        } catch {
            throw APIError.decoding(String(describing: error))
        }
    }
}
