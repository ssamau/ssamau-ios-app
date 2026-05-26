import Foundation
import Combine

/// Lightweight viewer for the head/admin's "who is this member?" sheet.
/// Loads hours summary + recent assignments + cert count in parallel.
/// Read-only; no mutations. Everything is fetched via existing actions
/// that the head/admin already has scope for.
@MainActor
final class MemberProfileViewerViewModel: ObservableObject {
    @Published var hours: [HoursAdminRow] = []
    @Published var assignments: [AssignmentRow] = []
    @Published var isLoading: Bool = false

    /// Sum of FinalApproved hours (matches the canonical members.total_hours
    /// rollup logic). Meeting attendance hours are mirrored into the
    /// hours table by the server so this sum is complete.
    var totalApprovedHours: Double {
        hours.filter { $0.approvalStatus == "FinalApproved" }
             .reduce(0) { $0 + $1.totalHours }
    }
    var pendingHoursCount: Int {
        hours.filter { ["Draft", "PrimaryApproved"].contains($0.approvalStatus) }.count
    }
    var attendedAssignmentsCount: Int {
        assignments.filter { $0.attendanceStatus == "Attended" }.count
    }
    var upcomingAssignmentsCount: Int {
        assignments.filter { ($0.attendanceStatus ?? "Pending") == "Pending" }.count
    }

    func load(memberId: String) async {
        isLoading = true
        defer { isLoading = false }
        async let h: [HoursAdminRow] = (try? APIClient.shared.call(
            "getMemberHours",
            params: ["member_id": memberId],
            as: [HoursAdminRow].self
        )) ?? []
        async let a: [AssignmentRow] = (try? APIClient.shared.call(
            "assignments.list",
            params: ["member_id": memberId],
            as: [AssignmentRow].self
        )) ?? []
        let (hh, aa) = await (h, a)
        self.hours = hh
        self.assignments = aa
    }
}
