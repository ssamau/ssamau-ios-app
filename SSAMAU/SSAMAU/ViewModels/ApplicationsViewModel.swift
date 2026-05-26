import Foundation
import Combine

@MainActor
final class ApplicationsViewModel: ObservableObject {
    @Published var rows: [Application] = []
    @Published var committees: [Committee] = []
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    @Published var toast: Toast?

    @Published var statusFilter: StatusFilter = .pending
    @Published var inFlightId: String?

    enum StatusFilter: String, CaseIterable, Identifiable {
        case pending, all
        var id: String { rawValue }
        var labelKey: String {
            switch self {
            case .pending: return "hp.apps.filter_pending"
            case .all:     return "hp.apps.filter_all"
            }
        }
    }

    var filteredRows: [Application] {
        rows.filter { row in
            switch statusFilter {
            case .all:     return true
            case .pending:
                let s = row.status ?? ""
                return s != "Accepted" && s != "Rejected"
            }
        }
    }

    func load() async {
        isLoading = true
        defer { isLoading = false }
        async let apps: [Application] = (try? APIClient.shared.call(
            "applications.list", as: [Application].self
        )) ?? []
        async let coms: [Committee] = (try? APIClient.shared.call(
            "getCommittees", as: [Committee].self
        )) ?? []
        let (a, c) = await (apps, coms)
        self.rows = a
        self.committees = c
        self.errorMessage = nil
    }

    func accept(_ application: Application, note: String?) async {
        await mutate(application: application, action: "applications.accept",
                     params: noteParams(application.id, note),
                     successKey: "hp.apps.accepted_ok")
    }
    func requestInterview(_ application: Application, note: String?) async {
        await mutate(application: application, action: "applications.requestInterview",
                     params: noteParams(application.id, note),
                     successKey: "hp.apps.interview_ok")
    }
    func reject(_ application: Application, reason: String?) async {
        var p: [String: Any] = ["id": application.id]
        if let r = reason, !r.isEmpty { p["reason"] = r }
        await mutate(application: application, action: "applications.reject",
                     params: p, successKey: "hp.apps.rejected_ok")
    }
    func assignCommittee(_ application: Application, committeeId: String) async {
        let p: [String: Any] = ["id": application.id, "committee_id": committeeId]
        await mutate(application: application, action: "applications.assignCommittee",
                     params: p, successKey: "ap.apps.assigned_ok")
    }

    private func noteParams(_ id: String, _ note: String?) -> [String: Any] {
        var p: [String: Any] = ["id": id]
        if let n = note, !n.isEmpty { p["note"] = n }
        return p
    }

    private func mutate(application: Application, action: String,
                        params: [String: Any], successKey: String) async {
        guard inFlightId == nil else { return }
        inFlightId = application.id
        defer { inFlightId = nil }
        do {
            _ = try await APIClient.shared.call(action, params: params, as: AnyJSON.self)
            toast = .success(ErrorLocalization.localize(successKey))
            await load()
        } catch let apiError as APIError {
            if apiError.isCancellation { return }
            toast = .error(apiError.localizedMessage)
        } catch {
            toast = .error(ErrorLocalization.localize("err.unknown"))
        }
    }
}
