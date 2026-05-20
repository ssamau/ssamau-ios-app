import SwiftUI

/// Member-mode tab bar — spec §7.
/// Profile is real; Opportunities / MyTasks / Hours / Certificates are
/// stubs until Phase 2 wires them.
struct MemberTabView: View {
    var body: some View {
        TabView {
            OpportunitiesView()
                .tabItem {
                    Label(LocalizedStringKey("mp.tabs.opportunities"),
                          systemImage: "list.bullet.rectangle")
                }

            TabStub(
                titleKey: "mp.tabs.tasks",
                systemImage: "checkmark.circle"
            )
            .tabItem {
                Label(LocalizedStringKey("mp.tabs.tasks"),
                      systemImage: "checkmark.circle")
            }

            TabStub(
                titleKey: "mp.tabs.hours",
                systemImage: "clock.badge.checkmark"
            )
            .tabItem {
                Label(LocalizedStringKey("mp.tabs.hours"),
                      systemImage: "clock.badge.checkmark")
            }

            TabStub(
                titleKey: "mp.tabs.certs",
                systemImage: "doc.badge.gearshape"
            )
            .tabItem {
                Label(LocalizedStringKey("mp.tabs.certs"),
                      systemImage: "doc.badge.gearshape")
            }

            ProfileView()
                .tabItem {
                    Label(LocalizedStringKey("mp.tabs.profile"),
                          systemImage: "person.circle")
                }
        }
        .tint(Color.ssGreen)
    }
}

/// Placeholder shown for any tab whose real view ships in a later phase.
private struct TabStub: View {
    let titleKey: LocalizedStringKey
    let systemImage: String

    var body: some View {
        VStack(spacing: 14) {
            Image(systemName: systemImage)
                .font(.system(size: 48))
                .foregroundStyle(Color.ssGold)
            Text(titleKey)
                .font(.ssH2)
                .foregroundStyle(Color.ssGreen)
            GoldRule(width: 32)
            Text(LocalizedStringKey("mp.tabs.coming_soon"))
                .font(.ssCaption)
                .foregroundStyle(Color.ssGrey)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.ssCream)
    }
}
