import Foundation
import Combine

@MainActor
final class CertificatesViewModel: ObservableObject {
    @Published var certificates: [Certificate] = []
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?

    func load() async {
        // Self-scoped action — server filters by user.member_id and
        // returns an empty array when the caller has no member link
        // (dev accounts). Same row shape as certs.list.
        // Web 2026-05-21 — api edge fn v126.
        isLoading = true
        defer { isLoading = false }
        do {
            let rows = try await APIClient.shared.call(
                "certs.listOwn",
                as: [Certificate].self
            )
            self.certificates = rows
            self.errorMessage = nil
        } catch let apiError as APIError {
            if apiError.isCancellation { return }
            #if DEBUG
            print("⚠️ CertificatesViewModel.load APIError: \(apiError)")
            #endif
            self.errorMessage = apiError.localizedMessage
        } catch {
            #if DEBUG
            print("⚠️ CertificatesViewModel.load error: \(error)")
            #endif
            self.errorMessage = ErrorLocalization.localize("err.unknown")
        }
    }
}
