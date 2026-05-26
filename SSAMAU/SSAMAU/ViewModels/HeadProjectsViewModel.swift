import Foundation
import Combine

/// Shared by HeadProjectsView (committee-scoped, client-filtered) and
/// AdminProjectsView (full club). Server's `getProjects` returns
/// everything — we filter on the client by owning_committee_id when
/// the caller is a head.
@MainActor
final class HeadProjectsViewModel: ObservableObject {
    @Published var projects: [Project] = []
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    @Published var toast: Toast?

    @Published var searchText: String = ""
    @Published var inFlightProjectId: String?

    /// Set by the caller (HeadProjectsView passes the head's own
    /// committee_id; AdminProjectsView leaves it nil).
    var committeeFilter: String?

    var filteredProjects: [Project] {
        let q = searchText.trimmingCharacters(in: .whitespaces).lowercased()
        return projects.filter { p in
            if let filter = committeeFilter, p.owningCommitteeId != filter { return false }
            guard !q.isEmpty else { return true }
            let hay = [p.name, p.location, p.projectType, p.id]
                .compactMap { $0 }.joined(separator: " ").lowercased()
            return hay.contains(q)
        }
    }

    func load() async {
        isLoading = true
        defer { isLoading = false }
        do {
            let fetched: [Project] = try await APIClient.shared.call(
                "getProjects", as: [Project].self
            )
            self.projects = fetched
            self.errorMessage = nil
        } catch let apiError as APIError {
            if apiError.isCancellation { return }
            #if DEBUG
            print("HeadProjects.load APIError: \(apiError)")
            #endif
            self.errorMessage = apiError.localizedMessage
        } catch {
            #if DEBUG
            print("HeadProjects.load error: \(error)")
            #endif
            self.errorMessage = ErrorLocalization.localize("err.unknown")
        }
    }

    func createOrUpdate(
        existing: Project?,
        name: String, type: String, status: String,
        eventDate: Date?, startTime: String, endTime: String,
        location: String, description: String, notes: String,
        owningCommitteeId: String?
    ) async -> Bool {
        guard inFlightProjectId == nil else { return false }
        var data: [String: Any] = [
            "project_name":   name,
            "project_type":   type,
            "project_status": status,
        ]
        if let d = eventDate {
            data["event_date"] = MemberFieldMaps.serverDateString(d)
        }
        if !startTime.isEmpty   { data["start_time"]          = startTime }
        if !endTime.isEmpty     { data["end_time"]            = endTime }
        if !location.isEmpty    { data["location"]            = location }
        if !description.isEmpty { data["project_description"] = description }
        if !notes.isEmpty       { data["notes"]               = notes }
        if let committee = owningCommitteeId {
            data["owning_committee_id"] = committee
        }
        var params: [String: Any] = ["data": data]
        let action: String
        if let existing {
            inFlightProjectId = existing.id
            params["id"] = existing.id
            action = "updateProject"
        } else {
            inFlightProjectId = "new"
            action = "createProject"
        }
        defer { inFlightProjectId = nil }
        do {
            _ = try await APIClient.shared.call(action, params: params, as: AnyJSON.self)
            toast = .success(ErrorLocalization.localize(
                existing != nil ? "hp.projects.updated_ok" : "hp.projects.created_ok"
            ))
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
