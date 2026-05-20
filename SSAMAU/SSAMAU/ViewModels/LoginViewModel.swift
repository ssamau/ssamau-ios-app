import Foundation
import Combine

@MainActor
final class LoginViewModel: ObservableObject {
    @Published var identifier: String = ""
    @Published var password: String = ""
    @Published var isPasswordVisible: Bool = false
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?

    /// Snapshot of (identifier, password) at the moment of the last
    /// failed sign-in. Guards against AutoFill rapid-fire re-submitting
    /// the same wrong credentials on a loop. Cleared when the user
    /// edits either field (the didSets below) and on success.
    private var lastFailedSnapshot: String?

    init() {}

    func setIdentifier(_ value: String) {
        identifier = value
        lastFailedSnapshot = nil
    }

    func setPassword(_ value: String) {
        password = value
        lastFailedSnapshot = nil
    }

    var canSubmit: Bool {
        !identifier.trimmingCharacters(in: .whitespaces).isEmpty
            && !password.isEmpty
            && !isLoading
    }

    private var currentSnapshot: String {
        "\(identifier.trimmingCharacters(in: .whitespaces))|\(password)"
    }

    func signIn() async {
        guard canSubmit else { return }

        // Guard against same-credentials resubmit. AutoFill commits the
        // password field on each prompt-accept; without this, a wrong
        // saved password loops failure → AutoFill prompt → failure …
        if currentSnapshot == lastFailedSnapshot { return }

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
            // Success — clear the guard so a subsequent log-out/log-in
            // with the same credentials still works.
            lastFailedSnapshot = nil
        } catch let apiError as APIError {
            errorMessage = apiError.localizedMessage
            lastFailedSnapshot = currentSnapshot
        } catch {
            errorMessage = ErrorLocalization.localize("err.unknown")
            lastFailedSnapshot = currentSnapshot
        }
    }
}
