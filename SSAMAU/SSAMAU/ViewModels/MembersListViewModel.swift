import Foundation
import Combine

/// Shared list ViewModel for Head's "own committee" view + Admin's
/// cross-committee view. Server's users.list auto-scopes based on
/// caller role, so the model is the same.
@MainActor
final class MembersListViewModel: ObservableObject {
    @Published var rows: [MemberAccountRow] = []
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    @Published var toast: Toast?

    @Published var searchText: String = ""
    @Published var statusFilter: StatusFilter = .all
    @Published var pinInviteResult: PinInviteResult?
    @Published var inFlightMemberId: String?

    enum StatusFilter: String, CaseIterable, Identifiable {
        case all, active, pendingInvite, noAccount
        var id: String { rawValue }
        var labelKey: String {
            switch self {
            case .all:           return "hp.members.filter_all"
            case .active:        return "hp.members.filter_active"
            case .pendingInvite: return "hp.members.filter_pending"
            case .noAccount:     return "hp.members.filter_no_account"
            }
        }
    }

    struct PinInviteResult: Identifiable {
        let id = UUID()
        let memberName: String
        let pin: String
        let expiresHours: Int
    }

    var filteredRows: [MemberAccountRow] {
        let q = searchText.trimmingCharacters(in: .whitespaces).lowercased()
        return rows.filter { row in
            switch statusFilter {
            case .all: break
            case .active where row.state != .active: return false
            case .pendingInvite where row.state != .pendingInvite: return false
            case .noAccount where row.state != .noAccount: return false
            default: break
            }
            guard !q.isEmpty else { return true }
            let hay = [
                row.memberFullName, row.memberPreferredName,
                row.username, row.authEmail, row.memberCommitteeName,
                row.memberClubRole, row.memberId,
            ].compactMap { $0 }.joined(separator: " ").lowercased()
            return hay.contains(q)
        }
    }

    func load() async {
        isLoading = true
        defer { isLoading = false }
        do {
            let fetched: [MemberAccountRow] = try await APIClient.shared.call(
                "users.list",
                as: [MemberAccountRow].self
            )
            self.rows = fetched
            self.errorMessage = nil
        } catch let apiError as APIError {
            if apiError.isCancellation { return }
            #if DEBUG
            print("⚠️ MembersListViewModel.load APIError: \(apiError)")
            #endif
            self.errorMessage = apiError.localizedMessage
        } catch {
            #if DEBUG
            print("⚠️ MembersListViewModel.load error: \(error)")
            #endif
            self.errorMessage = ErrorLocalization.localize("err.unknown")
        }
    }

    func inviteByEmail(_ row: MemberAccountRow) async {
        guard inFlightMemberId == nil, let memberId = row.memberId else { return }
        inFlightMemberId = memberId
        defer { inFlightMemberId = nil }
        do {
            _ = try await APIClient.shared.call(
                "auth.invite.byEmail",
                params: ["member_id": memberId],
                as: EmptyResponse.self
            )
            toast = .success(ErrorLocalization.localize("hp.members.invite_email_ok"))
            await load()
        } catch let apiError as APIError {
            if apiError.isCancellation { return }
            toast = .error(apiError.localizedMessage)
        } catch {
            toast = .error(ErrorLocalization.localize("err.unknown"))
        }
    }

    func inviteByPin(_ row: MemberAccountRow) async {
        guard inFlightMemberId == nil, let memberId = row.memberId else { return }
        inFlightMemberId = memberId
        defer { inFlightMemberId = nil }
        do {
            let resp = try await APIClient.shared.call(
                "auth.invite.byPin",
                params: ["member_id": memberId],
                as: PinInviteResponse.self
            )
            pinInviteResult = PinInviteResult(
                memberName: resp.memberName ?? row.displayName,
                pin: resp.pin,
                expiresHours: resp.expiresInHours ?? 72
            )
            await load()
        } catch let apiError as APIError {
            if apiError.isCancellation { return }
            toast = .error(apiError.localizedMessage)
        } catch {
            toast = .error(ErrorLocalization.localize("err.unknown"))
        }
    }

    func revokeInvite(_ row: MemberAccountRow) async {
        guard inFlightMemberId == nil, let memberId = row.memberId else { return }
        inFlightMemberId = memberId
        defer { inFlightMemberId = nil }
        do {
            _ = try await APIClient.shared.call(
                "auth.invite.revoke",
                params: ["member_id": memberId],
                as: EmptyResponse.self
            )
            toast = .success(ErrorLocalization.localize("hp.members.revoked_ok"))
            await load()
        } catch let apiError as APIError {
            if apiError.isCancellation { return }
            toast = .error(apiError.localizedMessage)
        } catch {
            toast = .error(ErrorLocalization.localize("err.unknown"))
        }
    }

    // MARK: - Admin: manual account create / update / delete

    /// AccountsView uses these to provision accounts outside the
    /// invite/PIN flow. Gated server-side: users.create / users.update
    /// require admin tier, users.delete requires admin tier with
    /// superadmin guards on cross-tier ops. Surfaces server errors
    /// (e.g. err.business.username_taken) via toast.

    @discardableResult
    func createAccount(
        username: String, password: String,
        memberId: String?, accessLevel: String
    ) async -> Bool {
        guard !username.isEmpty, !password.isEmpty else { return false }
        var data: [String: Any] = [
            "username":     username,
            "password":     password,
            "access_level": accessLevel,
        ]
        if let m = memberId, !m.isEmpty { data["member_id"] = m }
        do {
            _ = try await APIClient.shared.call(
                "users.create",
                params: ["data": data],
                as: AnyJSON.self
            )
            toast = .success(ErrorLocalization.localize("ap.accounts.created_ok"))
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
    func updateAccount(
        accountId: Int, username: String?,
        memberId: String??, accessLevel: String?
    ) async -> Bool {
        var data: [String: Any] = ["id": accountId]
        if let u = username, !u.isEmpty { data["username"] = u }
        if let a = accessLevel { data["access_level"] = a }
        // Three-state member_id: not-supplied (keep existing),
        // supplied non-nil (set), supplied nil (unlink).
        if let memberWrapper = memberId {
            if let m = memberWrapper, !m.isEmpty {
                data["member_id"] = m
            } else {
                data["member_id"] = NSNull()
            }
        }
        do {
            _ = try await APIClient.shared.call(
                "users.update",
                params: ["data": data],
                as: AnyJSON.self
            )
            toast = .success(ErrorLocalization.localize("ap.accounts.updated_ok"))
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
    func deleteAccount(accountId: Int) async -> Bool {
        do {
            _ = try await APIClient.shared.call(
                "users.delete",
                params: ["id": accountId],
                as: AnyJSON.self
            )
            toast = .success(ErrorLocalization.localize("ap.accounts.deleted_ok"))
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

    private struct PinInviteResponse: Decodable {
        let pin: String
        let memberName: String?
        let expiresInHours: Int?
        enum CodingKeys: String, CodingKey {
            case pin
            case memberName     = "member_name"
            case expiresInHours = "expires_in_hours"
        }
    }
}
