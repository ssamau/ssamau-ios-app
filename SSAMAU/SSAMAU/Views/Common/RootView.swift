import SwiftUI

/// Role-gated root. Switches on `SessionStore.state` to decide which tab
/// bar (or login) to show. See spec §7.
///
/// Until Phase 1+ ships real screens, this renders placeholders so the
/// foundation can be exercised end-to-end.
struct RootView: View {
    @EnvironmentObject var session: SessionStore

    var body: some View {
        switch session.state {
        case .loggedOut:
            LoginView()
        case .loggedIn(let user):
            if user.hasAdminScope {
                PlaceholderView(
                    title: "Admin",
                    subtitle: "AdminTabView — signed in as \(user.name)"
                )
            } else if user.isHead {
                PlaceholderView(
                    title: "Head",
                    subtitle: "HeadTabView — signed in as \(user.name)"
                )
            } else {
                PlaceholderView(
                    title: "Member",
                    subtitle: "MemberTabView — signed in as \(user.name)"
                )
            }
        }
    }
}

private struct PlaceholderView: View {
    let title: String
    let subtitle: String

    var body: some View {
        VStack(spacing: 16) {
            Image("SSAMLogo")
                .resizable()
                .scaledToFit()
                .frame(width: 120, height: 120)
            Text(title)
                .font(.largeTitle.weight(.semibold))
                .foregroundStyle(Color("Ink"))
            Text(subtitle)
                .font(.callout)
                .foregroundStyle(Color("InkMuted"))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color("Background"))
    }
}

#Preview {
    RootView().environmentObject(SessionStore.shared)
}
