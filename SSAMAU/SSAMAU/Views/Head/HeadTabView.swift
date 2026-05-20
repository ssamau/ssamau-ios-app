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
    /// More menu specifically that feels wrong — the tab IS the menu, so
    /// you expect the menu when you come back.
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
    /// path whenever it becomes active (re-tap while active OR coming
    /// back from another tab). Other tabs preserve their state per iOS
    /// default.
    private var tabSelectionBinding: Binding<Tab> {
        Binding(
            get: { selection },
            set: { newValue in
                if newValue == .more {
                    morePath = NavigationPath()
                }
                selection = newValue
            }
        )
    }
}

// MARK: - "More" tab — Projects, Attendance, Applications, Thanks, Certs, Profile

private struct HeadMoreView: View {
    @Binding var path: NavigationPath

    var body: some View {
        NavigationStack(path: $path) {
            ScrollView {
                VStack(spacing: 10) {
                    row(icon: "folder.fill",         key: "hp.tabs.projects")     { HeadProjectsView() }
                    row(icon: "checkmark.rectangle", key: "hp.tabs.attendance")   { AttendanceView() }
                    row(icon: "doc.text.fill",       key: "hp.tabs.applications") { ApplicationsView() }
                    row(icon: "envelope.badge",      key: "hp.tabs.thanks")       { ThanksView() }
                    row(icon: "doc.badge.gearshape", key: "hp.tabs.certs")        { HeadCertsView() }
                    row(icon: "person.circle",       key: "hp.tabs.profile")      { ProfileView() }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
            }
            .background(Color.ssCream)
            .navigationTitle(LocalizedStringKey("hp.tabs.more"))
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    /// Direct-destination NavigationLink. Avoids the value/destination
    /// dance which trips SwiftUI's "no matching navigationDestination"
    /// warning when the .navigationDestination modifier sits on ScrollView.
    private func row<Destination: View>(
        icon: String,
        key: String,
        @ViewBuilder destination: @escaping () -> Destination
    ) -> some View {
        NavigationLink {
            destination()
        } label: {
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
