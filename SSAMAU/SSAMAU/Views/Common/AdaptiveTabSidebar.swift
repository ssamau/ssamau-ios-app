import SwiftUI

/// Adaptive primary-navigation chrome.
///
/// On compact width (iPhone, iPad in narrow Split View, Slide Over) this
/// renders a standard bottom `TabView` — the iOS pattern the rest of the
/// app was originally built against, so nothing about the iPhone
/// experience changes when a screen migrates to this wrapper.
///
/// On regular width (iPad in any layout wider than narrow Split View,
/// Mac via Catalyst once we get there) it renders a `NavigationSplitView`
/// with a left-hand sidebar and a detail column on the right. Items are
/// grouped into optional sections so the "More menu" items on Head /
/// Admin can become a flat second section in the sidebar instead of
/// being buried behind a tab tap.
///
/// Generic over the selection type. Pass anything `Hashable` —
/// typically a per-role enum like `HeadTab.dashboard / .members / …`.
/// The wrapper keeps the same `selection` binding wired through both
/// layouts so size-class transitions (e.g. rotating an iPad or dragging
/// the app from full-screen into Split View) preserve which screen the
/// user was on.
///
/// iOS 16+ compatible. Doesn't depend on iOS 18's `.sidebarAdaptable`
/// `TabView` style, which would force a deployment-target bump and cut
/// off the slice of members still on iOS 16/17 hardware.
struct AdaptiveTabSidebar<Selection: Hashable, Detail: View>: View {
    @Environment(\.horizontalSizeClass) private var hSizeClass

    /// The grouped list of items. Order within a section is preserved.
    let sections: [SidebarSection<Selection>]
    /// Two-way binding to the currently-selected item. Stored by the
    /// caller (typically as `@State` on the wrapping tab view) so the
    /// selection survives size-class transitions.
    @Binding var selection: Selection
    /// Builds the detail screen for a given selection. Called by both
    /// the compact and regular branches with the same value, so a
    /// single switch statement works.
    @ViewBuilder let detail: (Selection) -> Detail

    /// Localized navigation title shown above the detail column on
    /// iPad. Defaults to nothing (each detail view brings its own
    /// title). Pass a value when you want the sidebar to add a
    /// consistent header above the list of rows.
    var sidebarTitleKey: LocalizedStringKey?

    /// Flat view of all items across all sections, used by the
    /// compact-width TabView branch (TabView doesn't section).
    private var allItems: [SidebarItem<Selection>] {
        sections.flatMap(\.items)
    }

    var body: some View {
        if hSizeClass == .regular {
            regularLayout
        } else {
            compactLayout
        }
    }

    // MARK: - Compact: bottom TabView (existing iPhone behaviour)

    private var compactLayout: some View {
        TabView(selection: $selection) {
            ForEach(allItems) { item in
                detail(item.tag)
                    .tabItem {
                        Label {
                            Text(item.label)
                        } icon: {
                            Image(systemName: item.systemImage)
                        }
                    }
                    .tag(item.tag)
            }
        }
        .tint(Color.ssGreen)
    }

    // MARK: - Regular: NavigationSplitView with sidebar (iPad / Mac Catalyst)

    private var regularLayout: some View {
        // List's single-select init on iOS requires an Optional
        // binding. The wrapper exposes a non-optional Selection because
        // the compact TabView path needs one — we wrap-unwrap here so
        // both layouts share the same upstream binding.
        let optionalSelection = Binding<Selection?>(
            get: { selection },
            set: { newValue in
                if let new = newValue { selection = new }
            }
        )
        return NavigationSplitView {
            List(selection: optionalSelection) {
                ForEach(sections) { section in
                    Section {
                        ForEach(section.items) { item in
                            sidebarRow(item)
                        }
                    } header: {
                        if let header = section.headerKey {
                            Text(header)
                                .font(.ssLatinLabel)
                                .tracking(1.5)
                                .foregroundStyle(Color.ssGold)
                        }
                    }
                }
            }
            .listStyle(.sidebar)
            .navigationTitle(sidebarTitleKey ?? "")
            .scrollContentBackground(.hidden)
            .background(Color.ssCream)
        } detail: {
            detail(selection)
        }
        .tint(Color.ssGreen)
        // ⌘1…⌘9/⌘0 jump straight to a sidebar destination. Regular
        // width only — the compact TabView path is left byte-identical.
        .ssKeyboardShortcuts(
            SSKeyboardShortcut.numbered(allItems.map(\.tag)) { tag in
                selection = tag
            }
        )
    }

    /// One sidebar row: gold icon, brand-aligned label, .ssHover for
    /// pointer feedback. Tap = select (NavigationSplitView wires this
    /// to the bound `selection` automatically because the row's tag
    /// matches a value in `selection`'s type).
    private func sidebarRow(_ item: SidebarItem<Selection>) -> some View {
        Label {
            Text(item.label)
                .font(.ssBody)
                .foregroundStyle(Color.ssCharcoal)
        } icon: {
            Image(systemName: item.systemImage)
                .foregroundStyle(item.iconTint ?? Color.ssGold)
        }
        .tag(item.tag)
        .ssHover()
    }
}

// MARK: - Data types

/// One sidebar / tab destination. `tag` is the unique selection value
/// (typically a per-role enum case). `label` is localised; pass a
/// localised string from your strings table.
struct SidebarItem<Tag: Hashable>: Identifiable {
    let tag: Tag
    let label: LocalizedStringKey
    let systemImage: String
    /// Overrides the default gold tint, e.g. red for Sign Out.
    var iconTint: Color?

    /// `id` derives from `tag` so the same item id is stable across
    /// re-renders. `tag` must be `Hashable`, which `id` requires.
    var id: Tag { tag }
}

/// A grouped section of sidebar items. The header is shown only in the
/// sidebar layout, not in the compact TabView layout (TabView is
/// inherently flat). Headers are optional — pass `nil` for an unlabeled
/// section, e.g. the primary tabs on Head / Admin.
struct SidebarSection<Tag: Hashable>: Identifiable {
    let id = UUID()
    let headerKey: LocalizedStringKey?
    let items: [SidebarItem<Tag>]

    /// Convenience init: ungrouped, no header.
    static func main(_ items: [SidebarItem<Tag>]) -> SidebarSection<Tag> {
        SidebarSection(headerKey: nil, items: items)
    }

    /// Convenience init: labeled section.
    static func grouped(_ headerKey: LocalizedStringKey, _ items: [SidebarItem<Tag>]) -> SidebarSection<Tag> {
        SidebarSection(headerKey: headerKey, items: items)
    }
}
