import Foundation
import Combine

@MainActor
final class HoursViewModel: ObservableObject {
    @Published var rows: [HoursRow] = []
    @Published var assignments: [Assignment] = []
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    @Published var toastMessage: String?
    @Published var isLogging: Bool = false

    /// Sum of FinalApproved hours — the headline number shown at the top.
    var totalFinalApprovedHours: Double {
        rows.filter { $0.approvalStatus == "FinalApproved" }
            .reduce(0) { $0 + $1.totalHours }
    }

    /// Assignments eligible for logging: attendance_status == "Attended"
    /// AND not yet covered by an existing hours row.
    var loggableAssignments: [Assignment] {
        let recordedIds = Set(rows.compactMap(\.assignmentId))
        return assignments
            .filter { ($0.attendanceStatus ?? "") == "Attended" }
            .filter { !recordedIds.contains($0.id) }
    }

    func load() async {
        isLoading = true
        defer { isLoading = false }
        async let hoursTask: [HoursRow] = APIClient.shared.call(
            "hours.listOwn", as: [HoursRow].self
        )
        async let assnTask: [Assignment] = APIClient.shared.call(
            "assignments.listOwn", as: [Assignment].self
        )
        do {
            self.rows = try await hoursTask
            self.assignments = (try? await assnTask) ?? []
            self.errorMessage = nil
        } catch let apiError as APIError {
            if apiError.isCancellation { return }
            #if DEBUG
            print("⚠️ HoursViewModel.load APIError: \(apiError)")
            #endif
            self.errorMessage = apiError.localizedMessage
        } catch {
            #if DEBUG
            print("⚠️ HoursViewModel.load error: \(error)")
            #endif
            self.errorMessage = ErrorLocalization.localize("err.unknown")
        }
    }

    /// Submit a new hours entry. Server enforces:
    ///   - assignment must belong to caller (err.business.assignment_not_yours)
    ///   - assignment status == "Attended" (err.business.hours_needs_attended)
    ///   - no existing hours row (err.business.hours_already_recorded)
    ///   - before+during+after > 0 (err.business.hours_zero)
    func logHours(
        assignment: Assignment,
        before: Double,
        during: Double,
        after: Double,
        notes: String?
    ) async -> Bool {
        guard !isLogging else { return false }
        isLogging = true
        defer { isLogging = false }

        var data: [String: Any] = [
            "assignment_id": assignment.id,
            "hours_before":  before,
            "hours_during":  during,
            "hours_after":   after,
        ]
        if let n = notes?.trimmingCharacters(in: .whitespaces), !n.isEmpty {
            data["notes"] = n
        }

        do {
            _ = try await APIClient.shared.call(
                "hours.recordOwn",
                params: ["data": data],
                as: EmptyResponse.self
            )
            toastMessage = ErrorLocalization.localize("mp.hours.logged_ok")
            await load()
            return true
        } catch let apiError as APIError {
            if apiError.isCancellation { return false }
            #if DEBUG
            print("⚠️ logHours APIError: \(apiError)")
            #endif
            toastMessage = apiError.localizedMessage
            return false
        } catch {
            #if DEBUG
            print("⚠️ logHours error: \(error)")
            #endif
            toastMessage = ErrorLocalization.localize("err.unknown")
            return false
        }
    }
}
