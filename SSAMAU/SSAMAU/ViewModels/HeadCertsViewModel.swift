import Foundation
import Combine

@MainActor
final class HeadCertsViewModel: ObservableObject {
    @Published var rows: [Certificate] = []
    @Published var projects: [Project] = []
    @Published var members: [MemberAccountRow] = []
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    @Published var toast: Toast?
    @Published var searchText: String = ""
    @Published var inFlight: Bool = false

    var filteredRows: [Certificate] {
        let q = searchText.trimmingCharacters(in: .whitespaces).lowercased()
        guard !q.isEmpty else { return rows }
        return rows.filter { c in
            let hay = [c.displayRecipient, c.projectName, c.role, c.certCode]
                .compactMap { $0 }.joined(separator: " ").lowercased()
            return hay.contains(q)
        }
    }

    func load(committeeId: String?) async {
        isLoading = true
        defer { isLoading = false }
        async let c: [Certificate]      = (try? APIClient.shared.call("certs.list", as: [Certificate].self)) ?? []
        async let p: [Project]          = (try? APIClient.shared.call("getProjects", as: [Project].self)) ?? []
        async let m: [MemberAccountRow] = (try? APIClient.shared.call("users.list", as: [MemberAccountRow].self)) ?? []
        let (rc, rp, rm) = await (c, p, m)
        self.rows = rc
        self.projects = rp.filter { committeeId == nil || $0.owningCommitteeId == committeeId }
        self.members = rm
    }

    func issueSingle(
        projectId: String, memberId: String?, recipientName: String,
        recipientEmail: String, role: String, hours: Double?
    ) async -> Bool {
        guard !inFlight else { return false }
        inFlight = true
        defer { inFlight = false }
        var data: [String: Any] = ["project_id": projectId]
        if let m = memberId, !m.isEmpty       { data["member_id"]       = m }
        if !recipientName.isEmpty             { data["recipient_name"]  = recipientName }
        if !recipientEmail.isEmpty            { data["recipient_email"] = recipientEmail }
        if !role.isEmpty                      { data["role"]            = role }
        if let h = hours                      { data["hours"]           = h }
        do {
            _ = try await APIClient.shared.call(
                "certs.issue", params: ["data": data], as: AnyJSON.self
            )
            toast = .success(ErrorLocalization.localize("hp.certs.issued_ok"))
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

    func issueBulk(projectId: String, role: String) async -> Bool {
        guard !inFlight else { return false }
        inFlight = true
        defer { inFlight = false }
        var params: [String: Any] = ["project_id": projectId]
        if !role.isEmpty { params["role"] = role }
        do {
            _ = try await APIClient.shared.call(
                "certs.bulkIssue", params: params, as: AnyJSON.self
            )
            toast = .success(ErrorLocalization.localize("hp.certs.issued_ok"))
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
