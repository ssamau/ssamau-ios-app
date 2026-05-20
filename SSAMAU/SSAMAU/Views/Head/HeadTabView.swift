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

            HoursApprovalView()
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

    /// Intercepts tab selection so we can reset the More tab's navigation
    /// path. Reset happens whenever the user was just on More — covers
    /// both "leaving More for another tab" AND "re-tapping More while
    /// already there". By resetting on LEAVE (not on entry), the next
    /// visit lands on the More menu without the user seeing the old
    /// sub-page slide in during the tab transition. Other tabs preserve
    /// their state per iOS default.
    private var tabSelectionBinding: Binding<Tab> {
        Binding(
            get: { selection },
            set: { newValue in
                if selection == .more {
                    morePath = NavigationPath()
                }
                selection = newValue
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
    @Binding var path: NavigationPath

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
                }
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
        }
    }

    /// Value-based NavigationLink so the push registers on the bound
    /// NavigationPath. NavigationLink(destination:) wouldn't — it
    /// pushes outside the path tracking, which made the
    /// tab-reentry-pops-to-root logic a no-op.
    private func row(_ dest: HeadMoreDestination, icon: String, key: String) -> some View {
        NavigationLink(value: dest) {
            HStack(spacing: 14) {
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundStyle(Color.ssGold)
                    .frame(width: 32)
                Text(LocalizedStringKey(key))
                    .font(.ssBody)
                    .foregroundStyle(Color.ssCharcoal)
                Spacer()
                Image(systemName: "chevron.forward")
                    .foregroundStyle(Color.ssGrey)
                    .font(.caption)
            }
            .padding(14)
            .background(Color.ssPale)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.ssGold.opacity(0.4), lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
    }
}
