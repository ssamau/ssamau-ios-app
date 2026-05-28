import SwiftUI

/// Head-mode tab bar — spec §7.
///
/// Five tabs + a "More" sheet for the overflow. Real views land
/// incrementally; everything starts as a stub view so navigation works
/// from day one.
struct HeadTabView: View {
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

    var body: some View {
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
