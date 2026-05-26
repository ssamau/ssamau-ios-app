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
        guard inFlightMemberId == nil else { return }
        inFlightMemberId = row.memberId
        defer { inFlightMemberId = nil }
        do {
            _ = try await APIClient.shared.call(
                "auth.invite.byEmail",
                params: ["member_id": row.memberId],
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
        guard inFlightMemberId == nil else { return }
        inFlightMemberId = row.memberId
        defer { inFlightMemberId = nil }
        do {
            let resp = try await APIClient.shared.call(
                "auth.invite.byPin",
                params: ["member_id": row.memberId],
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
        guard inFlightMemberId == nil else { return }
        inFlightMemberId = row.memberId
        defer { inFlightMemberId = nil }
        do {
            _ = try await APIClient.shared.call(
                "auth.invite.revoke",
                params: ["member_id": row.memberId],
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
