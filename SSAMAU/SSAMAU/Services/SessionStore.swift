import Foundation
import Combine

/// In-memory user session. The token lives in the Keychain; this object
/// holds the decoded profile + drives the role-gated root view.
/// See spec §7.
///
/// iOS 16 min target rules out the `@Observable` macro — falls back to
/// `ObservableObject` + `@Published`.
@MainActor
final class SessionStore: ObservableObject {
    enum State: Equatable {
        case loggedOut
        case loggedIn(SessionUser)
    }

    static let shared = SessionStore()

    @Published private(set) var state: State = .loggedOut

    private init() {}

    var currentUser: SessionUser? {
        if case let .loggedIn(user) = state { return user }
        return nil
    }

    /// Called after a successful login (legacy or Supabase-exchange path).
    func login(_ user: SessionUser, token: String) throws {
        try KeychainService.setToken(token)
        state = .loggedIn(user)
    }

    /// Called by `APIClient` on 401. Drops the token and forces the user
    /// back to `LoginView` via `RootView`'s switch on `state`.
    func handleUnauthorized() {
        KeychainService.deleteToken()
        state = .loggedOut
    }

    /// Explicit user-initiated sign-out. Best-effort call to
    /// `auth.signOut` with a 3-second cap so an offline device still
    /// clears local state. See spec §4.
    func signOut() async {
        let task = Task {
            try? await APIClient.shared.call("auth.signOut", as: EmptyResponse.self)
        }
        _ = try? await withThrowingTaskGroup(of: Void.self) { group in
            group.addTask { _ = await task.value }
            group.addTask {
                try await Task.sleep(nanoseconds: 3_000_000_000)
            }
            try await group.next()
            group.cancelAll()
        }
        KeychainService.deleteToken()
        state = .loggedOut
    }
}
