import Foundation
import Combine

@MainActor
final class AdminDashboardViewModel: ObservableObject {
    @Published var summary: DashboardStats?
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?

    func load() async {
        isLoading = true
        defer { isLoading = false }
        do {
            let s = try await APIClient.shared.call(
                "getDashboardStats", as: DashboardStats.self
            )
            self.summary = s
            self.errorMessage = nil
        } catch let apiError as APIError {
            if apiError.isCancellation { return }
            #if DEBUG
            print("AdminDashboard.load APIError: \(apiError)")
            #endif
            self.errorMessage = apiError.localizedMessage
        } catch {
            #if DEBUG
            print("AdminDashboard.load error: \(error)")
            #endif
            self.errorMessage = ErrorLocalization.localize("err.unknown")
        }
    }
}
