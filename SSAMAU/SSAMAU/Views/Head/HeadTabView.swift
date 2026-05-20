import SwiftUI

/// Head-mode tab bar — spec §7.
///
/// Five tabs + a "More" sheet for the overflow. Real views land
/// incrementally; everything starts as a stub view so navigation works
/// from day one.
struct HeadTabView: View {
    var body: some View {
        TabView {
            DashboardView()
                .tabItem {
                    Label(LocalizedStringKey("hp.tabs.dashboard"),
                          systemImage: "chart.bar")
                }

            HeadMembersView()
                .tabItem {
                    Label(LocalizedStringKey("hp.tabs.members"),
                          systemImage: "person.2")
                }

            HeadOpportunitiesView()
                .tabItem {
                    Label(LocalizedStringKey("hp.tabs.opportunities"),
                          systemImage: "list.bullet.rectangle")
                }

            HoursApprovalView()
                .tabItem {
                    Label(LocalizedStringKey("hp.tabs.hours"),
                          systemImage: "clock.badge.checkmark")
                }

            HeadMoreView()
                .tabItem {
                    Label(LocalizedStringKey("hp.tabs.more"),
                          systemImage: "ellipsis.circle")
                }
        }
        .tint(Color.ssGreen)
    }
}

// MARK: - "More" tab — Projects, Attendance, Applications, Thanks, Certs, Profile

private struct HeadMoreView: View {
    var body: some View {
        NavigationStack {
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
