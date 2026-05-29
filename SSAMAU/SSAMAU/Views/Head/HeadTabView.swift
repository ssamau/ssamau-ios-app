import SwiftUI

/// Head-mode primary navigation — spec §7.
///
/// Adaptive:
///   - Compact width (iPhone, iPad in narrow Split View / Slide Over):
///     bottom `TabView` with 5 primary tabs + a `More` tab whose
///     navigation is reset on tab transitions via the
///     `tabSelectionBinding` state machine below. **This iPhone path
///     is byte-identical to build 75 and earlier** — the 9-iteration
///     More-tab flicker fix is preserved unchanged.
///   - Regular width (iPad fullscreen, Mac Catalyst): persistent left
///     sidebar with all 11 destinations flat across two sections
///     (primary + More) plus a destructive Sign Out row at the
///     bottom. Detail column on the right shows whichever sidebar row
///     is selected. No More tab needed — every destination is one
///     tap away.
///
/// The two paths use separate @State for selection because the
/// destination sets are different shapes (iPhone has 5 tabs incl.
/// .more; iPad has 11 individual rows). Size-class transitions (e.g.
/// rotating iPad or dragging into Split View) preserve state inside
/// each branch but don't try to migrate it between branches — if a
/// user is on iPad sidebar with Projects selected, then drags into
/// narrow Split View, the iPhone path defaults back to .dashboard.
/// Acceptable: rare gesture, no data loss.
struct HeadTabView: View {
    @Environment(\.horizontalSizeClass) private var hSizeClass

    var body: some View {
        if hSizeClass == .regular {
            HeadIPadSidebarView()
        } else {
            iphoneTabBar
        }
    }

    // MARK: - iPhone / compact: existing TabView (untouched)

    private enum Tab: Hashable {
        case dashboard, members, opportunities, hours, more
    }

    @State private var selection: Tab = .dashboard
    /// Bound to HeadMoreView's NavigationStack so we can pop it to root
    /// whenever the More tab is (re-)entered. iOS's default behaviour is
    /// to preserve per-tab navigation state across switches; for the
    /// More menu specifically that feels wrong — the tab IS the menu,
    /// so you expect the menu when you come back.
    @State private var morePath = NavigationPath()

    private var iphoneTabBar: some View {
        TabView(selection: tabSelectionBinding) {
            DashboardView()
                .tabItem {
                    Label(LocalizedStringKey("hp.tabs.dashboard"),
                          systemImage: "chart.bar")
                }
                .tag(Tab.dashboard)

            HeadMembersView()
                .tabItem {
                    Label(LocalizedStringKey("hp.tabs.members"),
                          systemImage: "person.2")
                }
                .tag(Tab.members)

            HeadOpportunitiesView()
                .tabItem {
                    Label(LocalizedStringKey("hp.tabs.opportunities"),
                          systemImage: "list.bullet.rectangle")
                }
                .tag(Tab.opportunities)

            HoursApprovalView(mode: .headQueue)
                .tabItem {
                    Label(LocalizedStringKey("hp.tabs.hours"),
                          systemImage: "clock.badge.checkmark")
                }
                .tag(Tab.hours)

            HeadMoreView(path: $morePath)
                .tabItem {
                    Label(LocalizedStringKey("hp.tabs.more"),
                          systemImage: "ellipsis.circle")
                }
                .tag(Tab.more)
        }
        .tint(Color.ssGreen)
    }

    /// Intercepts tab selection to reset the More tab's navigation path.
    /// Three branches cover every case without flicker:
    ///
    ///   1. **Leaving More** — defer the reset by 0.4s so it runs after
    ///      the tab transition completes AND the More tab is fully
    ///      off-screen. Re-check `selection` inside the deferred block
    ///      so we don't reset if the user has already come back.
    ///   2. **Re-tapping More while on a sub-page** — pop to root
    ///      immediately (iOS convention, user-visible animation).
    ///   3. **Entering More with a leftover path** (user came back
    ///      faster than the deferred reset fired) — reset immediately
    ///      so they don't see the stale sub-page. Rare; only if you
    ///      bounce tabs in under 0.4 seconds.
    private var tabSelectionBinding: Binding<Tab> {
        Binding(
            get: { selection },
            set: { newValue in
                let wasOnMore = selection == .more
                selection = newValue

                if wasOnMore && newValue != .more {
                    // 1. Leaving More — defer reset off-screen.
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                        if selection != .more {
                            morePath = NavigationPath()
                        }
                    }
                } else if wasOnMore && newValue == .more {
                    // 2. Re-tap on More — animated pop.
                    morePath = NavigationPath()
                } else if !wasOnMore && newValue == .more && !morePath.isEmpty {
                    // 3. Entered More before deferred reset could fire.
                    morePath = NavigationPath()
                }
            }
        )
    }
}

// MARK: - iPad / regular: NavigationSplitView sidebar

/// Flat sidebar destination — all 11 head screens are first-class
/// items here, organised into two sections. Sign Out is handled as
/// a separate `Button` outside the selectable list (it's an action,
/// not a destination, so it doesn't belong in the selection enum).
private enum HeadSidebarTab: Hashable {
    case dashboard, members, opportunities, hours
    case projects, attendance, applications, thanks, certs, profile
}

/// The iPad-only layout. Pulled out as its own struct so its
/// @State (selection + sign-out alert) doesn't pollute HeadTabView
/// and doesn't survive a size-class transition (which it shouldn't:
/// iPhone has different selection state).
private struct HeadIPadSidebarView: View {
    @EnvironmentObject private var session: SessionStore
    @State private var selection: HeadSidebarTab = .dashboard
    @State private var showSignOutConfirm: Bool = false

    /// Optional binding for List's selection. Same pattern as
    /// AdaptiveTabSidebar — iOS's List(selection:) on a single value
    /// needs an Optional binding even though we never want nil.
    private var selectionBinding: Binding<HeadSidebarTab?> {
        Binding(
            get: { selection },
            set: { newValue in
                if let new = newValue { selection = new }
            }
        )
    }

    /// Sidebar order — must match the visual row order in `sidebarList`
    /// so ⌘1…⌘0 line up with what the user sees top-to-bottom.
    private let orderedTabs: [HeadSidebarTab] = [
        .dashboard, .members, .opportunities, .hours,
        .projects, .attendance, .applications, .thanks, .certs, .profile,
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
        // ⌘1…⌘9/⌘0 jump straight to a sidebar destination (iPad with a
        // hardware keyboard / Mac Catalyst). iPhone TabView path is
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
            // Primary section — no header, matches the original 4
            // primary tabs on iPhone (Dashboard / Members / Opps /
            // Hours).
            Section {
                row(.dashboard,     "hp.tabs.dashboard",     "chart.bar")
                row(.members,       "hp.tabs.members",       "person.2")
                row(.opportunities, "hp.tabs.opportunities", "list.bullet.rectangle")
                row(.hours,         "hp.tabs.hours",         "clock.badge.checkmark")
            }

            // "More" section — what was hidden behind the More tab on
            // iPhone is now visible as first-class sidebar items here.
            Section {
                row(.projects,     "hp.tabs.projects",     "folder.fill")
                row(.attendance,   "hp.tabs.attendance",   "checkmark.rectangle")
                row(.applications, "hp.tabs.applications", "doc.text.fill")
                row(.thanks,       "hp.tabs.thanks",       "envelope.badge")
                row(.certs,        "hp.tabs.certs",        "doc.badge.gearshape")
                row(.profile,      "hp.tabs.profile",      "person.circle")
            } header: {
                Text(LocalizedStringKey("hp.tabs.more"))
                    .font(.ssLatinLabel)
                    .tracking(1.5)
                    .foregroundStyle(Color.ssGold)
            }

            // Sign Out section — destructive action, not a selectable
            // destination, so it's a Button instead of a tagged row.
            // The alert is owned by the parent view so triggering it
            // here works.
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

    private func row(_ tag: HeadSidebarTab, _ key: String, _ icon: String) -> some View {
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
    /// the iPhone tab bar / More menu pushes. The Profile case uses
    /// `nestedInNavStack: true` because the NavigationSplitView's
    /// detail column already provides nav chrome — nesting another
    /// NavigationStack would corrupt the destination registry (the
    /// trap that was documented in the More-tab nav saga).
    @ViewBuilder
    private var sidebarDetail: some View {
        switch selection {
        case .dashboard:     DashboardView()
        case .members:       HeadMembersView()
        case .opportunities: HeadOpportunitiesView()
        case .hours:         HoursApprovalView(mode: .headQueue)
        case .projects:      HeadProjectsView()
        case .attendance:    AttendanceView()
        case .applications:  ApplicationsView()
        case .thanks:        ThanksView()
        case .certs:         HeadCertsView()
        case .profile:       ProfileView(nestedInNavStack: true)
        }
    }
}

// MARK: - "More" tab — Projects, Attendance, Applications, Thanks, Certs, Profile

/// File-scope (non-private) so the navigationDestination modifier and
/// the NavigationLink value can both see the same type unambiguously.
enum HeadMoreDestination: Hashable {
    case projects, attendance, applications, thanks, certs, profile
}

private struct HeadMoreView: View {
    @EnvironmentObject private var session: SessionStore
    @Binding var path: NavigationPath
    @State private var showSignOutConfirm: Bool = false

    var body: some View {
        NavigationStack(path: $path) {
            ScrollView {
                VStack(spacing: 10) {
                    row(.projects,     icon: "folder.fill",         key: "hp.tabs.projects")
                    row(.attendance,   icon: "checkmark.rectangle", key: "hp.tabs.attendance")
                    row(.applications, icon: "doc.text.fill",       key: "hp.tabs.applications")
                    row(.thanks,       icon: "envelope.badge",      key: "hp.tabs.thanks")
                    row(.certs,        icon: "doc.badge.gearshape", key: "hp.tabs.certs")
                    row(.profile,      icon: "person.circle",       key: "hp.tabs.profile")
                    // Sign out directly under Profile — mirrors the
                    // Admin More menu. Useful even for heads (with a
                    // member link) as a shortcut, and essential for
                    // dev/admin sessions where Profile won't load.
                    signOutRow
                }
                .ipadContentWidth()
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
            }
            .background(Color.ssCream)
            .navigationTitle(LocalizedStringKey("hp.tabs.more"))
            .navigationBarTitleDisplayMode(.inline)
            // Attached directly to the NavigationStack's immediate
            // content. Must be on a view INSIDE the stack — the
            // value-based NavigationLink writes into `path`, so
            // resetting `path` to empty actually pops to root.
            .navigationDestination(for: HeadMoreDestination.self) { dest in
                switch dest {
                case .projects:     HeadProjectsView()
                case .attendance:   AttendanceView()
                case .applications: ApplicationsView()
                case .thanks:       ThanksView()
                case .certs:        HeadCertsView()
                case .profile:      ProfileView(nestedInNavStack: true)
                }
            }
            // Centered system-style alert — matches the iOS settings
            // restart-prompt look (full overlay, centered modal card).
            // See AdminTabView for the rationale.
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

    /// Value-based NavigationLink so the push registers on the bound
    /// NavigationPath. NavigationLink(destination:) wouldn't — it
    /// pushes outside the path tracking, which made the
    /// tab-reentry-pops-to-root logic a no-op.
    private func row(_ dest: HeadMoreDestination, icon: String, key: String) -> some View {
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
