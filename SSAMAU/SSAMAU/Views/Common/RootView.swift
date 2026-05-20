import SwiftUI

/// Role-gated root. Switches on `SessionStore.state` to decide which tab
/// bar (or login) to show. See spec §7.
///
/// Until Phase 3/4 ship the head + admin tab views, those roles fall
/// back to a branded placeholder so the foundation can be exercised
/// end-to-end without crashing on a missing view.
struct RootView: View {
    @EnvironmentObject var session: SessionStore

    var body: some View {
        switch session.state {
        case .loggedOut:
            LoginView()
        case .loggedIn(let user):
            if user.hasAdminScope {
                PlaceholderView(
                    latin: "Admin",
                    title: "Admin",
                    subtitle: "AdminTabView — signed in as \(user.displayName)"
                )
            } else if user.isHead {
                HeadTabView()
            } else {
                MemberTabView()
            }
        }
    }
}

private struct PlaceholderView: View {
    let latin: String
    let title: String
    let subtitle: String

    var body: some View {
        VStack(spacing: 16) {
            Image("SSAMLogo")
                .resizable()
                .scaledToFit()
                .frame(width: 120, height: 120)
            Text(latin)
                .font(.ssLatinLabel)
                .tracking(2)
                .foregroundStyle(Color.ssGold)
            Text(title)
                .font(.ssDisplay)
                .foregroundStyle(Color.ssGreen)
            GoldRule(width: 40)
            Text(subtitle)
                .font(.ssCaption)
                .foregroundStyle(Color.ssGrey)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.ssCream)
    }
}

#Preview {
    RootView().environmentObject(SessionStore.shared)
}
