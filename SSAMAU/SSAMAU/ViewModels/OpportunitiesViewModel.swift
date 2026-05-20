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

            // Optimistic local update so the chip flips immediately —
            // doesn't depend on the listOwn refresh succeeding.
            let synthetic = InterestRequest(
                id: -1,
                projectId: opportunity.projectId,
                opportunityId: opportunity.id,
                roleId: roleId,
                interested: true,
                comment: comment,
                submittedAt: nil,
                reviewedAt: nil
            )
            // Replace any existing row for this opportunity, otherwise append.
            if let idx = ownInterests.firstIndex(where: { $0.opportunityId == opportunity.id }) {
                ownInterests[idx] = synthetic
            } else {
                ownInterests.append(synthetic)
            }

            // Then refresh from server so we have the real row + ids.
            // Errors logged but don't undo the optimistic update.
            await refreshOwnInterests()
            // Also refresh the opportunities list — server may auto-flip
            // status to "Filled" if the role hit capacity.
            await refreshOpportunities()
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

    private func refreshOwnInterests() async {
        do {
            let refreshed = try await APIClient.shared.call(
                "interest.listOwn",
                as: [InterestRequest].self
            )
            self.ownInterests = refreshed
        } catch {
            #if DEBUG
            print("⚠️ refreshOwnInterests failed: \(error)")
            #endif
            // Keep the optimistic update — chip stays correct visually.
        }
    }

    private func refreshOpportunities() async {
        do {
            let refreshed = try await APIClient.shared.call(
                "opportunities.list",
                as: [Opportunity].self
            )
            self.opportunities = refreshed
        } catch {
            #if DEBUG
            print("⚠️ refreshOpportunities failed: \(error)")
            #endif
        }
    }
}

// InterestRequest synthesized init — used for the optimistic local
// update path. Codable's auto-init covers the from-JSON path.
extension InterestRequest {
    init(
        id: Int64,
        projectId: String,
        opportunityId: String?,
        roleId: Int64?,
        interested: Bool,
        comment: String?,
        submittedAt: String?,
        reviewedAt: String?
    ) {
        self.id = id
        self.projectId = projectId
        self.opportunityId = opportunityId
        self.roleId = roleId
        self.interested = interested
        self.comment = comment
        self.submittedAt = submittedAt
        self.reviewedAt = reviewedAt
    }
}
