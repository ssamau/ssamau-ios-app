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

            NavigationStack { HeadOpportunitiesView() }
                .tabItem {
                    Label(LocalizedStringKey("ap.tabs.opportunities"),
                          systemImage: "list.bullet.rectangle")
                }
                .tag(Tab.opportunities)

            NavigationStack { HoursApprovalView(mode: .adminFinalApproval) }
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

    var body: some View {
        NavigationStack(path: $path) {
            ScrollView {
                VStack(spacing: 10) {
                    row(.projects,     icon: "folder.fill",          key: "ap.tabs.projects")
                    row(.attendance,   icon: "checkmark.rectangle",  key: "ap.tabs.attendance")
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
        }
    }

    private func row(_ dest: AdminMoreDestination, icon: String, key: String) -> some View {
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
