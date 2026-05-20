import Foundation
import Combine

@MainActor
final class LoginViewModel: ObservableObject {
    @Published var identifier: String = ""
    @Published var password: String = ""
    @Published var isPasswordVisible: Bool = false
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?

    /// Source of a sign-in attempt — used to decide whether to apply
    /// the same-credentials guard.
    enum Trigger {
        case button        // explicit user tap — always proceeds
        case fieldSubmit   // keyboard "Go" / AutoFill commit — gated to break loops
    }

    /// Snapshot of (identifier, password) at the moment of the last
    /// failed sign-in. Used to gate `.fieldSubmit` calls so AutoFill
    /// rapid-fires after a failure don't loop. Explicit button taps
    /// ignore this — the user is the source of truth there.
    private var lastFailedSnapshot: String?

    var canSubmit: Bool {
        !identifier.trimmingCharacters(in: .whitespaces).isEmpty
            && !password.isEmpty
            && !isLoading
    }

    private var currentSnapshot: String {
        "\(identifier.trimmingCharacters(in: .whitespaces))|\(password)"
    }

    func signIn(trigger: Trigger = .button) async {
        guard canSubmit else { return }

        if trigger == .fieldSubmit && currentSnapshot == lastFailedSnapshot {
            // Same credentials, auto-submitted again — skip silently so
            // AutoFill prompt → failure → prompt doesn't loop. User can
            // still retry by tapping the Sign in button (.button trigger).
            return
        }

        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        let trimmed = identifier.trimmingCharacters(in: .whitespacesAndNewlines)

        do {
            let resolved = try await AuthService.resolveIdentifier(trimmed)
            guard resolved.found, let provider = resolved.authProvider else {
                errorMessage = ErrorLocalization.localize("err.auth.invalid_credentials")
                lastFailedSnapshot = currentSnapshot
                return
            }

            switch provider {
            case .supabase:
                let email = resolved.email ?? trimmed
                _ = try await AuthService.loginSupabase(email: email, password: password)
            case .legacy:
                let username = resolved.username ?? trimmed
                _ = try await AuthService.loginLegacy(username: username, password: password)
            }
            lastFailedSnapshot = nil
        } catch let apiError as APIError {
            #if DEBUG
            print("⚠️ LoginViewModel.signIn APIError: \(apiError)")
            #endif
            errorMessage = apiError.localizedMessage
            lastFailedSnapshot = currentSnapshot
        } catch {
            #if DEBUG
            print("⚠️ LoginViewModel.signIn non-API error: \(error)")
            #endif
            errorMessage = ErrorLocalization.localize("err.unknown")
            lastFailedSnapshot = currentSnapshot
        }
    }
}
