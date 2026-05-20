import Foundation
import Combine

@MainActor
final class LoginViewModel: ObservableObject {
    @Published var identifier: String = ""
    @Published var password: String = ""
    @Published var isPasswordVisible: Bool = false
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?

    var canSubmit: Bool {
        !identifier.trimmingCharacters(in: .whitespaces).isEmpty
            && !password.isEmpty
            && !isLoading
    }

    func signIn() async {
        guard canSubmit else { return }

        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        let trimmed = identifier.trimmingCharacters(in: .whitespacesAndNewlines)

        do {
            let resolved = try await AuthService.resolveIdentifier(trimmed)
            guard resolved.found, let provider = resolved.authProvider else {
                errorMessage = ErrorLocalization.localize("err.auth.invalid_credentials")
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
        } catch let apiError as APIError {
            errorMessage = apiError.localizedMessage
        } catch {
            errorMessage = ErrorLocalization.localize("err.unknown")
        }
    }
}
