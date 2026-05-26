import Foundation
import Combine

@MainActor
final class ThanksViewModel: ObservableObject {
    @Published var rows: [ThanksRow] = []
    @Published var projects: [Project] = []
    @Published var members: [MemberAccountRow] = []
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    @Published var toast: Toast?
    @Published var searchText: String = ""
    @Published var inFlight: Bool = false

    var filteredRows: [ThanksRow] {
        let q = searchText.trimmingCharacters(in: .whitespaces).lowercased()
        guard !q.isEmpty else { return rows }
        return rows.filter { r in
            let hay = [r.displayRecipient, r.projectName, r.subject, r.recipientEmail]
                .compactMap { $0 }.joined(separator: " ").lowercased()
            return hay.contains(q)
        }
    }

    func load(committeeId: String?) async {
        isLoading = true
        defer { isLoading = false }
        async let t: [ThanksRow] = (try? APIClient.shared.call("thanks.list", as: [ThanksRow].self)) ?? []
        async let p: [Project]   = (try? APIClient.shared.call("getProjects", as: [Project].self)) ?? []
        async let m: [MemberAccountRow] = (try? APIClient.shared.call("users.list", as: [MemberAccountRow].self)) ?? []
        let (rt, rp, rm) = await (t, p, m)
        self.rows = rt
        self.projects = rp.filter { committeeId == nil || $0.owningCommitteeId == committeeId }
        self.members = rm
    }

    func sendSingle(
        projectId: String?, memberId: String?, email: String,
        subject: String, message: String
    ) async -> Bool {
        guard !inFlight else { return false }
        inFlight = true
        defer { inFlight = false }
        var data: [String: Any] = ["recipient_email": email, "message": message]
        if !subject.isEmpty       { data["subject"]    = subject }
        if let p = projectId      { data["project_id"] = p }
        if let m = memberId       { data["member_id"]  = m }
        do {
            _ = try await APIClient.shared.call(
                "thanks.send", params: ["data": data], as: AnyJSON.self
            )
            toast = .success(ErrorLocalization.localize("hp.thanks.sent_ok"))
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

    func sendBulk(projectId: String, subject: String, message: String) async -> Bool {
        guard !inFlight else { return false }
        inFlight = true
        defer { inFlight = false }
        var params: [String: Any] = ["project_id": projectId, "message": message]
        if !subject.isEmpty { params["subject"] = subject }
        do {
            _ = try await APIClient.shared.call(
                "thanks.bulkSend", params: params, as: AnyJSON.self
            )
            toast = .success(ErrorLocalization.localize("hp.thanks.sent_ok"))
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
