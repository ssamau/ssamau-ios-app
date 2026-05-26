import Foundation
import Combine

@MainActor
final class HeadDashboardViewModel: ObservableObject {
    @Published var summary: HeadDashboardSummary?
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?

    func load() async {
        isLoading = true
        defer { isLoading = false }
        do {
            let result = try await APIClient.shared.call(
                "head.dashboardSummary",
                as: HeadDashboardSummary.self
            )
            self.summary = result
            self.errorMessage = nil
        } catch let apiError as APIError {
            if apiError.isCancellation { return }
            #if DEBUG
            print("⚠️ HeadDashboardViewModel.load APIError: \(apiError)")
            #endif
            self.errorMessage = apiError.localizedMessage
        } catch {
            #if DEBUG
            print("⚠️ HeadDashboardViewModel.load error: \(error)")
            #endif
            self.errorMessage = ErrorLocalization.localize("err.unknown")
        }
    }
}
