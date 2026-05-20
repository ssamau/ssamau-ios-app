import Foundation
import Combine

@MainActor
final class OpportunitiesViewModel: ObservableObject {
    @Published var opportunities: [Opportunity] = []
    @Published var ownInterests: [InterestRequest] = []
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    @Published var toastMessage: String?

    @Published var searchText: String = ""
    @Published var statusFilter: StatusFilter = .openOnly

    enum StatusFilter: String, CaseIterable, Identifiable {
        case openOnly      // "Open" or "NeedsHelp"
        case all
        var id: String { rawValue }
    }

    var filteredOpportunities: [Opportunity] {
        let trimmed = searchText.trimmingCharacters(in: .whitespaces).lowercased()
        return opportunities.filter { opp in
            let statusOK: Bool
            switch statusFilter {
            case .openOnly: statusOK = opp.isOpenForInterest
            case .all:      statusOK = true
            }
            guard statusOK else { return false }
            guard !trimmed.isEmpty else { return true }
            let hay = [
                opp.projectName,
                opp.owningCommitteeName,
                opp.roles.map(\.roleName).joined(separator: " "),
            ].compactMap { $0 }.joined(separator: " ").lowercased()
            return hay.contains(trimmed)
        }
    }

    /// Set of opportunity_ids the current member has expressed interest in
    /// (where `interested == true`). Used for the ✓ row chip.
    var expressedOpportunityIds: Set<String> {
        Set(ownInterests.filter { $0.interested }.compactMap(\.opportunityId))
    }

    func load() async {
        isLoading = true
        defer { isLoading = false }
        async let opps: [Opportunity] = APIClient.shared.call(
            "opportunities.list",
            as: [Opportunity].self
        )
        async let own: [InterestRequest] = APIClient.shared.call(
            "interest.listOwn",
            as: [InterestRequest].self
        )
        do {
            self.opportunities = try await opps
            self.ownInterests = (try? await own) ?? []
            self.errorMessage = nil
        } catch let apiError as APIError {
            #if DEBUG
            print("⚠️ OpportunitiesViewModel.load APIError: \(apiError)")
            #endif
            self.errorMessage = apiError.localizedMessage
        } catch {
            #if DEBUG
            print("⚠️ OpportunitiesViewModel.load error: \(error)")
            #endif
            self.errorMessage = ErrorLocalization.localize("err.unknown")
        }
    }

    /// Express interest in a single role (or `roleId: nil` for "any role").
    func expressInterest(opportunity: Opportunity, roleId: Int64?, comment: String?) async -> Bool {
        var data: [String: Any] = [
            "project_id":     opportunity.projectId,
            "opportunity_id": opportunity.id,
            "interested":     true,
        ]
        data["role_id"] = roleId ?? NSNull()
        if let c = comment?.trimmingCharacters(in: .whitespaces), !c.isEmpty {
            data["comment"] = c
        }
        do {
            _ = try await APIClient.shared.call(
                "interest.submit",
                params: ["data": data],
                as: EmptyResponse.self
            )
            toastMessage = ErrorLocalization.localize("mp.opps.expressed_ok")
            // Refresh own-interests so the row chip updates.
            if let refreshed = try? await APIClient.shared.call(
                "interest.listOwn",
                as: [InterestRequest].self
            ) {
                self.ownInterests = refreshed
            }
            return true
        } catch let apiError as APIError {
            #if DEBUG
            print("⚠️ expressInterest APIError: \(apiError)")
            #endif
            toastMessage = apiError.localizedMessage
            return false
        } catch {
            #if DEBUG
            print("⚠️ expressInterest error: \(error)")
            #endif
            toastMessage = ErrorLocalization.localize("err.unknown")
            return false
        }
    }
}
