import Foundation
import Combine

@MainActor
final class AdvisorsViewModel: ObservableObject {
    @Published var rows: [Advisor] = []
    @Published var isLoading: Bool = false
    @Published var toast: Toast?
    @Published var inFlightId: String?

    func load() async {
        isLoading = true
        defer { isLoading = false }
        do {
            rows = try await APIClient.shared.call("getAdvisors", as: [Advisor].self)
        } catch let apiError as APIError where !apiError.isCancellation {
            toast = .error(apiError.localizedMessage)
        } catch { }
    }

    func save(
        existing: Advisor?, fullName: String, advisoryRole: String,
        email: String, phone: String, status: String, notes: String
    ) async -> Bool {
        let key = existing.map { String($0.id) } ?? "new"
        inFlightId = key
        defer { inFlightId = nil }
        var data: [String: Any] = ["full_name": fullName, "status": status]
        if !advisoryRole.isEmpty { data["advisory_role"] = advisoryRole }
        if !email.isEmpty        { data["email"]         = email }
        if !phone.isEmpty        { data["phone"]         = phone }
        if !notes.isEmpty        { data["notes"]         = notes }
        var params: [String: Any] = ["data": data]
        let action: String
        if let e = existing { params["id"] = e.id; action = "updateAdvisor" }
        else { action = "createAdvisor" }
        do {
            _ = try await APIClient.shared.call(action, params: params, as: AnyJSON.self)
            toast = .success(ErrorLocalization.localize("ap.advisors.saved_ok"))
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

    func delete(_ advisor: Advisor) async {
        inFlightId = String(advisor.id)
        defer { inFlightId = nil }
        do {
            _ = try await APIClient.shared.call(
                "deleteAdvisor", params: ["id": advisor.id], as: AnyJSON.self
            )
            toast = .success(ErrorLocalization.localize("ap.advisors.deleted_ok"))
            rows.removeAll { $0.id == advisor.id }
        } catch let apiError as APIError where !apiError.isCancellation {
            toast = .error(apiError.localizedMessage)
        } catch {
            toast = .error(ErrorLocalization.localize("err.unknown"))
        }
    }
}
