import SwiftUI

/// Member-mode primary navigation — spec §7.
///
/// Adaptive: bottom `TabView` on iPhone / compact width (unchanged
/// from the original implementation), `NavigationSplitView` with
/// sidebar on iPad regular width and Mac Catalyst (the new path).
/// Both layouts share the same `selection` binding so rotating an
/// iPad or dragging the app into Split View preserves the user's
/// current screen.
///
/// Member portal has no More menu (only 5 destinations), which makes
/// it the safest first conversion to validate the AdaptiveTabSidebar
/// wrapper — Phase 2 sub-B.
struct MemberTabView: View {
    @State private var selection: MemberTab = .opportunities

    enum MemberTab: Hashable {
        case opportunities, tasks, hours, certs, profile
    }

    /// One ungrouped section. Order matches the original tab bar so
    /// the iPhone bottom bar looks identical to before.
    private var sections: [SidebarSection<MemberTab>] {
        [
            .main([
                SidebarItem(
                    tag: .opportunities,
                    label: "mp.tabs.opportunities",
                    systemImage: "list.bullet.rectangle"
                ),
                SidebarItem(
                    tag: .tasks,
                    label: "mp.tabs.tasks",
                    systemImage: "checkmark.circle"
                ),
                SidebarItem(
                    tag: .hours,
                    label: "mp.tabs.hours",
                    systemImage: "clock.badge.checkmark"
                ),
                SidebarItem(
                    tag: .certs,
                    label: "mp.tabs.certs",
                    systemImage: "doc.badge.gearshape"
                ),
                SidebarItem(
                    tag: .profile,
                    label: "mp.tabs.profile",
                    systemImage: "person.circle"
                ),
            ])
        ]
    }

    var body: some View {
        AdaptiveTabSidebar(
            sections: sections,
            selection: $selection,
            detail: { tab in
                // @ViewBuilder + switch returns _ConditionalContent;
                // each branch hands back the same fully-wrapped screen
                // the original tab bar showed. Each of these views
                // wraps itself in NavigationStack so the detail column
                // gets its own nav chrome on iPad (title, push state).
                switch tab {
                case .opportunities: OpportunitiesView()
                case .tasks:         MyTasksView()
                case .hours:         HoursView()
                case .certs:         CertificatesView()
                case .profile:       ProfileView()
                }
            },
            sidebarTitleKey: "brand.ssam_full"
        )
    }
}
