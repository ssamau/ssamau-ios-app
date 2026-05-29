import SwiftUI

/// Admin-mode primary navigation — spec §10.
///
/// Adaptive:
///   - Compact width (iPhone, iPad in narrow Split View / Slide Over):
///     bottom `TabView` with 5 primary tabs + a `More` tab whose
///     navigation is reset on tab transitions via the
///     `tabSelectionBinding` state machine below. **This iPhone path
///     is byte-identical to build 76 and earlier** — the 9-iteration
///     More-tab flicker fix is preserved unchanged.
///   - Regular width (iPad fullscreen, Mac Catalyst): persistent left
///     sidebar with all destinations flat across two sections
///     (primary + More) plus a destructive Sign Out row at the
///     bottom. Dev row only appears for superadmins, same as the
///     iPhone More menu.
///
/// Same shape as HeadTabView — see that file's header for the
/// rationale on why the two paths use separate @State (different
/// destination shapes; size-class transitions don't migrate state).
///
/// Attendance is intentionally absent from admin nav in both layouts:
/// `head.attendance.*` server scopes are head-or-superadmin only, so
/// the admin (presidency) hits 403. Heads handle attendance per
/// committee; cross-club review goes through the web for now.
struct AdminTabView: View {
    @Environment(\.horizontalSizeClass) private var hSizeClass

    var body: some View {
        if hSizeClass == .regular {
            AdminIPadSidebarView()
        } else {
            iphoneTabBar
        }
    }

    // MARK: - iPhone / compact: existing TabView (untouched from build 76)

    @EnvironmentObject private var session: SessionStore

    private enum Tab: Hashable {
        case dashboard, members, opportunities, hours, more
    }

    @State private var selection: Tab = .dashboard
    @State private var morePath = NavigationPath()

    private var iphoneTabBar: some View {
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

// MARK: - iPad / regular: NavigationSplitView sidebar

/// Flat sidebar destination — all admin screens are first-class
/// items, organised into two sections. Dev appears only when the
/// signed-in user is a superadmin, gated at row-render time so the
/// enum case can exist universally. Sign Out is a Button outside
/// the selection set (action, not destination).
private enum AdminSidebarTab: Hashable {
    case dashboard, members, opportunities, hours
    case projects, applications, thanks, certs, interest
    case committees, advisors, accounts, support, dev, profile
}

/// The iPad-only admin layout. Same shape as HeadIPadSidebarView —
/// see that struct's docs for the Optional-binding pattern and the
/// nestedInNavStack: true rationale for Profile.
private struct AdminIPadSidebarView: View {
    @EnvironmentObject private var session: SessionStore
    @State private var selection: AdminSidebarTab = .dashboard
    @State private var showSignOutConfirm: Bool = false

    private var selectionBinding: Binding<AdminSidebarTab?> {
        Binding(
            get: { selection },
            set: { newValue in
                if let new = newValue { selection = new }
            }
        )
    }

    /// Sidebar order for ⌘-number shortcuts — matches the visual row
    /// order in `sidebarList`. Admin has more than 10 destinations, so
    /// only the first 10 get a shortcut (the `numbered` helper stops at
    /// ⌘0); the top-10 are the highest-traffic, and `dev` / `profile`
    /// (the tail) stay click-only. `dev` is omitted here so numbering is
    /// identical for superadmins and regular admins.
    private let orderedTabs: [AdminSidebarTab] = [
        .dashboard, .members, .opportunities, .hours,
        .projects, .applications, .thanks, .certs, .interest,
        .committees, .advisors, .accounts, .support, .profile,
    ]

    var body: some View {
        NavigationSplitView {
            sidebarList
                .navigationTitle(LocalizedStringKey("brand.ssam_full"))
                .scrollContentBackground(.hidden)
                .background(Color.ssCream)
        } detail: {
            sidebarDetail
        }
        .tint(Color.ssGreen)
        // ⌘1…⌘9/⌘0 jump to the first 10 sidebar destinations (iPad with
        // a hardware keyboard / Mac Catalyst). iPhone TabView path is
        // untouched — this struct only renders at regular width.
        .ssKeyboardShortcuts(
            SSKeyboardShortcut.numbered(orderedTabs) { selection = $0 }
        )
        .alert(
            LocalizedStringKey("common.logout_confirm"),
            isPresented: $showSignOutConfirm
        ) {
            Button(LocalizedStringKey("common.cancel"), role: .cancel) {}
            Button(LocalizedStringKey("common.logout"), role: .destructive) {
                Task { await session.signOut() }
            }
        } message: {
            Text(LocalizedStringKey("common.logout_message"))
        }
    }

    private var sidebarList: some View {
        List(selection: selectionBinding) {
            // Primary — matches the 4 primary tabs on iPhone (Dashboard
            // / Members / Opps / Hours).
            Section {
                row(.dashboard,     "ap.tabs.dashboard",     "chart.bar")
                row(.members,       "ap.tabs.members",       "person.2")
                row(.opportunities, "ap.tabs.opportunities", "list.bullet.rectangle")
                row(.hours,         "ap.tabs.hours",         "checkmark.seal")
            }

            // "More" — order matches AdminMoreView's iPhone row order so
            // muscle memory survives the size-class transition.
            // Attendance intentionally absent (see file header).
            Section {
                row(.projects,     "ap.tabs.projects",     "folder.fill")
                row(.applications, "ap.tabs.applications", "doc.text.fill")
                row(.thanks,       "ap.tabs.thanks",       "envelope.badge")
                row(.certs,        "ap.tabs.certs",        "rosette")
                row(.interest,     "ap.tabs.interest",     "hand.raised")
                row(.committees,   "ap.tabs.committees",   "building.2")
                row(.advisors,     "ap.tabs.advisors",     "person.2.crop.square.stack")
                row(.accounts,     "ap.tabs.accounts",     "key.fill")
                row(.support,      "ap.tabs.support",      "lifepreserver")
                if session.currentUser?.isSuperadmin == true {
                    row(.dev,      "ap.tabs.dev",          "wrench.and.screwdriver")
                }
                row(.profile,      "hp.tabs.profile",      "person.circle")
            } header: {
                Text(LocalizedStringKey("ap.tabs.more"))
                    .font(.ssLatinLabel)
                    .tracking(1.5)
                    .foregroundStyle(Color.ssGold)
            }

            // Sign Out — destructive, not selectable.
            Section {
                Button(role: .destructive) {
                    showSignOutConfirm = true
                } label: {
                    Label {
                        Text(LocalizedStringKey("common.logout"))
                            .font(.ssBody)
                            .foregroundStyle(.red)
                    } icon: {
                        Image(systemName: "rectangle.portrait.and.arrow.right")
                            .foregroundStyle(.red)
                    }
                }
                .ssHover()
            }
        }
        .listStyle(.sidebar)
    }

    private func row(_ tag: AdminSidebarTab, _ key: String, _ icon: String) -> some View {
        Label {
            Text(LocalizedStringKey(key))
                .font(.ssBody)
                .foregroundStyle(Color.ssCharcoal)
        } icon: {
            Image(systemName: icon)
                .foregroundStyle(Color.ssGold)
        }
        .tag(tag)
        .ssHover()
    }

    /// Detail column. Each branch returns the same fully-wrapped view
    /// the iPhone tab bar / More menu pushes. Profile uses
    /// `nestedInNavStack: true` because NavigationSplitView's detail
    /// column already provides nav chrome.
    ///
    /// If the user was on .dev when their superadmin flag flipped off
    /// (e.g. role demotion mid-session) the switch falls through to the
    /// EmptyView default — they then can't navigate back to it because
    /// the row hides. Acceptable: extremely rare, recoverable by tapping
    /// any other row.
    @ViewBuilder
    private var sidebarDetail: some View {
        switch selection {
        case .dashboard:     NavigationStack { AdminDashboardView() }
        case .members:       HeadMembersView(adminMode: true)
        case .opportunities: HeadOpportunitiesView()
        case .hours:         HoursApprovalView(mode: .adminFinalApproval)
        case .projects:      HeadProjectsView(adminMode: true)
        case .applications:  ApplicationsView(adminMode: true)
        case .thanks:        ThanksView(adminMode: true)
        case .certs:         HeadCertsView(adminMode: true)
        case .interest:      InterestTriageView()
        case .committees:    CommitteesView()
        case .advisors:      AdvisorsView()
        case .accounts:      AccountsView()
        case .support:       AdminSupportView()
        case .dev:
            if session.currentUser?.isSuperadmin == true {
                DevPagesView()
            } else {
                EmptyView()
            }
        case .profile:       ProfileView(nestedInNavStack: true)
        }
    }
}

// MARK: - "More" tab — iPhone path (unchanged)

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
                .ipadContentWidth()
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
            // System-style centered alert (NOT confirmationDialog —
            // that one renders as a small bottom action sheet on
            // iPhone and feels lightweight for a destructive action
            // like sign out). The alert API gives us the same modal
            // chrome iOS uses for "Applying this setting will restart
            // your iPhone" — full overlay, centered card, dimmed
            // background, side-by-side Cancel/destructive buttons.
            .alert(
                LocalizedStringKey("common.logout_confirm"),
                isPresented: $showSignOutConfirm
            ) {
                Button(LocalizedStringKey("common.cancel"), role: .cancel) {}
                Button(LocalizedStringKey("common.logout"), role: .destructive) {
                    Task { await session.signOut() }
                }
            } message: {
                Text(LocalizedStringKey("common.logout_message"))
            }
        }
    }

    private func row(_ dest: AdminMoreDestination, icon: String, key: String) -> some View {
        NavigationLink(value: dest) {
            menuRowLabel(icon: icon, key: key,
                         tint: Color.ssGold, textColor: Color.ssCharcoal)
        }
        .buttonStyle(.plain)
        .ssHover()
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
        .ssHover()
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
