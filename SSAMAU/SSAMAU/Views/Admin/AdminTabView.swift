import SwiftUI

/// Admin-mode tab bar — spec §10. Five tabs + a "More" menu for the
/// long tail (Projects, Attendance, Applications, Thanks, Certs,
/// Committees, Advisors, Accounts, Interest, Support, Dev, Profile).
struct AdminTabView: View {
    @EnvironmentObject private var session: SessionStore

    private enum Tab: Hashable {
        case dashboard, members, opportunities, hours, more
    }

    @State private var selection: Tab = .dashboard
    @State private var morePath = NavigationPath()

    var body: some View {
        TabView(selection: tabSelectionBinding) {
            // AdminDashboardView is the only view here that doesn't wrap
            // itself in a NavigationStack — wrap it so the title + chrome
            // render correctly. The others (HeadMembersView,
            // HeadOpportunitiesView, HoursApprovalView) all wrap themselves,
            // and double-wrapping would corrupt the destination registry
            // (see ios-app-session-handoff-2.md — same trap that bit
            // ProfileView in Phase 3).
            NavigationStack { AdminDashboardView() }
                .tabItem {
                    Label(LocalizedStringKey("ap.tabs.dashboard"),
                          systemImage: "chart.bar")
                }
                .tag(Tab.dashboard)

            HeadMembersView(adminMode: true)
                .tabItem {
                    Label(LocalizedStringKey("ap.tabs.members"),
                          systemImage: "person.2")
                }
                .tag(Tab.members)

            HeadOpportunitiesView()
                .tabItem {
                    Label(LocalizedStringKey("ap.tabs.opportunities"),
                          systemImage: "list.bullet.rectangle")
                }
                .tag(Tab.opportunities)

            HoursApprovalView(mode: .adminFinalApproval)
                .tabItem {
                    Label(LocalizedStringKey("ap.tabs.hours"),
                          systemImage: "checkmark.seal")
                }
                .tag(Tab.hours)

            AdminMoreView(path: $morePath)
                .tabItem {
                    Label(LocalizedStringKey("ap.tabs.more"),
                          systemImage: "ellipsis.circle")
                }
                .tag(Tab.more)
        }
        .tint(Color.ssGreen)
    }

    /// Mirrors HeadTabView.tabSelectionBinding — same flicker-free reset
    /// pattern (defer 400ms after leaving More, immediate pop on re-tap,
    /// catch-up reset on quick re-entry).
    private var tabSelectionBinding: Binding<Tab> {
        Binding(
            get: { selection },
            set: { newValue in
                let wasOnMore = selection == .more
                selection = newValue
                if wasOnMore && newValue != .more {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                        if selection != .more {
                            morePath = NavigationPath()
                        }
                    }
                } else if wasOnMore && newValue == .more {
                    morePath = NavigationPath()
                } else if !wasOnMore && newValue == .more && !morePath.isEmpty {
                    morePath = NavigationPath()
                }
            }
        )
    }
}

// MARK: - More menu

enum AdminMoreDestination: Hashable {
    case projects, attendance, applications, thanks, certs
    case committees, advisors, accounts, interest
    case support, dev, profile
}

private struct AdminMoreView: View {
    @EnvironmentObject private var session: SessionStore
    @Binding var path: NavigationPath
    @State private var showSignOutConfirm: Bool = false

    var body: some View {
        NavigationStack(path: $path) {
            ScrollView {
                VStack(spacing: 10) {
                    row(.projects,     icon: "folder.fill",          key: "ap.tabs.projects")
                    // Attendance intentionally NOT in admin More:
                    // head.attendance.* is head-or-superadmin scoped on
                    // the server, so the admin (presidency) hits 403.
                    // Heads handle attendance per-committee; cross-club
                    // attendance review is via the web for now.
                    row(.applications, icon: "doc.text.fill",        key: "ap.tabs.applications")
                    row(.thanks,       icon: "envelope.badge",       key: "ap.tabs.thanks")
                    row(.certs,        icon: "rosette",              key: "ap.tabs.certs")
                    row(.interest,     icon: "hand.raised",          key: "ap.tabs.interest")
                    row(.committees,   icon: "building.2",           key: "ap.tabs.committees")
                    row(.advisors,     icon: "person.2.crop.square.stack", key: "ap.tabs.advisors")
                    row(.accounts,     icon: "key.fill",             key: "ap.tabs.accounts")
                    row(.support,      icon: "lifepreserver",        key: "ap.tabs.support")
                    if session.currentUser?.isSuperadmin == true {
                        row(.dev,      icon: "wrench.and.screwdriver",
                            key: "ap.tabs.dev")
                    }
                    row(.profile,      icon: "person.circle",        key: "hp.tabs.profile")
                    // Sign out sits directly under Profile so the
                    // dev/admin can reach it even when their account
                    // has no linked member row (ProfileView fails to
                    // load for member-less accounts since members.getOwn
                    // returns 404). Same pattern as the in-Profile
                    // sign out button — confirms before tearing down
                    // the session.
                    signOutRow
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
            }
            .background(Color.ssCream)
            .navigationTitle(LocalizedStringKey("ap.tabs.more"))
            .navigationBarTitleDisplayMode(.inline)
            .navigationDestination(for: AdminMoreDestination.self) { dest in
                switch dest {
                case .projects:     HeadProjectsView(adminMode: true)
                case .attendance:   AttendanceView()
                case .applications: ApplicationsView(adminMode: true)
                case .thanks:       ThanksView(adminMode: true)
                case .certs:        HeadCertsView(adminMode: true)
                case .interest:     InterestTriageView()
                case .committees:   CommitteesView()
                case .advisors:     AdvisorsView()
                case .accounts:     AccountsView()
                case .support:      AdminSupportView()
                case .dev:          DevPagesView()
                case .profile:      ProfileView(nestedInNavStack: true)
                }
            }
            .confirmationDialog(
                LocalizedStringKey("common.logout_confirm"),
                isPresented: $showSignOutConfirm,
                titleVisibility: .visible
            ) {
                Button(LocalizedStringKey("common.logout"), role: .destructive) {
                    Task { await session.signOut() }
                }
                Button(LocalizedStringKey("common.cancel"), role: .cancel) {}
            }
        }
    }

    private func row(_ dest: AdminMoreDestination, icon: String, key: String) -> some View {
        NavigationLink(value: dest) {
            menuRowLabel(icon: icon, key: key,
                         tint: Color.ssGold, textColor: Color.ssCharcoal)
        }
        .buttonStyle(.plain)
    }

    private var signOutRow: some View {
        Button(role: .destructive) {
            showSignOutConfirm = true
        } label: {
            menuRowLabel(icon: "rectangle.portrait.and.arrow.right",
                         key: "common.logout",
                         tint: .red, textColor: .red,
                         showChevron: false,
                         borderColor: .red.opacity(0.35))
        }
        .buttonStyle(.plain)
    }

    /// Shared row chrome — extracted so Sign Out can reuse the same
    /// padding + corner radius + border treatment as the navigation
    /// rows, with red tint instead of gold.
    private func menuRowLabel(
        icon: String, key: String,
        tint: Color, textColor: Color,
        showChevron: Bool = true,
        borderColor: Color = Color.ssGold.opacity(0.4)
    ) -> some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(tint)
                .frame(width: 32)
            Text(LocalizedStringKey(key))
                .font(.ssBody)
                .foregroundStyle(textColor)
            Spacer()
            if showChevron {
                Image(systemName: "chevron.forward")
                    .foregroundStyle(Color.ssGrey)
                    .font(.caption)
            }
        }
        .padding(14)
        .background(Color.ssPale)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(borderColor, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}
