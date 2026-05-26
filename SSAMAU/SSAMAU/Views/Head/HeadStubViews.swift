import SwiftUI

/// Placeholder views for the head-side screens that haven't been built
/// yet. Each one is replaced by a real implementation in its own commit
/// (tasks #20-#28). Until then they show a branded "coming soon" panel
/// with the screen's icon + name so navigation is exercisable.

struct HeadProjectsView: View {
    var body: some View {
        HeadComingSoon(
            titleKey: "hp.tabs.projects",
            systemImage: "folder.fill"
        )
        .navigationTitle(LocalizedStringKey("hp.tabs.projects"))
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct AttendanceView: View {
    var body: some View {
        HeadComingSoon(
            titleKey: "hp.tabs.attendance",
            systemImage: "checkmark.rectangle"
        )
        .navigationTitle(LocalizedStringKey("hp.tabs.attendance"))
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct ApplicationsView: View {
    var body: some View {
        HeadComingSoon(
            titleKey: "hp.tabs.applications",
            systemImage: "doc.text.fill"
        )
        .navigationTitle(LocalizedStringKey("hp.tabs.applications"))
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct ThanksView: View {
    var body: some View {
        HeadComingSoon(
            titleKey: "hp.tabs.thanks",
            systemImage: "envelope.badge"
        )
        .navigationTitle(LocalizedStringKey("hp.tabs.thanks"))
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct HeadCertsView: View {
    var body: some View {
        HeadComingSoon(
            titleKey: "hp.tabs.certs",
            systemImage: "doc.badge.gearshape"
        )
        .navigationTitle(LocalizedStringKey("hp.tabs.certs"))
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Shared "coming soon" panel

private struct HeadComingSoon: View {
    let titleKey: String
    let systemImage: String

    var body: some View {
        VStack(spacing: 14) {
            Image(systemName: systemImage)
                .font(.system(size: 48))
                .foregroundStyle(Color.ssGold)
            Text(LocalizedStringKey(titleKey))
                .font(.ssH2)
                .foregroundStyle(Color.ssGreen)
            GoldRule(width: 32)
            Text(LocalizedStringKey("hp.coming_soon"))
                .font(.ssCaption)
                .foregroundStyle(Color.ssGrey)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.ssCream)
    }
}
