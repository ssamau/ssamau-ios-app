import Foundation
import Combine

@MainActor
final class ResetPasswordViewModel: ObservableObject {
    @Published var identifier: String = ""
    @Published var isLoading: Bool = false
    @Published var successMessage: String?
    @Published var errorMessage: String?

    var canSubmit: Bool {
        !identifier.trimmingCharacters(in: .whitespaces).isEmpty && !isLoading
    }

    func submit() async {
        let trimmed = identifier.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            errorMessage = ErrorLocalization.localize("reset.identifier_empty")
            return
        }
        guard !isLoading else { return }

        isLoading = true
        errorMessage = nil
        successMessage = nil
        defer { isLoading = false }

        do {
            // Server always returns { sent: true } (anti-enumeration).
            // No need to read the value — success of the call is enough.
            _ = try await APIClient.shared.call(
                "auth.requestPasswordReset",
                params: ["identifier": trimmed],
                as: SentResponse.self
            )
            successMessage = ErrorLocalization.localize("reset.sent_success")
        } catch let apiError as APIError {
            errorMessage = apiError.localizedMessage
        } catch {
            errorMessage = ErrorLocalization.localize("err.unknown")
        }
    }

    private struct SentResponse: Decodable {
        let sent: Bool
    }
}
