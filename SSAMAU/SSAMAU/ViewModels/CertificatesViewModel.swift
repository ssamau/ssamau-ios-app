import Foundation
import Combine

@MainActor
final class CertificatesViewModel: ObservableObject {
    @Published var certificates: [Certificate] = []
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?

    func load() async {
        // Member-scoped: filter by the current member_id. Server's
        // certs.list returns ALL certs when called without filters by
        // a non-head — we don't want that.
        guard let memberId = SessionStore.shared.currentUser?.memberId else {
            self.certificates = []
            return
        }
        isLoading = true
        defer { isLoading = false }
        do {
            let rows = try await APIClient.shared.call(
                "certs.list",
                params: ["member_id": memberId],
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
