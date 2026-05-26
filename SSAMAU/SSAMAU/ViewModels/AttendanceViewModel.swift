import Foundation
import Combine

@MainActor
final class AttendanceViewModel: ObservableObject {
    @Published var rows: [AttendanceRow] = []
    @Published var members: [MemberAccountRow] = []
    @Published var projects: [Project] = []
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    @Published var toast: Toast?
    @Published var inFlightId: String?

    /// Head-side load — pulls attendance rows + scoping data (members + projects)
    /// needed for the record sheet.
    func load(committeeId: String?) async {
        isLoading = true
        defer { isLoading = false }
        async let att: [AttendanceRow] = (try? APIClient.shared.call(
            "head.attendance.list", as: [AttendanceRow].self
        )) ?? []
        async let mem: [MemberAccountRow] = (try? APIClient.shared.call(
            "users.list", as: [MemberAccountRow].self
        )) ?? []
        async let proj: [Project] = (try? APIClient.shared.call(
            "getProjects", as: [Project].self
        )) ?? []
        let (a, m, p) = await (att, mem, proj)
        self.rows = a
        self.members = m
        self.projects = p.filter { committeeId == nil || $0.owningCommitteeId == committeeId }
        self.errorMessage = nil
    }

    func recordProjectAttendance(
        projectId: String, memberId: String?, status: String,
        notes: String, hours: Double?
    ) async -> Bool {
        inFlightId = "new"
        defer { inFlightId = nil }
        var data: [String: Any] = [
            "project_id":        projectId,
            "attendance_status": status,
        ]
        if let m = memberId { data["member_id"] = m }
        if !notes.isEmpty   { data["notes"]     = notes }
        if let h = hours    { data["meeting_hours"] = h }
        do {
            _ = try await APIClient.shared.call(
                "head.attendance.record",
                params: ["data": data],
                as: AnyJSON.self
            )
            toast = .success(ErrorLocalization.localize("hp.attendance.recorded_ok"))
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

    func recordMeetingAttendance(
        title: String, type: String, date: Date, startTime: String,
        location: String, memberId: String?, status: String,
        notes: String, hours: Double?
    ) async -> Bool {
        inFlightId = "new"
        defer { inFlightId = nil }
        var data: [String: Any] = [
            "meeting_title":       title,
            "meeting_type":        type,
            "meeting_date":        MemberFieldMaps.serverDateString(date),
            "meeting_start_time":  startTime,
            "attendance_status":   status,
        ]
        if let m = memberId      { data["member_id"]        = m }
        if !location.isEmpty     { data["meeting_location"] = location }
        if !notes.isEmpty        { data["notes"]            = notes }
        if let h = hours         { data["meeting_hours"]    = h }
        do {
            _ = try await APIClient.shared.call(
                "head.attendance.record",
                params: ["data": data],
                as: AnyJSON.self
            )
            toast = .success(ErrorLocalization.localize("hp.attendance.recorded_ok"))
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

    func deleteRow(_ row: AttendanceRow) async {
        inFlightId = String(row.id)
        defer { inFlightId = nil }
        do {
            _ = try await APIClient.shared.call(
                "head.attendance.delete",
                params: ["id": row.id],
                as: AnyJSON.self
            )
            toast = .success(ErrorLocalization.localize("hp.attendance.deleted_ok"))
            rows.removeAll { $0.id == row.id }
        } catch let apiError as APIError {
            if apiError.isCancellation { return }
            toast = .error(apiError.localizedMessage)
        } catch {
            toast = .error(ErrorLocalization.localize("err.unknown"))
        }
    }
}
