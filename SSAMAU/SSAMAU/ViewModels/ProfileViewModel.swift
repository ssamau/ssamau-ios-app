import Foundation
import Combine

@MainActor
final class ProfileViewModel: ObservableObject {
    @Published var member: Member?
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?

    func load() async {
        isLoading = true
        defer { isLoading = false }
        do {
            let loaded = try await APIClient.shared.call(
                "members.getOwn",
                as: Member.self
            )
            self.member = loaded
            self.errorMessage = nil
        } catch let apiError as APIError {
            self.errorMessage = apiError.localizedMessage
        } catch {
            self.errorMessage = ErrorLocalization.localize("err.unknown")
        }
    }
}
