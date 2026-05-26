import Foundation
import Combine

/// Drives both Head's primary-review queue AND Admin's final-approval
/// queue. Mode determines:
///   - Which statuses are shown
///   - What "Approve" does (primary vs final)
///   - Whether committee-scoping is applied client-side
@MainActor
final class HoursApprovalViewModel: ObservableObject {
    enum Mode {
        /// Head's queue: Draft + PrimaryApproved, scoped to own committee.
        /// Approve button: Draft → primary, PrimaryApproved → final.
        case headQueue
        /// Admin's queue: PrimaryApproved only (final-approval).
        /// Approve button: → FinalApproved.
        case adminFinalApproval
    }

    let mode: Mode
    @Published var rows: [HoursAdminRow] = []
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    @Published var toast: Toast?
    @Published var rowInFlight: Int?

    init(mode: Mode) {
        self.mode = mode
    }

    func load() async {
        isLoading = true
        defer { isLoading = false }
        do {
            // Fan-out for Draft + PrimaryApproved when in head mode;
            // PrimaryApproved-only for admin final-approval.
            let statuses: [String] = mode == .headQueue
                ? ["Draft", "PrimaryApproved"]
                : ["PrimaryApproved"]
            var combined: [HoursAdminRow] = []
            for status in statuses {
                let fetched: [HoursAdminRow] = try await APIClient.shared.call(
                    "getMemberHours",
                    params: ["approval_status": status],
                    as: [HoursAdminRow].self
                )
                combined.append(contentsOf: fetched)
            }
            // Client-side committee scope for heads. Admins see everything.
            if mode == .headQueue,
               let committeeId = SessionStore.shared.currentUser?.committeeId {
                combined = combined.filter { row in
                    // Match on opportunity-owning committee OR member-belongs-to-committee
                    // (the latter handled by the dashboard query; for simplicity
                    // we use opportunity committee here. May miss legacy rows
                    // that have no opportunity link.)
                    row.opportunityCommitteeId == committeeId
                }
            }
            // Sort: Draft first (oldest), then PrimaryApproved (oldest)
            combined.sort { (a, b) -> Bool in
                let aDraft = a.approvalStatus == "Draft"
                let bDraft = b.approvalStatus == "Draft"
                if aDraft != bDraft { return aDraft && !bDraft }
                let aDate = a.recordedAt ?? ""
                let bDate = b.recordedAt ?? ""
                return aDate < bDate
            }
            self.rows = combined
            self.errorMessage = nil
        } catch let apiError as APIError {
            if apiError.isCancellation { return }
            #if DEBUG
            print("⚠️ HoursApprovalViewModel.load APIError: \(apiError)")
            #endif
            self.errorMessage = apiError.localizedMessage
        } catch {
            #if DEBUG
            print("⚠️ HoursApprovalViewModel.load error: \(error)")
            #endif
            self.errorMessage = ErrorLocalization.localize("err.unknown")
        }
    }

    /// "Approve" → next state in the chain. Returns true on success so
    /// the caller can decide whether to dismiss a sheet / clear state.
    @discardableResult
    func approve(_ row: HoursAdminRow) async -> Bool {
        guard rowInFlight == nil else { return false }
        rowInFlight = row.id
        defer { rowInFlight = nil }

        // Decide action based on mode + current row status.
        let action: String
        switch (mode, row.approvalStatus) {
        case (.headQueue, "Draft"):
            action = "hours.primaryApprove"
        case (.headQueue, "PrimaryApproved"):
            action = "hours.finalApprove"
        case (.adminFinalApproval, _):
            action = "hours.finalApprove"
        default:
            action = "hours.finalApprove"
        }

        do {
            _ = try await APIClient.shared.call(
                action,
                params: ["id": row.id],
                as: EmptyResponse.self
            )
            toast = .success(ErrorLocalization.localize("hp.hours.approved_ok"))
            await load()
            return true
        } catch let apiError as APIError {
            if apiError.isCancellation { return false }
            toast = .error(apiError.localizedMessage)
            return false
        } catch {
            toast = .error(ErrorLocalization.localize("err.unknown"))
            return false
        }
    }

    @discardableResult
    func reject(_ row: HoursAdminRow, reason: String) async -> Bool {
        guard rowInFlight == nil else { return false }
        rowInFlight = row.id
        defer { rowInFlight = nil }
        let trimmed = reason.trimmingCharacters(in: .whitespacesAndNewlines)
        do {
            _ = try await APIClient.shared.call(
                "hours.reject",
                params: trimmed.isEmpty
                    ? ["id": row.id]
                    : ["id": row.id, "reason": trimmed],
                as: EmptyResponse.self
            )
            toast = .success(ErrorLocalization.localize("hp.hours.rejected_ok"))
            await load()
            return true
        } catch let apiError as APIError {
            if apiError.isCancellation { return false }
            toast = .error(apiError.localizedMessage)
            return false
        } catch {
            toast = .error(ErrorLocalization.localize("err.unknown"))
            return false
        }
    }
}
