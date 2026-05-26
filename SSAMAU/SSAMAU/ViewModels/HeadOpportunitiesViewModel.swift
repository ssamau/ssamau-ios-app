import Foundation
import Combine

/// Head's "Opportunities" tab — spec §9.4. Lists opportunities (server
/// returns either own committee or full club depending on caller's
/// access), with per-role assign + attendance flows.
@MainActor
final class HeadOpportunitiesViewModel: ObservableObject {
    @Published var opportunities: [Opportunity] = []
    @Published var assignments: [String: [AssignmentRow]] = [:]   // opp.id → rows
    @Published var interestRows: [String: [InterestRow]] = [:]    // opp.id → rows
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    @Published var toast: Toast?

    @Published var searchText: String = ""
    @Published var statusFilter: StatusFilter = .openOnly
    @Published var inFlightOppId: String?
    @Published var inFlightAssignmentId: String?

    enum StatusFilter: String, CaseIterable, Identifiable {
        case openOnly, all, past
        var id: String { rawValue }
        var labelKey: String {
            switch self {
            case .openOnly: return "hp.opps.filter_open"
            case .all:      return "hp.opps.filter_all"
            case .past:     return "hp.opps.filter_past"
            }
        }
    }

    var filteredOpportunities: [Opportunity] {
        let q = searchText.trimmingCharacters(in: .whitespaces).lowercased()
        return opportunities.filter { opp in
            switch statusFilter {
            case .openOnly: if !opp.isOpenForInterest { return false }
            case .past:     if opp.status != "Done" && opp.status != "Cancelled" { return false }
            case .all:      break
            }
            guard !q.isEmpty else { return true }
            let hay = [
                opp.projectName, opp.owningCommitteeName, opp.id,
                opp.roles.map(\.roleName).joined(separator: " ")
            ].compactMap { $0 }.joined(separator: " ").lowercased()
            return hay.contains(q)
        }
    }

    // MARK: - Load list

    func load() async {
        isLoading = true
        defer { isLoading = false }
        do {
            let fetched: [Opportunity] = try await APIClient.shared.call(
                "opportunities.list",
                as: [Opportunity].self
            )
            self.opportunities = fetched
            self.errorMessage = nil
        } catch let apiError as APIError {
            if apiError.isCancellation { return }
            #if DEBUG
            print("HeadOpps.load APIError: \(apiError)")
            #endif
            self.errorMessage = apiError.localizedMessage
        } catch {
            #if DEBUG
            print("HeadOpps.load error: \(error)")
            #endif
            self.errorMessage = ErrorLocalization.localize("err.unknown")
        }
    }

    // MARK: - Per-opportunity detail load

    /// Loads both assignments + interest rows for a single opportunity.
    /// Used when the assign sheet opens.
    func loadDetail(for opportunity: Opportunity) async {
        async let assigns: [AssignmentRow] = (try? APIClient.shared.call(
            "assignments.list",
            params: ["opportunity_id": opportunity.id],
            as: [AssignmentRow].self
        )) ?? []
        async let interests: [InterestRow] = (try? APIClient.shared.call(
            "interest.list",
            params: ["project_id": opportunity.projectId],
            as: [InterestRow].self
        )) ?? []
        let (a, i) = await (assigns, interests)
        self.assignments[opportunity.id] = a
        self.interestRows[opportunity.id] = i.filter {
            $0.interested && ($0.opportunityId == nil || $0.opportunityId == opportunity.id)
        }
    }

    // MARK: - Mutations

    func assign(member: InterestRow, to role: OpportunityRole?, opportunity: Opportunity) async {
        guard inFlightOppId == nil else { return }
        inFlightOppId = opportunity.id
        defer { inFlightOppId = nil }
        var params: [String: Any] = [
            "opportunity_id": opportunity.id,
            "member_id":      member.memberId,
        ]
        if let role { params["role_id"] = role.id }
        do {
            _ = try await APIClient.shared.call(
                "assignments.add",
                params: params,
                as: AnyJSON.self
            )
            toast = .success(ErrorLocalization.localize("hp.opps.assigned_ok"))
            await loadDetail(for: opportunity)
            await load()    // refresh counts on the main row
        } catch let apiError as APIError {
            if apiError.isCancellation { return }
            toast = .error(apiError.localizedMessage)
        } catch {
            toast = .error(ErrorLocalization.localize("err.unknown"))
        }
    }

    func removeAssignment(_ assignment: AssignmentRow, opportunity: Opportunity) async {
        guard inFlightAssignmentId == nil else { return }
        inFlightAssignmentId = assignment.id
        defer { inFlightAssignmentId = nil }
        do {
            _ = try await APIClient.shared.call(
                "assignments.remove",
                params: ["id": assignment.id],
                as: AnyJSON.self
            )
            toast = .success(ErrorLocalization.localize("hp.opps.removed_ok"))
            await loadDetail(for: opportunity)
            await load()
        } catch let apiError as APIError {
            if apiError.isCancellation { return }
            toast = .error(apiError.localizedMessage)
        } catch {
            toast = .error(ErrorLocalization.localize("err.unknown"))
        }
    }

    func markAttendance(
        _ assignment: AssignmentRow,
        status: String,
        hoursOverride: Double?,
        opportunity: Opportunity
    ) async {
        guard inFlightAssignmentId == nil else { return }
        inFlightAssignmentId = assignment.id
        defer { inFlightAssignmentId = nil }
        var params: [String: Any] = [
            "assignment_id": assignment.id,
            "attendance_status": status,
        ]
        if let h = hoursOverride { params["hours_override"] = h }
        do {
            _ = try await APIClient.shared.call(
                "assignments.markAttendance",
                params: params,
                as: AnyJSON.self
            )
            toast = .success(ErrorLocalization.localize("hp.opps.attendance_marked"))
            await loadDetail(for: opportunity)
            await load()
        } catch let apiError as APIError {
            if apiError.isCancellation { return }
            toast = .error(apiError.localizedMessage)
        } catch {
            toast = .error(ErrorLocalization.localize("err.unknown"))
        }
    }
}

